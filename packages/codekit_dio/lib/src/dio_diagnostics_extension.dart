import 'package:codekit_core/codekit_core.dart';
import 'package:dio/dio.dart';

import 'codekit_dio_interceptor.dart';

extension DioDiagnosticsExtension on Dio {
  /// Adds [diagnostics] to this Dio instance once and returns this instance.
  Dio withDiagnostics(
    CodeKitDiagnostics diagnostics, {
    int? maxBodyCaptureBytes,
  }) {
    final alreadyAttached = interceptors.whereType<CodeKitDioInterceptor>().any(
      (interceptor) => identical(interceptor.diagnostics, diagnostics),
    );
    if (!alreadyAttached) {
      interceptors.add(
        CodeKitDioInterceptor(
          diagnostics: diagnostics,
          maxBodyCaptureBytes: maxBodyCaptureBytes,
        ),
      );
    }
    return this;
  }
}
