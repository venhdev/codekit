import 'dart:io';

import 'package:codekit_core/codekit_core.dart';
import 'package:codekit_drift_diagnostic_store/codekit_drift_diagnostic_store.dart';

Future<void> main() async {
  final databasePath =
      '${Directory.systemTemp.path}${Platform.pathSeparator}codekit.sqlite';
  final diagnostics = await createDriftDiagnostics(
    databasePath: databasePath,
    retention: RetentionPolicy(maxRecords: 1000),
  );
  try {
    final receipt = diagnostics.log(
      const LogInput(message: 'Persistent diagnostics are ready'),
    );
    await receipt.persistedOrNull();
    final page = await diagnostics.query(RecordQuery());
    print('Stored ${page.records.length} record(s) at $databasePath');
  } finally {
    await diagnostics.dispose();
  }
}
