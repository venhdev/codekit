import 'dart:convert';

import 'package:codekit_core/codekit_core.dart';

import 'formatters/discord_formatter.dart';
import 'package_http_webhook_transport.dart';
import 'sink_delivery_controller.dart';
import 'webhook_sink_options.dart';
import 'webhook_transport.dart';

/// Fire-and-forget Discord webhook sink with a package:http default transport.
final class DiscordSink implements DiagnosticSink {
  final Uri webhookUrl;
  final WebhookTransport _transport;
  final PackageHttpWebhookTransport? _ownedTransport;
  final DiscordSinkOptions? options;
  final DiagnosticContentOptions? contentOptions;
  final SinkDeliveryController _delivery;
  @override
  final HttpDispatchPolicy? httpDispatchPolicy;
  @override
  final LogDispatchPolicy? logDispatchPolicy;
  bool _disposed = false;

  factory DiscordSink({
    required Uri webhookUrl,
    WebhookTransport? transport,
    DiscordSinkOptions? options,
    DiagnosticContentOptions? contentOptions,
    HttpDispatchPolicy? httpDispatchPolicy,
    LogDispatchPolicy? logDispatchPolicy,
    SinkCircuitBreakerOptions? circuitBreaker,
    WebhookWarningCallback? onWarning,
  }) {
    if (webhookUrl.scheme != 'https' && webhookUrl.scheme != 'http') {
      throw ArgumentError.value(webhookUrl, 'webhookUrl');
    }
    if (options?.color case final color? when color < 0 || color > 0xFFFFFF) {
      throw ArgumentError.value(options!.color, 'options.color');
    }
    final owned = transport == null ? PackageHttpWebhookTransport() : null;
    return DiscordSink._(
      webhookUrl: webhookUrl,
      transport: transport ?? owned!,
      ownedTransport: owned,
      options: options,
      contentOptions: contentOptions,
      httpDispatchPolicy: httpDispatchPolicy,
      logDispatchPolicy: logDispatchPolicy,
      delivery: SinkDeliveryController(
        options: circuitBreaker,
        onWarning: onWarning,
      ),
    );
  }

  DiscordSink._({
    required this.webhookUrl,
    required this._transport,
    required this._ownedTransport,
    required this.options,
    required this.contentOptions,
    required this.httpDispatchPolicy,
    required this.logDispatchPolicy,
    required this._delivery,
  });

  @override
  void dispatch(DiagnosticRecord record) {
    if (_disposed || !_delivery.tryAcquire()) return;
    _send(record);
  }

  Future<void> _send(DiagnosticRecord record) async {
    try {
      final uri = webhookUrl.replace(
        queryParameters: {...webhookUrl.queryParameters, 'wait': 'true'},
      );
      final payload = discordPayload(
        record,
        options: options,
        contentOptions: contentOptions,
      );
      final response = await _transport.send(
        WebhookRequest(
          uri: uri,
          method: 'POST',
          headers: const {
            'content-type': ['application/json'],
          },
          body: utf8.encode(jsonEncode(payload)),
        ),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw _WebhookDeliveryFailure(_retryAfter(response));
      }
      _delivery.succeeded();
    } catch (error) {
      _delivery.failed(
        serverRetryAfter: error is _WebhookDeliveryFailure
            ? error.retryAfter
            : null,
      );
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _delivery.disposed();
    _ownedTransport?.close();
  }
}

Duration? _retryAfter(WebhookResponse response) {
  if (response.statusCode != 429) return null;
  final header = response.headers.entries
      .where((entry) => entry.key.toLowerCase() == 'retry-after')
      .expand((entry) => entry.value)
      .firstOrNull;
  if (header != null) {
    final seconds = double.tryParse(header);
    if (seconds != null && seconds > 0) {
      return Duration(milliseconds: (seconds * 1000).round());
    }
  }
  try {
    final decoded = jsonDecode(utf8.decode(response.body));
    final seconds = (decoded as Map)['retry_after'];
    if (seconds is num && seconds > 0) {
      return Duration(milliseconds: (seconds * 1000).round());
    }
  } catch (_) {}
  return null;
}

final class _WebhookDeliveryFailure implements Exception {
  final Duration? retryAfter;
  const _WebhookDeliveryFailure(this.retryAfter);
}
