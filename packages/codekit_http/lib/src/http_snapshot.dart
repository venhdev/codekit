import 'dart:convert';

import 'package:codekit_core/codekit_core.dart';
import 'package:http/http.dart' as http;

/// Snapshots only an already buffered response, subject to optional [maxBodyCaptureBytes].
BodySnapshot snapshotResponseBody(
  http.Response response, {
  int? maxBodyCaptureBytes,
}) {
  final bytes = response.bodyBytes;
  if (bytes.isEmpty) return const BodySnapshot.absent();
  final type =
      response.headers['content-type']?.split(';').first.trim().toLowerCase() ??
      '';
  final isJson =
      type == 'application/json' ||
      (type.startsWith('application/') && type.endsWith('+json'));
  if (!isJson &&
      !type.startsWith('text/') &&
      type != 'application/xml' &&
      !type.endsWith('+xml')) {
    return const BodySnapshot.unsupported();
  }
  if (maxBodyCaptureBytes != null && bytes.length > maxBodyCaptureBytes) {
    return BodySnapshot.oversized(bytes.length, type);
  }
  try {
    final text = isJson ? utf8.decode(bytes) : response.body;
    if (isJson) {
      try {
        return BodySnapshot.json(jsonDecode(text)).detached();
      } on FormatException {
        return BodySnapshot.text(text);
      }
    }
    return BodySnapshot.text(text);
  } catch (_) {
    return const BodySnapshot.unsupported();
  }
}

Map<String, List<String>> snapshotRequestHeaders(http.BaseRequest request) {
  final headers = request.headers.map((key, value) => MapEntry(key, [value]));
  if (request is http.MultipartRequest &&
      !headers.keys.any((key) => key.toLowerCase() == 'content-type')) {
    // package:http adds the boundary during finalize(); don't finalize early.
    headers['content-type'] = ['multipart/form-data'];
  }
  return headers;
}

BodySnapshot snapshotRequestBody(
  http.BaseRequest request, {
  int? maxBodyCaptureBytes,
}) {
  if (request is http.MultipartRequest) {
    final files = request.files
        .map(
          (file) => <String, Object?>{
            'fieldName': file.field,
            'fileName': file.filename,
            'contentType': file.contentType.toString(),
            'sizeBytes': file.length,
          },
        )
        .toList(growable: false);
    return BodySnapshot.json({'fields': request.fields, 'files': files});
  }
  if (request is! http.Request) return const BodySnapshot.unsupported();
  if (request.bodyBytes.isEmpty) return const BodySnapshot.absent();

  final contentTypeHeader = request.headers.entries
      .where((entry) => entry.key.toLowerCase() == 'content-type')
      .firstOrNull
      ?.value;
  final contentType = contentTypeHeader?.split(';').first.trim().toLowerCase();
  if (contentType == 'application/x-www-form-urlencoded') {
    return BodySnapshot.json(request.bodyFields);
  }
  if (maxBodyCaptureBytes != null &&
      request.bodyBytes.length > maxBodyCaptureBytes) {
    return BodySnapshot.oversized(request.bodyBytes.length, contentType);
  }
  final isJson =
      contentType == 'application/json' ||
      (contentType?.startsWith('application/') == true &&
          contentType!.endsWith('+json'));
  if (isJson) {
    try {
      return BodySnapshot.json(jsonDecode(request.body));
    } on FormatException {
      return const BodySnapshot.unsupported();
    }
  }
  if (contentType?.startsWith('text/') == true ||
      contentType?.endsWith('+xml') == true ||
      contentType == 'application/xml') {
    try {
      return BodySnapshot.text(request.body);
    } on FormatException {
      return const BodySnapshot.unsupported();
    }
  }
  return const BodySnapshot.unsupported();
}
