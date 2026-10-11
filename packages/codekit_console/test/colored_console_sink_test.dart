import 'package:codekit_console/codekit_console.dart';
import 'package:codekit_core/codekit_core.dart';
import 'package:test/test.dart';

void main() {
  test(
    'prints selected log and HTTP summaries through the injected writer',
    () async {
      final lines = <String>[];
      final diagnostics = CodeKitDiagnostics(
        sinks: [
          ColoredConsoleSink(
            writer: lines.add,
            logDispatchPolicy: LogDispatchPolicy(levels: {LogLevel.error}),
            httpDispatchPolicy: HttpDispatchPolicy(
              statusGroups: {HttpStatusGroup.serverError},
            ),
          ),
        ],
      );
      try {
        diagnostics.log(const LogInput(message: 'ignored info'));
        diagnostics.log(
          const LogInput(message: 'Failed to load', level: LogLevel.error),
        );
        diagnostics.log(
          HttpInput(
            recordId: diagnostics.createRecordId(),
            requestStartedAt: DateTime.utc(2026),
            method: 'GET',
            uri: Uri.parse('https://example.test/payments'),
            duration: const Duration(milliseconds: 42),
            response: const HttpResponseSnapshot(statusCode: 500),
          ),
        );
        await Future<void>.delayed(Duration.zero);
        expect(lines.length, 2);
        expect(lines[0], contains('[ERROR] Failed to load'));
        expect(lines[1], contains('GET https://example.test/payments'));
        expect(lines[1], contains('42 ms'));
      } finally {
        await diagnostics.dispose();
      }
    },
  );
}
