import 'dart:io';

import 'package:codekit_drift_diagnostic_store/src/connection/connection.dart';
import 'package:codekit_drift_diagnostic_store/src/connection/connection_stub.dart'
    as stub;
import 'package:test/test.dart';

void main() {
  group('Connection perimeter', () {
    test('native connection prepares directory and opens executor', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'codekit-connection-test-',
      );
      addTearDown(() => tempDir.delete(recursive: true));

      final dbPath = '${tempDir.path}/nested/db.sqlite';
      await prepareDatabaseDirectory(dbPath);
      expect(Directory('${tempDir.path}/nested').existsSync(), isTrue);

      final executor = openConnection(dbPath);
      expect(executor, isNotNull);
      await executor.close();
    });

    test('connection_stub throws UnsupportedError directing to MemoryDiagnosticStore', () async {
      expect(
        () => stub.prepareDatabaseDirectory('test.sqlite'),
        throwsA(
          isA<UnsupportedError>().having(
            (e) => e.message,
            'message',
            contains('MemoryDiagnosticStore'),
          ),
        ),
      );

      expect(
        () => stub.openConnection('test.sqlite'),
        throwsA(
          isA<UnsupportedError>().having(
            (e) => e.message,
            'message',
            contains('MemoryDiagnosticStore'),
          ),
        ),
      );
    });
  });
}
