import 'dart:convert';
import 'package:crypto/crypto.dart' as crypto;
import 'package:uuid/uuid.dart';

/// Computes HMAC-SHA256(secret, message) and returns lowercase hex.
String hmacSha256Hex(String secret, String message) {
  final key = utf8.encode(secret);
  final bytes = utf8.encode(message);
  final h = crypto.Hmac(crypto.sha256, key).convert(bytes);
  return h.toString();
}

/// Builds a signed payload for create_checkout with ts, nonce, signature.
/// Signature base is: "amount.currency.ts.nonce"
Map<String, dynamic> buildSignedCreatePayload({
  required int amount,
  required String currency,
  Map<String, dynamic>? metadata,
  required String hmacSecret,
  int? ts,
  String? nonce,
}) {
  final _ts = ts ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000);
  final _nonce = nonce ?? const Uuid().v4();
  final base = '$amount.$currency.$_ts.$_nonce';
  final sig = hmacSha256Hex(hmacSecret, base);
  return {
    'amount': amount,
    'currency': currency,
    if (metadata != null) 'metadata': metadata,
    'ts': _ts,
    'nonce': _nonce,
    'signature': sig,
  };
}

