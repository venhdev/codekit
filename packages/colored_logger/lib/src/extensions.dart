import '../colored_logger.dart';
import 'utils.dart';

// Public functions for styling
StyledString bold(String text) => StyledString(text, [Ansi.bold]);
StyledString faint(String text) => StyledString(text, [Ansi.faint]);
StyledString italic(String text) => StyledString(text, [Ansi.italic]);
StyledString underline(String text) => StyledString(text, [Ansi.underline]);
StyledString slowBlink(String text) => StyledString(text, [Ansi.slowBlink]);
StyledString fastBlink(String text) => StyledString(text, [Ansi.fastBlink]);
StyledString inverse(String text) => StyledString(text, [Ansi.inverse]);
StyledString conceal(String text) => StyledString(text, [Ansi.conceal]);
StyledString strikethrough(String text) =>
    StyledString(text, [Ansi.strikethrough]);
StyledString defaultFont(String text) => StyledString(text, [Ansi.defaultFont]);
StyledString doubleUnderline(String text) =>
    StyledString(text, [Ansi.doubleUnderline]);
StyledString superscript(String text) => StyledString(text, [Ansi.superscript]);
StyledString subscript(String text) => StyledString(text, [Ansi.subscript]);
StyledString overline(String text) => StyledString(text, [Ansi.overline]);
StyledString framed(String text) => StyledString(text, [Ansi.framed]);
StyledString encircled(String text) => StyledString(text, [Ansi.encircled]);
StyledString font(String text, int n) => StyledString(text, [Ansi.font(n)]);
StyledString fg256(String text, int colorIndex) =>
    StyledString(text, [Ansi.fg256(colorIndex)]);
StyledString bg256(String text, int colorIndex) =>
    StyledString(text, [Ansi.bg256(colorIndex)]);
StyledString fgRgb(String text, int r, int g, int b) =>
    StyledString(text, [Ansi.fgRgb(r, g, b)]);
StyledString bgRgb(String text, int r, int g, int b) =>
    StyledString(text, [Ansi.bgRgb(r, g, b)]);
StyledString black(String text) => StyledString(text, [Ansi.black]);
StyledString red(String text) => StyledString(text, [Ansi.red]);
StyledString green(String text) => StyledString(text, [Ansi.green]);
StyledString yellow(String text) => StyledString(text, [Ansi.yellow]);
StyledString blue(String text) => StyledString(text, [Ansi.blue]);
StyledString magenta(String text) => StyledString(text, [Ansi.magenta]);
StyledString cyan(String text) => StyledString(text, [Ansi.cyan]);
StyledString white(String text) => StyledString(text, [Ansi.white]);
StyledString brightBlack(String text) => StyledString(text, [Ansi.brightBlack]);
StyledString brightRed(String text) => StyledString(text, [Ansi.brightRed]);
StyledString brightGreen(String text) => StyledString(text, [Ansi.brightGreen]);
StyledString brightYellow(String text) =>
    StyledString(text, [Ansi.brightYellow]);
StyledString brightBlue(String text) => StyledString(text, [Ansi.brightBlue]);
StyledString brightMagenta(String text) =>
    StyledString(text, [Ansi.brightMagenta]);
StyledString brightCyan(String text) => StyledString(text, [Ansi.brightCyan]);
StyledString brightWhite(String text) => StyledString(text, [Ansi.brightWhite]);
StyledString bgBlack(String text) => StyledString(text, [Ansi.bgBlack]);
StyledString bgRed(String text) => StyledString(text, [Ansi.bgRed]);
StyledString bgGreen(String text) => StyledString(text, [Ansi.bgGreen]);
StyledString bgYellow(String text) => StyledString(text, [Ansi.bgYellow]);
StyledString bgBlue(String text) => StyledString(text, [Ansi.bgBlue]);
StyledString bgMagenta(String text) => StyledString(text, [Ansi.bgMagenta]);
StyledString bgCyan(String text) => StyledString(text, [Ansi.bgCyan]);
StyledString bgWhite(String text) => StyledString(text, [Ansi.bgWhite]);
StyledString bgBrightBlack(String text) =>
    StyledString(text, [Ansi.bgBrightBlack]);
StyledString bgBrightRed(String text) => StyledString(text, [Ansi.bgBrightRed]);
StyledString bgBrightGreen(String text) =>
    StyledString(text, [Ansi.bgBrightGreen]);
StyledString bgBrightYellow(String text) =>
    StyledString(text, [Ansi.bgBrightYellow]);
StyledString bgBrightBlue(String text) =>
    StyledString(text, [Ansi.bgBrightBlue]);
StyledString bgBrightMagenta(String text) =>
    StyledString(text, [Ansi.bgBrightMagenta]);
StyledString bgBrightCyan(String text) =>
    StyledString(text, [Ansi.bgBrightCyan]);
StyledString bgBrightWhite(String text) =>
    StyledString(text, [Ansi.bgBrightWhite]);

extension AnsiString on String {
  String paint(Ansi? ansi, [bool force = false]) =>
      ansi == null ? this : StyledString(this, [ansi]).toString(force);

  // Helper method to start styling
  StyledString style(Ansi? ansi) =>
      ansi == null ? _empty() : StyledString(this, [ansi]);
  StyledString styles(List<Ansi> ansiList) => StyledString(this, ansiList);
  StyledString _empty() => StyledString(this, []);

  // ## 1. Text Formatting
  StyledString get bold => style(Ansi.bold);
  StyledString get faint => style(Ansi.faint);
  StyledString get italic => style(Ansi.italic);
  StyledString get underline => style(Ansi.underline);
  StyledString get slowBlink => style(Ansi.slowBlink);
  StyledString get fastBlink => style(Ansi.fastBlink);
  StyledString get inverse => style(Ansi.inverse);
  StyledString get conceal => style(Ansi.conceal);
  StyledString get strikethrough => style(Ansi.strikethrough);
  StyledString get defaultFont => style(Ansi.defaultFont);
  StyledString get doubleUnderline => style(Ansi.doubleUnderline);
  StyledString get superscript => style(Ansi.superscript);
  StyledString get subscript => style(Ansi.subscript);
  StyledString get overline => style(Ansi.overline);
  StyledString get framed => style(Ansi.framed);
  StyledString get encircled => style(Ansi.encircled);

  // ## 2. Alternate Fonts
  StyledString font(int n) => style(Ansi.font(n));

  // ## 3. Foreground Colors
  StyledString get black => style(Ansi.black);
  StyledString get red => style(Ansi.red);
  StyledString get green => style(Ansi.green);
  StyledString get yellow => style(Ansi.yellow);
  StyledString get blue => style(Ansi.blue);
  StyledString get magenta => style(Ansi.magenta);
  StyledString get cyan => style(Ansi.cyan);
  StyledString get white => style(Ansi.white);
  StyledString get brightBlack => style(Ansi.brightBlack);
  StyledString get brightRed => style(Ansi.brightRed);
  StyledString get brightGreen => style(Ansi.brightGreen);
  StyledString get brightYellow => style(Ansi.brightYellow);
  StyledString get brightBlue => style(Ansi.brightBlue);
  StyledString get brightMagenta => style(Ansi.brightMagenta);
  StyledString get brightCyan => style(Ansi.brightCyan);
  StyledString get brightWhite => style(Ansi.brightWhite);

  // ## 4. Background Colors
  StyledString get bgBlack => style(Ansi.bgBlack);
  StyledString get bgRed => style(Ansi.bgRed);
  StyledString get bgGreen => style(Ansi.bgGreen);
  StyledString get bgYellow => style(Ansi.bgYellow);
  StyledString get bgBlue => style(Ansi.bgBlue);
  StyledString get bgMagenta => style(Ansi.bgMagenta);
  StyledString get bgCyan => style(Ansi.bgCyan);
  StyledString get bgWhite => style(Ansi.bgWhite);
  StyledString get bgBrightBlack => style(Ansi.bgBrightBlack);
  StyledString get bgBrightRed => style(Ansi.bgBrightRed);
  StyledString get bgBrightGreen => style(Ansi.bgBrightGreen);
  StyledString get bgBrightYellow => style(Ansi.bgBrightYellow);
  StyledString get bgBrightBlue => style(Ansi.bgBrightBlue);
  StyledString get bgBrightMagenta => style(Ansi.bgBrightMagenta);
  StyledString get bgBrightCyan => style(Ansi.bgBrightCyan);
  StyledString get bgBrightWhite => style(Ansi.bgBrightWhite);

  // ## 5. 256-Color Support
  StyledString fg256(int colorIndex) => style(Ansi.fg256(colorIndex));
  StyledString bg256(int colorIndex) => style(Ansi.bg256(colorIndex));

  // ## 6. True Color (RGB) Support
  StyledString fgRgb(int r, int g, int b) => style(Ansi.fgRgb(r, g, b));
  StyledString bgRgb(int r, int g, int b) => style(Ansi.bgRgb(r, g, b));

  /// This function will paint the string with rainbow colors. If your string already have ansi code, it will be stripped first.
  StyledString rainbow([bool force = false]) {
    // check whether string is empty or isSupportAnsi
    if ((isEmpty || !isSupportAnsi) && !force) return _empty();

    final colors = [
      Ansi.red,
      Ansi.yellow,
      Ansi.green,
      Ansi.cyan,
      Ansi.blue,
      Ansi.magenta,
    ];
    // strip all ansi code before split prevent color mix
    final stripped = strip(this);
    final runes = stripped.runes.toList();
    final styledRunes = <int>[];

    for (var i = 0; i < runes.length; i++) {
      final color = colors[i % colors.length];
      styledRunes.addAll(color.paint(String.fromCharCode(runes[i])).runes);
    }
    return StyledString(String.fromCharCodes(styledRunes), []);
  }
}

// Helper class to accumulate and apply styles
class StyledString {
  final String _text;
  final List<Ansi> _styles;

  StyledString(this._text, this._styles);

  // Combine with another style
  StyledString _addStyle(Ansi ansi) => StyledString(_text, [..._styles, ansi]);

  /// Convert to string by combining all styles
  /// - [force] force apply ansi code even if not support ansi
  @override
  String toString([bool force = false]) {
    if ((_styles.isEmpty || !isSupportAnsi) && !force) return _text;
    final combined = _styles.reduce((a, b) => a.combine(b));
    return combined.paint(_text);
  }

  /// Convert to string by combining all styles
  /// - [force] force apply ansi code even if not support ansi
  String paint([bool force = true]) => toString(force);

  /// Convert to string by combining all styles
  /// - [force] force apply ansi code even if not support ansi
  String call([bool force = true]) => paint(force);

  // Text Formatting
  StyledString get bold => _addStyle(Ansi.bold);
  StyledString get faint => _addStyle(Ansi.faint);
  StyledString get italic => _addStyle(Ansi.italic);
  StyledString get underline => _addStyle(Ansi.underline);
  StyledString get slowBlink => _addStyle(Ansi.slowBlink);
  StyledString get fastBlink => _addStyle(Ansi.fastBlink);
  StyledString get inverse => _addStyle(Ansi.inverse);
  StyledString get conceal => _addStyle(Ansi.conceal);
  StyledString get strikethrough => _addStyle(Ansi.strikethrough);
  StyledString get defaultFont => _addStyle(Ansi.defaultFont);
  StyledString get doubleUnderline => _addStyle(Ansi.doubleUnderline);
  StyledString get superscript => _addStyle(Ansi.superscript);
  StyledString get subscript => _addStyle(Ansi.subscript);
  StyledString get overline => _addStyle(Ansi.overline);
  StyledString get framed => _addStyle(Ansi.framed);
  StyledString get encircled => _addStyle(Ansi.encircled);

  // Alternate Fonts
  StyledString font(int n) => _addStyle(Ansi.font(n));

  // Foreground Colors
  StyledString get black => _addStyle(Ansi.black);
  StyledString get red => _addStyle(Ansi.red);
  StyledString get green => _addStyle(Ansi.green);
  StyledString get yellow => _addStyle(Ansi.yellow);
  StyledString get blue => _addStyle(Ansi.blue);
  StyledString get magenta => _addStyle(Ansi.magenta);
  StyledString get cyan => _addStyle(Ansi.cyan);
  StyledString get white => _addStyle(Ansi.white);
  StyledString get brightBlack => _addStyle(Ansi.brightBlack);
  StyledString get brightRed => _addStyle(Ansi.brightRed);
  StyledString get brightGreen => _addStyle(Ansi.brightGreen);
  StyledString get brightYellow => _addStyle(Ansi.brightYellow);
  StyledString get brightBlue => _addStyle(Ansi.brightBlue);
  StyledString get brightMagenta => _addStyle(Ansi.brightMagenta);
  StyledString get brightCyan => _addStyle(Ansi.brightCyan);
  StyledString get brightWhite => _addStyle(Ansi.brightWhite);

  // Background Colors
  StyledString get bgBlack => _addStyle(Ansi.bgBlack);
  StyledString get bgRed => _addStyle(Ansi.bgRed);
  StyledString get bgGreen => _addStyle(Ansi.bgGreen);
  StyledString get bgYellow => _addStyle(Ansi.bgYellow);
  StyledString get bgBlue => _addStyle(Ansi.bgBlue);
  StyledString get bgMagenta => _addStyle(Ansi.bgMagenta);
  StyledString get bgCyan => _addStyle(Ansi.bgCyan);
  StyledString get bgWhite => _addStyle(Ansi.bgWhite);
  StyledString get bgBrightBlack => _addStyle(Ansi.bgBrightBlack);
  StyledString get bgBrightRed => _addStyle(Ansi.bgBrightRed);
  StyledString get bgBrightGreen => _addStyle(Ansi.bgBrightGreen);
  StyledString get bgBrightYellow => _addStyle(Ansi.bgBrightYellow);
  StyledString get bgBrightBlue => _addStyle(Ansi.bgBrightBlue);
  StyledString get bgBrightMagenta => _addStyle(Ansi.bgBrightMagenta);
  StyledString get bgBrightCyan => _addStyle(Ansi.bgBrightCyan);
  StyledString get bgBrightWhite => _addStyle(Ansi.bgBrightWhite);

  // 256-Color Support
  StyledString fg256(int colorIndex) => _addStyle(Ansi.fg256(colorIndex));
  StyledString bg256(int colorIndex) => _addStyle(Ansi.bg256(colorIndex));

  // True Color (RGB) Support
  StyledString fgRgb(int r, int g, int b) => _addStyle(Ansi.fgRgb(r, g, b));
  StyledString bgRgb(int r, int g, int b) => _addStyle(Ansi.bgRgb(r, g, b));
}
