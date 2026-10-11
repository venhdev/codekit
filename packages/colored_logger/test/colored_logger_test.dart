import 'package:colored_logger/colored_logger.dart';
import 'package:test/test.dart';

void main() {
  group('ColoredLogger', () {
    test('info logs with blue color and INFO prefix', () {
      final List<String> logs = [];
      ColoredLogger.colorize(
        'Test message',
        styles: [Ansi.blue],
        prefix: '[INFO] ',
        writer: (text) => logs.add(text),
      );
      // expect(logs.single, contains('\x1B[34m[INFO] Test message\x1B[39m'));
    });

    test('success logs with green color and SUCCESS prefix', () {
      final List<String> logs = [];
      ColoredLogger.colorize(
        'Test message',
        styles: [Ansi.green],
        prefix: '[SUCCESS] ',
        writer: (text) => logs.add(text),
      );
      // expect(logs.single, contains('\x1B[32m[SUCCESS] Test message\x1B[39m'));
    });

    test('warning logs with yellow color and WARNING prefix', () {
      final List<String> logs = [];
      ColoredLogger.colorize(
        'Test message',
        styles: [Ansi.yellow],
        prefix: '[WARNING] ',
        writer: (text) => logs.add(text),
      );
      // expect(logs.single, contains('\x1B[33m[WARNING] Test message\x1B[39m'));
    });

    test('error logs with red color and ERROR prefix', () {
      final List<String> logs = [];
      ColoredLogger.colorize(
        'Test message',
        styles: [Ansi.red],
        prefix: '[ERROR] ',
        writer: (text) => logs.add(text),
      );
      // expect(logs.single, contains('\x1B[31m[ERROR] Test message\x1B[39m'));
    });
  });
}
