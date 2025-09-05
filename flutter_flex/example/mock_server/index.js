const express = require('express');
const bodyParser = require('body-parser');
const cors = require('cors');
const { nanoid } = require('nanoid');

const app = express();
app.use(cors());
app.use(bodyParser.json());

// Create a mock checkout session. In real life you would call Flex API here.
app.post('/create_checkout_session', (req, res) => {
  const amount = req.body?.amount ?? 0;
  const sid = nanoid(12);
  const base = `http://localhost:3000`;
  const url = `${base}/checkout?sid=${sid}&amount=${amount}`;
  res.json({ id: sid, url });
});

// Mock checkout page with Pay and Cancel buttons
app.get('/checkout', (req, res) => {
  const sid = req.query.sid || '';
  const amount = req.query.amount || '0';
  res.set('Content-Type', 'text/html');
  res.send(`
    <!doctype html>
    <html>
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <title>Mock Flex Checkout</title>
        <style> body{font-family:system-ui,Arial;padding:2rem;} button{padding:.6rem 1rem;margin-right:.5rem;} .box{border:1px solid #ccc;padding:1rem;border-radius:.5rem;} </style>
      </head>
      <body>
        <h2>Mock Flex Checkout</h2>
        <div class="box">
          <p>Session: <b>${sid}</b></p>
          <p>Amount: <b>${amount}</b></p>
          <button onclick="onPay()">Pay</button>
          <button onclick="onCancel()">Cancel</button>
        </div>
        <script>
          function onPay(){ window.location.href = '/return?status=success&session_id=${sid}'; }
          function onCancel(){ window.location.href = '/return?status=cancel&session_id=${sid}'; }
        </script>
      </body>
    </html>
  `);
});

// Return page – plugin detects status via URL substring
app.get('/return', (req, res) => {
  const status = req.query.status || 'unknown';
  const sid = req.query.session_id || '';
  res.set('Content-Type', 'text/html');
  res.send(`
    <!doctype html>
    <html>
      <head><meta charset="utf-8" /><meta name="viewport" content="width=device-width, initial-scale=1" /><title>Return</title></head>
      <body>
        <h3>Result: ${status}</h3>
        <p>Session: <b>${sid}</b></p>
        <p>You can close this tab.</p>
      </body>
    </html>
  `);
});

const port = process.env.PORT || 3000;
app.listen(port, () => console.log(`Mock Flex server listening on :${port}`));

