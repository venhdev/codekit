import 'package:codekit_core/codekit_core.dart';
import 'package:flutter/material.dart';

/// Resolved surface, text, border, and optional indicator dot colors for a tag.
@immutable
class CodeKitTagStyle {
  const CodeKitTagStyle({
    required this.background,
    required this.foreground,
    required this.border,
    this.dotColor,
  });

  final Color background;
  final Color foreground;
  final Color border;
  final Color? dotColor;

  CodeKitTagStyle copyWith({
    Color? background,
    Color? foreground,
    Color? border,
    Color? dotColor,
  }) => CodeKitTagStyle(
    background: background ?? this.background,
    foreground: foreground ?? this.foreground,
    border: border ?? this.border,
    dotColor: dotColor ?? this.dotColor,
  );

  static CodeKitTagStyle lerp(CodeKitTagStyle a, CodeKitTagStyle b, double t) =>
      CodeKitTagStyle(
        background: Color.lerp(a.background, b.background, t)!,
        foreground: Color.lerp(a.foreground, b.foreground, t)!,
        border: Color.lerp(a.border, b.border, t)!,
        dotColor: Color.lerp(a.dotColor, b.dotColor, t),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CodeKitTagStyle &&
          background == other.background &&
          foreground == other.foreground &&
          border == other.border &&
          dotColor == other.dotColor;

  @override
  int get hashCode => Object.hash(background, foreground, border, dotColor);
}

/// Adaptive Light/Dark semantic tag palette for the CodeKit UI ecosystem.
@immutable
class CodeKitTagTheme extends ThemeExtension<CodeKitTagTheme> {
  const CodeKitTagTheme({
    required this.neutral,
    required this.info,
    required this.success,
    required this.warning,
    required this.danger,
    required this.critical,
    required this.recordHttp,
    required this.recordLog,
  });

  const CodeKitTagTheme.light()
    : neutral = const CodeKitTagStyle(
        background: Color(0xFFF1F5F9),
        foreground: Color(0xFF475569),
        border: Color(0xFFCBD5E1),
      ),
      info = const CodeKitTagStyle(
        background: Color(0xFFEFF6FF),
        foreground: Color(0xFF1D4ED8),
        border: Color(0xFFBFDBFE),
      ),
      success = const CodeKitTagStyle(
        background: Color(0xFFECFDF5),
        foreground: Color(0xFF047857),
        border: Color(0xFFA7F3D0),
      ),
      warning = const CodeKitTagStyle(
        background: Color(0xFFFFFBEB),
        foreground: Color(0xFFB45309),
        border: Color(0xFFFDE68A),
      ),
      danger = const CodeKitTagStyle(
        background: Color(0xFFFEF2F2),
        foreground: Color(0xFFB91C1C),
        border: Color(0xFFFECACA),
      ),
      critical = const CodeKitTagStyle(
        background: Color(0xFFFAF5FF),
        foreground: Color(0xFF7E22CE),
        border: Color(0xFFE9D5FF),
      ),
      recordHttp = const CodeKitTagStyle(
        background: Color(0xFFEEF2FF),
        foreground: Color(0xFF4338CA),
        border: Color(0xFFC7D2FE),
      ),
      recordLog = const CodeKitTagStyle(
        background: Color(0xFFF8FAFC),
        foreground: Color(0xFF334155),
        border: Color(0xFFCBD5E1),
      );

  const CodeKitTagTheme.dark()
    : neutral = const CodeKitTagStyle(
        background: Color(0xFF1E293B),
        foreground: Color(0xFFCBD5E1),
        border: Color(0xFF334155),
      ),
      info = const CodeKitTagStyle(
        background: Color(0xFF172554),
        foreground: Color(0xFF93C5FD),
        border: Color(0xFF1E3A8A),
      ),
      success = const CodeKitTagStyle(
        background: Color(0xFF064E3B),
        foreground: Color(0xFF6EE7B7),
        border: Color(0xFF065F46),
      ),
      warning = const CodeKitTagStyle(
        background: Color(0xFF451A03),
        foreground: Color(0xFFFCD34D),
        border: Color(0xFF78350F),
      ),
      danger = const CodeKitTagStyle(
        background: Color(0xFF450A0A),
        foreground: Color(0xFFFCA5A5),
        border: Color(0xFF7F1D1D),
      ),
      critical = const CodeKitTagStyle(
        background: Color(0xFF3B0764),
        foreground: Color(0xFFD8B4FE),
        border: Color(0xFF581C87),
      ),
      recordHttp = const CodeKitTagStyle(
        background: Color(0xFF1E1B4B),
        foreground: Color(0xFFA5B4FC),
        border: Color(0xFF312E81),
      ),
      recordLog = const CodeKitTagStyle(
        background: Color(0xFF0F172A),
        foreground: Color(0xFF94A3B8),
        border: Color(0xFF334155),
      );

  final CodeKitTagStyle neutral;
  final CodeKitTagStyle info;
  final CodeKitTagStyle success;
  final CodeKitTagStyle warning;
  final CodeKitTagStyle danger;
  final CodeKitTagStyle critical;
  final CodeKitTagStyle recordHttp;
  final CodeKitTagStyle recordLog;

  static CodeKitTagTheme of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<CodeKitTagTheme>() ??
        (theme.brightness == Brightness.dark
            ? const CodeKitTagTheme.dark()
            : const CodeKitTagTheme.light());
  }

  /// Tier 1: Primary severity or HTTP status group style.
  CodeKitTagStyle styleForTone(DiagnosticTone tone) => switch (tone) {
    DiagnosticTone.neutral => neutral,
    DiagnosticTone.info => info,
    DiagnosticTone.success => success,
    DiagnosticTone.warning => warning,
    DiagnosticTone.danger => danger,
    DiagnosticTone.critical => critical,
  };

  /// Tier 2: Structural record kind style (`HTTP` vs `LOG`).
  CodeKitTagStyle styleForRecordKind(DiagnosticRecordType type) =>
      switch (type) {
        DiagnosticRecordType.http => recordHttp,
        DiagnosticRecordType.log => recordLog,
      };

  /// Tier 3: Duration metric style.
  ///
  /// Fast/Normal use a muted neutral surface with a semantic indicator dot and
  /// foreground so they do not visually collide with Tier 1 status pills.
  /// Warn/Slow promote to full tonal alert fills.
  CodeKitTagStyle styleForDuration(DurationLevel level) {
    final semantic = styleForTone(level.tone);
    if (level.isPromotedAlert) return semantic;
    return CodeKitTagStyle(
      background: neutral.background,
      foreground: semantic.foreground,
      border: neutral.border,
      dotColor: level == DurationLevel.unknown ? null : semantic.foreground,
    );
  }

  @override
  CodeKitTagTheme copyWith({
    CodeKitTagStyle? neutral,
    CodeKitTagStyle? info,
    CodeKitTagStyle? success,
    CodeKitTagStyle? warning,
    CodeKitTagStyle? danger,
    CodeKitTagStyle? critical,
    CodeKitTagStyle? recordHttp,
    CodeKitTagStyle? recordLog,
  }) => CodeKitTagTheme(
    neutral: neutral ?? this.neutral,
    info: info ?? this.info,
    success: success ?? this.success,
    warning: warning ?? this.warning,
    danger: danger ?? this.danger,
    critical: critical ?? this.critical,
    recordHttp: recordHttp ?? this.recordHttp,
    recordLog: recordLog ?? this.recordLog,
  );

  @override
  CodeKitTagTheme lerp(ThemeExtension<CodeKitTagTheme>? other, double t) {
    if (other is! CodeKitTagTheme) return this;
    return CodeKitTagTheme(
      neutral: CodeKitTagStyle.lerp(neutral, other.neutral, t),
      info: CodeKitTagStyle.lerp(info, other.info, t),
      success: CodeKitTagStyle.lerp(success, other.success, t),
      warning: CodeKitTagStyle.lerp(warning, other.warning, t),
      danger: CodeKitTagStyle.lerp(danger, other.danger, t),
      critical: CodeKitTagStyle.lerp(critical, other.critical, t),
      recordHttp: CodeKitTagStyle.lerp(recordHttp, other.recordHttp, t),
      recordLog: CodeKitTagStyle.lerp(recordLog, other.recordLog, t),
    );
  }
}

enum _TagVariant { tonal, recordKind, duration, custom }

/// Canonical semantic badge widget used across CodeKit UI surfaces.
class CodeKitTag extends StatelessWidget {
  const CodeKitTag.tonal({
    super.key,
    required this.label,
    required DiagnosticTone this.tone,
  }) : _variant = _TagVariant.tonal,
       recordType = null,
       durationLevel = null;

  const CodeKitTag.recordKind({
    super.key,
    required DiagnosticRecordType this.recordType,
  }) : _variant = _TagVariant.recordKind,
       label = recordType == DiagnosticRecordType.http ? 'HTTP' : 'LOG',
       tone = null,
       durationLevel = null;

  const CodeKitTag.duration({
    super.key,
    required this.label,
    required DurationLevel this.durationLevel,
  }) : _variant = _TagVariant.duration,
       tone = null,
       recordType = null;

  const CodeKitTag.customTag({super.key, required String tag})
    : _variant = _TagVariant.custom,
      label = '#$tag',
      tone = DiagnosticTone.neutral,
      recordType = null,
      durationLevel = null;

  final String label;
  final DiagnosticTone? tone;
  final DiagnosticRecordType? recordType;
  final DurationLevel? durationLevel;
  final _TagVariant _variant;

  @override
  Widget build(BuildContext context) {
    final tagTheme = CodeKitTagTheme.of(context);
    final style = switch (_variant) {
      _TagVariant.tonal || _TagVariant.custom => tagTheme.styleForTone(
        tone ?? DiagnosticTone.neutral,
      ),
      _TagVariant.recordKind => tagTheme.styleForRecordKind(recordType!),
      _TagVariant.duration => tagTheme.styleForDuration(durationLevel!),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: style.border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (style.dotColor != null) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: style.dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: style.foreground,
              fontWeight: FontWeight.w600,
              letterSpacing: _variant == _TagVariant.recordKind ? 0.3 : null,
            ),
          ),
        ],
      ),
    );
  }
}
