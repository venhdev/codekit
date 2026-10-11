import 'dart:convert';

import 'package:codekit_core/codekit_core.dart';
import 'package:codekit_http/codekit_http.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

void main() {
  test('same diagnostics in the wrapper chain does not add a layer', () async {
    final diagnostics = CodeKitDiagnostics();
    final base = TrackingClient();
    final first = base.withDiagnostics(diagnostics);
    final second = first.withDiagnostics(diagnostics);
    final otherDiagnostics = CodeKitDiagnostics();
    final nested = first.withDiagnostics(otherDiagnostics);
    final nestedAgain = nested.withDiagnostics(diagnostics);

    expect(identical(first, second), isTrue);
    expect(identical(nested, nestedAgain), isTrue);
    expect(identical(nested, first), isFalse);

    nested.close();
    nested.close();
    expect(base.closeCount, 1);
    await diagnostics.dispose();
    await otherDiagnostics.dispose();
  });

  test('close forwards once and closed wrapper rejects later sends', () async {
    final diagnostics = CodeKitDiagnostics();
    final base = TrackingClient();
    final client = base.withDiagnostics(diagnostics);

    client.close();
    client.close();

    expect(base.closeCount, 1);
    await expectLater(
      client.get(Uri.parse('https://example.com')),
      throwsA(isA<StateError>()),
    );
    await diagnostics.dispose();
  });

  test('network errors are recorded and rethrown unchanged', () async {
    final diagnostics = CodeKitDiagnostics();
    final expected = http.ClientException(
      'network unavailable',
      Uri.parse('https://example.com/fail'),
    );
    final client = ThrowingClient(expected).withDiagnostics(diagnostics);

    await expectLater(
      client.get(Uri.parse('https://example.com/fail')),
      throwsA(same(expected)),
    );
    final records = (await diagnostics.query(RecordQuery())).records;
    expect(records, hasLength(1));
    final payload = records.single.payload as HttpPayload;
    expect(payload.error?.message, expected.toString());

    client.close();
    await diagnostics.dispose();
  });

  test(
    'recording failures do not change successful or failed requests',
    () async {
      final diagnostics = ThrowingDiagnostics();
      final base = TrackingClient();
      final client = base.withDiagnostics(diagnostics);

      final response = await client.get(Uri.parse('https://example.com'));

      expect(response.statusCode, 200);
      client.close();

      final originalError = http.ClientException(
        'original network failure',
        Uri.parse('https://example.com/fail'),
      );
      final failingClient = ThrowingClient(originalError)
          .withDiagnostics(diagnostics);
      await expectLater(
        failingClient.get(Uri.parse('https://example.com/fail')),
        throwsA(same(originalError)),
      );
      failingClient.close();
      await diagnostics.dispose();
    },
  );

  test('disposed diagnostics leaves injected client usable', () async {
    final diagnostics = CodeKitDiagnostics();
    final base = TrackingClient();
    final client = base.withDiagnostics(diagnostics);
    await diagnostics.dispose();

    final response = await client.get(Uri.parse('https://example.com'));

    expect(response.statusCode, 200);
    expect(base.closeCount, 0);
    client.close();
  });
}

class TrackingClient extends http.BaseClient {
  int closeCount = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      http.StreamedResponse(
        Stream<List<int>>.value(utf8.encode('ok')),
        200,
        request: request,
      );

  @override
  void close() => closeCount++;
}

class ThrowingClient extends http.BaseClient {
  final http.ClientException error;

  ThrowingClient(this.error);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      Future.error(error);
}

class ThrowingDiagnostics extends CodeKitDiagnostics {
  @override
  RecordReceipt log(DiagnosticInput input) =>
      throw StateError('simulated diagnostic failure');
}
