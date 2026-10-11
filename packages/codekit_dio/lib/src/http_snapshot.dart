import 'dart:typed_data';

import 'package:codekit_core/codekit_core.dart';
import 'package:dio/dio.dart';

Map<String, List<String>> snapshotHeaders(Map source) {
  final headers = <String, List<String>>{};
  for (final entry in source.entries) {
    final values = entry.value is Iterable
        ? entry.value as Iterable
        : [entry.value];
    final strings = <String>[];
    for (final value in values) {
      if (value is String || value is num || value is bool) {
        strings.add(value.toString());
      }
    }
    if (strings.isNotEmpty) headers[entry.key.toString()] = strings;
  }
  return headers;
}

BodySnapshot snapshotBody(Object? data) {
  if (data == null) return const BodySnapshot.absent();
  if (data is FormData) {
    final fields = <String, List<String>>{};
    for (final field in data.fields) {
      (fields[field.key] ??= []).add(field.value);
    }
    final files = data.files
        .map((entry) {
          final file = entry.value;
          return <String, Object?>{
            'fieldName': entry.key,
            'fileName': file.filename,
            'contentType': file.contentType.toString(),
            'sizeBytes': file.length,
          };
        })
        .toList(growable: false);
    return BodySnapshot.json({'fields': fields, 'files': files});
  }
  if (data is Uint8List) {
    return const BodySnapshot.unsupported();
  }
  if (data is String) return BodySnapshot.text(data);
  if (data is num || data is bool || data is Map || data is List) {
    try {
      return BodySnapshot.json(data);
    } on ArgumentError {
      return const BodySnapshot.unsupported();
    }
  }
  return const BodySnapshot.unsupported();
}

BodySnapshot snapshotResponseBody(Response<dynamic> response) {
  if (response.requestOptions.responseType == ResponseType.stream) {
    return const BodySnapshot.unsupported();
  }
  return snapshotBody(response.data);
}
