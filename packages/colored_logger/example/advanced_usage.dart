import 'package:colored_logger/colored_logger.dart';

void main() {
  print('=== Text Formatting ===');
  print('Bold: ${'Hello'.bold()}');
  print('Italic: ${'Hello'.italic()}');
  print('Underline: ${'Hello'.underline()}');
  print('Double Underline: ${'Hello'.doubleUnderline()}');
  print('Strikethrough: ${'Hello'.strikethrough()}');
  print('Inverse: ${'Hello'.inverse()}');

  print('\n=== Foreground Colors ===');
  print('Standard colors:');
  print('Black: ${'Hello'.black()}');
  print('Red: ${'Hello'.red()}');
  print('Green: ${'Hello'.green()}');
  print('Yellow: ${'Hello'.yellow()}');
  print('Blue: ${'Hello'.blue()}');
  print('Magenta: ${'Hello'.magenta()}');
  print('Cyan: ${'Hello'.cyan()}');
  print('White: ${'Hello'.white()}');

  print('\nBright colors:');
  print('Bright Black: ${'Hello'.brightBlack()}');
  print('Bright Red: ${'Hello'.brightRed()}');
  print('Bright Green: ${'Hello'.brightGreen()}');
  print('Bright Yellow: ${'Hello'.brightYellow()}');
  print('Bright Blue: ${'Hello'.brightBlue()}');
  print('Bright Magenta: ${'Hello'.brightMagenta()}');
  print('Bright Cyan: ${'Hello'.brightCyan()}');
  print('Bright White: ${'Hello'.brightWhite()}');

  print('\n=== Background Colors ===');
  print('Standard backgrounds:');
  print('BG Black: ${'Hello'.bgBlack()}');
  print('BG Red: ${'Hello'.bgRed()}');
  print('BG Green: ${'Hello'.bgGreen()}');
  print('BG Yellow: ${'Hello'.bgYellow()}');
  print('BG Blue: ${'Hello'.bgBlue()}');
  print('BG Magenta: ${'Hello'.bgMagenta()}');
  print('BG Cyan: ${'Hello'.bgCyan()}');
  print('BG White: ${'Hello'.bgWhite()}');

  print('\n=== Extended Color Support ===');
  print('256-color foreground: ${'Hello'.fg256(201)()}');
  print('256-color background: ${'Hello'.bg256(201)()}');
  print('RGB foreground: ${'Hello'.fgRgb(255, 100, 0)()}');
  print('RGB background: ${'Hello'.bgRgb(255, 100, 0)()}');

  print('\n=== Style Combinations ===');
  print('Bold + Red: ${'Hello'.bold.red()}');
  print('Italic + Green + BG Yellow: ${'Hello'.italic.green.bgYellow()}');
  print('Underline + Bright Blue: ${'Hello'.underline.brightBlue()}');
  print('RGB + Bold: ${'Hello'.fgRgb(100, 200, 255).bold()}');

  print('\n=== Fluent API with Ansi Class ===');
  final customStyle = Ansi.bold.combine(Ansi.red).combine(Ansi.bgYellow);
  print('Custom combined style: ${customStyle.paint('Hello')}');

  // Using the + operator for combining styles
  final combinedStyle = Ansi.italic + Ansi.cyan + Ansi.bgBrightBlack;
  print('Combined with + operator: ${combinedStyle.paint('Hello')}');

  // Using fluent chaining methods
  final fluentStyle = Ansi.empty.cBold.cItalic.cRed.cBgBlue;
  print('Fluent chaining: ${fluentStyle.paint('Hello')}');
}
