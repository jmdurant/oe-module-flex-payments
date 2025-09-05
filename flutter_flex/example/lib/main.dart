import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:http/http.dart' as http;
import 'package:flutter_flex/signing.dart';
import 'package:flutter_flex/flutter_flex.dart';
import 'package:flutter_flex/payment_sheet.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('flutter_flex example')),
        body: const _Body(),
      ),
    );
  }
}

class _Body extends StatefulWidget {
  const _Body();

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  String _status = 'idle';

  @override
  void initState() {
    super.initState();
    FlutterFlex.init(returnUrlScheme: 'com.example.app');
  }

  Future<void> _startCheckout() async {
    final res = await FlexPaymentSheet.present(
      context,
      config: const FlexPaymentSheetConfig(
        title: 'Pay with Flex',
        amountLabel: '\\$42.00',
      ),
      createSession: () async {
        // Preferred: Dart mock server on :3001
        // Alternate: Node mock server on :3000
        final dartBase = Platform.isAndroid ? 'http://10.0.2.2:3001' : 'http://localhost:3001';
        final nodeBase = Platform.isAndroid ? 'http://10.0.2.2:3000' : 'http://localhost:3000';

        Future<String> _tryBase(String base) async {
          final payload = buildSignedCreatePayload(
            amount: 4200,
            currency: 'usd',
            metadata: {'mrn': '1234'},
            // For demo only: do NOT hardcode secrets in production apps.
            hmacSecret: 'demo-secret',
          );
          final r = await http
              .post(Uri.parse('$base/create_checkout_session'),
                  headers: {'Content-Type': 'application/json'},
                  body: json.encode(payload))
              .timeout(const Duration(seconds: 2));
          final data = json.decode(r.body) as Map<String, dynamic>;
          return data['url'] as String;
        }

        try {
          return await _tryBase(dartBase);
        } catch (_) {
          return await _tryBase(nodeBase);
        }
      },
      onSuccess: (sid) async {
        // Optionally notify your backend to capture
      },
    );
    setState(() { _status = 'sheet: \\${res.status} sessionId=\\${res.sessionId}'; });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton(
            onPressed: _startCheckout,
            child: const Text('Pay with Flex'),
          ),
          const SizedBox(height: 12),
          Text(_status),
        ],
      ),
    );
  }
}
