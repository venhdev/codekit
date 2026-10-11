import 'dart:convert';

import 'package:codekit_core/codekit_core.dart';
import 'package:http/http.dart' as http;

Map<String, List<String>> snapshotRequestHeaders(http.BaseRequest request) {
  final headers = request.headers.map((key, value) => MapEntry(key, [value]));
  if (request is http.MultipartRequest &&
      !headers.keys.any((key) => key.toLowerCase() == 'content-type')) {
    // package:http adds the boundary during finalize(); don't finalize early.
    headers['content-type'] = ['multipart/form-data'];
  }
  return headers;
}

BodySnapshot snapshotRequestBody(http.BaseRequest request) {
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
