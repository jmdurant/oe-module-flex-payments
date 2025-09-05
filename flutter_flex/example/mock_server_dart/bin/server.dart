import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_router/shelf_router.dart';

String _html(String body) =>
    '<!doctype html><html><head><meta charset="utf-8" />\n'
    '<meta name="viewport" content="width=device-width, initial-scale=1" />\n'
    '<title>Mock Flex</title>\n'
    '<style>body{font-family:system-ui,Arial;padding:2rem;}button{padding:.6rem 1rem;margin-right:.5rem;} .box{border:1px solid #ccc;padding:1rem;border-radius:.5rem;}</style>\n'
    '</head><body>$body</body></html>';

void main(List<String> args) async {
  final port = int.tryParse(Platform.environment['PORT'] ?? '') ?? 3001;
  final router = Router();

  router.post('/create_checkout_session', (Request req) async {
    final jsonBody = json.decode(await req.readAsString()) as Map<String, dynamic>;
    final amount = jsonBody['amount'] ?? 0;
    final sid = DateTime.now().millisecondsSinceEpoch.toString();
    final base = 'http://localhost:$port';
    final url = '$base/checkout?sid=$sid&amount=$amount';
    final resp = {'id': sid, 'url': url};
    return Response.ok(json.encode(resp), headers: {
      'content-type': 'application/json',
      'access-control-allow-origin': '*',
    });
  });

  router.get('/checkout', (Request req) {
    final params = req.requestedUri.queryParameters;
    final sid = params['sid'] ?? '';
    final amount = params['amount'] ?? '0';
    final body = _html('''
      <h2>Mock Flex Checkout (Dart)</h2>
      <div class="box">
        <p>Session: <b>$sid</b></p>
        <p>Amount: <b>$amount</b></p>
        <button onclick="onPay()">Pay</button>
        <button onclick="onCancel()">Cancel</button>
      </div>
      <script>
        function onPay(){ window.location.href = '/return?status=success&session_id=$sid'; }
        function onCancel(){ window.location.href = '/return?status=cancel&session_id=$sid'; }
      </script>
    ''');
    return Response.ok(body, headers: {'content-type': 'text/html; charset=utf-8', 'access-control-allow-origin': '*'});
  });

  router.get('/return', (Request req) {
    final q = req.requestedUri.queryParameters;
    final status = q['status'] ?? 'unknown';
    final sid = q['session_id'] ?? '';
    final body = _html('<h3>Result: $status</h3><p>Session: <b>$sid</b></p><p>You can close this tab.</p>');
    return Response.ok(body, headers: {'content-type': 'text/html; charset=utf-8', 'access-control-allow-origin': '*'});
  });

  // CORS preflight
  Response _options(Request req) => Response.ok('', headers: {
        'access-control-allow-origin': '*',
        'access-control-allow-headers': 'content-type',
        'access-control-allow-methods': 'POST,GET,OPTIONS',
      });

  final handler = const Pipeline()
      .addMiddleware((innerHandler) {
        return (req) async {
          if (req.method == 'OPTIONS') return _options(req);
          final resp = await innerHandler(req);
          return resp.change(headers: {'access-control-allow-origin': '*'});
        };
      })
      .addHandler(router);

  final server = await serve(handler, InternetAddress.anyIPv4, port);
  // ignore: avoid_print
  print('Dart Mock Flex server running on http://${server.address.host}:${server.port}');
}

