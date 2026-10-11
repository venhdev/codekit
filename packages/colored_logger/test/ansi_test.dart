import 'package:colored_logger/colored_logger.dart';
import 'package:test/test.dart';

void main() {
  group('Ansi class', () {
    test('Basic formatting', () {
      expect(Ansi.bold.paint('test').contains('\x1B[1m'), isTrue);
      expect(Ansi.italic.paint('test').contains('\x1B[3m'), isTrue);
      expect(Ansi.underline.paint('test').contains('\x1B[4m'), isTrue);
    });

    test('Foreground colors', () {
      expect(Ansi.red.paint('test').contains('\x1B[31m'), isTrue);
      expect(Ansi.green.paint('test').contains('\x1B[32m'), isTrue);
      expect(Ansi.blue.paint('test').contains('\x1B[34m'), isTrue);
      expect(Ansi.brightRed.paint('test').contains('\x1B[91m'), isTrue);
    });

    test('Background colors', () {
      expect(Ansi.bgRed.paint('test').contains('\x1B[41m'), isTrue);
      expect(Ansi.bgGreen.paint('test').contains('\x1B[42m'), isTrue);
      expect(Ansi.bgBlue.paint('test').contains('\x1B[44m'), isTrue);
      expect(Ansi.bgBrightRed.paint('test').contains('\x1B[101m'), isTrue);
    });

    test('Extended colors', () {
      expect(Ansi.fg256(100).paint('test').contains('\x1B[38;5;100m'), isTrue);
      expect(Ansi.bg256(100).paint('test').contains('\x1B[48;5;100m'), isTrue);
      expect(
        Ansi.fgRgb(10, 20, 30).paint('test').contains('\x1B[38;2;10;20;30m'),
        isTrue,
      );
      expect(
        Ansi.bgRgb(10, 20, 30).paint('test').contains('\x1B[48;2;10;20;30m'),
        isTrue,
      );
    });

    test('Combining styles', () {
      final combined = Ansi.bold.combine(Ansi.red);
      expect(combined.paint('test').contains('\x1B[1;31m'), isTrue);

      final withOperator = Ansi.italic + Ansi.green;
      expect(withOperator.paint('test').contains('\x1B[3;32m'), isTrue);
    });

    test('Fluent chaining', () {
      final fluent = Ansi.empty.cBold.cRed;
      expect(fluent.paint('test').contains('\x1B[1;31m'), isTrue);
    });

    test('Error handling', () {
      expect(() => Ansi.font(0), throwsArgumentError);
      expect(() => Ansi.font(10), throwsArgumentError);
      expect(() => Ansi.fg256(-1), throwsArgumentError);
      expect(() => Ansi.fg256(256), throwsArgumentError);
      expect(() => Ansi.fgRgb(-1, 0, 0), throwsArgumentError);
      expect(() => Ansi.fgRgb(0, -1, 0), throwsArgumentError);
      expect(() => Ansi.fgRgb(0, 0, -1), throwsArgumentError);
      expect(() => Ansi.fgRgb(256, 0, 0), throwsArgumentError);
      expect(() => Ansi.fgRgb(0, 256, 0), throwsArgumentError);
      expect(() => Ansi.fgRgb(0, 0, 256), throwsArgumentError);
    });
  });
}
