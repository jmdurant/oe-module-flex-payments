<?php

/**
 * Flex session detail viewer. Fetches a Checkout Session and renders key fields
 * with a convenience copy UI and resolved Payment Intent ID.
 *
 * @package   OpenEMR
 */

require_once __DIR__ . "/../../../../globals.php";

use OpenEMR\Core\Header;
use OpenEMR\Modules\FlexPayments\Bootstrap;
use OpenEMR\Modules\FlexPayments\FlexGatewayService;

$sid = $_GET['id'] ?? '';
$error = '';
$session = [];
$intentId = '';

try {
    if ($sid) {
        $bootstrap = new Bootstrap($GLOBALS['kernel']->getEventDispatcher(), $GLOBALS['kernel']);
        $cfg = $bootstrap->getGlobalConfig();
        if (!$cfg->getGlobalSetting(\OpenEMR\Modules\FlexPayments\GlobalConfig::FLEX_ENABLE)) {
            $error = 'Flex gateway not enabled';
        } else {
            $svc = new FlexGatewayService($cfg);
            if (!$svc->isConfigured()) {
                $error = 'Flex gateway not configured';
            } else {
                $session = $svc->getCheckoutSession($sid);
                $intentId = $svc->findPaymentIntentIdFromSessionArray($session) ?? '';
            }
        }
    } else {
        $error = 'Missing session id';
    }
} catch (\Throwable $e) {
    $error = $e->getMessage();
}

?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8" />
    <title><?php echo xlt('Flex Session Details'); ?></title>
    <?php Header::setupHeader(); ?>
    <style>
        .container { max-width: 820px; margin: 1rem auto; }
        pre.json { background: #111; color: #eee; padding: 0.75rem; border-radius: 6px; overflow: auto; }
        .kv { display: grid; grid-template-columns: 200px 1fr; gap: 6px 12px; }
        .kv .k { font-weight: 600; }
        .copy { cursor: pointer; }
    </style>
</head>
<body>
<div class="container">
    <h3 class="mb-3"><?php echo xlt('Flex Session Details'); ?></h3>

    <?php if ($error) { ?>
        <div class="alert alert-danger"><?php echo text($error); ?></div>
    <?php } else { ?>
        <div class="kv mb-3">
            <div class="k"><?php echo xlt('Checkout Session ID'); ?></div>
            <div class="v"><code id="sidVal"><?php echo text($sid); ?></code> <button class="btn btn-sm btn-light copy" data-copy="#sidVal"><?php echo xlt('Copy'); ?></button></div>

            <div class="k"><?php echo xlt('Payment Intent ID'); ?></div>
            <div class="v"><code id="piVal"><?php echo text($intentId); ?></code> <button class="btn btn-sm btn-light copy" data-copy="#piVal"><?php echo xlt('Copy'); ?></button></div>

            <div class="k"><?php echo xlt('Status'); ?></div>
            <div class="v"><code><?php echo text($session['status'] ?? ''); ?></code></div>

            <div class="k"><?php echo xlt('Amount Total'); ?></div>
            <div class="v"><code><?php echo text((string)($session['amount_total'] ?? '')); ?></code></div>

            <div class="k"><?php echo xlt('Amount Received'); ?></div>
            <div class="v"><code><?php echo text((string)($session['amount_received'] ?? '')); ?></code></div>

            <div class="k"><?php echo xlt('Currency'); ?></div>
            <div class="v"><code><?php echo text($session['currency'] ?? ''); ?></code></div>
        </div>

        <div class="mb-2">
            <button id="receiptBtn" class="btn btn-primary btn-sm"><?php echo xlt('Send Receipt'); ?></button>
            <button id="refundBtn" class="btn btn-secondary btn-sm"><?php echo xlt('Refund'); ?></button>
        </div>

        <h5 class="mt-3"><?php echo xlt('Raw JSON'); ?></h5>
        <pre class="json" id="jsonBlock"><?php echo text(json_encode($session, JSON_PRETTY_PRINT)); ?></pre>
    <?php } ?>
</div>

<script>
(function(){
    function copySel(sel){
        try {
            var el = document.querySelector(sel);
            if (!el) return;
            var txt = el.textContent || '';
            navigator.clipboard && navigator.clipboard.writeText ? navigator.clipboard.writeText(txt) : legacyCopy(txt);
        } catch(e){}
    }
    function legacyCopy(text){
        var t = document.createElement('textarea');
        t.value = text; document.body.appendChild(t); t.select();
        try{ document.execCommand('copy'); }catch(e){}
        document.body.removeChild(t);
    }
    Array.prototype.forEach.call(document.querySelectorAll('.copy'), function(btn){
        btn.addEventListener('click', function(){ copySel(btn.getAttribute('data-copy')); });
    });

    var base = (function(){
        var here = window.location.href;
        return here.replace(/\/flex_session_view\.php.*$/, '/');
    })();
    var sid = document.getElementById('sidVal') ? (document.getElementById('sidVal').textContent||'').trim() : '';
    var pi  = document.getElementById('piVal') ? (document.getElementById('piVal').textContent||'').trim() : '';

    var receiptBtn = document.getElementById('receiptBtn');
    if (receiptBtn) {
        receiptBtn.addEventListener('click', async function(){
            // Try via session first; server will resolve intent
            try {
                var resp = await fetch(base + 'flex_controller.php?mode=send_receipt_checkout', {
                    method: 'POST', headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ id: sid })
                });
                var data = await resp.json();
                if (!resp.ok) throw new Error((data && data.error) || 'Send receipt failed');
                if (data && data.error === 'payment_intent_id_not_found' && pi) {
                    // fallback to explicit PI
                    var resp2 = await fetch(base + 'flex_controller.php?mode=send_receipt_intent', {
                        method: 'POST', headers: { 'Content-Type': 'application/json' },
                        body: JSON.stringify({ id: pi })
                    });
                    var data2 = await resp2.json();
                    if (!resp2.ok) throw new Error((data2 && data2.error) || 'Send receipt failed');
                }
                alert('Receipt requested.');
            } catch(e){ alert(e.message || String(e)); }
        });
    }

    var refundBtn = document.getElementById('refundBtn');
    if (refundBtn) {
        refundBtn.addEventListener('click', async function(){
            var amt = prompt('Enter refund amount (leave blank for full):');
            try {
                var resp = await fetch(base + 'flex_controller.php?mode=refund_checkout', {
                    method: 'POST', headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ id: sid, amount: (amt && amt.trim()) ? amt.trim() : null })
                });
                var data = await resp.json();
                if (!resp.ok) throw new Error((data && data.error) || 'Refund failed');
                alert('Refund requested.');
            } catch(e){ alert(e.message || String(e)); }
        });
    }
})();
</script>

</body>
</html>

