import 'package:codekit_core/codekit_core.dart';
import 'package:test/test.dart';

void main() {
  group('DevProxyConfig', () {
    test('defaults to disabled direct routing with default port 9090', () {
      const config = DevProxyConfig();

      expect(config.isEnabled, isFalse);
      expect(config.host, isEmpty);
      expect(config.port, equals(9090));
      expect(config.sanitizedHost, isEmpty);
      expect(config.isValid, isFalse);
      expect(config.proxyDirective, equals('DIRECT'));
    });

    group('sanitizedHost', () {
      test('trims leading and trailing whitespace', () {
        const config = DevProxyConfig(host: '  192.168.1.50  ');
        expect(config.sanitizedHost, equals('192.168.1.50'));
      });

      test('strips http:// scheme', () {
        const config = DevProxyConfig(host: 'http://192.168.1.50');
        expect(config.sanitizedHost, equals('192.168.1.50'));
      });

      test('strips https:// scheme', () {
        const config = DevProxyConfig(host: 'https://proxy.local');
        expect(config.sanitizedHost, equals('proxy.local'));
      });

      test('strips uppercase HTTP:// and HTTPS:// schemes', () {
        const config1 = DevProxyConfig(host: 'HTTP://192.168.1.50');
        const config2 = DevProxyConfig(host: 'HTTPS://PROXY.LOCAL');
        expect(config1.sanitizedHost, equals('192.168.1.50'));
        expect(config2.sanitizedHost, equals('PROXY.LOCAL'));
      });

      test('strips trailing path segments', () {
        const config = DevProxyConfig(host: '192.168.1.50/api/v1');
        expect(config.sanitizedHost, equals('192.168.1.50'));
      });

      test('strips trailing port specification from host string', () {
        const config = DevProxyConfig(host: '192.168.1.50:8888');
        expect(config.sanitizedHost, equals('192.168.1.50'));
      });

      test('sanitizes full URL into clean host', () {
        const config = DevProxyConfig(host: 'https://192.168.1.50:9090/test');
        expect(config.sanitizedHost, equals('192.168.1.50'));
      });
    });

    group('isValid', () {
      test('is false when host is empty', () {
        const config = DevProxyConfig(host: '', port: 9090);
        expect(config.isValid, isFalse);
      });

      test('is false when host contains only whitespace or scheme', () {
        const config = DevProxyConfig(host: 'http://', port: 9090);
        expect(config.isValid, isFalse);
      });

      test('is false when port is zero or negative', () {
        const zeroPort = DevProxyConfig(host: '127.0.0.1', port: 0);
        const negPort = DevProxyConfig(host: '127.0.0.1', port: -1);
        expect(zeroPort.isValid, isFalse);
        expect(negPort.isValid, isFalse);
      });

      test('is false when port exceeds 65535', () {
        const config = DevProxyConfig(host: '127.0.0.1', port: 65536);
        expect(config.isValid, isFalse);
      });

      test(
        'is true when sanitizedHost is non-empty and port is within 1-65535',
        () {
          const config1 = DevProxyConfig(host: '10.0.0.1', port: 1);
          const config2 = DevProxyConfig(host: 'proxy.internal', port: 65535);
          expect(config1.isValid, isTrue);
          expect(config2.isValid, isTrue);
        },
      );
    });

    group('proxyDirective', () {
      test('returns DIRECT when isEnabled is false even if valid', () {
        const config = DevProxyConfig(
          isEnabled: false,
          host: '192.168.1.50',
          port: 9090,
        );
        expect(config.proxyDirective, equals('DIRECT'));
      });

      test('returns DIRECT when isEnabled is true but host is invalid', () {
        const config = DevProxyConfig(isEnabled: true, host: '', port: 9090);
        expect(config.proxyDirective, equals('DIRECT'));
      });

      test('returns PROXY <host>:<port> when isEnabled is true and config is valid', () {
        const config = DevProxyConfig(
          isEnabled: true,
          host: 'http://192.168.1.50:9090/extra',
          port: 8888,
        );
        expect(config.proxyDirective, equals('PROXY 192.168.1.50:8888'));
      });
    });

    test('copyWith updates specified fields only', () {
      const original = DevProxyConfig(
        isEnabled: false,
        host: '10.0.0.1',
        port: 8080,
      );

      final updated = original.copyWith(isEnabled: true, port: 9090);
      expect(updated.isEnabled, isTrue);
      expect(updated.host, equals('10.0.0.1'));
      expect(updated.port, equals(9090));
    });

    test('supports value equality and hashCode', () {
      const config1 = DevProxyConfig(
        isEnabled: true,
        host: '10.0.0.1',
        port: 9090,
      );
      const config2 = DevProxyConfig(
        isEnabled: true,
        host: '10.0.0.1',
        port: 9090,
      );
      const config3 = DevProxyConfig(
        isEnabled: false,
        host: '10.0.0.1',
        port: 9090,
      );

      expect(config1, equals(config2));
      expect(config1.hashCode, equals(config2.hashCode));
      expect(config1, isNot(equals(config3)));
    });

    test('toString includes key details and directive', () {
      const config = DevProxyConfig(
        isEnabled: true,
        host: '10.0.0.1',
        port: 9090,
      );
      expect(config.toString(), contains('isEnabled: true'));
      expect(config.toString(), contains('PROXY 10.0.0.1:9090'));
    });
  });
}
