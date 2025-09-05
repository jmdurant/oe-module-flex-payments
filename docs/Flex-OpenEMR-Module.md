# Flex HSA/FSA Payments — OpenEMR Module Overview

This module integrates Flex (HSA/FSA) hosted checkout into OpenEMR without core edits. It adds buttons and menu entries to launch Flex checkout alongside existing payment options and can automatically reconcile refunds into AR.

## What’s Included

- Hosted checkout launcher (staff + portal)
- Optional immediate capture on success
- Refunds + receipts helpers
- Webhook verification (HMAC SHA-256)
- Automatic AR refund posting (including partials)
- Admin summary page (links to Globals)
- Patient portal Twig override for a native “Pay with Flex” button

## Paths and Key Files

- Module globals and wiring
  - `src/Bootstrap.php`
  - `src/GlobalConfig.php`
- Flex API wrapper
  - `src/FlexGatewayService.php`
- Controller endpoints (JSON)
  - `public/flex_controller.php`
  - `public/flex_webhook.php`
  - `public/flex_popup.php`, `public/flex_return.php`
- UI injection (staff + portal + terminal)
  - `public/assets/js/flex-inject.js`
- Admin summary page
  - `public/config.php`
- Portal Twig override (native Flex button on Payments tile)
  - `templates/portal/partial/_nav_icon.html.twig`
- AR refund reconciler
  - `src/RefundReconciler.php`

## Configuration

OpenEMR → Administration → Globals → Portal → “Flex HSA/FSA Payments”.

- Toggle + keys
  - Enable body footer injection (injects assets)
  - Enable Flex Gateway (HSA/FSA)
  - Flex API Base URL (e.g., `https://api.withflex.com`)
  - Flex API Key (Encrypted)
  - Flex Test Mode (optional)
- Webhooks (optional)
  - Flex Webhook Secret (Encrypted)
  - Flex Webhook Signature Header (default `Flex-Signature`)
  - Flex Webhook Tolerance Seconds (default `300`)
- Automation
  - Auto-post Flex refunds to AR (creates negative AR entries on refund)
  - Mobile HMAC Secret (Encrypted): shared secret for signing mobile create_checkout requests
  - Allow Mobile CORS for create_checkout: enables CORS for the mobile endpoint (POST/OPTIONS only)

After toggling template/menu settings, log out and in.

## UI Touchpoints

- Staff front payment modal: buttons in footer (Pay with Flex, Refund, Receipt, Session Info)
- Stripe Terminal window: adds a “Pay with Flex” button beside terminal controls
- Patient portal:
  - Native Twig button on Payments tile (override)
  - JS-injected button next to “Pay/Submit” inside the card
- Admin
  - Modules → Flex Payments → Flex Payment / Session Info / Flex Settings
  - Administration → Flex Settings (summary page)

## Webhook Verification

`public/flex_webhook.php` verifies signatures if a secret is set.

- Accepts either `t=timestamp,v1=hex` or raw `hex` signatures
- HMAC SHA-256 over `timestamp.rawBody` (if `t=` present) or over `rawBody`
- Tolerance seconds enforced if timestamped format is used

## Automatic Refund → AR Posting

- Toggle: “Auto-post Flex refunds to AR”
- Controller path: after a successful refund, posts negative AR (`ar_session`, `ar_activity`) using the Checkout Session ID as reference
- Webhook path: on refund-related events (type contains `refund`), posts negative AR with idempotency (tracks event IDs)
- Audit table: `module_flex_refunds` stores processed refunds

## Return + Capture Flow

- Success return: `public/flex_return.php` attempts immediate capture (`/v1/checkout/sessions/{id}/capture`) and posts the OpenEMR payment by setting the “Check/Reference Number” to the Flex session id.

## Developer Notes

- Success/Cancel detection (webview/browser return): defaults to `status=success`/`status=cancel`. Update as needed.
- Refunds/Receipts:
  - Refund: `flex_controller.php?mode=refund_checkout { id, amount? }`
  - Receipt: `mode=send_receipt_checkout { id }` resolves intent via session, else `mode=send_receipt_intent { id }`
- Session Viewer: `public/flex_session_view.php?id=<session>`

## Mobile App Integration (Flutter)

Mobile apps should call a single JSON endpoint to create a Flex Checkout Session, then present the hosted checkout URL via the flutter_flex plugin.

- Endpoint
  - `POST /interface/modules/custom_modules/oe-module-flex-payments/public/flex_controller.php?mode=create_checkout`
  - Request JSON:
    - `amount` (int)
    - `currency` (string)
    - `metadata` (object, optional)
    - `ts` (unix seconds) — if HMAC is enabled
    - `nonce` (uuid or random) — if HMAC is enabled
    - `signature` — if HMAC is enabled
  - Signature (if a Mobile HMAC Secret is configured):
    - `signature = HMAC_SHA256(secret, "amount.currency.ts.nonce")`
    - Timestamp tolerance uses the same "Flex Webhook Tolerance Seconds" setting (default 300s)
  - Response JSON: `{ "id": "<session_id>", "url": "<flex_checkout_url>" }`

- CORS
  - If "Allow Mobile CORS for create_checkout" is enabled, the endpoint handles `OPTIONS` and allows `POST` cross-origin.
  - Restrict this only to the mobile flow; do not enable global CORS.

- Security guidance
  - Prefer short-lived tokens or rotate the mobile secret regularly.
  - Keep strict timestamp tolerance and consider a nonce replay cache (store recent nonces for a TTL and reject repeats).
  - If staff are logged in to OpenEMR on-device, you may disable HMAC and rely on session ACLs instead.

- Processing remains in OpenEMR
  - Success return → capture (optional) → save payment (reference = Flex session id)
  - Webhooks → verify signature → auto-post AR for refunds (if enabled)
  - The app does not write to AR directly.

### Future Authentication Options (Choose One)

- Option A — Short‑Lived Token (recommended for pure mobile)
  - Add a token mint endpoint that returns a signed payload (ts, nonce, signature) valid for a few minutes.
  - App uses the signed payload once to call `create_checkout` (no long‑lived secret on the device).
  - Enforce timestamp tolerance, nonce replay cache, and rate limits.

- Option B — Session‑Based (portal/staff flows)
  - Rely on OpenEMR login/session and ACL instead of HMAC.
  - Prefer same‑origin calls (no CORS); if not possible, ensure cookie handling is correct in the client.

Document which option you will use and implement it before production.


---

# Quick Test

- Enable Flex in Globals and set keys.
- Staff: Record Payment → “Pay with Flex”.
- Portal: Home → Payments tile → “Pay with Flex”.
- Webhooks: configure endpoint `/interface/modules/custom_modules/oe-module-flex-payments/public/flex_webhook.php` and set the secret.
