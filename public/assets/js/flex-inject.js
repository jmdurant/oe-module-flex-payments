(function(window){
  'use strict';

  function findScriptBase(){
    try {
      var scripts = document.getElementsByTagName('script');
      for (var i = 0; i < scripts.length; i++) {
        var s = scripts[i];
        if (!s.src) continue;
        if (s.src.indexOf('/public/assets/js/flex-inject.js') !== -1) {
          // Base is everything up to /public/assets/js/flex-inject.js
          return s.src.replace(/\/public\/assets\/js\/flex-inject\.js.*$/, '/public/');
        }
      }
    } catch(e) {}
    return null;
  }

  function parseAmount(text){
    if (!text) return '';
    // Remove currency symbols and commas
    var cleaned = String(text).replace(/[^0-9.\-]/g, '');
    // If there are multiple dots, keep the first
    var parts = cleaned.split('.');
    if (parts.length > 2) {
      cleaned = parts.shift() + '.' + parts.join('');
    }
    return cleaned;
  }

  function injectButton(){
    try {
      // Only attempt on front payment screen (heuristic: presence of #payTotal and modal footer button group)
      var payTotalEl = document.getElementById('payTotal');
      var footer = document.querySelector('.modal-footer .button-group');
      if (!payTotalEl || !footer) return;

      // Avoid duplicate
      if (document.getElementById('flexPayBtn')) return;

      var btn = document.createElement('button');
      btn.id = 'flexPayBtn';
      btn.className = 'btn btn-secondary';
      btn.type = 'button';
      btn.textContent = (window.xl ? xl('Pay with Flex') : 'Pay with Flex');
      btn.addEventListener('click', function(){
        var base = findScriptBase();
        if (!base) {
          alert('Flex module path not found');
          return;
        }
        var amtTxt = (payTotalEl.textContent || payTotalEl.innerText || '').trim();
        var amount = parseAmount(amtTxt);
        var currency = 'usd';
        var url = base + 'flex_popup.php?amount=' + encodeURIComponent(amount) + '&currency=' + encodeURIComponent(currency);
        var w = window.open(url, 'flex_popup', 'width=820,height=740');
        if (w) { w.focus(); }
      });

      footer.appendChild(btn);

      // Add Refund button
      var refundBtn = document.createElement('button');
      refundBtn.id = 'flexRefundBtn';
      refundBtn.className = 'btn btn-outline-secondary ml-2';
      refundBtn.type = 'button';
      refundBtn.textContent = (window.xl ? xl('Flex Refund') : 'Flex Refund');
      refundBtn.addEventListener('click', async function(){
        var base = findScriptBase(); if (!base) return alert('Flex module path not found');
        var sessionId = prompt('Enter Flex Checkout Session ID to refund (stored as reference/check number):');
        if (!sessionId) return;
        var amt = prompt('Enter refund amount (leave blank for full):');
        try {
          var resp = await fetch(base + 'flex_controller.php?mode=refund_checkout', {
            method: 'POST', headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ id: sessionId, amount: amt && amt.trim() ? amt.trim() : null })
          });
          var data = await resp.json();
          if (!resp.ok) throw new Error((data && data.error) || 'Refund failed');
          alert('Refund requested.');
        } catch(e){ alert(e.message || String(e)); }
      });
      footer.appendChild(refundBtn);

      // Add Receipt button (accepts Checkout Session or Payment Intent)
      var receiptBtn = document.createElement('button');
      receiptBtn.id = 'flexReceiptBtn';
      receiptBtn.className = 'btn btn-outline-secondary ml-2';
      receiptBtn.type = 'button';
      receiptBtn.textContent = (window.xl ? xl('Flex Receipt') : 'Flex Receipt');
      receiptBtn.addEventListener('click', async function(){
        var base = findScriptBase(); if (!base) return alert('Flex module path not found');
        var sid = prompt('Enter Flex Checkout Session ID (leave blank to enter a Payment Intent ID):');
        if (sid && sid.trim()) {
          try {
            var resp = await fetch(base + 'flex_controller.php?mode=send_receipt_checkout', {
              method: 'POST', headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({ id: sid.trim() })
            });
            var data = await resp.json();
            if (!resp.ok) throw new Error((data && data.error) || 'Send receipt failed');
            if (data && data.error === 'payment_intent_id_not_found') {
              alert('Could not resolve Payment Intent from Checkout Session. Try entering a Payment Intent ID.');
            } else {
              alert('Receipt requested.');
            }
          } catch(e){ alert(e.message || String(e)); }
        } else {
          var intentId = prompt('Enter Flex Payment Intent ID to send receipt:');
          if (!intentId) return;
          try {
            var resp2 = await fetch(base + 'flex_controller.php?mode=send_receipt_intent', {
              method: 'POST', headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({ id: intentId.trim() })
            });
            var data2 = await resp2.json();
            if (!resp2.ok) throw new Error((data2 && data2.error) || 'Send receipt failed');
            alert('Receipt requested.');
          } catch(e){ alert(e.message || String(e)); }
        }
      });
      footer.appendChild(receiptBtn);

      // Add Session Info viewer
      var infoBtn = document.createElement('button');
      infoBtn.id = 'flexInfoBtn';
      infoBtn.className = 'btn btn-outline-secondary ml-2';
      infoBtn.type = 'button';
      infoBtn.textContent = (window.xl ? xl('Flex Session Info') : 'Flex Session Info');
      infoBtn.addEventListener('click', function(){
        var base = findScriptBase(); if (!base) return alert('Flex module path not found');
        // Try to default from current check/reference number if available on page
        var checkInput = document.getElementById('check_number');
        var def = checkInput && checkInput.value ? checkInput.value : '';
        var sid = prompt('Enter Flex Checkout Session ID:', def);
        if (!sid) return;
        var url = base + 'flex_session_view.php?id=' + encodeURIComponent(sid.trim());
        var w = window.open(url, 'flex_session_view', 'width=900,height=800');
        if (w) { w.focus(); }
      });
      footer.appendChild(infoBtn);

      // Add inline link next to Check/Reference Number field to open Session Info quickly
      var refInput = document.getElementById('check_number');
      if (refInput && !document.getElementById('flexRefInfoLink')) {
        var small = document.createElement('a');
        small.id = 'flexRefInfoLink';
        small.href = '#';
        small.style.marginLeft = '8px';
        small.textContent = (window.xl ? xl('View in Flex') : 'View in Flex');
        small.addEventListener('click', function(e){
          e.preventDefault();
          var base = findScriptBase(); if (!base) return alert('Flex module path not found');
          var sid = (refInput.value || '').trim();
          if (!sid) return alert((window.xl ? xl('Reference is empty') : 'Reference is empty'));
          var url = base + 'flex_session_view.php?id=' + encodeURIComponent(sid);
          var w = window.open(url, 'flex_session_view', 'width=900,height=800');
          if (w) { w.focus(); }
        });
        // Insert after the input
        if (refInput.parentNode) {
          refInput.parentNode.appendChild(small);
        }
      }
    } catch(e) {
      // swallow
    }
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', injectButton);
  } else {
    injectButton();
  }

  // Patient Portal payment card injection
  (function(){
    function findScriptBase(){
      try {
        var scripts = document.getElementsByTagName('script');
        for (var i = 0; i < scripts.length; i++) {
          var s = scripts[i];
          if (!s.src) continue;
          if (s.src.indexOf('/public/assets/js/flex-inject.js') !== -1) {
            return s.src.replace(/\/public\/assets\/js\/flex-inject\.js.*$/, '/public/');
          }
        }
      } catch(e){}
      return null;
    }
    function placePortalButton(){
      var container = document.getElementById('payment');
      if (!container) return;
      if (container.querySelector('#flexPortalPayBtn')) return;
      var base = findScriptBase(); if (!base) return;
      var btn = document.createElement('button');
      btn.id = 'flexPortalPayBtn';
      btn.className = 'btn btn-primary mb-2';
      btn.type = 'button';
      btn.textContent = (window.xl ? xl('Pay with Flex') : 'Pay with Flex');
      btn.addEventListener('click', function(){
        var amount = '';
        var moneyInputs = container.querySelectorAll('input[type="number"], input[type="text"], .money, .amount');
        if (moneyInputs && moneyInputs.length) amount = moneyInputs[0].value || '';
        var url = base + 'flex_popup.php' + (amount ? ('?amount=' + encodeURIComponent(amount)) : '');
        var w = window.open(url, 'flex_popup', 'width=820,height=740');
        if (w) { w.focus(); }
      });
      // Try to place side-by-side next to existing pay/submit button
      var targetBtn = container.querySelector('button[type="submit"], input[type="submit"], button.btn-primary, .btn-group .btn');
      if (targetBtn && targetBtn.parentNode) {
        targetBtn.parentNode.insertBefore(btn, targetBtn.nextSibling);
      } else {
        container.insertBefore(btn, container.firstChild);
      }
    }
    function init(){
      var target = document.getElementById('payment');
      if (!target) return;
      placePortalButton();
      var obs = new MutationObserver(function(){ placePortalButton(); });
      obs.observe(target, { childList: true, subtree: true });
    }
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', function(){ setTimeout(init, 600); });
    } else { setTimeout(init, 600); }
  })();

  // Attempt injection on Stripe Terminal window (side-by-side) if this script is present there
  (function(){
    function init(){
      var collect = document.getElementById('collect-button');
      var toolbar = collect ? collect.parentNode : null;
      if (!toolbar) return;
      if (document.getElementById('flexTerminalBtn')) return;
      var base = findScriptBase(); if (!base) return;
      var btn = document.createElement('button');
      btn.id = 'flexTerminalBtn';
      btn.className = 'btn btn-outline-secondary m-1';
      btn.type = 'button';
      btn.textContent = (window.xl ? xl('Pay with Flex') : 'Pay with Flex');
      btn.addEventListener('click', function(){
        var url = base + 'flex_popup.php';
        var w = window.open(url, 'flex_popup', 'width=820,height=740');
        if (w) { w.focus(); }
      });
      toolbar.insertBefore(btn, collect.nextSibling);
    }
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', init);
    } else { init(); }
  })();

})(window);
