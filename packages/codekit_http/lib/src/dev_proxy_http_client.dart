import 'dart:io';

import 'package:codekit_core/codekit_core.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import 'dev_proxy_http_options.dart';

/// Factory to create an [http.Client] wired with dynamic dev proxy routing and custom SSL rules.
http.Client createDevProxyHttpClient({
  required DevProxyConfig Function() proxyProvider,
  DevProxyHttpOptions options = const DevProxyHttpOptions(),
}) {
  final innerHttpClient = options.createHttpClient?.call() ?? HttpClient();

  // 1. Dynamic Per-request PAC proxy resolution
  innerHttpClient.findProxy = (Uri uri) {
    return proxyProvider().proxyDirective;
  };

  // 2. Certificate validation priority chain
  innerHttpClient.badCertificateCallback =
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

  return IOClient(innerHttpClient);
}
