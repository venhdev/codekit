import 'dart:io';

import 'package:codekit_core/codekit_core.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';

import 'dev_proxy_dio_options.dart';

extension CodeKitDioDevProxyExtension on Dio {
  /// Attaches dynamic dev proxy routing to this Dio instance's [httpClientAdapter].
  ///
  /// [proxyProvider] is invoked synchronously per-request to read active proxy directives.
  /// [options] controls certificate validation and underlying HttpClient instantiation.
  Dio attachDevProxy({
    required DevProxyConfig Function() proxyProvider,
    DevProxyDioOptions options = const DevProxyDioOptions(),
  }) {
    httpClientAdapter = createDevProxyHttpClientAdapter(
      proxyProvider: proxyProvider,
      options: options,
    );
    return this;
  }
}

/// Standalone factory to create an [IOHttpClientAdapter] configured with dev proxy rules.
IOHttpClientAdapter createDevProxyHttpClientAdapter({
  required DevProxyConfig Function() proxyProvider,
  DevProxyDioOptions options = const DevProxyDioOptions(),
}) {
  return IOHttpClientAdapter(
    createHttpClient: () {
      final client = options.createHttpClient?.call() ?? HttpClient();

      // 1. Dynamic Per-request PAC proxy resolution
      client.findProxy = (Uri uri) {
        return proxyProvider().proxyDirective;
      };

      // 2. Certificate validation priority chain
      client.badCertificateCallback =
          (X509Certificate cert, String host, int port) {
            final currentConfig = proxyProvider();

            // Priority 1: Custom developer callback takes precedence
            if (options.badCertificateCallback != null) {
              return options.badCertificateCallback!(cert, host, port);
            }

            // Priority 2: Built-in MITM bypass (Active Proxy + Explicit Sensitive Flag + Debug Gate)
            if (options.isDebug && options.allowBadCertificates) {
              return currentConfig.isEnabled && currentConfig.isValid;
            }

            // Priority 3: Default secure reject
            return false;
          };

      return client;
    },
  );
}
