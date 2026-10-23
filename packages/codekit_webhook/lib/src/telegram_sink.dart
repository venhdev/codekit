import 'dart:convert';

import 'package:codekit_core/codekit_core.dart';

import 'formatters/telegram_formatter.dart';
import 'http_webhook_sink_base.dart';
import 'package_http_webhook_transport.dart';
import 'sink_delivery_controller.dart';
import 'webhook_sink_options.dart';
import 'webhook_transport.dart';

/// Fire-and-forget Telegram sendMessage sink.
final class TelegramSink extends HttpWebhookSinkBase {
  final String botToken;
  final String chatId;
  final TelegramSinkOptions? options;
  final DiagnosticContentOptions? contentOptions;

  factory TelegramSink({
    required String botToken,
    required String chatId,
    WebhookTransport? transport,
    TelegramSinkOptions? options,
    DiagnosticContentOptions? contentOptions,
    HttpDispatchPolicy? httpDispatchPolicy,
    LogDispatchPolicy? logDispatchPolicy,
    SinkCircuitBreakerOptions? circuitBreaker,
    WebhookWarningCallback? onWarning,
  }) {
    if (botToken.isEmpty) throw ArgumentError.value(botToken, 'botToken');
    if (chatId.isEmpty) throw ArgumentError.value(chatId, 'chatId');
    final owned = transport == null ? PackageHttpWebhookTransport() : null;
    return TelegramSink._(
      botToken: botToken,
      chatId: chatId,
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

  TelegramSink._({
    required this.botToken,
    required this.chatId,
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
    final payload = telegramPayload(
      record,
      chatId: chatId,
      options: options,
      contentOptions: contentOptions,
    );
    return WebhookRequest(
      uri: Uri.https('api.telegram.org', '/bot$botToken/sendMessage'),
      method: 'POST',
      headers: const {
        'content-type': ['application/json'],
      },
      body: utf8.encode(jsonEncode(payload)),
    );
  }

  @override
  WebhookDeliveryFailure? evaluateResponse(WebhookResponse response) {
    final decoded = jsonDecode(utf8.decode(response.body));
    final ok =
        response.statusCode >= 200 &&
        response.statusCode < 300 &&
        decoded is Map &&
        decoded['ok'] == true;
    if (!ok) {
      return WebhookDeliveryFailure(_retryAfter(response, decoded));
    }
    return null;
  }

  static Duration? _retryAfter(WebhookResponse response, Object? decoded) {
    if (response.statusCode != 429 || decoded is! Map) return null;
    final parameters = decoded['parameters'];
    final seconds = parameters is Map ? parameters['retry_after'] : null;
    if (seconds is num && seconds > 0) {
      return Duration(seconds: seconds.ceil());
    }
    return null;
  }
}
