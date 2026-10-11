import 'package:codekit_core/codekit_core.dart';

Future<void> main() async {
  final diagnostics = CodeKitDiagnostics(
    retention: RetentionPolicy(maxRecords: 1000),
    redactionPolicy: RedactionPolicy(
      rules: [TextRedactionRule(RegExp(r'[\w.+-]+@[\w.-]+\.[A-Za-z]+'))],
    ),
  );
  try {
    diagnostics.startTrace();
    final receipt = diagnostics.log(
      const LogInput(
        message: 'Profile loaded for developer@example.com',
        tags: {'profileLoaded'},
        context: {'userId': '42'},
      ),
    );
    final session = await diagnostics.stopTrace(name: 'Profile inspection');
    final page = await diagnostics.query(RecordQuery(text: 'profile'));
    final export = await diagnostics.exportTraceSession(session!.id);
    print('Accepted: ${receipt.accepted}; matching: ${page.records.length}');
    print(export.text);
  } finally {
    await diagnostics.dispose();
  }
}
