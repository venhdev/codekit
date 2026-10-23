import 'package:codekit_core/codekit_core.dart';
import 'package:codekit_dio/codekit_dio.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

void main() {
  group('DioDiagnosticsExtension', () {
    test('returns the same Dio and avoids duplicate attachment', () async {
      final dio = Dio();
      final diagnostics = CodeKitDiagnostics();
      final first = dio.withDiagnostics(diagnostics);
      final second = dio.withDiagnostics(diagnostics);

      expect(identical(first, dio), isTrue);
      expect(identical(second, dio), isTrue);
      expect(dio.interceptors.whereType<CodeKitDioInterceptor>().length, 1);
      await diagnostics.dispose();
      dio.close(force: true);
    });

    test('recognizes an interceptor installed manually', () async {
      final dio = Dio();
      final diagnostics = CodeKitDiagnostics();
      dio.interceptors.add(CodeKitDioInterceptor(diagnostics: diagnostics));

      dio.withDiagnostics(diagnostics);

      expect(dio.interceptors.whereType<CodeKitDioInterceptor>().length, 1);
      await diagnostics.dispose();
      dio.close(force: true);
    });

    test('passes maxBodyCaptureBytes to CodeKitDioInterceptor', () async {
      final dio = Dio();
      final diagnostics = CodeKitDiagnostics();
      dio.withDiagnostics(diagnostics, maxBodyCaptureBytes: 2048);

      final interceptor = dio.interceptors
          .whereType<CodeKitDioInterceptor>()
          .single;
      expect(interceptor.maxBodyCaptureBytes, 2048);
      await diagnostics.dispose();
      dio.close(force: true);
    });
  });
}
