import 'dart:io';

/// Signature for custom bad certificate evaluation.
typedef DevProxyBadCertificateCallback = bool Function(
  X509Certificate cert,
  String host,
  int port,
);

/// Configuration options governing SSL certificate handling and transport creation for Dio.
class DevProxyDioOptions {
  static const bool _defaultIsDebug = !bool.fromEnvironment('dart.vm.product');

  /// Sensitive flag: Whether to automatically accept self-signed MITM proxy certificates
  /// (e.g. Proxyman, Charles) when dev proxy is active.
  ///
  /// Defaults to `false` for security safety.
  final bool allowBadCertificates;

  /// Environment gate guarding certificate bypass.
  /// Defaults to `!bool.fromEnvironment('dart.vm.product')` (true in debug/profile, false in product release).
  /// Callers can explicitly pass custom flags such as `kDebugMode` or `const bool.fromEnvironment('ENABLE_DEV_PROXY')`.
  final bool isDebug;

  /// Optional custom certificate validation hook.
  ///
  /// When provided, this callback takes precedence over the default fallback.
  /// Developers can inspect the certificate chain, check fingerprints, or whitelist issuers.
  final DevProxyBadCertificateCallback? badCertificateCallback;

  /// Optional factory allowing developers to customize [SecurityContext]
  /// or instantiate their own pre-configured [HttpClient].
  final HttpClient Function()? createHttpClient;

  const DevProxyDioOptions({
    this.allowBadCertificates = false,
    this.isDebug = _defaultIsDebug,
    this.badCertificateCallback,
    this.createHttpClient,
  });

  /// Permissive preset for local development with debugging proxies.
  const DevProxyDioOptions.permissiveDebug({
    bool isDebug = _defaultIsDebug,
    DevProxyBadCertificateCallback? badCertificateCallback,
    HttpClient Function()? createHttpClient,
  }) : this(
         allowBadCertificates: true,
         isDebug: isDebug,
         badCertificateCallback: badCertificateCallback,
         createHttpClient: createHttpClient,
       );
}
