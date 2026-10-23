import 'dart:convert';
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

BodySnapshot snapshotBody(Object? data, {int? maxBodyCaptureBytes}) {
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
  if (data is String) {
    final bytesLength = utf8.encode(data).length;
    if (maxBodyCaptureBytes != null && bytesLength > maxBodyCaptureBytes) {
      return BodySnapshot.oversized(bytesLength, 'text/plain');
    }
    return BodySnapshot.text(data);
  }
  if (data is num || data is bool || data is Map || data is List) {
    if (maxBodyCaptureBytes != null && (data is Map || data is List)) {
      try {
        final estimatedLength = utf8.encode(jsonEncode(data)).length;
        if (estimatedLength > maxBodyCaptureBytes) {
          return BodySnapshot.oversized(estimatedLength, 'application/json');
        }
      } catch (_) {}
    }
    try {
      return BodySnapshot.json(data);
    } on ArgumentError {
      return const BodySnapshot.unsupported();
    }
  }
  return const BodySnapshot.unsupported();
}

BodySnapshot snapshotResponseBody(
  Response<dynamic> response, {
  int? maxBodyCaptureBytes,
}) {
  if (response.requestOptions.responseType == ResponseType.stream) {
    return const BodySnapshot.unsupported();
  }
  return snapshotBody(response.data, maxBodyCaptureBytes: maxBodyCaptureBytes);
}
