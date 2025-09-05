<?php

/**
 * Flex webhook endpoint (skeleton). Verifies payload and logs or processes events.
 * You will need to configure this URL in Flex and, if applicable, verify signatures.
 *
 * @package   OpenEMR
 */

require_once __DIR__ . "/../../../../globals.php";

use OpenEMR\Modules\FlexPayments\Bootstrap;
use OpenEMR\Common\Logging\SystemLogger;
use OpenEMR\Common\Crypto\CryptoGen;

header('Content-Type: application/json');

// Webhooks should not require auth, but they must not leak sensitive info

$logger = new SystemLogger();

try {
    $bootstrap = new Bootstrap($GLOBALS['kernel']->getEventDispatcher(), $GLOBALS['kernel']);
    $config = $bootstrap->getGlobalConfig();

    if (!$config->getGlobalSetting(\OpenEMR\Modules\FlexPayments\GlobalConfig::FLEX_ENABLE)) {
        http_response_code(404);
        echo json_encode(['error' => 'Flex gateway not enabled']);
        exit;
    }

    $secretEnc = $config->getGlobalSetting(\OpenEMR\Modules\FlexPayments\GlobalConfig::FLEX_WEBHOOK_SECRET_ENCRYPTED) ?? '';
    $sigHeaderName = $config->getGlobalSetting(\OpenEMR\Modules\FlexPayments\GlobalConfig::FLEX_WEBHOOK_SIGNATURE_HEADER) ?? 'Flex-Signature';
    $tolerance = (int)($config->getGlobalSetting(\OpenEMR\Modules\FlexPayments\GlobalConfig::FLEX_WEBHOOK_TOLERANCE_SECONDS) ?? 300);

    $raw = file_get_contents('php://input');
    $hdrs = function_exists('getallheaders') ? getallheaders() : [];

    $logger->debug('Flex webhook received', [ 'len' => strlen($raw) ]);

    // Optional signature verification if a secret is configured
    if (!empty($secretEnc)) {
        $crypto = new CryptoGen();
        $secret = $crypto->decryptStandard($secretEnc) ?? '';
        $sigHeaderValue = '';
        // Case-insensitive header lookup
        foreach ($hdrs as $k => $v) {
            if (strcasecmp($k, $sigHeaderName) === 0) { $sigHeaderValue = trim((string)$v); break; }
        }
        if (empty($secret) || empty($sigHeaderValue)) {
            http_response_code(400);
            echo json_encode(['error' => 'missing signature']);
            exit;
        }

        $verified = false;
        $ts = null;
        // Support either a raw hex signature, or a key/value format like: t=timestamp,v1=hex
        if (strpos($sigHeaderValue, 'v1=') !== false) {
            // Parse format t=..., v1=...
            $parts = [];
            foreach (explode(',', $sigHeaderValue) as $seg) {
                $kv = array_map('trim', explode('=', $seg, 2));
                if (count($kv) === 2) { $parts[$kv[0]] = $kv[1]; }
            }
            $ts = isset($parts['t']) ? (int)$parts['t'] : null;
            $sig = $parts['v1'] ?? '';
            $signedPayload = ($ts !== null ? $ts . '.' : '') . $raw;
            $calc = hash_hmac('sha256', $signedPayload, $secret);
            $verified = hash_equals($calc, $sig);
            if ($verified && $ts !== null && $tolerance > 0) {
                if (abs(time() - $ts) > $tolerance) { $verified = false; }
            }
        } else {
            // Assume header is the hex signature for raw body
            $calc = hash_hmac('sha256', $raw, $secret);
            $verified = hash_equals($calc, $sigHeaderValue);
        }

        if (!$verified) {
            http_response_code(400);
            echo json_encode(['error' => 'invalid signature']);
            exit;
        }
    }

    $event = json_decode($raw, true) ?: [];
    if (empty($event)) {
        http_response_code(400);
        echo json_encode(['error' => 'invalid payload']);
        exit;
    }

    // Example event route
    $type = $event['type'] ?? '';
    switch ($type) {
        case 'payment_intent.succeeded':
            // no-op for now
            break;
        default:
            // Attempt refund reconcile on any event that includes a refund and a session id
            $eventId = $event['id'] ?? null;
            $data = $event['data'] ?? [];
            $obj = $data['object'] ?? [];
            $sessionId = $obj['checkout_session_id'] ?? ($obj['session_id'] ?? ($obj['id'] ?? ''));
            $amount = null;
            if (isset($obj['amount'])) { $amount = (float)$obj['amount']; }
            if (isset($obj['refund']) && isset($obj['refund']['amount'])) { $amount = (float)$obj['refund']['amount']; }
            if (is_string($type) && stripos($type, 'refund') !== false && !empty($sessionId) && !empty($amount)) {
                try {
                    \OpenEMR\Modules\FlexPayments\RefundReconciler::postRefundARBySession($sessionId, (float)$amount, 'webhook', $eventId);
                } catch (\Throwable $e) {
                    $logger->error('Flex webhook AR post error', ['message' => $e->getMessage()]);
                }
            }
            break;
    }

    echo json_encode(['ok' => true]);
} catch (\Throwable $e) {
    $logger->error('Flex webhook error', ['message' => $e->getMessage()]);
    http_response_code(500);
    echo json_encode(['error' => 'server error']);
}
