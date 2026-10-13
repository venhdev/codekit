import 'dart:io';
import 'dart:typed_data';

import 'package:codekit_core/codekit_core.dart';
import 'package:codekit_dio/codekit_dio.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:test/test.dart';

class _FakeX509Certificate implements X509Certificate {
  @override
  final String issuer;
  @override
  final String subject = 'CN=localhost';

  _FakeX509Certificate({this.issuer = 'CN=TestCA'});

  @override
  Uint8List get der => Uint8List(0);

  @override
  Uint8List get sha1 => Uint8List(0);

  @override
  String get pem => '';

  @override
  DateTime get startValidity => DateTime(2026, 1, 1);

  @override
  DateTime get endValidity => DateTime(2027, 1, 1);
}

class _FakeHttpClient implements HttpClient {
  String Function(Uri url)? findProxyCallback;
  bool Function(X509Certificate cert, String host, int port)? badCertCallback;

  @override
  set findProxy(String Function(Uri url)? f) => findProxyCallback = f;

  @override
  set badCertificateCallback(
    bool Function(X509Certificate cert, String host, int port)? callback,
  ) => badCertCallback = callback;

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('CodeKitDioDevProxyExtension & createDevProxyHttpClientAdapter', () {
    test(
      'attaches IOHttpClientAdapter to Dio and returns the same instance',
      () {
        final dio = Dio();
        DevProxyConfig currentConfig = const DevProxyConfig();

        final result = dio.attachDevProxy(proxyProvider: () => currentConfig);

        expect(identical(result, dio), isTrue);
        expect(dio.httpClientAdapter, isA<IOHttpClientAdapter>());
        dio.close(force: true);
      },
    );

    test('dynamically resolves PAC proxy directive per request without rebuilding adapter', () {
      DevProxyConfig currentConfig = const DevProxyConfig(
        isEnabled: false,
        host: '10.0.0.1',
        port: 9090,
      );

      final fakeClient = _FakeHttpClient();
      final adapter = createDevProxyHttpClientAdapter(
        proxyProvider: () => currentConfig,
        options: DevProxyDioOptions(createHttpClient: () => fakeClient),
      );

      adapter.createHttpClient!();
      final testUri = Uri.parse('https://example.com/test');

      // 1. Initial state: disabled -> DIRECT
      expect(fakeClient.findProxyCallback!(testUri), equals('DIRECT'));

      // 2. Toggle proxy on dynamically -> PROXY 10.0.0.1:9090
      currentConfig = currentConfig.copyWith(isEnabled: true);
      expect(
        fakeClient.findProxyCallback!(testUri),
        equals('PROXY 10.0.0.1:9090'),
      );

      // 3. Update host & port dynamically -> PROXY 192.168.1.50:8888
      currentConfig = const DevProxyConfig(
        isEnabled: true,
        host: 'http://192.168.1.50',
        port: 8888,
      );
      expect(
        fakeClient.findProxyCallback!(testUri),
        equals('PROXY 192.168.1.50:8888'),
      );
    });

    group('certificate validation priority chain', () {
      final fakeCert = _FakeX509Certificate(issuer: 'CN=ProxymanCA');

      test(
        'custom badCertificateCallback takes precedence over built-in fallback',
        () {
          DevProxyConfig currentConfig = const DevProxyConfig(
            isEnabled: true,
            host: '10.0.0.1',
            port: 9090,
          );

          bool customCallbackCalled = false;
          final fakeClient = _FakeHttpClient();
          final adapter = createDevProxyHttpClientAdapter(
            proxyProvider: () => currentConfig,
            options: DevProxyDioOptions(
              allowBadCertificates: true,
              isDebug: true,
              createHttpClient: () => fakeClient,
              badCertificateCallback: (cert, host, port) {
                customCallbackCalled = true;
                return cert.issuer.contains('ProxymanCA');
              },
            ),
          );

          adapter.createHttpClient!();
          final accepted = fakeClient.badCertCallback!(
            fakeCert,
            'api.example.com',
            443,
          );

          expect(customCallbackCalled, isTrue);
          expect(accepted, isTrue);
        },
      );

      test('accepts bad cert when proxy is active, allowBadCertificates is true, and isDebug is true', () {
        DevProxyConfig currentConfig = const DevProxyConfig(
          isEnabled: true,
          host: '10.0.0.1',
          port: 9090,
        );

        final fakeClient = _FakeHttpClient();
        final adapter = createDevProxyHttpClientAdapter(
          proxyProvider: () => currentConfig,
          options: DevProxyDioOptions.permissiveDebug(
            isDebug: true,
            createHttpClient: () => fakeClient,
          ),
        );

        adapter.createHttpClient!();
        expect(
          fakeClient.badCertCallback!(fakeCert, 'api.example.com', 443),
          isTrue,
        );

        // When proxy is toggled off, bad certificates are rejected
        currentConfig = currentConfig.copyWith(isEnabled: false);
        expect(
          fakeClient.badCertCallback!(fakeCert, 'api.example.com', 443),
          isFalse,
        );
      });

      test('rejects bad cert when allowBadCertificates is false even in debug mode', () {
        DevProxyConfig currentConfig = const DevProxyConfig(
          isEnabled: true,
          host: '10.0.0.1',
          port: 9090,
        );

        final fakeClient = _FakeHttpClient();
        final adapter = createDevProxyHttpClientAdapter(
          proxyProvider: () => currentConfig,
          options: DevProxyDioOptions(
            allowBadCertificates: false,
            isDebug: true,
            createHttpClient: () => fakeClient,
          ),
        );

        adapter.createHttpClient!();
        expect(
          fakeClient.badCertCallback!(fakeCert, 'api.example.com', 443),
          isFalse,
        );
      });

      test('rejects bad cert when isDebug is false even if allowBadCertificates is true', () {
        DevProxyConfig currentConfig = const DevProxyConfig(
          isEnabled: true,
          host: '10.0.0.1',
          port: 9090,
        );

        final fakeClient = _FakeHttpClient();
        final adapter = createDevProxyHttpClientAdapter(
          proxyProvider: () => currentConfig,
          options: DevProxyDioOptions(
            allowBadCertificates: true,
            isDebug: false,
            createHttpClient: () => fakeClient,
          ),
        );

        adapter.createHttpClient!();
        expect(
          fakeClient.badCertCallback!(fakeCert, 'api.example.com', 443),
          isFalse,
        );
      });

      test('uses custom createHttpClient factory if provided', () {
        bool customClientCreated = false;
        final fakeClient = _FakeHttpClient();
        final adapter = createDevProxyHttpClientAdapter(
          proxyProvider: () => const DevProxyConfig(),
          options: DevProxyDioOptions(
            createHttpClient: () {
              customClientCreated = true;
              return fakeClient;
            },
          ),
        );

        adapter.createHttpClient!();
        expect(customClientCreated, isTrue);
      });
    });
  });

  group('createCodeKitDio', () {
    test('creates and wires Dio with options, dev proxy, diagnostics, and interceptors', () async {
      final diagnostics = CodeKitDiagnostics();
      DevProxyConfig proxyState = const DevProxyConfig(
        isEnabled: true,
        host: '127.0.0.1',
        port: 9090,
      );
      bool configureHookCalled = false;

      final dio = createCodeKitDio(
        options: BaseOptions(baseUrl: 'https://api.test.com'),
        diagnostics: diagnostics,
        proxyProvider: () => proxyState,
        devProxyOptions: const DevProxyDioOptions.permissiveDebug(
          isDebug: true,
        ),
        interceptors: [LogInterceptor(request: false, responseBody: false)],
        configure: (instance) {
          configureHookCalled = true;
        },
      );

      expect(dio.options.baseUrl, equals('https://api.test.com'));
      expect(configureHookCalled, isTrue);
      expect(dio.httpClientAdapter, isA<IOHttpClientAdapter>());
      expect(dio.interceptors.whereType<CodeKitDioInterceptor>().length, 1);
      expect(dio.interceptors.whereType<LogInterceptor>().length, 1);

      await diagnostics.dispose();
      dio.close(force: true);
    });
  });
}
