<?php

/**
 * Minimal Flex payment popup UI that creates a Checkout Session and opens it.
 * After completion, Flex redirects back to flex_return.php which posts back to the opener.
 *
 * @package   OpenEMR
 */

require_once __DIR__ . "/../../../../globals.php";

use OpenEMR\Core\Header;
use OpenEMR\Modules\FlexPayments\Bootstrap;

$bootstrap = new Bootstrap($GLOBALS['kernel']->getEventDispatcher(), $GLOBALS['kernel']);
$config = $bootstrap->getGlobalConfig();

// Allow passing amount from query for convenience (in dollars or minor units as you prefer)
$amount = $_GET['amount'] ?? '';
$currency = $_GET['currency'] ?? 'usd';

?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8" />
    <title><?php echo xlt('Flex Payment'); ?></title>
    <?php Header::setupHeader(['opener']); ?>
    <style>
        .container { max-width: 720px; margin: 1rem auto; }
    </style>
</head>
<body>
<div class="container">
    <h3><?php echo xlt('Pay with Flex'); ?></h3>
    <div class="alert alert-info">
        <?php echo xlt('Enter an amount and click Create Checkout to open Flex checkout.'); ?>
    </div>
    <form id="flex-form" onsubmit="return false;">
        <div class="form-group mb-2">
            <label for="amount"><?php echo xlt('Amount'); ?></label>
            <input class="form-control" id="amount" name="amount" value="<?php echo attr($amount); ?>" placeholder="e.g., 100.00 or 10000" />
        </div>
        <div class="form-group mb-3">
            <label for="currency"><?php echo xlt('Currency'); ?></label>
            <input class="form-control" id="currency" name="currency" value="<?php echo attr($currency); ?>" />
        </div>
        <button id="createBtn" class="btn btn-primary"><?php echo xlt('Create Checkout'); ?></button>
        <button id="closeBtn" type="button" class="btn btn-secondary"><?php echo xlt('Close'); ?></button>
        <div id="status" class="mt-3 small text-muted"></div>
    </form>
</div>

<script>
    (function(){
        const createBtn = document.getElementById('createBtn');
        const closeBtn = document.getElementById('closeBtn');
        const status = document.getElementById('status');

        closeBtn.addEventListener('click', () => { window.close(); });

        createBtn.addEventListener('click', async () => {
            status.textContent = '<?php echo xls('Creating checkout session...'); ?>';
            const amount = document.getElementById('amount').value.trim();
            const currency = document.getElementById('currency').value.trim() || 'usd';
            if(!amount){ alert('<?php echo xls('Please enter an amount'); ?>'); return; }

            // Basic patient metadata if opened from front_payment.php (best-effort scrape)
            let metadata = {};
            try {
                // Example: you can enhance this to scrape patient name or invoice details from opener
                if (window.opener && window.opener.document) {
                    const encTable = window.opener.document.getElementById('table_display');
                    if (encTable) {
                        metadata['invoice_preview'] = encTable.innerText.substring(0, 180);
                    }
                }
            } catch(e) { }

            try {
                const resp = await fetch('flex_controller.php?mode=create_checkout', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ amount, currency, metadata })
                });
                const data = await resp.json();
                if (!resp.ok) {
                    status.textContent = (data && data.error) ? data.error : 'Error creating session';
                    return;
                }
                // Open hosted checkout if provided
                if (data && data.url) {
                    window.location.href = data.url;
                } else if (data && data.redirect_url) {
                    window.location.href = data.redirect_url;
                } else {
                    status.textContent = 'No redirect URL returned by Flex.';
                }
            } catch(err) {
                status.textContent = 'Failed: ' + (err && err.message ? err.message : String(err));
            }
        });
    })();
</script>

</body>
</html>

