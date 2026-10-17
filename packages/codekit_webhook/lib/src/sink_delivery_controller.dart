import 'webhook_sink_options.dart';

/// Applies drop-while-busy, server cooldown and per-instance circuit breaking.
final class SinkDeliveryController {
  final SinkCircuitBreakerOptions _options;
  final WebhookWarningCallback? _onWarning;
  final DateTime Function() _clock;
  int _failures = 0;
  DateTime? _circuitUntil;
  DateTime? _serverCooldownUntil;
  bool _busy = false;
  bool _disposed = false;

  SinkDeliveryController({
    SinkCircuitBreakerOptions? options,
    WebhookWarningCallback? onWarning,
    DateTime Function()? clock,
  }) : this._(
         options ?? const SinkCircuitBreakerOptions(),
         onWarning,
         clock ?? DateTime.now,
       );

  SinkDeliveryController._(this._options, this._onWarning, this._clock) {
    _options.validate();
  }

  /// Returns false if this event should be dropped immediately.
  bool tryAcquire() {
    if (_disposed || _busy || _coolingDown) return false;
    if (_circuitUntil != null) _circuitUntil = null; // One half-open probe.
    _busy = true;
    return true;
  }

  bool get _coolingDown {
    final now = _clock();
    return (_circuitUntil?.isAfter(now) ?? false) ||
        (_serverCooldownUntil?.isAfter(now) ?? false);
  }

  void succeeded() {
    if (_disposed) return;
    _failures = 0;
    _circuitUntil = null;
    _serverCooldownUntil = null;
    _busy = false;
  }

  void failed({Duration? serverRetryAfter}) {
    if (_disposed) return;
    _failures++;
    if (serverRetryAfter != null && serverRetryAfter > Duration.zero) {
      _serverCooldownUntil = _clock().add(serverRetryAfter);
      reportWebhookWarning(
        _onWarning,
        'rateLimited',
        'Webhook sink is rate limited; later deliveries are dropped temporarily.',
      );
    }
    if (_failures >= _options.effectiveFailureThreshold &&
        _circuitUntil == null) {
      _circuitUntil = _clock().add(_options.effectiveCooldown);
      reportWebhookWarning(
        _onWarning,
        'circuitOpened',
        'Webhook sink circuit opened after consecutive delivery failures.',
      );
    }
    _busy = false;
  }

  void dispose() {
    _disposed = true;
    _busy = false;
  }
}
