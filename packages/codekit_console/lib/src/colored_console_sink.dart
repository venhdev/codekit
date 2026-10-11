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

  @override
  void dispatch(DiagnosticRecord record) {
    final payload = record.payload;
    final String text;
    final Ansi color;
    if (payload is LogPayload) {
      text =
          '[${payload.level.name.toUpperCase()}] '
          '${payload.message}'
          '${record.source == null ? '' : ' (${record.source})'}'
          '${payload.stackTrace == null ? '' : '\n${payload.stackTrace}'}';
      color = switch (payload.level) {
        LogLevel.trace || LogLevel.debug => Ansi.brightBlack,
        LogLevel.info => Ansi.blue,
        LogLevel.warning => Ansi.yellow,
        LogLevel.error || LogLevel.fatal => Ansi.red,
      };
    } else if (payload is HttpPayload) {
      final status = payload.response?.statusCode;
      text =
          '[HTTP ${status ?? 'Unknown'}] '
          '${payload.method} ${payload.uri}'
          '${payload.duration == null ? '' : ' · ${payload.duration!.inMilliseconds} ms'}'
          '${payload.error == null ? '' : ' · ${payload.error!.message}'}';
      color = switch (HttpStatusGroup.fromCode(status)) {
        HttpStatusGroup.success => Ansi.green,
        HttpStatusGroup.redirection => Ansi.cyan,
        HttpStatusGroup.clientError => Ansi.yellow,
        HttpStatusGroup.serverError => Ansi.red,
        HttpStatusGroup.informational || HttpStatusGroup.unknown => Ansi.blue,
      };
    } else {
      return;
    }
    ColoredLogger.colorize(text, styles: [color], writer: writer);
  }

  @override
  void dispose() {}
}
