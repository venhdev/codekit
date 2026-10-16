import 'package:drift/drift.dart';

import '../connection/connection.dart';

part 'diagnostic_database.g.dart';

class StoredRecordRows extends Table {
  IntColumn get order => integer().autoIncrement()();
  TextColumn get recordId => text().unique()();
  IntColumn get recordedAtMicros => integer()();
  TextColumn get recordJson => text()();
}

class StoredTraceSessionRows extends Table {
  IntColumn get order => integer().autoIncrement()();
  TextColumn get sessionId => text().unique()();
  TextColumn get name => text().nullable()();
  IntColumn get fromMicros => integer()();
  IntColumn get toMicros => integer()();
  TextColumn get recordIdsJson => text()();
}

@DriftDatabase(tables: [StoredRecordRows, StoredTraceSessionRows])
class DiagnosticDatabase extends _$DiagnosticDatabase {
  DiagnosticDatabase(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => migrator.createAll(),
    onUpgrade: (migrator, from, to) async {
      throw StateError(
        'No migration is defined from database schema $from to $to.',
      );
    },
  );
}

QueryExecutor openNativeDatabase(String databasePath) =>
    openConnection(databasePath);
