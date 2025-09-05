<?php

namespace OpenEMR\Modules\FlexPayments;

use OpenEMR\Common\Crypto\CryptoGen;

class MobileHmacVerifier
{
    public static function verify(array $payload, GlobalConfig $config): array
    {
        $secretEnc = $config->getGlobalSetting(GlobalConfig::FLEX_MOBILE_HMAC_SECRET_ENCRYPTED) ?? '';
        if (empty($secretEnc)) {
            return ['ok' => true, 'skipped' => true];
        }
        $secret = (new CryptoGen())->decryptStandard($secretEnc) ?? '';
        if (empty($secret)) {
            return ['ok' => false, 'error' => 'hmac_secret_unavailable'];
        }

        $ts = $payload['ts'] ?? null;
        $nonce = $payload['nonce'] ?? null;
        $sig = $payload['signature'] ?? null;
        if (empty($ts) || empty($nonce) || empty($sig)) {
            return ['ok' => false, 'error' => 'bad_sign'];
        }
        $tol = (int)($config->getGlobalSetting(GlobalConfig::FLEX_WEBHOOK_TOLERANCE_SECONDS) ?? 300);
        if ($tol > 0 && abs(time() - (int)$ts) > $tol) {
            return ['ok' => false, 'error' => 'expired'];
        }
        $amtStr = (string)($payload['amount'] ?? '');
        $curStr = (string)($payload['currency'] ?? '');
        $baseStr = $amtStr . '.' . $curStr . '.' . $ts . '.' . $nonce;
        $calc = hash_hmac('sha256', $baseStr, $secret);
        if (!hash_equals($calc, (string)$sig)) {
            return ['ok' => false, 'error' => 'invalid_sign'];
        }
        return ['ok' => true];
    }
}

