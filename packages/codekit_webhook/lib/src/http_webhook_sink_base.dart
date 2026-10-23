import 'dart:async';

import 'package:codekit_core/codekit_core.dart';

import 'package_http_webhook_transport.dart';
import 'sink_delivery_controller.dart';
import 'webhook_transport.dart';

/// Abstract base class for HTTP-based diagnostic webhook sinks.
///
/// Encapsulates transport lifecycle, circuit breaker delivery control,
/// and dispatch error handling. Subclasses implement [buildRequest] to construct
/// the target payload and [evaluateResponse] to handle platform-specific response validation.
abstract base class HttpWebhookSinkBase implements DiagnosticSink {
  final WebhookTransport transport;
  final PackageHttpWebhookTransport? ownedTransport;
  final SinkDeliveryController delivery;

  @override
  final HttpDispatchPolicy? httpDispatchPolicy;

  @override
  final LogDispatchPolicy? logDispatchPolicy;

  bool _disposed = false;

  HttpWebhookSinkBase({
    required this.transport,
    this.ownedTransport,
    SinkDeliveryController? delivery,
    this.httpDispatchPolicy,
    this.logDispatchPolicy,
  }) : delivery = delivery ?? SinkDeliveryController();

  @override
  void dispatch(DiagnosticRecord record) {
    if (_disposed || !delivery.tryAcquire()) return;
    _send(record);
  }

  Future<void> _send(DiagnosticRecord record) async {
    try {
      final request = await buildRequest(record);
      final response = await transport.send(request);
      final failure = evaluateResponse(response);
      if (failure != null) {
        throw failure;
      }
      delivery.succeeded();
    } catch (error) {
      delivery.failed(
        serverRetryAfter: error is WebhookDeliveryFailure
            ? error.retryAfter
            : null,
      );
    }
  }

  /// Builds the [WebhookRequest] for the given [record].
  FutureOr<WebhookRequest> buildRequest(DiagnosticRecord record);

  /// Evaluates the [response] from the transport.
  ///
  /// Returns `null` if the request succeeded.
  /// Returns a [WebhookDeliveryFailure] (optionally with retry-after) if the delivery failed.
  WebhookDeliveryFailure? evaluateResponse(WebhookResponse response);

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    delivery.dispose();
    ownedTransport?.close();
  }
}

/// Represents a failure during webhook delivery.
final class WebhookDeliveryFailure implements Exception {
  final Duration? retryAfter;
  const WebhookDeliveryFailure([this.retryAfter]);
}
