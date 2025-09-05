# Flutter Flex Plugin — Overview

A minimal Flutter plugin that presents Flex (HSA/FSA) hosted checkout and returns a simple result to Dart. It avoids collecting card data on-device (PCI-friendly) and integrates with your backend for session creation, capture, refunds, and webhooks.

## Packages and Structure

- `flutter_flex/` (plugin root)
  - `lib/flutter_flex.dart`: MethodChannel facade (init, presentCheckout)
  - `lib/payment_sheet.dart`: PaymentSheet-style wrapper (loading → present → result)
  - `android/…`: WebView-based presenter
  - `ios/…`: WKWebView-based presenter
  - `example/`: demo app
    - `mock_server/` (Node/Express) :3000
    - `mock_server_dart/` (Shelf) :3001

## Dart API

```dart
await FlutterFlex.init(returnUrlScheme: 'com.your.app'); // optional for future deep-link mode

final result = await FlutterFlex.presentCheckout(
  checkoutUrl: '<Flex Checkout URL>',
  successUrlContains: 'status=success', // default
  cancelUrlContains: 'status=cancel',   // default
);
// result: { status: 'success'|'cancel'|'error', sessionId? }
```

### PaymentSheet wrapper

```dart
final res = await FlexPaymentSheet.present(
  context,
  config: const FlexPaymentSheetConfig(
    title: 'Pay with Flex',
    amountLabel: '\$42.00',
  ),
  createSession: () async {
    final session = await backend.createFlexSession(amountCents: 4200);
    return session.url; // Flex Checkout URL
  },
  onSuccess: (sid) => backend.captureIfNeeded(sid),
);
```

## Backend Expectations

- Create Checkout Session: `POST /v1/checkout/sessions` → return `{ id, url }` to the app.
- Return URLs: include markers (defaults: `status=success` / `status=cancel`) and ideally `session_id` or `id` query param for extraction.
- Capture/refund/receipt: server-side via Flex API.
- Webhooks: verify signatures; reconcile payments/refunds (see OpenEMR module docs for patterns).

### Using an OpenEMR backend

If your OpenEMR module exposes a mobile endpoint to create sessions, call it directly from Flutter and return its `url` into the PaymentSheet wrapper:

```
final payload = buildSignedCreatePayload(
  amount: 4200,
  currency: 'usd',
  metadata: {'mrn': '1234'},
  hmacSecret: '<short-lived or demo secret>',
);

final r = await http.post(
  Uri.parse('$openemrBase/interface/modules/custom_modules/oe-module-flex-payments/public/flex_controller.php?mode=create_checkout'),
  headers: {'Content-Type': 'application/json'},
  body: json.encode(payload),
);
final data = json.decode(r.body) as Map<String, dynamic>;
return data['url'] as String; // pass this into FlexPaymentSheet.present
```

The OpenEMR module can then auto-capture on success (return page), verify webhooks, and auto-post AR for refunds.

## Platform Notes

- Android: `FlexWebViewActivity` intercepts navigation and returns results (status, sessionId?).
- iOS: `WKWebView` modal does the same.
- Optional enhancement (future): system browser sessions (ASWebAuthenticationSession/Custom Tabs) with deep links; current implementation uses in-app WebView for speed.

## Running the Example + Mock Servers

- Dart mock server (recommended):
  - `cd flutter_flex/example/mock_server_dart`
  - `dart pub get && dart run bin/server.dart`
  - Runs at `http://localhost:3001` (Android emulator: `http://10.0.2.2:3001`)
- Node mock server (fallback):
  - `cd flutter_flex/example/mock_server`
  - `npm install && npm start`
  - Runs at `http://localhost:3000` (Android emulator: `http://10.0.2.2:3000`)
- Run the app:
  - `cd flutter_flex/example && flutter run`
  - The example prefers the Dart server and falls back to Node if not available.

## Differences vs flutter_stripe

- No native card entry or tokenization in-app; everything is hosted by Flex Checkout (lower PCI scope).
- No Apple/Google Pay (by request). If Flex Checkout supports wallets, they appear within hosted pages.
- SCA/3DS handled by Flex Checkout.
- Simpler surface: `presentCheckout` or the PaymentSheet wrapper around it.

## Customization

- Update `successUrlContains` / `cancelUrlContains` to match your return URLs.
- Wrap the PaymentSheet with your brand and include an interstitial “processing” state if your backend captures post-return.
- Switch to a system browser flow later (deep links) while keeping the same Dart surface.

### Security tips

- Do not hardcode long-lived secrets in the app. Prefer short-lived tokens issued by your server/OpenEMR.
- Keep strict timestamp tolerance and consider a nonce replay cache on the server.
- Bind CORS only to the mobile create-session endpoint.

### Future Authentication Choice

- Option A — Short‑Lived Token (Recommended)
  - Server mints a signed payload or token valid for a few minutes; the app uses it once to call `create_checkout`.
  - No long‑lived secret on-device; combine with nonce replay cache and rate limits.

- Option B — Session‑Based
  - App relies on OpenEMR login/session and ACL; no HMAC.
  - Best when the app is essentially a portal/staff client reusing the existing session.

Pick A or B before production and document your choice for the mobile team.
