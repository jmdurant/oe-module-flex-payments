import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_flex/flutter_flex.dart';

enum FlexSheetStatus { success, cancel, error }

class FlexPaymentSheetResult {
  final FlexSheetStatus status;
  final String? sessionId;
  final Object? error;
  const FlexPaymentSheetResult(this.status, {this.sessionId, this.error});
}

class FlexPaymentSheetConfig {
  final String title;
  final String? subtitle;
  final String? amountLabel;
  final String successUrlContains;
  final String cancelUrlContains;

  const FlexPaymentSheetConfig({
    this.title = 'Pay with Flex',
    this.subtitle,
    this.amountLabel,
    this.successUrlContains = 'status=success',
    this.cancelUrlContains = 'status=cancel',
  });
}

class FlexPaymentSheet {
  static Future<FlexPaymentSheetResult> present(
    BuildContext context, {
    required Future<String> Function() createSession,
    FlexPaymentSheetConfig config = const FlexPaymentSheetConfig(),
    FutureOr<void> Function(String sessionId)? onSuccess,
    FutureOr<void> Function()? onCancel,
    FutureOr<void> Function(Object error)? onError,
  }) async {
    return Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (_, __, ___) => _FlexSheetPage(
          createSession: createSession,
          config: config,
          onSuccess: onSuccess,
          onCancel: onCancel,
          onError: onError,
        ),
      ),
    );
  }
}

class _FlexSheetPage extends StatefulWidget {
  final Future<String> Function() createSession;
  final FlexPaymentSheetConfig config;
  final FutureOr<void> Function(String sessionId)? onSuccess;
  final FutureOr<void> Function()? onCancel;
  final FutureOr<void> Function(Object error)? onError;
  const _FlexSheetPage({
    required this.createSession,
    required this.config,
    this.onSuccess,
    this.onCancel,
    this.onError,
  });

  @override
  State<_FlexSheetPage> createState() => _FlexSheetPageState();
}

class _FlexSheetPageState extends State<_FlexSheetPage> {
  String? _error;
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    setState(() => _busy = true);
    try {
      final url = await widget.createSession();
      final result = await FlutterFlex.presentCheckout(
        checkoutUrl: url,
        successUrlContains: widget.config.successUrlContains,
        cancelUrlContains: widget.config.cancelUrlContains,
      );
      final statusStr = (result['status'] ?? 'error').toString();
      final sid = result['sessionId']?.toString();

      if (statusStr == 'success') {
        try { if (sid != null) await widget.onSuccess?.call(sid); } catch (_) {}
        if (!mounted) return;
        Navigator.of(context).pop(FlexPaymentSheetResult(FlexSheetStatus.success, sessionId: sid));
      } else if (statusStr == 'cancel') {
        try { await widget.onCancel?.call(); } catch (_) {}
        if (!mounted) return;
        Navigator.of(context).pop(const FlexPaymentSheetResult(FlexSheetStatus.cancel));
      } else {
        setState(() { _error = 'Checkout failed'; _busy = false; });
      }
    } catch (e) {
      try { await widget.onError?.call(e); } catch (_) {}
      setState(() { _error = e.toString(); _busy = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.config;
    return Material(
      color: Colors.black54,
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(c.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              if (c.subtitle != null) ...[
                const SizedBox(height: 4),
                Text(c.subtitle!, style: const TextStyle(color: Colors.black54)),
              ],
              if (c.amountLabel != null) ...[
                const SizedBox(height: 8),
                Text(c.amountLabel!, style: const TextStyle(fontSize: 18)),
              ],
              const SizedBox(height: 16),
              if (_busy) ...[
                const Center(child: CircularProgressIndicator()),
              ] else if (_error != null) ...[
                Text(_error!, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => Navigator.of(context).pop(const FlexPaymentSheetResult(FlexSheetStatus.error)), child: const Text('Close')),
                    const SizedBox(width: 8),
                    ElevatedButton(onPressed: _run, child: const Text('Try again')),
                  ],
                )
              ],
            ],
          ),
        ),
      ),
    );
  }
}

