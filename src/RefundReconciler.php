<?php

namespace OpenEMR\Modules\FlexPayments;

/**
 * Posts AR reversals for Flex refunds and records a simple audit trail.
 */
class RefundReconciler
{
    public static function ensureTable(): void
    {
        $sql = "CREATE TABLE IF NOT EXISTS module_flex_refunds (
            id INT AUTO_INCREMENT PRIMARY KEY,
            session_id VARCHAR(128) NOT NULL,
            event_id VARCHAR(128) DEFAULT NULL,
            amount DECIMAL(12,2) NOT NULL,
            source VARCHAR(32) NOT NULL,
            ar_session_id INT DEFAULT NULL,
            ar_activity_id INT DEFAULT NULL,
            created_at DATETIME NOT NULL
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8";
        sqlStatement($sql);
    }

    public static function hasProcessed(?string $eventId): bool
    {
        if (empty($eventId)) { return false; }
        $row = sqlQuery("SELECT id FROM module_flex_refunds WHERE event_id = ? LIMIT 1", [$eventId]);
        return !empty($row['id']);
    }

    public static function record(string $sessionId, float $amount, string $source, ?string $eventId, ?int $arSessionId, ?int $arActivityId): void
    {
        sqlStatement(
            "INSERT INTO module_flex_refunds (session_id, event_id, amount, source, ar_session_id, ar_activity_id, created_at) VALUES (?,?,?,?,?,?,NOW())",
            [$sessionId, $eventId, $amount, $source, $arSessionId, $arActivityId]
        );
    }

    public static function findPaymentBySession(string $sessionId)
    {
        return sqlQuery("SELECT * FROM payments WHERE source = ? ORDER BY dtime DESC LIMIT 1", [$sessionId]);
    }

    public static function postRefundARBySession(string $sessionId, float $amount, string $source = 'controller', ?string $eventId = null): array
    {
        self::ensureTable();
        if (self::hasProcessed($eventId)) {
            return ['ok' => true, 'skipped' => 'already_processed'];
        }

        $payment = self::findPaymentBySession($sessionId);
        if (empty($payment)) {
            return ['ok' => false, 'error' => 'payment_not_found'];
        }
        $pid = (int)$payment['pid'];
        $encounter = (int)($payment['encounter'] ?? 0);

        // Create AR session (negative pay_total)
        $userId = $_SESSION['authUserID'] ?? 0;
        $desc = 'Flex refund';
        $arSessionId = sqlInsert(
            "INSERT INTO ar_session (payer_id,user_id,reference,check_date,deposit_date,pay_total,global_amount,payment_type,description,patient_id,payment_method,adjustment_code,post_to_date) ".
            " VALUES ('0',?,?,?,?,?,'','patient',?,?,?,'refund',NOW())",
            [$userId, $sessionId, date('Y-m-d'), date('Y-m-d'), -1 * abs($amount), $pid, 'credit card']
        );

        // Insert AR activity negative pay_amount
        sqlStatement("START TRANSACTION");
        $seq = sqlQuery("SELECT IFNULL(MAX(sequence_no),0) + 1 AS increment FROM ar_activity WHERE pid = ? AND encounter = ?", [$pid, $encounter]);
        $sequenceNo = (int)($seq['increment'] ?? 1);
        $arActivityId = sqlInsert(
            "INSERT INTO ar_activity (pid,encounter,sequence_no,payer_type,post_time,post_user,session_id,pay_amount,adj_amount,account_code) ".
            " VALUES (?,?,?,?,NOW(),?,?,?,0,'Refund')",
            [$pid, $encounter, $sequenceNo, 0, $userId, $arSessionId, -1 * abs($amount)]
        );
        sqlStatement("COMMIT");

        self::record($sessionId, abs($amount), $source, $eventId, $arSessionId, $arActivityId);

        return ['ok' => true, 'ar_session_id' => $arSessionId, 'ar_activity_id' => $arActivityId];
    }
}

