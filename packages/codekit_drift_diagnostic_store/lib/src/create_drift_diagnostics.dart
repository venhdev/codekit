import 'package:codekit_core/codekit_core.dart';

import 'drift_diagnostic_store.dart';

/// Opens a native Drift store and creates a diagnostics instance that owns it.
Future<CodeKitDiagnostics> createDriftDiagnostics({
  required String databasePath,
  RetentionPolicy? retention,
  RedactionPolicy? redactionPolicy,
  RecordMode? recordMode,
  List<DiagnosticSink>? sinks,
  List<RegExp>? captureExcludeUriPatterns,
  int? pendingRecordLimit,
  DateTime Function()? clock,
  void Function(DiagnosticWarning)? onWarning,
  DriftStoreWarningCallback? onStoreWarning,
}) async {
  final store = await DriftDiagnosticStore.open(
    databasePath: databasePath,
    onWarning: onStoreWarning,
  );
  try {
    return CodeKitDiagnostics(
      store: store,
      retention: retention,
      redactionPolicy: redactionPolicy,
      recordMode: recordMode,
      sinks: sinks,
      captureExcludeUriPatterns: captureExcludeUriPatterns,
      pendingRecordLimit: pendingRecordLimit,
      clock: clock,
      onWarning: onWarning,
    );
  } catch (_) {
    await store.close();
    rethrow;
  }
}
