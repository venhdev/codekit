import 'dart:developer';

import 'terminal_environment_io.dart'
    if (dart.library.js_interop) 'terminal_environment_web.dart'
    as terminal;

import 'package:colored_logger/src/extensions.dart';
import 'package:colored_logger/src/utils.dart';

import 'ansi.dart';
import 'types.dart';

void _defaultConsoleWriter(String text) => print(text);

bool get _supportsAnsiEscapes => terminal.supportsAnsiEscapes;
bool get _supportStdout => terminal.supportsStdout;

/// Environment variable for ANSI support
const bool? _ansiEnv_ = bool.hasEnvironment("ANSI")
    ? bool.fromEnvironment("ANSI")
    : null;
bool get _isTest => terminal.isTest;
bool get isSupportAnsi => _ansiEnv_ != null
    ? _ansiEnv_!
    : (_supportsAnsiEscapes && _supportStdout) || _isTest;

void showAnsiInfo() => print(ansiInfo());
void showStdInfo() => stdioInfo();

/// A simple yet powerful colored logging utility for Dart and Flutter applications.
///
/// This class provides static methods for logging messages with different colors
/// and styles using ANSI escape codes. It's designed to enhance console output
/// with color-coded log levels for better readability.
class ColoredLogger {
  /// Private constructor to prevent instantiation
  ColoredLogger._();

  /// Logs an informational message in blue color.
  ///
  /// Example:
  /// ```dart
  /// ColoredLogger.info('Server started on port 8080');
  /// ```
  ///
  /// - [message] The message to log
  /// - [prefix] The prefix to add before the message (default: '[INFO] ')
  static void info(
    String message, {
    String prefix = '[INFO] ',
    Writer? writer,
  }) {
    colorize(message, styles: [Ansi.blue], prefix: prefix, writer: writer);
  }

  /// Logs a success message in green.
  ///
  /// - [message] The message to log
  /// - [prefix] The prefix to add before the message (default: '[SUCCESS] ')
  static void success(
    String message, {
    String prefix = '[SUCCESS] ',
    Writer? writer,
  }) {
    colorize(message, styles: [Ansi.green], prefix: prefix, writer: writer);
  }

  /// Logs a warning message in yellow.
  ///
  /// - [message] The message to log
  /// - [prefix] The prefix to add before the message (default: '[WARNING] ')
  static void warning(
    String message, {
    String prefix = '[WARNING] ',
    Writer? writer,
  }) {
    colorize(message, styles: [Ansi.yellow], prefix: prefix, writer: writer);
  }

  /// Logs an error message in red.
  ///
  /// - [message] The message to log
  /// - [prefix] The prefix to add before the message (default: '[ERROR] ')
  static void error(
    String message, {
    String prefix = '[ERROR] ',
    Writer? writer,
  }) {
    colorize(message, styles: [Ansi.red], prefix: prefix, writer: writer);
  }

  /// A public method to generate a String that applies ANSI escape codes to colorize the given text.
  ///
  /// This method leverages `StyledString` and `Ansi` for advanced text styling.
  ///
  /// - [input] The text to colorize. Can be a `String` or `StyledString`.
  /// - [styles] Optional list of `Ansi` styles to apply.
  /// - [prefix] An optional prefix to add before the text.
  ///
  /// Example:
  /// ```dart
  /// ColoredLogger.colorize(
  ///   'This is a custom message with bold and cyan text.',
  ///   styles: [Ansi.bold, Ansi.cyan],
  ///   prefix: '[STYLED] ',
  ///   printer: print, // You can provide a custom printer function here
  /// );
  /// ```
  static void colorize(
    dynamic input, {
    List<Ansi>? styles,
    String prefix = '',
    Writer? writer,
  }) {
    final String text_ = '$prefix${stringify(input)}';
    if (styles == null || styles.isEmpty || !isSupportAnsi) {
      _print(text_, writer: writer);
    } else {
      final StyledString styledText = StyledString(text_, styles);
      _print(styledText.toString(), writer: writer);
    }
  }
}

void _print(String text, {Writer? writer}) {
  (writer ?? _defaultConsoleWriter)(text);
}

void stdioInfo() => print(terminal.terminalInfo());

String ansiInfo([Writer? writer = log]) {
  final String s1 =
      '[AnsiInfo] Connected to a terminal that supports ANSI escape sequences (Not all terminals are recognized): $_supportsAnsiEscapes';
  final String suffixS2 = '\n\t ==> isSupportAnsi: $isSupportAnsi';
  final String s2 =
      '[AnsiInfo] Supports stdout: $_supportStdout (${terminal.stdoutDescription})$suffixS2';
  final String s3 =
      '[AnsiInfo] ANSI support is determined by the environment variable "ANSI": $_ansiEnv_ \n\t(flutter run --dart-define=ANSI=true main.dart) or \n\t(dart run --define=ANSI=true main.dart)';
  final String s4 =
      '[AnsiInfo] The current environment is a test environment: $_isTest';
  final String s5 =
      '[AnsiInfo] Demo: ${'This is underlines ${'red${'Italic'.italic}'.red()}'.underline()} text and this is ${'green${bold('\nBold')} in multi-line'.green.paint()} text. This is a ${'rainbow text'.rainbow(true).italic.slowBlink()}. Can you see it?';

  final result = '$s1\n$s2\n$s3\n$s4\n$s5';
  if (writer != null) writer(result);
  return result;
}
