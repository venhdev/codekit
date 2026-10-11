import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'webhook_transport.dart';

/// Package-owned transport. Kept separate from codekit_http so its own
/// requests cannot re-enter diagnostics through the application wrapper.
final class PackageHttpWebhookTransport implements WebhookTransport {
  final http.Client _client;
  bool _closed = false;

  PackageHttpWebhookTransport() : _client = http.Client();

  @override
  Future<WebhookResponse> send(WebhookRequest request) async {
    if (_closed) throw StateError('Webhook transport is closed');
    final outgoing = http.Request(request.method, request.uri)
      ..bodyBytes = Uint8List.fromList(request.body);
    for (final entry in request.headers.entries) {
      outgoing.headers[entry.key] = entry.value.join(', ');
    }
    final response = await _client.send(outgoing);
    final bytes = await response.stream.toBytes();
    return WebhookResponse(
      statusCode: response.statusCode,
      headers: response.headers.map(
        (key, value) => MapEntry(key, <String>[value]),
      ),
      body: bytes,
    );
  }

  void close() {
    if (_closed) return;
    _closed = true;
    _client.close();
  }
}
