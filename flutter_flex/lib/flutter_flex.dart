import 'dart:async';
import 'package:flutter/services.dart';

/// Minimal Flex hosted checkout facade.
class FlutterFlex {
  FlutterFlex._();

  static const MethodChannel _channel = MethodChannel('flutter_flex');

  /// Configure optional return URL scheme for deep link return (iOS/Android).
  static Future<void> init({String? returnUrlScheme}) async {
    await _channel.invokeMethod('init', {
      'returnUrlScheme': returnUrlScheme,
    });
  }

  /// Presents a Flex Checkout URL (hosted) and returns a result map:
  /// { 'status': 'success'|'cancel'|'error', 'sessionId': String?, 'error': String? }
  ///
  /// On mobile, a platform implementation should use ASWebAuthenticationSession
  /// (iOS) or Custom Tabs (Android) with return URL handling. As a fallback,
  /// platform code may open an in-app webview and detect return/cancel URLs.
  static Future<Map<String, dynamic>> presentCheckout({
    required String checkoutUrl,
    String successUrlContains = 'status=success',
    String cancelUrlContains = 'status=cancel',
  }) async {
    final result = await _channel.invokeMapMethod<String, dynamic>(
      'presentCheckout',
      {
        'checkoutUrl': checkoutUrl,
        'successUrlContains': successUrlContains,
        'cancelUrlContains': cancelUrlContains,
      },
    );
    return (result ?? const <String, dynamic>{});
  }
}
