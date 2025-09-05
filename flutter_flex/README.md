# flutter_flex (preview)

A minimal Flex (HSA/FSA) hosted checkout Flutter plugin.

- Presents a Flex Checkout URL (hosted) via native browser session (ASWebAuthenticationSession / Custom Tabs) or in-app web view.
- Returns a simple result to Dart: `{ status: success|cancel|error, sessionId?, error? }`.
- Secrets are never stored on-device. Your backend must create Checkout Sessions via Flex HTTP API and return the `url` (and optionally `id`).

## Dart API

```dart
import 'package:flutter_flex/flutter_flex.dart';

await FlutterFlex.init(returnUrlScheme: 'com.your.app');

final session = await yourBackendCreateFlexSession(amountCents: 1234);

final result = await FlutterFlex.presentCheckout(checkoutUrl: session.url);
if (result['status'] == 'success') {
  final sid = result['sessionId'];
  // inform backend; backend can capture/send receipt/refund as needed
}
```

## Backend responsibilities

- `POST /create_checkout_session` → Flex `POST /v1/checkout/sessions` → return `{ url, id }`
- On success callback (in-app return), capture if needed: `POST /v1/checkout/sessions/{id}/capture`
- Webhooks: verify HMAC signature, reconcile payments/refunds

## Platform integration

This package exposes a `MethodChannel('flutter_flex')` with methods:
- `init({ returnUrlScheme })`
- `presentCheckout({ checkoutUrl })`

Implement these on Android (Kotlin) and iOS (Swift) to:
- Open the URL in an authenticated browser session (ASWebAuthenticationSession/Custom Tabs)
- Handle return URL deep link and pass `{ status, sessionId }` back via the method channel result

For a quick start, you can prototype with an in-app WebView as a temporary fallback.

## Mapping from flutter_stripe

- `initPaymentSheet`/`presentPaymentSheet` → `FlutterFlex.presentCheckout(checkoutUrl)`
- `createPaymentMethod` / `confirmPayment` → N/A (Flex hosted handles this)
- `handleNextAction` → N/A (handled by hosted checkout)
- `PaymentIntent` actions (capture/refund/receipt) → do server-side with Flex HTTP API

## Example app

A simple example is provided in `example/` showing the end-to-end flow assuming a mock backend.

> Note: This is a preview scaffold. Add your platform code under `android/` and `ios/` to complete the native session and deep link handling.

