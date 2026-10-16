import 'package:drift/drift.dart';

/// Prepares the database directory on platforms where local filesystem access
/// is supported.
Future<void> prepareDatabaseDirectory(String databasePath) async {
  throw UnsupportedError(
    'DriftDiagnosticStore is only supported on native platforms (Android, iOS, desktop). '
    'On Web, use MemoryDiagnosticStore from package:codekit_core.',
  );
}

/// Opens a [QueryExecutor] for the specified [databasePath].
QueryExecutor openConnection(String databasePath) {
  throw UnsupportedError(
    'DriftDiagnosticStore is only supported on native platforms (Android, iOS, desktop). '
    'On Web, use MemoryDiagnosticStore from package:codekit_core.',
  );
}
