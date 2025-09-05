<?php

/**
 * Flex controller endpoint for module (create/capture/refund/get checkout sessions).
 *
 * @package   OpenEMR
 * @link      https://www.open-emr.org
 */

require_once __DIR__ . "/../../../../globals.php";

use OpenEMR\Modules\FlexPayments\Bootstrap;
use OpenEMR\Modules\FlexPayments\FlexGatewayService;

header('Content-Type: application/json');

try {
    $bootstrap = new Bootstrap($GLOBALS['kernel']->getEventDispatcher(), $GLOBALS['kernel']);
    $config = $bootstrap->getGlobalConfig();
    if (!$config->getGlobalSetting(\OpenEMR\Modules\FlexPayments\GlobalConfig::FLEX_ENABLE)) {
        http_response_code(404);
        echo json_encode(['error' => 'Flex gateway not enabled']);
        exit;
    }

    $service = new FlexGatewayService($config);
    if (!$service->isConfigured()) {
        http_response_code(400);
        echo json_encode(['error' => 'Flex gateway not configured']);
        exit;
    }

    $mode = $_GET['mode'] ?? $_POST['mode'] ?? null;
    $raw = file_get_contents('php://input');
    $payload = [];
    if (!empty($raw)) {
        $dec = json_decode($raw, true);
        if (is_array($dec)) {
            $payload = $dec;
        }
    }

    switch ($mode) {
        case 'create_checkout': {
            // Optionally allow mobile CORS
            $allowCors = $config->getGlobalSetting(\OpenEMR\Modules\FlexPayments\GlobalConfig::FLEX_ALLOW_MOBILE_CORS);
            if ($allowCors) {
                header('Access-Control-Allow-Origin: *');
                header('Vary: Origin');
                header('Access-Control-Allow-Headers: Content-Type');
                header('Access-Control-Allow-Methods: POST, OPTIONS');
                if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { exit; }
            }

            // Verify HMAC signature if configured (for mobile app calls)
            $ver = \OpenEMR\Modules\FlexPayments\MobileHmacVerifier::verify($payload, $config);
            if (!($ver['ok'] ?? false)) { http_response_code(400); echo json_encode(['error' => $ver['error'] ?? 'sign_failed']); break; }

            $amount = $payload['amount'] ?? $_POST['amount'] ?? null;
            $currency = $payload['currency'] ?? $_POST['currency'] ?? 'usd';
            $metadata = $payload['metadata'] ?? [];
            // Build return URLs pointing back into this module
            $base = $GLOBALS['webroot'] . "/interface/modules/custom_modules/" . basename(dirname(__DIR__)) . "/public";
            $successUrl = $payload['success_url'] ?? ($base . "/flex_return.php?status=success");
            $cancelUrl = $payload['cancel_url'] ?? ($base . "/flex_return.php?status=cancel");
            $res = $service->createCheckoutSession($amount, $currency, $metadata, $successUrl, $cancelUrl);
            echo json_encode($res);
            break;
        }
        case 'capture_checkout': {
            $id = $payload['id'] ?? $_POST['id'] ?? null;
            if (empty($id)) {
                http_response_code(400);
                echo json_encode(['error' => 'missing id']);
                break;
            }
            echo json_encode($service->captureCheckoutSession($id));
            break;
        }
        case 'refund_checkout': {
            $id = $payload['id'] ?? $_POST['id'] ?? null;
            $amount = $payload['amount'] ?? $_POST['amount'] ?? null;
            if (empty($id)) {
                http_response_code(400);
                echo json_encode(['error' => 'missing id']);
                break;
            }
            $resp = $service->refundCheckoutSession($id, $amount);
            // Auto-post AR refund if enabled
            $bootstrap = new Bootstrap($GLOBALS['kernel']->getEventDispatcher(), $GLOBALS['kernel']);
            $cfg = $bootstrap->getGlobalConfig();
            if ($cfg->getGlobalSetting(\OpenEMR\Modules\FlexPayments\GlobalConfig::FLEX_AUTO_POST_REFUNDS)) {
                $amt = null;
                if ($amount !== null && $amount !== '') { $amt = (float)$amount; }
                // Try to find amount in response if not given
                if ($amt === null) {
                    if (isset($resp['amount'])) { $amt = (float)$resp['amount']; }
                    elseif (isset($resp['refund']) && isset($resp['refund']['amount'])) { $amt = (float)$resp['refund']['amount']; }
                }
                if ($amt !== null) {
                    try {
                        \OpenEMR\Modules\FlexPayments\RefundReconciler::postRefundARBySession($id, (float)$amt, 'controller', null);
                    } catch (\Throwable $e) {
                        // swallow but attach note in response
                        $resp['_ar_error'] = $e->getMessage();
                    }
                } else {
                    $resp['_ar_error'] = 'refund_amount_unknown';
                }
            }
            echo json_encode($resp);
            break;
        }
        case 'send_receipt_intent': {
            $id = $payload['id'] ?? $_POST['id'] ?? null;
            if (empty($id)) {
                http_response_code(400);
                echo json_encode(['error' => 'missing id']);
                break;
            }
            echo json_encode($service->sendReceiptPaymentIntent($id));
            break;
        }
        case 'send_receipt_checkout': {
            $id = $payload['id'] ?? $_POST['id'] ?? null;
            if (empty($id)) {
                http_response_code(400);
                echo json_encode(['error' => 'missing id']);
                break;
            }
            echo json_encode($service->sendReceiptByCheckoutSession($id));
            break;
        }
        case 'get_checkout': {
            $id = $_GET['id'] ?? null;
            if (empty($id)) {
                http_response_code(400);
                echo json_encode(['error' => 'missing id']);
                break;
            }
            echo json_encode($service->getCheckoutSession($id));
            break;
        }
        default: {
            http_response_code(404);
            echo json_encode(['error' => 'unknown mode']);
        }
    }
} catch (\Throwable $e) {
    http_response_code(500);
    echo json_encode(['error' => $e->getMessage()]);
}
