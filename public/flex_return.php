<?php

/**
 * Flex return handler. If opened with an opener (front_payment.php), attempts to
 * set the reference and submit the payment form automatically.
 *
 * @package   OpenEMR
 */

require_once __DIR__ . "/../../../../globals.php";

use OpenEMR\Core\Header;

$status = $_GET['status'] ?? '';
$sessionId = $_GET['session_id'] ?? ($_GET['id'] ?? '');

?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8" />
    <title><?php echo xlt('Flex Return'); ?></title>
    <?php Header::setupHeader(['opener']); ?>
</head>
<body>
<div class="container mt-3">
    <h4><?php echo xlt('Flex Checkout Status'); ?>: <?php echo text($status ?: ''); ?></h4>
    <?php if (!empty($sessionId)) { ?>
        <p><?php echo xlt('Session'); ?>: <code><?php echo text($sessionId); ?></code></p>
    <?php } ?>
    <p class="text-muted small"><?php echo xlt('This window will attempt to post back to the payment screen if opened from there.'); ?></p>
</div>

<?php
// Immediate capture attempt on success
if ($status === 'success' && !empty($sessionId)) {
    try {
        $bootstrap = new \OpenEMR\Modules\FlexPayments\Bootstrap($GLOBALS['kernel']->getEventDispatcher(), $GLOBALS['kernel']);
        $config = $bootstrap->getGlobalConfig();
        if ($config->getGlobalSetting(\OpenEMR\Modules\FlexPayments\GlobalConfig::FLEX_ENABLE)) {
            $service = new \OpenEMR\Modules\FlexPayments\FlexGatewayService($config);
            if ($service->isConfigured()) {
                // Attempt capture; ignore errors if already captured
                try { $service->captureCheckoutSession($sessionId); } catch (\Throwable $e) { /* noop */ }
            }
        }
    } catch (\Throwable $e) { /* noop */ }
}
?>

<script>
(function(){
    try {
        var sessionId = <?php echo json_encode($sessionId); ?>;
        var ok = <?php echo json_encode($status === 'success'); ?>;
        if (window.opener && ok) {
            var doc = window.opener.document;
            var ref = doc.getElementById('check_number');
            if (ref) { ref.value = sessionId || ('FLEX-' + Date.now()); }
            var methodSelect = doc.querySelector("select[name='payment_method1']");
            if (methodSelect) {
                var found = false;
                for (var i = 0; i < methodSelect.options.length; i++) {
                    var t = methodSelect.options[i].text || '';
                    if (/card|credit/i.test(t)) { methodSelect.selectedIndex = i; found = true; break; }
                }
            }
            var saveBtn = doc.querySelector("[name='form_save']");
            if (saveBtn) { saveBtn.click(); }
            window.close();
        }
    } catch (e) {
        // ignore
    }
})();
</script>

</body>
</html>
