// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'diagnostic_database.dart';

// ignore_for_file: type=lint
class $StoredRecordRowsTable extends StoredRecordRows
    with TableInfo<$StoredRecordRowsTable, StoredRecordRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StoredRecordRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _orderMeta = const VerificationMeta('order');
  @override
  late final GeneratedColumn<int> order = GeneratedColumn<int>(
    'order',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _recordIdMeta = const VerificationMeta(
    'recordId',
  );
  @override
  late final GeneratedColumn<String> recordId = GeneratedColumn<String>(
    'record_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _recordedAtMicrosMeta = const VerificationMeta(
    'recordedAtMicros',
  );
  @override
  late final GeneratedColumn<int> recordedAtMicros = GeneratedColumn<int>(
    'recorded_at_micros',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _recordJsonMeta = const VerificationMeta(
    'recordJson',
  );
  @override
  late final GeneratedColumn<String> recordJson = GeneratedColumn<String>(
    'record_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    order,
    recordId,
    recordedAtMicros,
    recordJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'stored_record_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<StoredRecordRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('order')) {
      context.handle(
        _orderMeta,
        order.isAcceptableOrUnknown(data['order']!, _orderMeta),
      );
    }
    if (data.containsKey('record_id')) {
      context.handle(
        _recordIdMeta,
        recordId.isAcceptableOrUnknown(data['record_id']!, _recordIdMeta),
      );
    } else if (isInserting) {
      context.missing(_recordIdMeta);
    }
    if (data.containsKey('recorded_at_micros')) {
      context.handle(
        _recordedAtMicrosMeta,
        recordedAtMicros.isAcceptableOrUnknown(
          data['recorded_at_micros']!,
          _recordedAtMicrosMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_recordedAtMicrosMeta);
    }
    if (data.containsKey('record_json')) {
      context.handle(
        _recordJsonMeta,
        recordJson.isAcceptableOrUnknown(data['record_json']!, _recordJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_recordJsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {order};
  @override
  StoredRecordRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StoredRecordRow(
      order: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}order'],
      )!,
      recordId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}record_id'],
      )!,
      recordedAtMicros: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}recorded_at_micros'],
      )!,
      recordJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}record_json'],
      )!,
    );
  }

  @override
  $StoredRecordRowsTable createAlias(String alias) {
    return $StoredRecordRowsTable(attachedDatabase, alias);
  }
}

class StoredRecordRow extends DataClass implements Insertable<StoredRecordRow> {
  final int order;
  final String recordId;
  final int recordedAtMicros;
  final String recordJson;
  const StoredRecordRow({
    required this.order,
    required this.recordId,
    required this.recordedAtMicros,
    required this.recordJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['order'] = Variable<int>(order);
    map['record_id'] = Variable<String>(recordId);
    map['recorded_at_micros'] = Variable<int>(recordedAtMicros);
    map['record_json'] = Variable<String>(recordJson);
    return map;
  }

  StoredRecordRowsCompanion toCompanion(bool nullToAbsent) {
    return StoredRecordRowsCompanion(
      order: Value(order),
      recordId: Value(recordId),
      recordedAtMicros: Value(recordedAtMicros),
      recordJson: Value(recordJson),
    );
  }

  factory StoredRecordRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StoredRecordRow(
      order: serializer.fromJson<int>(json['order']),
      recordId: serializer.fromJson<String>(json['recordId']),
      recordedAtMicros: serializer.fromJson<int>(json['recordedAtMicros']),
      recordJson: serializer.fromJson<String>(json['recordJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'order': serializer.toJson<int>(order),
      'recordId': serializer.toJson<String>(recordId),
      'recordedAtMicros': serializer.toJson<int>(recordedAtMicros),
      'recordJson': serializer.toJson<String>(recordJson),
    };
  }

  StoredRecordRow copyWith({
    int? order,
    String? recordId,
    int? recordedAtMicros,
    String? recordJson,
  }) => StoredRecordRow(
    order: order ?? this.order,
    recordId: recordId ?? this.recordId,
    recordedAtMicros: recordedAtMicros ?? this.recordedAtMicros,
    recordJson: recordJson ?? this.recordJson,
  );
  StoredRecordRow copyWithCompanion(StoredRecordRowsCompanion data) {
    return StoredRecordRow(
      order: data.order.present ? data.order.value : this.order,
      recordId: data.recordId.present ? data.recordId.value : this.recordId,
      recordedAtMicros: data.recordedAtMicros.present
          ? data.recordedAtMicros.value
          : this.recordedAtMicros,
      recordJson: data.recordJson.present
          ? data.recordJson.value
          : this.recordJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StoredRecordRow(')
          ..write('order: $order, ')
          ..write('recordId: $recordId, ')
          ..write('recordedAtMicros: $recordedAtMicros, ')
          ..write('recordJson: $recordJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(order, recordId, recordedAtMicros, recordJson);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StoredRecordRow &&
          other.order == this.order &&
          other.recordId == this.recordId &&
          other.recordedAtMicros == this.recordedAtMicros &&
          other.recordJson == this.recordJson);
}

class StoredRecordRowsCompanion extends UpdateCompanion<StoredRecordRow> {
  final Value<int> order;
  final Value<String> recordId;
  final Value<int> recordedAtMicros;
  final Value<String> recordJson;
  const StoredRecordRowsCompanion({
    this.order = const Value.absent(),
    this.recordId = const Value.absent(),
    this.recordedAtMicros = const Value.absent(),
    this.recordJson = const Value.absent(),
  });
  StoredRecordRowsCompanion.insert({
    this.order = const Value.absent(),
    required String recordId,
    required int recordedAtMicros,
    required String recordJson,
  }) : recordId = Value(recordId),
       recordedAtMicros = Value(recordedAtMicros),
       recordJson = Value(recordJson);
  static Insertable<StoredRecordRow> custom({
    Expression<int>? order,
    Expression<String>? recordId,
    Expression<int>? recordedAtMicros,
    Expression<String>? recordJson,
  }) {
    return RawValuesInsertable({
      if (order != null) 'order': order,
      if (recordId != null) 'record_id': recordId,
      if (recordedAtMicros != null) 'recorded_at_micros': recordedAtMicros,
      if (recordJson != null) 'record_json': recordJson,
    });
  }

  StoredRecordRowsCompanion copyWith({
    Value<int>? order,
    Value<String>? recordId,
    Value<int>? recordedAtMicros,
    Value<String>? recordJson,
  }) {
    return StoredRecordRowsCompanion(
      order: order ?? this.order,
      recordId: recordId ?? this.recordId,
      recordedAtMicros: recordedAtMicros ?? this.recordedAtMicros,
      recordJson: recordJson ?? this.recordJson,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (order.present) {
      map['order'] = Variable<int>(order.value);
    }
    if (recordId.present) {
      map['record_id'] = Variable<String>(recordId.value);
    }
    if (recordedAtMicros.present) {
      map['recorded_at_micros'] = Variable<int>(recordedAtMicros.value);
    }
    if (recordJson.present) {
      map['record_json'] = Variable<String>(recordJson.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StoredRecordRowsCompanion(')
          ..write('order: $order, ')
          ..write('recordId: $recordId, ')
          ..write('recordedAtMicros: $recordedAtMicros, ')
          ..write('recordJson: $recordJson')
          ..write(')'))
        .toString();
  }
}

class $StoredTraceSessionRowsTable extends StoredTraceSessionRows
    with TableInfo<$StoredTraceSessionRowsTable, StoredTraceSessionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StoredTraceSessionRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _orderMeta = const VerificationMeta('order');
  @override
  late final GeneratedColumn<int> order = GeneratedColumn<int>(
    'order',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fromMicrosMeta = const VerificationMeta(
    'fromMicros',
  );
  @override
  late final GeneratedColumn<int> fromMicros = GeneratedColumn<int>(
    'from_micros',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _toMicrosMeta = const VerificationMeta(
    'toMicros',
  );
  @override
  late final GeneratedColumn<int> toMicros = GeneratedColumn<int>(
    'to_micros',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _recordIdsJsonMeta = const VerificationMeta(
    'recordIdsJson',
  );
  @override
  late final GeneratedColumn<String> recordIdsJson = GeneratedColumn<String>(
    'record_ids_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    order,
    sessionId,
    name,
    fromMicros,
    toMicros,
    recordIdsJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'stored_trace_session_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<StoredTraceSessionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('order')) {
      context.handle(
        _orderMeta,
        order.isAcceptableOrUnknown(data['order']!, _orderMeta),
      );
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('from_micros')) {
      context.handle(
        _fromMicrosMeta,
        fromMicros.isAcceptableOrUnknown(data['from_micros']!, _fromMicrosMeta),
      );
    } else if (isInserting) {
      context.missing(_fromMicrosMeta);
    }
    if (data.containsKey('to_micros')) {
      context.handle(
        _toMicrosMeta,
        toMicros.isAcceptableOrUnknown(data['to_micros']!, _toMicrosMeta),
      );
    } else if (isInserting) {
      context.missing(_toMicrosMeta);
    }
    if (data.containsKey('record_ids_json')) {
      context.handle(
        _recordIdsJsonMeta,
        recordIdsJson.isAcceptableOrUnknown(
          data['record_ids_json']!,
          _recordIdsJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_recordIdsJsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {order};
  @override
  StoredTraceSessionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StoredTraceSessionRow(
      order: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}order'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      ),
      fromMicros: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}from_micros'],
      )!,
      toMicros: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}to_micros'],
      )!,
      recordIdsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}record_ids_json'],
      )!,
    );
  }

  @override
  $StoredTraceSessionRowsTable createAlias(String alias) {
    return $StoredTraceSessionRowsTable(attachedDatabase, alias);
  }
}

class StoredTraceSessionRow extends DataClass
    implements Insertable<StoredTraceSessionRow> {
  final int order;
  final String sessionId;
  final String? name;
  final int fromMicros;
  final int toMicros;
  final String recordIdsJson;
  const StoredTraceSessionRow({
    required this.order,
    required this.sessionId,
    this.name,
    required this.fromMicros,
    required this.toMicros,
    required this.recordIdsJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['order'] = Variable<int>(order);
    map['session_id'] = Variable<String>(sessionId);
    if (!nullToAbsent || name != null) {
      map['name'] = Variable<String>(name);
    }
    map['from_micros'] = Variable<int>(fromMicros);
    map['to_micros'] = Variable<int>(toMicros);
    map['record_ids_json'] = Variable<String>(recordIdsJson);
    return map;
  }

  StoredTraceSessionRowsCompanion toCompanion(bool nullToAbsent) {
    return StoredTraceSessionRowsCompanion(
      order: Value(order),
      sessionId: Value(sessionId),
      name: name == null && nullToAbsent ? const Value.absent() : Value(name),
      fromMicros: Value(fromMicros),
      toMicros: Value(toMicros),
      recordIdsJson: Value(recordIdsJson),
    );
  }

  factory StoredTraceSessionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StoredTraceSessionRow(
      order: serializer.fromJson<int>(json['order']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
      name: serializer.fromJson<String?>(json['name']),
      fromMicros: serializer.fromJson<int>(json['fromMicros']),
      toMicros: serializer.fromJson<int>(json['toMicros']),
      recordIdsJson: serializer.fromJson<String>(json['recordIdsJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'order': serializer.toJson<int>(order),
      'sessionId': serializer.toJson<String>(sessionId),
      'name': serializer.toJson<String?>(name),
      'fromMicros': serializer.toJson<int>(fromMicros),
      'toMicros': serializer.toJson<int>(toMicros),
      'recordIdsJson': serializer.toJson<String>(recordIdsJson),
    };
  }

  StoredTraceSessionRow copyWith({
    int? order,
    String? sessionId,
    Value<String?> name = const Value.absent(),
    int? fromMicros,
    int? toMicros,
    String? recordIdsJson,
  }) => StoredTraceSessionRow(
    order: order ?? this.order,
    sessionId: sessionId ?? this.sessionId,
    name: name.present ? name.value : this.name,
    fromMicros: fromMicros ?? this.fromMicros,
    toMicros: toMicros ?? this.toMicros,
    recordIdsJson: recordIdsJson ?? this.recordIdsJson,
  );
  StoredTraceSessionRow copyWithCompanion(
    StoredTraceSessionRowsCompanion data,
  ) {
    return StoredTraceSessionRow(
      order: data.order.present ? data.order.value : this.order,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      name: data.name.present ? data.name.value : this.name,
      fromMicros: data.fromMicros.present
          ? data.fromMicros.value
          : this.fromMicros,
      toMicros: data.toMicros.present ? data.toMicros.value : this.toMicros,
      recordIdsJson: data.recordIdsJson.present
          ? data.recordIdsJson.value
          : this.recordIdsJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StoredTraceSessionRow(')
          ..write('order: $order, ')
          ..write('sessionId: $sessionId, ')
          ..write('name: $name, ')
          ..write('fromMicros: $fromMicros, ')
          ..write('toMicros: $toMicros, ')
          ..write('recordIdsJson: $recordIdsJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(order, sessionId, name, fromMicros, toMicros, recordIdsJson);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StoredTraceSessionRow &&
          other.order == this.order &&
          other.sessionId == this.sessionId &&
          other.name == this.name &&
          other.fromMicros == this.fromMicros &&
          other.toMicros == this.toMicros &&
          other.recordIdsJson == this.recordIdsJson);
}

class StoredTraceSessionRowsCompanion
    extends UpdateCompanion<StoredTraceSessionRow> {
  final Value<int> order;
  final Value<String> sessionId;
  final Value<String?> name;
  final Value<int> fromMicros;
  final Value<int> toMicros;
  final Value<String> recordIdsJson;
  const StoredTraceSessionRowsCompanion({
    this.order = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.name = const Value.absent(),
    this.fromMicros = const Value.absent(),
    this.toMicros = const Value.absent(),
    this.recordIdsJson = const Value.absent(),
  });
  StoredTraceSessionRowsCompanion.insert({
    this.order = const Value.absent(),
    required String sessionId,
    this.name = const Value.absent(),
    required int fromMicros,
    required int toMicros,
    required String recordIdsJson,
  }) : sessionId = Value(sessionId),
       fromMicros = Value(fromMicros),
       toMicros = Value(toMicros),
       recordIdsJson = Value(recordIdsJson);
  static Insertable<StoredTraceSessionRow> custom({
    Expression<int>? order,
    Expression<String>? sessionId,
    Expression<String>? name,
    Expression<int>? fromMicros,
    Expression<int>? toMicros,
    Expression<String>? recordIdsJson,
  }) {
    return RawValuesInsertable({
      if (order != null) 'order': order,
      if (sessionId != null) 'session_id': sessionId,
      if (name != null) 'name': name,
      if (fromMicros != null) 'from_micros': fromMicros,
      if (toMicros != null) 'to_micros': toMicros,
      if (recordIdsJson != null) 'record_ids_json': recordIdsJson,
    });
  }

  StoredTraceSessionRowsCompanion copyWith({
    Value<int>? order,
    Value<String>? sessionId,
    Value<String?>? name,
    Value<int>? fromMicros,
    Value<int>? toMicros,
    Value<String>? recordIdsJson,
  }) {
    return StoredTraceSessionRowsCompanion(
      order: order ?? this.order,
      sessionId: sessionId ?? this.sessionId,
      name: name ?? this.name,
      fromMicros: fromMicros ?? this.fromMicros,
      toMicros: toMicros ?? this.toMicros,
      recordIdsJson: recordIdsJson ?? this.recordIdsJson,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (order.present) {
      map['order'] = Variable<int>(order.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (fromMicros.present) {
      map['from_micros'] = Variable<int>(fromMicros.value);
    }
    if (toMicros.present) {
      map['to_micros'] = Variable<int>(toMicros.value);
    }
    if (recordIdsJson.present) {
      map['record_ids_json'] = Variable<String>(recordIdsJson.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StoredTraceSessionRowsCompanion(')
          ..write('order: $order, ')
          ..write('sessionId: $sessionId, ')
          ..write('name: $name, ')
          ..write('fromMicros: $fromMicros, ')
          ..write('toMicros: $toMicros, ')
          ..write('recordIdsJson: $recordIdsJson')
          ..write(')'))
        .toString();
  }
}

abstract class _$DiagnosticDatabase extends GeneratedDatabase {
  _$DiagnosticDatabase(QueryExecutor e) : super(e);
  $DiagnosticDatabaseManager get managers => $DiagnosticDatabaseManager(this);
  late final $StoredRecordRowsTable storedRecordRows = $StoredRecordRowsTable(
    this,
  );
  late final $StoredTraceSessionRowsTable storedTraceSessionRows =
      $StoredTraceSessionRowsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    storedRecordRows,
    storedTraceSessionRows,
  ];
}

typedef $$StoredRecordRowsTableCreateCompanionBuilder =
    StoredRecordRowsCompanion Function({
      Value<int> order,
      required String recordId,
      required int recordedAtMicros,
      required String recordJson,
    });
typedef $$StoredRecordRowsTableUpdateCompanionBuilder =
    StoredRecordRowsCompanion Function({
      Value<int> order,
      Value<String> recordId,
      Value<int> recordedAtMicros,
      Value<String> recordJson,
    });

class $$StoredRecordRowsTableFilterComposer
    extends Composer<_$DiagnosticDatabase, $StoredRecordRowsTable> {
  $$StoredRecordRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get order => $composableBuilder(
    column: $table.order,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recordId => $composableBuilder(
    column: $table.recordId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get recordedAtMicros => $composableBuilder(
    column: $table.recordedAtMicros,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recordJson => $composableBuilder(
    column: $table.recordJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $$StoredRecordRowsTableOrderingComposer
    extends Composer<_$DiagnosticDatabase, $StoredRecordRowsTable> {
  $$StoredRecordRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get order => $composableBuilder(
    column: $table.order,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recordId => $composableBuilder(
    column: $table.recordId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get recordedAtMicros => $composableBuilder(
    column: $table.recordedAtMicros,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recordJson => $composableBuilder(
    column: $table.recordJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$StoredRecordRowsTableAnnotationComposer
    extends Composer<_$DiagnosticDatabase, $StoredRecordRowsTable> {
  $$StoredRecordRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get order =>
      $composableBuilder(column: $table.order, builder: (column) => column);

  GeneratedColumn<String> get recordId =>
      $composableBuilder(column: $table.recordId, builder: (column) => column);

  GeneratedColumn<int> get recordedAtMicros => $composableBuilder(
    column: $table.recordedAtMicros,
    builder: (column) => column,
  );

  GeneratedColumn<String> get recordJson => $composableBuilder(
    column: $table.recordJson,
    builder: (column) => column,
  );
}

class $$StoredRecordRowsTableTableManager
    extends
        RootTableManager<
          _$DiagnosticDatabase,
          $StoredRecordRowsTable,
          StoredRecordRow,
          $$StoredRecordRowsTableFilterComposer,
          $$StoredRecordRowsTableOrderingComposer,
          $$StoredRecordRowsTableAnnotationComposer,
          $$StoredRecordRowsTableCreateCompanionBuilder,
          $$StoredRecordRowsTableUpdateCompanionBuilder,
          (
            StoredRecordRow,
            BaseReferences<
              _$DiagnosticDatabase,
              $StoredRecordRowsTable,
              StoredRecordRow
            >,
          ),
          StoredRecordRow,
          PrefetchHooks Function()
        > {
  $$StoredRecordRowsTableTableManager(
    _$DiagnosticDatabase db,
    $StoredRecordRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StoredRecordRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StoredRecordRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StoredRecordRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> order = const Value.absent(),
                Value<String> recordId = const Value.absent(),
                Value<int> recordedAtMicros = const Value.absent(),
                Value<String> recordJson = const Value.absent(),
              }) => StoredRecordRowsCompanion(
                order: order,
                recordId: recordId,
                recordedAtMicros: recordedAtMicros,
                recordJson: recordJson,
              ),
          createCompanionCallback:
              ({
                Value<int> order = const Value.absent(),
                required String recordId,
                required int recordedAtMicros,
                required String recordJson,
              }) => StoredRecordRowsCompanion.insert(
                order: order,
                recordId: recordId,
                recordedAtMicros: recordedAtMicros,
                recordJson: recordJson,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$StoredRecordRowsTable, StoredRecordRow>(table),
                  BaseReferences<
                    _$DiagnosticDatabase,
                    $StoredRecordRowsTable,
                    StoredRecordRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$StoredRecordRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$DiagnosticDatabase,
      $StoredRecordRowsTable,
      StoredRecordRow,
      $$StoredRecordRowsTableFilterComposer,
      $$StoredRecordRowsTableOrderingComposer,
      $$StoredRecordRowsTableAnnotationComposer,
      $$StoredRecordRowsTableCreateCompanionBuilder,
      $$StoredRecordRowsTableUpdateCompanionBuilder,
      (
        StoredRecordRow,
        BaseReferences<
          _$DiagnosticDatabase,
          $StoredRecordRowsTable,
          StoredRecordRow
        >,
      ),
      StoredRecordRow,
      PrefetchHooks Function()
    >;
typedef $$StoredTraceSessionRowsTableCreateCompanionBuilder =
    StoredTraceSessionRowsCompanion Function({
      Value<int> order,
      required String sessionId,
      Value<String?> name,
      required int fromMicros,
      required int toMicros,
      required String recordIdsJson,
    });
typedef $$StoredTraceSessionRowsTableUpdateCompanionBuilder =
    StoredTraceSessionRowsCompanion Function({
      Value<int> order,
      Value<String> sessionId,
      Value<String?> name,
      Value<int> fromMicros,
      Value<int> toMicros,
      Value<String> recordIdsJson,
    });

class $$StoredTraceSessionRowsTableFilterComposer
    extends Composer<_$DiagnosticDatabase, $StoredTraceSessionRowsTable> {
  $$StoredTraceSessionRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get order => $composableBuilder(
    column: $table.order,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fromMicros => $composableBuilder(
    column: $table.fromMicros,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get toMicros => $composableBuilder(
    column: $table.toMicros,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recordIdsJson => $composableBuilder(
    column: $table.recordIdsJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $$StoredTraceSessionRowsTableOrderingComposer
    extends Composer<_$DiagnosticDatabase, $StoredTraceSessionRowsTable> {
  $$StoredTraceSessionRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get order => $composableBuilder(
    column: $table.order,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fromMicros => $composableBuilder(
    column: $table.fromMicros,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get toMicros => $composableBuilder(
    column: $table.toMicros,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recordIdsJson => $composableBuilder(
    column: $table.recordIdsJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$StoredTraceSessionRowsTableAnnotationComposer
    extends Composer<_$DiagnosticDatabase, $StoredTraceSessionRowsTable> {
  $$StoredTraceSessionRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get order =>
      $composableBuilder(column: $table.order, builder: (column) => column);

  GeneratedColumn<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get fromMicros => $composableBuilder(
    column: $table.fromMicros,
    builder: (column) => column,
  );

  GeneratedColumn<int> get toMicros =>
      $composableBuilder(column: $table.toMicros, builder: (column) => column);

  GeneratedColumn<String> get recordIdsJson => $composableBuilder(
    column: $table.recordIdsJson,
    builder: (column) => column,
  );
}

class $$StoredTraceSessionRowsTableTableManager
    extends
        RootTableManager<
          _$DiagnosticDatabase,
          $StoredTraceSessionRowsTable,
          StoredTraceSessionRow,
          $$StoredTraceSessionRowsTableFilterComposer,
          $$StoredTraceSessionRowsTableOrderingComposer,
          $$StoredTraceSessionRowsTableAnnotationComposer,
          $$StoredTraceSessionRowsTableCreateCompanionBuilder,
          $$StoredTraceSessionRowsTableUpdateCompanionBuilder,
          (
            StoredTraceSessionRow,
            BaseReferences<
              _$DiagnosticDatabase,
              $StoredTraceSessionRowsTable,
              StoredTraceSessionRow
            >,
          ),
          StoredTraceSessionRow,
          PrefetchHooks Function()
        > {
  $$StoredTraceSessionRowsTableTableManager(
    _$DiagnosticDatabase db,
    $StoredTraceSessionRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StoredTraceSessionRowsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$StoredTraceSessionRowsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$StoredTraceSessionRowsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> order = const Value.absent(),
                Value<String> sessionId = const Value.absent(),
                Value<String?> name = const Value.absent(),
                Value<int> fromMicros = const Value.absent(),
                Value<int> toMicros = const Value.absent(),
                Value<String> recordIdsJson = const Value.absent(),
              }) => StoredTraceSessionRowsCompanion(
                order: order,
                sessionId: sessionId,
                name: name,
                fromMicros: fromMicros,
                toMicros: toMicros,
                recordIdsJson: recordIdsJson,
              ),
          createCompanionCallback:
              ({
                Value<int> order = const Value.absent(),
                required String sessionId,
                Value<String?> name = const Value.absent(),
                required int fromMicros,
                required int toMicros,
                required String recordIdsJson,
              }) => StoredTraceSessionRowsCompanion.insert(
                order: order,
                sessionId: sessionId,
                name: name,
                fromMicros: fromMicros,
                toMicros: toMicros,
                recordIdsJson: recordIdsJson,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $StoredTraceSessionRowsTable,
                    StoredTraceSessionRow
                  >(table),
                  BaseReferences<
                    _$DiagnosticDatabase,
                    $StoredTraceSessionRowsTable,
                    StoredTraceSessionRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$StoredTraceSessionRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$DiagnosticDatabase,
      $StoredTraceSessionRowsTable,
      StoredTraceSessionRow,
      $$StoredTraceSessionRowsTableFilterComposer,
      $$StoredTraceSessionRowsTableOrderingComposer,
      $$StoredTraceSessionRowsTableAnnotationComposer,
      $$StoredTraceSessionRowsTableCreateCompanionBuilder,
      $$StoredTraceSessionRowsTableUpdateCompanionBuilder,
      (
        StoredTraceSessionRow,
        BaseReferences<
          _$DiagnosticDatabase,
          $StoredTraceSessionRowsTable,
          StoredTraceSessionRow
        >,
      ),
      StoredTraceSessionRow,
      PrefetchHooks Function()
    >;

class $DiagnosticDatabaseManager {
  final _$DiagnosticDatabase _db;
  $DiagnosticDatabaseManager(this._db);
  $$StoredRecordRowsTableTableManager get storedRecordRows =>
      $$StoredRecordRowsTableTableManager(_db, _db.storedRecordRows);
  $$StoredTraceSessionRowsTableTableManager get storedTraceSessionRows =>
      $$StoredTraceSessionRowsTableTableManager(
        _db,
        _db.storedTraceSessionRows,
      );
}
