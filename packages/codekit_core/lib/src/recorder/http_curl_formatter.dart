import 'dart:convert';

import '../models/records.dart';

/// Formats a POSIX shell-quoted `curl` command for [payload].
String formatHttpCurl(HttpPayload payload) {
  final parts = <String>[
    'curl',
    '-X',
    _shellQuote(payload.method),
    _shellQuote(payload.uri.toString()),
  ];
  for (final entry
      in payload.requestHeaders?.entries ??
          const <MapEntry<String, List<String>>>[]) {
    for (final value in entry.value) {
      parts.addAll(['-H', _shellQuote('${entry.key}: $value')]);
    }
  }
  final body = payload.requestBody;
  if (body?.state == BodyCaptureState.captured &&
      body?.representation != BodyRepresentation.media) {
    final raw = body!.representation == BodyRepresentation.text
        ? body.data as String
        : jsonEncode(body.data);
    parts.addAll(['--data-raw', _shellQuote(raw)]);
  }
  return parts.join(' ');
}

String _shellQuote(String value) => "'${value.replaceAll("'", "'\\''")}'";
