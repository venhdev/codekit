# Colored Logger

A simple yet powerful colored logging utility for Dart and Flutter applications that enhances console output with ANSI colors and styles.

[![pub package](https://img.shields.io/pub/v/colored_logger.svg)](https://pub.dev/packages/colored_logger)

![Screenshot](https://raw.githubusercontent.com/venhdev/colored_logger/main/screenshots/image.png)

## Features

- **Color-coded log levels**: Info (blue), success (green), warning (yellow), error (red)
- **Rich text formatting**: Bold, italic, underline, strikethrough, and more
- **Extensive color support**: Basic colors, bright colors, 256-color palette, and true RGB colors
- **Fluent API**: Chain multiple styles together with a clean, readable syntax
- **String extensions**: Apply styles directly to strings with extension methods

## Installation

```yaml
dependencies:
  colored_logger: ^2.2.0
```

See [Ansi Support](#ansi-support) for more details about ansi support.

On Web, output defaults to plain text because browser consoles are not ANSI
terminals. Terminal detection stays in the native implementation.

## Basic Usage

```dart
import 'package:colored_logger/colored_logger.dart';

void main() {
  // Basic log levels
  ColoredLogger.info('Server started on port 8080');
  ColoredLogger.success('Operation completed successfully');
  ColoredLogger.warning('This is a warning message');
  ColoredLogger.error('An error occurred');

  // Custom styling
  ColoredLogger.colorize(
    'Custom message with bold and cyan text',
    styles: [Ansi.bold, Ansi.cyan],
    prefix: '[STYLED] ',
  );
}
```

## String Extensions

```dart
import 'package:colored_logger/colored_logger.dart';

void main() {
  // Apply styles directly to strings
  print('Bold text'.bold());
  print('Red text'.red());

  // Chain multiple styles
  print('Bold italic green text'.bold.italic.green());

  // Advanced colors
  print('256-color text'.fg256(201)());
  print('RGB color text'.fgRgb(255, 100, 0)());

  // Special effects
  print('Rainbow text'.rainbow());
}
```

## Ansi Class

```dart
import 'package:colored_logger/colored_logger.dart';

void main() {
  // Static methods
  print(Ansi.bold.paint('Bold text'));
  print(Ansi.red.paint('Red text'));

  // Combine styles
  final boldRed = Ansi.bold.combine(Ansi.red);
  print(boldRed.paint('Bold red text'));

  // Using + operator
  final boldItalicGreen = Ansi.bold + Ansi.italic + Ansi.green;
  print(boldItalicGreen.paint('Bold italic green text'));

  // Fluent chaining API
  final customStyle = Ansi.empty.cBold.cItalic.cRed.cBgYellow;
  print(customStyle.paint('Custom styled text'));
}
```

## Available Styles

### Text Formatting

- `bold`, `faint`, `italic`, `underline`, `doubleUnderline`
- `strikethrough`, `overline`, `inverse`, `conceal`
- `slowBlink`, `fastBlink`, `superscript`, `subscript`
- `framed`, `encircled`

### Colors

- Standard: `black`, `red`, `green`, `yellow`, `blue`, `magenta`, `cyan`, `white`
- Bright: `brightBlack`, `brightRed`, `brightGreen`, `brightYellow`, `brightBlue`, `brightMagenta`, `brightCyan`, `brightWhite`
- Background: `bgBlack`, `bgRed`, `bgGreen`, `bgYellow`, `bgBlue`, `bgMagenta`, `bgCyan`, `bgWhite`
- Bright Background: `bgBrightBlack`, `bgBrightRed`, `bgBrightGreen`, `bgBrightYellow`, `bgBrightBlue`, `bgBrightMagenta`, `bgBrightCyan`, `bgBrightWhite`

### Extended Colors

- 256-color: `fg256(index)`, `bg256(index)`
- RGB: `fgRgb(r, g, b)`, `bgRgb(r, g, b)`

## ANSI Support

ANSI escape codes might not render if your terminal lacks support or if `isSupportAnsi` returns `false`.

- Use `paint()` or `call()` on `StyledString` to **force** ANSI rendering, even if `isSupportAnsi` is false. e.g:

  - `print('Text'.bold.paint())`
  - `print('Text'.bold())`

- Otherwise, `print('Hello'.red)` may not colorize the text because not all recognized terminals can report whether they support ANSI escape sequences.

Force ANSI support with environment variables:

```bash
# Dart
dart run --define=ANSI=true main.dart

# Flutter
flutter run --dart-define=ANSI=true
```

To check you have ANSI support in your terminal with `showAnsiInfo()` function.

## License

This project is licensed under the MIT License - see the LICENSE file for details.
