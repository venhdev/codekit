import 'package:codekit_core/codekit_core.dart';
import 'package:http/http.dart' as http;

import 'codekit_http_client.dart';
import 'dev_proxy_http_client.dart';
import 'dev_proxy_http_options.dart';

/// Turnkey factory to instantiate an [http.Client] configured with
/// CodeKit Diagnostics tracking and Dev Proxy routing.
http.Client createCodeKitHttpClient({
  CodeKitDiagnostics? diagnostics,
  DevProxyConfig Function()? proxyProvider,
  DevProxyHttpOptions devProxyOptions = const DevProxyHttpOptions(),
  int? maxBodyCaptureBytes,
}) {
  http.Client client = proxyProvider != null
      ? createDevProxyHttpClient(
          proxyProvider: proxyProvider,
          options: devProxyOptions,
        )
      : http.Client();

  if (diagnostics != null) {
    client = client.withDiagnostics(
      diagnostics,
      maxBodyCaptureBytes: maxBodyCaptureBytes,
    );
  }

  return client;
}
