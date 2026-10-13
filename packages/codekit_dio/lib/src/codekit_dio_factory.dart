import 'package:codekit_core/codekit_core.dart';
import 'package:dio/dio.dart';

import 'dev_proxy_dio_extension.dart';
import 'dev_proxy_dio_options.dart';
import 'dio_diagnostics_extension.dart';

/// Turnkey factory to instantiate and fully configure a Dio client with
/// CodeKit Diagnostics tracking, Dev Proxy routing, and custom interceptors.
Dio createCodeKitDio({
  BaseOptions? options,
  CodeKitDiagnostics? diagnostics,
  DevProxyConfig Function()? proxyProvider,
  DevProxyDioOptions devProxyOptions = const DevProxyDioOptions(),
  List<Interceptor>? interceptors,
  void Function(Dio dio)? configure,
}) {
  final dio = Dio(options);

  if (proxyProvider != null) {
    dio.attachDevProxy(proxyProvider: proxyProvider, options: devProxyOptions);
  }

  if (diagnostics != null) {
    dio.withDiagnostics(diagnostics);
  }

  if (interceptors != null && interceptors.isNotEmpty) {
    dio.interceptors.addAll(interceptors);
  }

  configure?.call(dio);
  return dio;
}
