import 'dart:collection';

const int diagnosticRecordSchemaVersion = 1;

enum DiagnosticTone { neutral, info, success, warning, danger, critical }

enum LogLevel {
  trace,
  debug,
  info,
  warning,
  error,
  fatal;

  DiagnosticTone get tone => switch (this) {
    trace || debug => DiagnosticTone.neutral,
    info => DiagnosticTone.info,
    warning => DiagnosticTone.warning,
    error => DiagnosticTone.danger,
    fatal => DiagnosticTone.critical,
  };
}

enum RecordMode { redactBeforeRecording, storeRaw }

enum BodyCaptureState { absent, captured, disabled, unsupported, overflow }

enum BodyRepresentation { text, json, media }

enum HttpStatusGroup {
  informational,
  success,
  redirection,
  clientError,
  serverError,
  unknown;

  DiagnosticTone get tone => switch (this) {
    informational || unknown => DiagnosticTone.neutral,
    success => DiagnosticTone.success,
    redirection => DiagnosticTone.info,
    clientError => DiagnosticTone.warning,
    serverError => DiagnosticTone.danger,
  };

  String get label => switch (this) {
    informational => '1xx',
    success => '2xx',
    redirection => '3xx',
    clientError => '4xx',
    serverError => '5xx',
    unknown => 'Unknown',
  };

  static HttpStatusGroup fromCode(int? code) {
    if (code == null) return unknown;
    return switch (code) {
      >= 100 && < 200 => informational,
      >= 200 && < 300 => success,
      >= 300 && < 400 => redirection,
      >= 400 && < 500 => clientError,
      >= 500 && < 600 => serverError,
      _ => unknown,
    };
  }
}

/// Detaches JSON-compatible data without coercing arbitrary objects.
Object? freezeJson(Object? value, [Set<Object>? ancestors]) {
  if (value == null || value is String || value is bool) return value;
  if (value is num && value.isFinite) return value;
  final seen = ancestors ?? HashSet<Object>.identity();
  if (value is! List && value is! Map) {
    throw ArgumentError('Expected finite JSON-compatible data');
  }
  if (!seen.add(value)) throw ArgumentError('Cyclic diagnostic data');
  try {
    if (value is List) {
      return List<Object?>.unmodifiable(value.map((e) => freezeJson(e, seen)));
    }
    final map = value as Map;
    final out = <String, Object?>{};
    for (final entry in map.entries) {
      if (entry.key is! String) throw ArgumentError('Non-string JSON key');
      out[entry.key as String] = freezeJson(entry.value, seen);
    }
    return Map<String, Object?>.unmodifiable(out);
  } finally {
    seen.remove(value);
  }
}

Map<String, Object?>? freezeContext(Map<String, Object?>? context) =>
    context == null ? null : freezeJson(context) as Map<String, Object?>;
Map<String, List<String>>? freezeHeaders(Map<String, List<String>>? headers) =>
    headers == null
    ? null
    : Map.unmodifiable(
        headers.map(
          (key, value) => MapEntry(key, List<String>.unmodifiable(value)),
        ),
      );

final class DiagnosticError {
  final String type;
  final String message;
  final String? stackTrace;
  const DiagnosticError({
    required this.type,
    required this.message,
    this.stackTrace,
  });
  Map<String, Object?> toJson() => {
    'type': type,
    'message': message,
    if (stackTrace != null) 'stackTrace': stackTrace,
  };
  factory DiagnosticError.fromJson(Map<String, Object?> m) => DiagnosticError(
    type: m['type'] as String,
    message: m['message'] as String,
    stackTrace: m['stackTrace'] as String?,
  );
}

/// File metadata only. Adapters must not read file bytes to populate it.
final class MediaFileMetadata {
  final String? fileName;
  final String? contentType;
  final int? sizeBytes;
  final String? path;
  const MediaFileMetadata({
    this.fileName,
    this.contentType,
    this.sizeBytes,
    this.path,
  });
  Map<String, Object?> toJson() {
    if (sizeBytes != null && sizeBytes! < 0) {
      throw ArgumentError('Negative file size');
    }
    return {
      if (fileName != null) 'fileName': fileName,
      if (contentType != null) 'contentType': contentType,
      if (sizeBytes != null) 'sizeBytes': sizeBytes,
      if (path != null) 'path': path,
    };
  }

  factory MediaFileMetadata.fromJson(Map<String, Object?> m) =>
      MediaFileMetadata(
        fileName: m['fileName'] as String?,
        contentType: m['contentType'] as String?,
        sizeBytes: m['sizeBytes'] as int?,
        path: m['path'] as String?,
      );
}

/// Input body is normalized and detached when diagnostics accepts the input.
final class BodySnapshot {
  final BodyCaptureState state;
  final BodyRepresentation? representation;
  final Object? data;
  const BodySnapshot._({required this.state, this.data})
    : representation = null;

  const BodySnapshot.absent()
    : state = BodyCaptureState.absent,
      representation = null,
      data = null;
  const BodySnapshot.disabled()
    : state = BodyCaptureState.disabled,
      representation = null,
      data = null;
  const BodySnapshot.unsupported()
    : state = BodyCaptureState.unsupported,
      representation = null,
      data = null;
  factory BodySnapshot.overflow({int? sizeBytes, String? contentType}) {
    return BodySnapshot._(
      state: BodyCaptureState.overflow,
      data: sizeBytes == null
          ? null
          : (contentType == null
                ? {'sizeBytes': sizeBytes}
                : {'sizeBytes': sizeBytes, 'contentType': contentType}),
    );
  }
  factory BodySnapshot.oversized(int sizeBytes, [String? contentType]) {
    return BodySnapshot.overflow(
      sizeBytes: sizeBytes,
      contentType: contentType,
    );
  }
  const BodySnapshot.text(String value)
    : state = BodyCaptureState.captured,
      representation = BodyRepresentation.text,
      data = value;
  const BodySnapshot.json(Object? value)
    : state = BodyCaptureState.captured,
      representation = BodyRepresentation.json,
      data = value;
  BodySnapshot.media(List<MediaFileMetadata> files)
    : state = BodyCaptureState.captured,
      representation = BodyRepresentation.media,
      data = List<Object?>.unmodifiable(
        files.map((f) => Map<String, Object?>.unmodifiable(f.toJson())),
      );
  static BodySnapshot _media(Object? value) => BodySnapshot.media(
    (value as List).map((e) => MediaFileMetadata.fromJson(jsonMap(e))).toList(),
  );
  BodySnapshot detached() => switch (representation) {
    BodyRepresentation.text => BodySnapshot.text(data as String),
    BodyRepresentation.json => BodySnapshot.json(freezeJson(data)),
    BodyRepresentation.media => _media(data),
    null => switch (state) {
      BodyCaptureState.absent => const BodySnapshot.absent(),
      BodyCaptureState.disabled => const BodySnapshot.disabled(),
      BodyCaptureState.unsupported => const BodySnapshot.unsupported(),
      BodyCaptureState.overflow => BodySnapshot.overflow(
        sizeBytes: (data as Map?)?['sizeBytes'] as int?,
        contentType: (data as Map?)?['contentType'] as String?,
      ),
      BodyCaptureState.captured => throw ArgumentError(
        'Missing body representation',
      ),
    },
  };
  Map<String, Object?> toJson() => {
    'state': state.name,
    if (representation != null) 'representation': representation!.name,
    if (state == BodyCaptureState.captured) 'data': data,
    if (state == BodyCaptureState.overflow && data != null) 'data': data,
  };
  factory BodySnapshot.fromJson(Map<String, Object?> m) {
    final state = BodyCaptureState.values.byName(m['state'] as String);
    if (state != BodyCaptureState.captured) {
      if (state == BodyCaptureState.overflow) {
        final d = m['data'] as Map?;
        return BodySnapshot.overflow(
          sizeBytes: d?['sizeBytes'] as int?,
          contentType: d?['contentType'] as String?,
        );
      }
      if (m.containsKey('data') || m.containsKey('representation')) {
        throw FormatException('Uncaptured body contains data');
      }
      return switch (state) {
        BodyCaptureState.absent => const BodySnapshot.absent(),
        BodyCaptureState.disabled => const BodySnapshot.disabled(),
        _ => const BodySnapshot.unsupported(),
      };
    }
    if (!m.containsKey('data')) {
      throw FormatException('Missing captured body data');
    }
    return switch (BodyRepresentation.values.byName(
      m['representation'] as String,
    )) {
      BodyRepresentation.text => BodySnapshot.text(m['data'] as String),
      BodyRepresentation.json => BodySnapshot.json(m['data']),
      BodyRepresentation.media => _media(m['data']),
    };
  }
}

Map<String, Object?> jsonMap(Object? value) =>
    Map<String, Object?>.from(value as Map);
Map<String, List<String>>? headersFromJson(Object? value) => value == null
    ? null
    : jsonMap(value).map((k, v) => MapEntry(k, List<String>.from(v as List)));

final class HttpResponseSnapshot {
  final int? statusCode;
  final Map<String, List<String>>? headers;
  final BodySnapshot? body;
  const HttpResponseSnapshot({this.statusCode, this.headers, this.body});
  HttpResponseSnapshot detached() => HttpResponseSnapshot(
    statusCode: statusCode,
    headers: freezeHeaders(headers),
    body: body?.detached(),
  );
  Map<String, Object?> toJson() => {
    if (statusCode != null) 'statusCode': statusCode,
    if (headers != null) 'headers': headers,
    if (body != null) 'body': body!.toJson(),
  };
  factory HttpResponseSnapshot.fromJson(Map<String, Object?> m) =>
      HttpResponseSnapshot(
        statusCode: m['statusCode'] as int?,
        headers: headersFromJson(m['headers']),
        body: m['body'] == null
            ? null
            : BodySnapshot.fromJson(jsonMap(m['body'])),
      );
}

sealed class DiagnosticPayload {
  const DiagnosticPayload();
  Map<String, Object?> toJson();
}

final class LogPayload extends DiagnosticPayload {
  final String message;
  final LogLevel level;
  final Set<String>? tags;
  final DiagnosticError? error;
  final String? stackTrace;
  const LogPayload({
    required this.message,
    this.level = LogLevel.info,
    this.tags,
    this.error,
    this.stackTrace,
  });
  @override
  Map<String, Object?> toJson() => {
    'type': 'log',
    'message': message,
    'level': level.name,
    if (tags != null) 'tags': tags!.toList(),
    if (error != null) 'error': error!.toJson(),
    if (stackTrace != null) 'stackTrace': stackTrace,
  };
}

final class HttpPayload extends DiagnosticPayload {
  final DateTime requestStartedAt;
  final Duration? duration;
  final String method;
  final Uri uri;
  final Map<String, List<String>>? requestHeaders;
  final BodySnapshot? requestBody;
  final HttpResponseSnapshot? response;
  final DiagnosticError? error;
  const HttpPayload({
    required this.requestStartedAt,
    required this.method,
    required this.uri,
    this.duration,
    this.requestHeaders,
    this.requestBody,
    this.response,
    this.error,
  });
  @override
  Map<String, Object?> toJson() => {
    'type': 'http',
    'requestStartedAt': requestStartedAt.toUtc().toIso8601String(),
    'method': method,
    'uri': uri.toString(),
    if (duration != null) 'durationMicros': duration!.inMicroseconds,
    if (requestHeaders != null) 'requestHeaders': requestHeaders,
    if (requestBody != null) 'requestBody': requestBody!.toJson(),
    if (response != null) 'response': response!.toJson(),
    if (error != null) 'error': error!.toJson(),
  };
}

sealed class DiagnosticInput {
  final String? source;
  final Map<String, Object?>? context;
  const DiagnosticInput({this.source, this.context});
}

final class LogInput extends DiagnosticInput {
  final String message;
  final LogLevel level;
  final Set<String>? tags;
  final Object? error;
  final StackTrace? stackTrace;
  const LogInput({
    required this.message,
    LogLevel? level,
    this.tags,
    this.error,
    this.stackTrace,
    super.source,
    super.context,
  }) : level = level ?? LogLevel.info;
}

final class HttpInput extends DiagnosticInput {
  final String recordId;
  final DateTime requestStartedAt;
  final Duration? duration;
  final String method;
  final Uri uri;
  final Map<String, List<String>>? requestHeaders;
  final BodySnapshot? requestBody;
  final HttpResponseSnapshot? response;
  final DiagnosticError? error;
  const HttpInput({
    required this.recordId,
    required this.requestStartedAt,
    required this.method,
    required this.uri,
    this.duration,
    this.requestHeaders,
    this.requestBody,
    this.response,
    this.error,
    super.source,
    super.context,
  });
}

final class DiagnosticRecord {
  final String id;
  final DateTime recordedAt;
  final RecordMode recordMode;
  final String? source;
  final Map<String, Object?>? context;
  final DiagnosticPayload payload;
  DiagnosticRecord({
    required this.id,
    required DateTime recordedAt,
    required this.recordMode,
    required DiagnosticPayload payload,
    this.source,
    Map<String, Object?>? context,
  }) : recordedAt = recordedAt.toUtc(),
       context = freezeContext(context),
       payload = _detachPayload(payload) {
    if (id.isEmpty) throw ArgumentError('Empty record ID');
  }

  DiagnosticRecord._trusted({
    required this.id,
    required this.recordedAt,
    required this.recordMode,
    required this.payload,
    this.source,
    this.context,
  });

  static DiagnosticPayload _detachPayload(DiagnosticPayload p) => switch (p) {
    LogPayload() => LogPayload(
      message: p.message,
      level: p.level,
      tags: p.tags == null ? null : Set.unmodifiable(p.tags!),
      error: p.error,
      stackTrace: p.stackTrace,
    ),
    HttpPayload() => _detachHttp(p),
  };
  static HttpPayload _detachHttp(HttpPayload p) {
    if (p.method.isEmpty ||
        p.uri.toString().isEmpty ||
        (p.duration?.isNegative ?? false)) {
      throw ArgumentError('Invalid HTTP snapshot');
    }
    return HttpPayload(
      requestStartedAt: p.requestStartedAt.toUtc(),
      method: p.method,
      uri: p.uri,
      duration: p.duration,
      requestHeaders: freezeHeaders(p.requestHeaders),
      requestBody: p.requestBody?.detached(),
      response: p.response?.detached(),
      error: p.error,
    );
  }

  Map<String, Object?> toJson() => {
    'schemaVersion': diagnosticRecordSchemaVersion,
    'id': id,
    'recordedAt': recordedAt.toIso8601String(),
    'recordMode': recordMode.name,
    if (source != null) 'source': source,
    if (context != null) 'context': context,
    'payload': payload.toJson(),
  };
  factory DiagnosticRecord.fromJson(
    Map<String, Object?> m, {
    bool summaryOnly = false,
  }) {
    final p = jsonMap(m['payload']);
    final error = p['error'] == null
        ? null
        : DiagnosticError.fromJson(jsonMap(p['error']));
    final DiagnosticPayload payload;
    switch (p['type']) {
      case 'log':
        payload = LogPayload(
          message: p['message'] as String,
          level: LogLevel.values.byName(p['level'] as String),
          tags: p['tags'] == null ? null : Set<String>.from(p['tags'] as List),
          error: error,
          stackTrace: summaryOnly ? null : p['stackTrace'] as String?,
        );
      case 'http':
        final duration = p['durationMicros'] == null
            ? null
            : Duration(microseconds: p['durationMicros'] as int);
        if (duration?.isNegative ?? false) {
          throw FormatException('Duration cannot be negative');
        }
        final method = p['method'] as String;
        if (method.isEmpty) {
          throw FormatException('HTTP method cannot be empty');
        }
        payload = HttpPayload(
          requestStartedAt: _utc(p['requestStartedAt'] as String),
          method: method,
          uri: Uri.parse(p['uri'] as String),
          duration: duration,
          requestHeaders: summaryOnly
              ? null
              : headersFromJson(p['requestHeaders']),
          requestBody: summaryOnly
              ? null
              : (p['requestBody'] == null
                    ? null
                    : BodySnapshot.fromJson(jsonMap(p['requestBody']))),
          response: p['response'] == null
              ? null
              : (summaryOnly
                    ? HttpResponseSnapshot(
                        statusCode:
                            (p['response'] as Map)['statusCode'] as int?,
                      )
                    : HttpResponseSnapshot.fromJson(jsonMap(p['response']))),
          error: error,
        );
      default:
        throw FormatException('Unknown payload type');
    }
    final id = m['id'] as String;
    if (id.isEmpty) {
      throw FormatException('Record ID cannot be empty');
    }
    return DiagnosticRecord._trusted(
      id: id,
      recordedAt: _utc(m['recordedAt'] as String),
      recordMode: RecordMode.values.byName(m['recordMode'] as String),
      source: m['source'] as String?,
      context: summaryOnly
          ? null
          : (m['context'] == null ? null : jsonMap(m['context'])),
      payload: payload,
    );
  }
  static DateTime _utc(String value) {
    final time = DateTime.parse(value);
    if (!time.isUtc) throw FormatException('Timestamp must include UTC offset');
    return time;
  }
}

final class TraceSession {
  final String id;
  final String? name;
  final DateTime from;
  final DateTime to;
  final List<String> recordIds;
  TraceSession({
    required this.id,
    this.name,
    required DateTime from,
    required DateTime to,
    required Iterable<String> recordIds,
  }) : from = from.toUtc(),
       to = to.toUtc(),
       recordIds = List.unmodifiable(recordIds.toSet());
}
