import 'package:codekit_webhook/src/sink_delivery_controller.dart';
import 'package:codekit_webhook/codekit_webhook.dart';
import 'package:test/test.dart';

void main() {
  test(
    'circuit opens at threshold, allows one cooled-down probe, then resets',
    () {
      var now = DateTime.utc(2026);
      final warnings = <WebhookWarning>[];
      final controller = SinkDeliveryController(
        options: const SinkCircuitBreakerOptions(
          failureThreshold: 2,
          cooldown: Duration(minutes: 1),
        ),
        onWarning: warnings.add,
        clock: () => now,
      );

      expect(controller.tryAcquire(), isTrue);
      controller.failed();
      expect(controller.tryAcquire(), isTrue);
      controller.failed();
      expect(controller.tryAcquire(), isFalse);
      expect(warnings.map((warning) => warning.code), ['circuitOpened']);

      now = now.add(const Duration(minutes: 1));
      expect(controller.tryAcquire(), isTrue);
      controller.succeeded();
      expect(controller.tryAcquire(), isTrue);
      controller.succeeded();
      expect(warnings, hasLength(1));
    },
  );

  test('server cooldown drops subsequent deliveries without buffering', () {
    var now = DateTime.utc(2026);
    final warnings = <WebhookWarning>[];
    final controller = SinkDeliveryController(
      onWarning: warnings.add,
      clock: () => now,
    );

    expect(controller.tryAcquire(), isTrue);
    controller.failed(serverRetryAfter: const Duration(seconds: 30));
    expect(controller.tryAcquire(), isFalse);
    expect(warnings.map((warning) => warning.code), ['rateLimited']);

    now = now.add(const Duration(seconds: 30));
    expect(controller.tryAcquire(), isTrue);
    controller.succeeded();
  });
}
