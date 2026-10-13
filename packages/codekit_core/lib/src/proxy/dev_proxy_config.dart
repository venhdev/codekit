/// Configuration for runtime HTTP debugging proxy (e.g. Proxyman, Charles).
class DevProxyConfig {
  /// Default proxy port commonly used by Proxyman.
  static const int defaultPort = 9090;

  /// Whether proxy routing is actively requested.
  final bool isEnabled;

  /// Configured proxy host or IP address.
  final String host;

  /// Configured proxy port.
  final int port;

  const DevProxyConfig({
    this.isEnabled = false,
    this.host = '',
    this.port = defaultPort,
  });

  /// Sanitized host without leading/trailing whitespace, schemes (http/https),
  /// trailing paths, or extraneous port declarations.
  String get sanitizedHost {
    var raw = host.trim();
    final schemeMatch = RegExp(
      r'^https?://',
      caseSensitive: false,
    ).firstMatch(raw);
    if (schemeMatch != null) {
      raw = raw.substring(schemeMatch.end);
    }

    final slashIndex = raw.indexOf('/');
    if (slashIndex != -1) {
      raw = raw.substring(0, slashIndex);
    }
    final colonIndex = raw.indexOf(':');
    if (colonIndex != -1) {
      raw = raw.substring(0, colonIndex);
    }
    return raw;
  }

  /// Whether the configuration contains a non-empty host and valid port range (1–65535).
  bool get isValid => sanitizedHost.isNotEmpty && port > 0 && port <= 65535;

  /// Returns standard PAC / HttpClient directive:
  /// `PROXY <host>:<port>` when active and valid, otherwise `DIRECT`.
  String get proxyDirective {
    if (isEnabled && isValid) {
      return 'PROXY $sanitizedHost:$port';
    }
    return 'DIRECT';
  }

  /// Creates a copy with the given fields replaced by the new values.
  DevProxyConfig copyWith({bool? isEnabled, String? host, int? port}) {
    return DevProxyConfig(
      isEnabled: isEnabled ?? this.isEnabled,
      host: host ?? this.host,
      port: port ?? this.port,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DevProxyConfig &&
          runtimeType == other.runtimeType &&
          isEnabled == other.isEnabled &&
          host == other.host &&
          port == other.port;

  @override
  int get hashCode => Object.hash(isEnabled, host, port);

  @override
  String toString() =>
      'DevProxyConfig(isEnabled: $isEnabled, host: $host, port: $port, directive: $proxyDirective)';
}
