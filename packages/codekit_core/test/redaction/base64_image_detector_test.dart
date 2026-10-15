import 'dart:convert';

import 'package:codekit_core/src/redaction/base64_image_detector.dart';
import 'package:test/test.dart';

void main() {
  test('recognizes supported signatures and encoding variants', () {
    for (final bytes in [
      [137, 80, 78, 71, 13, 10, 26, 10],
      [255, 216, 255, 224],
      ascii.encode('GIF87a'),
      ascii.encode('GIF89a'),
      [...ascii.encode('RIFF'), 0, 0, 0, 0, ...ascii.encode('WEBP')],
    ]) {
      final encoded = base64Encode(bytes);
      for (final value in [
        encoded,
        encoded.replaceAll('=', ''),
        base64UrlEncode(bytes),
        'data:image/unknown;base64,$encoded',
      ]) {
        expect(isBase64Image(value), isTrue, reason: value);
      }
      expect(isBase64Image('$encoded!'), isFalse);
    }
  });
  test('rejects ordinary strings, invalid syntax and false MIME claims', () {
    for (final value in [
      '',
      'test',
      'deadbeef',
      'aaaaaaaa' * 128,
      'a===',
      'Zh==',
      'data:image/png;base64,aGVsbG8=',
      'iVBORw0KGgo=\n',
      'iVBORw0K Ggo=',
      'iVBORw0KGgo%3D',
      'prefix iVBORw0KGgo=',
      'iVBORw0KGgo===',
      'iVBORw0KGgo=!',
    ]) {
      expect(isBase64Image(value), isFalse, reason: value);
    }
  });
  test('header-only image matches; detector does not validate entire file', () {
    expect(isBase64Image('iVBORw0KGgo='), isTrue);
    expect(isBase64Image('iVBORw0KGgp='), isFalse);
    expect(isBase64Image('iVBORw0KGgo'), isTrue);
  });
}
