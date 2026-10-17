import 'package:codekit_core/codekit_core.dart';
import 'package:colored_logger/colored_logger.dart';

/// Prints concise, already-redacted records to the application's console.
final class ColoredConsoleSink implements DiagnosticSink {
  ColoredConsoleSink({
    HttpDispatchPolicy? httpDispatchPolicy,
    LogDispatchPolicy? logDispatchPolicy,
    this.writer,
  }) : httpDispatchPolicy = httpDispatchPolicy ?? HttpDispatchPolicy(),
       logDispatchPolicy = logDispatchPolicy ?? LogDispatchPolicy();

  @override
  final HttpDispatchPolicy httpDispatchPolicy;
  @override
  final LogDispatchPolicy logDispatchPolicy;
  final void Function(String)? writer;

  static List<Ansi> stylesForTone(DiagnosticTone tone) => switch (tone) {
    DiagnosticTone.neutral => const [Ansi.brightBlack],
    DiagnosticTone.info => const [Ansi.blue],
    DiagnosticTone.success => const [Ansi.green],
    DiagnosticTone.warning => const [Ansi.yellow],
    DiagnosticTone.danger => const [Ansi.red],
    DiagnosticTone.critical => const [Ansi.bold, Ansi.red],
  };

  @override
  void dispatch(DiagnosticRecord record) {
    final payload = record.payload;
    final String text;
    final List<Ansi> styles;
    if (payload is LogPayload) {
      text =
          '[${payload.level.name.toUpperCase()}] '
          '${payload.message}'
          '${record.source == null ? '' : ' (${record.source})'}'
          '${payload.stackTrace == null ? '' : '\n${payload.stackTrace}'}';
      styles = stylesForTone(payload.level.tone);
    } else if (payload is HttpPayload) {
      final status = payload.response?.statusCode;
      final group = HttpStatusGroup.fromCode(status);
      text =
          '[HTTP ${status ?? 'Unknown'}] '
          '${payload.method} ${payload.uri}'
          '${payload.duration == null ? '' : ' · ${payload.duration!.inMilliseconds} ms'}'
          '${payload.error == null ? '' : ' · ${payload.error!.message}'}';
      styles = group == HttpStatusGroup.redirection
          ? const [Ansi.cyan]
          : stylesForTone(group.tone);
    } else {
      return;
    }
    ColoredLogger.colorize(text, styles: styles, writer: writer);
  }

  @override
  void dispose() {}
}
