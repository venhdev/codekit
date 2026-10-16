import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

/// Prepares the parent directory for a SQLite database file on native platforms.
Future<void> prepareDatabaseDirectory(String databasePath) async {
  final file = File(databasePath).absolute;
  await file.parent.create(recursive: true);
}

/// Opens a native SQLite [QueryExecutor] using background isolates.
QueryExecutor openConnection(String databasePath) =>
    NativeDatabase.createInBackground(File(databasePath));
