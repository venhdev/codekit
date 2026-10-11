import 'package:colored_logger/src/ansi.dart';
import 'package:colored_logger/src/debug.dart';
import 'package:colored_logger/src/extensions.dart';
import 'package:test/test.dart';

// Mock isSupportAnsi for testing non-ANSI environments
bool _mockIsSupportAnsi = true;
bool get isSupportAnsi => _mockIsSupportAnsi;

void main() {
  test('print raw', () {
    print('=== Basic Text Formatting ===');
    printEscCodes(bold('Hello').toString(), label: 'Bold');
    printEscCodes(italic('Hello').toString(), label: 'Italic');
    printEscCodes(underline('Hello').toString(), label: 'Underline');
    printEscCodes(
      doubleUnderline('Hello').toString(),
      label: 'Double Underline',
    );
    printEscCodes(superscript('Hello').toString(), label: 'Superscript');
    printEscCodes(subscript('Hello').toString(), label: 'Subscript');
    printEscCodes(overline('Hello').toString(), label: 'Overline');
    printEscCodes(framed('Hello').toString(), label: 'Framed');
    printEscCodes(encircled('Hello').toString(), label: 'Encircled');
    printEscCodes(slowBlink('Hello').toString(), label: 'Slow Blink');
    printEscCodes(fastBlink('Hello').toString(), label: 'Fast Blink');
    printEscCodes(inverse('Hello').toString(), label: 'Inverse');
    printEscCodes(conceal('Hello').toString(), label: 'Conceal');
    printEscCodes(strikethrough('Hello').toString(), label: 'Strikethrough');
    printEscCodes(defaultFont('Hello').toString(), label: 'Default Font');

    print('\n=== Alternate Fonts ===');
    printEscCodes(font('Hello', 1).toString(), label: 'Font 1');
    printEscCodes(font('Hello', 9).toString(), label: 'Font 9');
    try {
      printEscCodes(
        font('Hello', 0).toString(),
        label: 'Font 0 (should throw)',
      );
    } catch (e) {
      print('Font 0 error: $e');
    }
    try {
      printEscCodes(
        font('Hello', 10).toString(),
        label: 'Font 10 (should throw)',
      );
    } catch (e) {
      print('Font 10 error: $e');
    }

    print('\n=== Foreground Colors (16-color) ===');
    printEscCodes(red('Hello').toString(), label: 'Red');
    printEscCodes(brightGreen('Hello').toString(), label: 'Bright Green');
    printEscCodes(cyan('Hello').toString(), label: 'Cyan');
    printEscCodes(brightWhite('Hello').toString(), label: 'Bright White');

    print('\n=== Background Colors (16-color) ===');
    printEscCodes(bgBlue('Hello').toString(), label: 'Blue Background');
    printEscCodes(
      bgBrightYellow('Hello').toString(),
      label: 'Bright Yellow Background',
    );
    printEscCodes(bgMagenta('Hello').toString(), label: 'Magenta Background');
    printEscCodes(
      bgBrightBlack('Hello').toString(),
      label: 'Bright Black Background',
    );

    print('\n=== 256-Color Support ===');
    printEscCodes(
      fg256('Hello', 208).toString(),
      label: 'Foreground 256 (208)',
    );
    printEscCodes(
      bg256('Hello', 128).toString(),
      label: 'Background 256 (128)',
    );
    try {
      printEscCodes(
        fg256('Hello', -1).toString(),
        label: 'Foreground 256 (-1, should throw)',
      );
    } catch (e) {
      print('Foreground 256 (-1) error: $e');
    }
    try {
      printEscCodes(
        bg256('Hello', 256).toString(),
        label: 'Background 256 (256, should throw)',
      );
    } catch (e) {
      print('Background 256 (256) error: $e');
    }

    print('\n=== True Color (RGB) Support ===');
    printEscCodes(
      fgRgb('Hello', 255, 165, 0).toString(),
      label: 'Foreground RGB(255,165,0)',
    );
    printEscCodes(
      bgRgb('Hello', 0, 128, 255).toString(),
      label: 'Background RGB(0,128,255)',
    );
    try {
      printEscCodes(
        fgRgb('Hello', 256, 0, 0).toString(),
        label: 'Foreground RGB(256,0,0, should throw)',
      );
    } catch (e) {
      print('Foreground RGB(256,0,0) error: $e');
    }

    print('\n=== Chaining Multiple Styles ===');
    printEscCodes(
      bold('Hello').green.bgRgb(0, 0, 0).toString(),
      label: 'Bold + Green + Black RGB Background',
    );
    printEscCodes(
      italic('Hello').fg256(208).bgBrightYellow.superscript.toString(),
      label: 'Italic + 256(208) + Bright Yellow Background + Superscript',
    );
    printEscCodes(
      underline('Hello').brightCyan.bgBlack.font(2).toString(),
      label: 'Underline + Bright Cyan + Black Background + Font 2',
    );

    print('\n=== Nested Styles ===');
    String nested = '${bold('Bold')} and ${red('Red')}';
    printEscCodes(italic(nested).toString(), label: 'Bold + Red, then Italic');
    String complexNested = green('Green ${underline('Underlined')}').toString();
    printEscCodes(
      bold(complexNested).toString(),
      label: 'Green + Underlined, then Bold',
    );

    print('\n=== Complex Chaining with Nested Styles ===');
    String nested2 = red('Red ${italic('Italic')}').toString();
    printEscCodes(
      bold(nested2).bg256(128).toString(),
      label: 'Red + Italic, then Bold + 256(128)',
    );
    String multiNested =
        bold('Bold').toString() +
        cyan(underline('Under').toString()).toString();
    printEscCodes(
      fg256(multiNested, 208).overline.toString(),
      label: 'Bold + (Cyan + Under), then 256(208) + Overline',
    );

    print('\n=== Non-ANSI Environment ===');
    _mockIsSupportAnsi = false;
    printEscCodes(
      bold('Hello').green.bgRgb(0, 0, 0).toString(),
      label: 'Bold + Green + RGB Background (no ANSI)',
    );
    printEscCodes(
      fg256('Hello', 208).italic.toString(),
      label: '256(208) + Italic (no ANSI)',
    );
    _mockIsSupportAnsi = true; // Reset

    print('\n=== Edge Cases ===');
    printEscCodes(bold('').toString(), label: 'Empty string');
    printEscCodes(
      fgRgb('', 255, 0, 0).bg256(128).toString(),
      label: 'Empty string with multiple styles',
    );
    printEscCodes(Ansi.bold.paint(null), label: 'Null input');
    String alreadyStyled = '\x1B[31mRed\x1B[39m';
    printEscCodes(
      bold(alreadyStyled).toString(),
      label: 'Already styled + Bold',
    );
    printEscCodes(
      StyledString('Hello', [Ansi.reset]).toString(),
      label: 'Reset',
    );

    print('\n=== Combining Conflicting Styles ===');
    printEscCodes(
      red('Hello').brightGreen.fg256(208).toString(),
      label: 'Multiple foregrounds (Red + Bright Green + 256(208))',
    );
    printEscCodes(
      bgBlue('Hello').bgBrightYellow.bgRgb(0, 0, 0).toString(),
      label: 'Multiple backgrounds (Blue + Bright Yellow + RGB(0,0,0))',
    );

    print('\n=== Stringify with Non-String Inputs ===');
    printEscCodes(Ansi.bold.paint(123), label: 'Number');
    printEscCodes(Ansi.green.paint({'key': 'value'}), label: 'Map');
    printEscCodes(Ansi.italic.paint([1, 2, 3]), label: 'List');
    printEscCodes(Ansi.bold.paint(() => 'Dynamic'), label: 'Function');
  });
}
