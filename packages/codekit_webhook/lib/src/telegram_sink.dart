import 'dart:convert';

import 'package:codekit_core/codekit_core.dart';

import 'formatters/telegram_formatter.dart';
import 'package_http_webhook_transport.dart';
import 'sink_delivery_controller.dart';
import 'webhook_sink_options.dart';
import 'webhook_transport.dart';

/// Fire-and-forget Telegram sendMessage sink.
final class TelegramSink implements DiagnosticSink {
  final String botToken;
  final String chatId;
  final WebhookTransport _transport;
  final PackageHttpWebhookTransport? _ownedTransport;
  final TelegramSinkOptions? options;
  final DiagnosticContentOptions? contentOptions;
  final SinkDeliveryController _delivery;
  @override
  final HttpDispatchPolicy? httpDispatchPolicy;
  @override
  final LogDispatchPolicy? logDispatchPolicy;
  bool _disposed = false;

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
      final payload = telegramPayload(
        record,
        chatId: chatId,
        options: options,
        contentOptions: contentOptions,
      );
      final response = await _transport.send(
        WebhookRequest(
          uri: Uri.https('api.telegram.org', '/bot$botToken/sendMessage'),
          method: 'POST',
          headers: const {
            'content-type': ['application/json'],
          },
          body: utf8.encode(jsonEncode(payload)),
        ),
      );
      final decoded = jsonDecode(utf8.decode(response.body));
      final ok =
          response.statusCode >= 200 &&
          response.statusCode < 300 &&
          decoded is Map &&
          decoded['ok'] == true;
      if (!ok) throw _TelegramDeliveryFailure(_retryAfter(response, decoded));
      _delivery.succeeded();
    } catch (error) {
      _delivery.failed(
        serverRetryAfter: error is _TelegramDeliveryFailure
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

Duration? _retryAfter(WebhookResponse response, Object? decoded) {
  if (response.statusCode != 429 || decoded is! Map) return null;
  final parameters = decoded['parameters'];
  final seconds = parameters is Map ? parameters['retry_after'] : null;
  if (seconds is num && seconds > 0) {
    return Duration(seconds: seconds.ceil());
  }
  return null;
}

final class _TelegramDeliveryFailure implements Exception {
  final Duration? retryAfter;
  const _TelegramDeliveryFailure(this.retryAfter);
}
