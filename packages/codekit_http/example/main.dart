import 'package:codekit_core/codekit_core.dart';
import 'package:codekit_http/codekit_http.dart';
import 'package:http/http.dart' as http;

Future<void> main() async {
  final diagnostics = CodeKitDiagnostics();
  final appClient = http.Client();
  final client = appClient.withDiagnostics(diagnostics);

  try {
    await client.get(Uri.parse('https://example.com'));
    final page = await diagnostics.query(RecordQuery());
    for (final record in page.records) {
      final request = record.payload as HttpPayload;
      print(
        '${request.method} ${request.uri} → ${request.response?.statusCode}',
      );
    }
  } finally {
    client.close();
    await diagnostics.dispose();
  }
}
