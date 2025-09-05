<?php

/**
 * Module Settings/Config visibility page for the Flex gateway integration.
 * Shows current values and links to Admin -> Globals where settings are edited.
 *
 * @package   OpenEMR
 */

require_once __DIR__ . "/../../../../globals.php";

use OpenEMR\Core\Header;
use OpenEMR\Common\Acl\AclMain;
use OpenEMR\Modules\FlexPayments\Bootstrap;

if (!AclMain::aclCheckCore('admin', 'super') && !AclMain::aclCheckCore('admin', 'admin')) {
    echo (new \OpenEMR\Common\Twig\TwigContainer(null, $GLOBALS['kernel']))->getTwig()->render('core/unauthorized.html.twig', ['pageTitle' => xl('Flex Settings')]);
    exit;
}

$bootstrap = new Bootstrap($GLOBALS['kernel']->getEventDispatcher(), $GLOBALS['kernel']);
$cfg = $bootstrap->getGlobalConfig();

function yesno($b){ return $b ? xlt('Yes') : xlt('No'); }

$flexEnabled = (bool)$cfg->getGlobalSetting(\OpenEMR\Modules\FlexPayments\GlobalConfig::FLEX_ENABLE);
$apiBase = (string)($cfg->getGlobalSetting(\OpenEMR\Modules\FlexPayments\GlobalConfig::FLEX_API_BASE_URL) ?? '');
$testMode = (bool)$cfg->getGlobalSetting(\OpenEMR\Modules\FlexPayments\GlobalConfig::FLEX_TEST_MODE);
$sigHdr = (string)($cfg->getGlobalSetting(\OpenEMR\Modules\FlexPayments\GlobalConfig::FLEX_WEBHOOK_SIGNATURE_HEADER) ?? '');
$tol = (string)($cfg->getGlobalSetting(\OpenEMR\Modules\FlexPayments\GlobalConfig::FLEX_WEBHOOK_TOLERANCE_SECONDS) ?? '');

$globalsUrl = $GLOBALS['webroot'] . '/interface/super/edit_globals.php';

?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8" />
    <title><?php echo xlt('Flex Settings'); ?></title>
    <?php Header::setupHeader(); ?>
    <style>
        .container { max-width: 900px; margin: 1rem auto; }
        .kv { display: grid; grid-template-columns: 260px 1fr; gap: 6px 12px; }
        .k { font-weight: 600; }
    </style>
    <script>
        function goGlobals(){ window.location.href = <?php echo json_encode($globalsUrl); ?>; }
    </script>
</head>
<body>
<div class="container">
    <h3 class="mb-3"><?php echo xlt('Flex Settings'); ?></h3>
    <p class="text-muted"><?php echo xlt('Editing of settings is done in Admin → Globals → Portal → “Flex HSA/FSA Payments”. This page summarizes key values.'); ?></p>
    <div class="mb-3">
        <button class="btn btn-primary" onclick="goGlobals()"><?php echo xlt('Open Admin → Globals'); ?></button>
    </div>

    <div class="kv">
        <div class="k"><?php echo xlt('Flex Enabled'); ?></div>
        <div class="v"><?php echo text(yesno($flexEnabled)); ?></div>

        <div class="k"><?php echo xlt('API Base URL'); ?></div>
        <div class="v"><code><?php echo text($apiBase); ?></code></div>

        <div class="k"><?php echo xlt('Test Mode'); ?></div>
        <div class="v"><?php echo text(yesno($testMode)); ?></div>

        <div class="k"><?php echo xlt('Webhook Signature Header'); ?></div>
        <div class="v"><code><?php echo text($sigHdr); ?></code></div>

        <div class="k"><?php echo xlt('Webhook Tolerance (seconds)'); ?></div>
        <div class="v"><code><?php echo text($tol); ?></code></div>
    </div>

    <hr>
    <h5><?php echo xlt('Quick Launch'); ?></h5>
    <p>
        <a class="btn btn-sm btn-secondary" href="flex_popup.php"><?php echo xlt('Open Flex Payment'); ?></a>
        <a class="btn btn-sm btn-outline-secondary" href="flex_session_view.php"><?php echo xlt('Open Session Viewer'); ?></a>
        <a class="btn btn-sm btn-outline-secondary" href="flex_webhook.php" target="_blank"><?php echo xlt('Webhook Endpoint'); ?></a>
    </p>
</div>

</body>
</html>
