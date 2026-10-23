import 'dart:convert';

import 'package:codekit_core/codekit_core.dart';

import 'formatters/discord_formatter.dart';
import 'http_webhook_sink_base.dart';
import 'package_http_webhook_transport.dart';
import 'sink_delivery_controller.dart';
import 'webhook_sink_options.dart';
import 'webhook_transport.dart';

/// Fire-and-forget Discord webhook sink with a package:http default transport.
final class DiscordSink extends HttpWebhookSinkBase {
  final Uri webhookUrl;
  final DiscordSinkOptions? options;
  final DiagnosticContentOptions? contentOptions;

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
    required super.transport,
    required super.ownedTransport,
    required this.options,
    required this.contentOptions,
    super.httpDispatchPolicy,
    super.logDispatchPolicy,
    required super.delivery,
  });

  @override
  WebhookRequest buildRequest(DiagnosticRecord record) {
    final uri = webhookUrl.replace(
      queryParameters: {...webhookUrl.queryParameters, 'wait': 'true'},
    );
    final payload = discordPayload(
      record,
      options: options,
      contentOptions: contentOptions,
    );
    return WebhookRequest(
      uri: uri,
      method: 'POST',
      headers: const {
        'content-type': ['application/json'],
      },
      body: utf8.encode(jsonEncode(payload)),
    );
  }

  @override
  WebhookDeliveryFailure? evaluateResponse(WebhookResponse response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return WebhookDeliveryFailure(_retryAfter(response));
    }
    return null;
  }

  static Duration? _retryAfter(WebhookResponse response) {
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
}
