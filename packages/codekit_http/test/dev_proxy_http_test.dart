import 'dart:io';
import 'dart:typed_data';

import 'package:codekit_core/codekit_core.dart';
import 'package:codekit_http/codekit_http.dart';
import 'package:http/io_client.dart';
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
  group('createDevProxyHttpClient', () {
    test('dynamically resolves PAC proxy directive per request', () {
      DevProxyConfig currentConfig = const DevProxyConfig(
        isEnabled: false,
        host: '10.0.0.1',
        port: 9090,
      );

      final fakeClient = _FakeHttpClient();
      final client = createDevProxyHttpClient(
        proxyProvider: () => currentConfig,
        options: DevProxyHttpOptions(createHttpClient: () => fakeClient),
      );

      expect(client, isA<IOClient>());
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
      client.close();
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
          final client = createDevProxyHttpClient(
            proxyProvider: () => currentConfig,
            options: DevProxyHttpOptions(
              allowBadCertificates: true,
              isDebug: true,
              createHttpClient: () => fakeClient,
              badCertificateCallback: (cert, host, port) {
                customCallbackCalled = true;
                return cert.issuer.contains('ProxymanCA');
              },
            ),
          );

          final accepted = fakeClient.badCertCallback!(
            fakeCert,
            'api.example.com',
            443,
          );
          expect(customCallbackCalled, isTrue);
          expect(accepted, isTrue);
          client.close();
        },
      );

      test('accepts bad cert when proxy is active, allowBadCertificates is true, and isDebug is true', () {
        DevProxyConfig currentConfig = const DevProxyConfig(
          isEnabled: true,
          host: '10.0.0.1',
          port: 9090,
        );

        final fakeClient = _FakeHttpClient();
        final client = createDevProxyHttpClient(
          proxyProvider: () => currentConfig,
          options: DevProxyHttpOptions.permissiveDebug(
            isDebug: true,
            createHttpClient: () => fakeClient,
          ),
        );

        expect(
          fakeClient.badCertCallback!(fakeCert, 'api.example.com', 443),
          isTrue,
        );

        currentConfig = currentConfig.copyWith(isEnabled: false);
        expect(
          fakeClient.badCertCallback!(fakeCert, 'api.example.com', 443),
          isFalse,
        );
        client.close();
      });

      test('rejects bad cert when allowBadCertificates is false even in debug mode', () {
        DevProxyConfig currentConfig = const DevProxyConfig(
          isEnabled: true,
          host: '10.0.0.1',
          port: 9090,
        );

        final fakeClient = _FakeHttpClient();
        final client = createDevProxyHttpClient(
          proxyProvider: () => currentConfig,
          options: DevProxyHttpOptions(
            allowBadCertificates: false,
            isDebug: true,
            createHttpClient: () => fakeClient,
          ),
        );

        expect(
          fakeClient.badCertCallback!(fakeCert, 'api.example.com', 443),
          isFalse,
        );
        client.close();
      });

      test('rejects bad cert when isDebug is false even if allowBadCertificates is true', () {
        DevProxyConfig currentConfig = const DevProxyConfig(
          isEnabled: true,
          host: '10.0.0.1',
          port: 9090,
        );

        final fakeClient = _FakeHttpClient();
        final client = createDevProxyHttpClient(
          proxyProvider: () => currentConfig,
          options: DevProxyHttpOptions(
            allowBadCertificates: true,
            isDebug: false,
            createHttpClient: () => fakeClient,
          ),
        );

        expect(
          fakeClient.badCertCallback!(fakeCert, 'api.example.com', 443),
          isFalse,
        );
        client.close();
      });
    });
  });

  group('createCodeKitHttpClient', () {
    test(
      'creates and wires http.Client with diagnostics and dev proxy',
      () async {
        final diagnostics = CodeKitDiagnostics();
        final fakeClient = _FakeHttpClient();
        DevProxyConfig proxyState = const DevProxyConfig(
          isEnabled: true,
          host: '127.0.0.1',
          port: 9090,
        );

        final client = createCodeKitHttpClient(
          diagnostics: diagnostics,
          proxyProvider: () => proxyState,
          devProxyOptions: DevProxyHttpOptions(
            createHttpClient: () => fakeClient,
          ),
        );

        expect(client, isA<CodeKitHttpClient>());
        client.close();
        await diagnostics.dispose();
      },
    );

    test('creates plain http.Client when proxyProvider is null', () async {
      final diagnostics = CodeKitDiagnostics();
      final client = createCodeKitHttpClient(diagnostics: diagnostics);

      expect(client, isA<CodeKitHttpClient>());
      client.close();
      await diagnostics.dispose();
    });
  });
}
