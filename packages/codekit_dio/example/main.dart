import 'package:codekit_core/codekit_core.dart';
import 'package:codekit_dio/codekit_dio.dart';
import 'package:dio/dio.dart';

Future<void> main() async {
  final diagnostics = CodeKitDiagnostics();
  final dio = Dio().withDiagnostics(diagnostics);

  try {
    await dio.get('https://example.com');
    final page = await diagnostics.query(RecordQuery());
    for (final record in page.records) {
      final request = record.payload as HttpPayload;
      print(
        '${request.method} ${request.uri} → ${request.response?.statusCode}',
      );
    }
  } finally {
    dio.close();
    await diagnostics.dispose();
  }
}
