<?php

/**
 * Flex Gateway API wrapper for module usage.
 *
 * @package   OpenEMR
 * @link      https://www.open-emr.org
 */

namespace OpenEMR\Modules\FlexPayments;

use GuzzleHttp\Client;
use GuzzleHttp\Exception\GuzzleException;
use OpenEMR\Common\Crypto\CryptoGen;

class FlexGatewayService
{
    private string $apiBase;
    private string $apiKey;
    private bool $testMode;

    private Client $http;

    public function __construct(GlobalConfig $config)
    {
        $crypto = new CryptoGen();
        $this->apiBase = rtrim($config->getGlobalSetting(GlobalConfig::FLEX_API_BASE_URL) ?? 'https://api.withflex.com', '/');
        $this->apiKey = $crypto->decryptStandard($config->getGlobalSetting(GlobalConfig::FLEX_API_KEY_ENCRYPTED) ?? '') ?? '';
        $this->testMode = (bool)($config->getGlobalSetting(GlobalConfig::FLEX_TEST_MODE) ?? false);

        $this->http = new Client([
            'base_uri' => $this->apiBase,
            'timeout' => 15,
        ]);
    }

    public function isConfigured(): bool
    {
        return !empty($this->apiKey) && !empty($this->apiBase);
    }

    /**
     * Creates a Flex Checkout Session and returns the decoded response array.
     * @param int|string $amount Amount in smallest currency unit if required by API
     * @param string $currency ISO currency (e.g., 'usd')
     * @param array $metadata Additional metadata such as patient name/MRN
     * @param string $successUrl Redirect on success
     * @param string $cancelUrl Redirect on cancel
     * @return array
     * @throws GuzzleException
     */
    public function createCheckoutSession($amount, string $currency, array $metadata, string $successUrl, string $cancelUrl): array
    {
        $body = [
            'amount' => $amount,
            'currency' => $currency,
            'success_url' => $successUrl,
            'cancel_url' => $cancelUrl,
            'metadata' => $metadata,
        ];
        if ($this->testMode) {
            $body['test_mode'] = true;
        }

        $resp = $this->http->post('/v1/checkout/sessions', [
            'headers' => $this->authHeaders(),
            'json' => $body,
        ]);
        return json_decode((string)$resp->getBody(), true) ?: [];
    }

    /**
     * Capture an authorized Checkout Session.
     */
    public function captureCheckoutSession(string $sessionId): array
    {
        $resp = $this->http->post("/v1/checkout/sessions/{$sessionId}/capture", [
            'headers' => $this->authHeaders(),
        ]);
        return json_decode((string)$resp->getBody(), true) ?: [];
    }

    /**
     * Refund a Checkout Session (full or partial).
     */
    public function refundCheckoutSession(string $sessionId, $amount = null): array
    {
        $payload = [];
        if ($amount !== null) {
            $payload['amount'] = $amount;
        }
        $resp = $this->http->post("/v1/checkout/sessions/{$sessionId}/refund", [
            'headers' => $this->authHeaders(),
            'json' => $payload,
        ]);
        return json_decode((string)$resp->getBody(), true) ?: [];
    }

    /**
     * Get a Checkout Session by id.
     */
    public function getCheckoutSession(string $sessionId): array
    {
        $resp = $this->http->get("/v1/checkout/sessions/{$sessionId}", [
            'headers' => $this->authHeaders(),
        ]);
        return json_decode((string)$resp->getBody(), true) ?: [];
    }

    /**
     * Send a receipt for a payment intent (Flex API).
     */
    public function sendReceiptPaymentIntent(string $paymentIntentId): array
    {
        $resp = $this->http->post("/v1/payment_intents/{$paymentIntentId}/receipt", [
            'headers' => $this->authHeaders(),
        ]);
        return json_decode((string)$resp->getBody(), true) ?: [];
    }

    /**
     * Attempts to extract a Payment Intent ID from a Checkout Session payload.
     * Tries common keys and falls back to a recursive scan for keys containing 'payment_intent'.
     */
    public function findPaymentIntentIdFromSessionArray(array $session): ?string
    {
        // Try common direct keys first
        $candidates = [
            'payment_intent', 'payment_intent_id', 'latest_payment_intent',
        ];
        foreach ($candidates as $k) {
            if (!empty($session[$k]) && is_string($session[$k])) {
                return $session[$k];
            }
        }
        // Look into top-level nested keys where intent might live
        $nestedKeys = ['payment', 'charges', 'captures', 'data'];
        foreach ($nestedKeys as $nk) {
            if (!empty($session[$nk])) {
                $found = $this->scanForIntentId($session[$nk]);
                if ($found) { return $found; }
            }
        }
        // Fallback: recursive scan entire structure
        return $this->scanForIntentId($session);
    }

    private function scanForIntentId($val): ?string
    {
        if (is_array($val)) {
            foreach ($val as $k => $v) {
                if (is_string($v) && is_string($k) && stripos($k, 'payment_intent') !== false) {
                    return $v;
                }
                $found = $this->scanForIntentId($v);
                if ($found) { return $found; }
            }
        }
        return null;
    }

    /**
     * Sends a receipt using a Checkout Session by resolving its Payment Intent ID first.
     */
    public function sendReceiptByCheckoutSession(string $sessionId): array
    {
        $session = $this->getCheckoutSession($sessionId);
        $pi = $this->findPaymentIntentIdFromSessionArray($session);
        if (empty($pi)) {
            return ['error' => 'payment_intent_id_not_found', 'session' => $sessionId];
        }
        return $this->sendReceiptPaymentIntent($pi);
    }

    private function authHeaders(): array
    {
        return [
            'Authorization' => 'Bearer ' . $this->apiKey,
            'Accept' => 'application/json',
        ];
    }
}
