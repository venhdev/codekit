import 'dart:convert';

import '../models/records.dart';
import 'base64_image_detector.dart';

const redactionMarker = '[REDACTED]';

enum HeaderTarget {
  request,
  response,
  both;

  bool get includesRequest => this != response;
  bool get includesResponse => this != request;
}

sealed class RedactionRule {
  const RedactionRule();
}

final class HeaderRedactionRule extends RedactionRule {
  final Set<String> names;
  final HeaderTarget target;
  HeaderRedactionRule(Iterable<String> names, {this.target = HeaderTarget.both})
    : names = Set.unmodifiable(names.map((n) => n.toLowerCase()));
}

final class QueryRedactionRule extends RedactionRule {
  final Set<String> names;
  QueryRedactionRule(Iterable<String> names) : names = Set.unmodifiable(names);
}

final class BodyFieldRedactionRule extends RedactionRule {
  final List<String> paths;
  BodyFieldRedactionRule(Iterable<String> paths)
    : paths = List.unmodifiable(paths) {
    for (final path in this.paths) {
      if (path
          .split('.')
          .any((k) => k.isEmpty || RegExp(r'[\[\]*]').hasMatch(k))) {
        throw ArgumentError('Only simple dotted object paths are supported');
      }
    }
  }
}

final class TextRedactionRule extends RedactionRule {
  final RegExp pattern;
  const TextRedactionRule(this.pattern);
}

Object? _mutable(Object? value) => value is Map
    ? value.map((k, v) => MapEntry(k, _mutable(v)))
    : value is List
    ? value.map(_mutable).toList()
    : value;

final class RedactionPolicy {
  final bool authorization;
  final bool cookie;
  final bool setCookie;
  final bool base64Images;
  final List<RedactionRule>? rules;
  RedactionPolicy({
    bool? authorization,
    bool? cookie,
    bool? setCookie,
    bool? base64Images,
    List<RedactionRule>? rules,
  }) : authorization = authorization ?? true,
       cookie = cookie ?? true,
       setCookie = setCookie ?? true,
       base64Images = base64Images ?? true,
       rules = rules == null ? null : List.unmodifiable(rules);
  DiagnosticRecord apply(DiagnosticRecord record) {
    final map = jsonMap(_mutable(record.toJson()));
    final payload = jsonMap(map['payload']);
    map['payload'] = payload;
    if (base64Images && payload['type'] == 'http') {
      _redactBase64ImageBody(payload['requestBody']);
      if (payload['response'] is Map) {
        _redactBase64ImageBody((payload['response'] as Map)['body']);
      }
    }
    final presets = [
      if (authorization) 'authorization',
      if (cookie) 'cookie',
      if (setCookie) 'set-cookie',
    ];
    for (final rule in [HeaderRedactionRule(presets), ...?rules]) {
      switch (rule) {
        case HeaderRedactionRule():
          if (payload['type'] != 'http') continue;
          if (rule.target.includesRequest) {
            _redactHeaders(payload['requestHeaders'], rule);
          }
          if (rule.target.includesResponse && payload['response'] is Map) {
            _redactHeaders((payload['response'] as Map)['headers'], rule);
          }
        case QueryRedactionRule():
          if (payload['type'] != 'http') continue;
          _redactQueryParameters(payload, rule);
        case BodyFieldRedactionRule():
          if (payload['type'] == 'http') {
            _redactBodyFields(payload['requestBody'], rule);
            if (payload['response'] is Map) {
              _redactBodyFields((payload['response'] as Map)['body'], rule);
            }
          }
        case TextRedactionRule():
          _applyTextRule(map, payload, rule);
      }
    }
    return DiagnosticRecord.fromJson(map);
  }

  Object? _maskBase64ImageValue(Object? value) {
    if (value is String) {
      return isBase64Image(value) ? redactionMarker : value;
    }
    if (value is List) return value.map(_maskBase64ImageValue).toList();
    if (value is Map) {
      return value.map(
        (key, child) => MapEntry(key, _maskBase64ImageValue(child)),
      );
    }
    return value;
  }

  void _redactBase64ImageBody(Object? value) {
    if (value is! Map || value['state'] != 'captured') return;
    if (value['representation'] == 'json') {
      value['data'] = _maskBase64ImageValue(value['data']);
    } else if (value['representation'] == 'text') {
      final original = value['data'] as String;
      if (isBase64Image(original)) {
        value['data'] = redactionMarker;
        return;
      }
      try {
        final parsed = jsonDecode(original);
        final masked = _maskBase64ImageValue(parsed);
        if (jsonEncode(parsed) != jsonEncode(masked)) {
          value['data'] = jsonEncode(masked);
        }
      } on FormatException {
        // Ordinary text is preserved exactly.
      }
    }
  }

  void _redactHeaders(Object? headers, HeaderRedactionRule rule) {
    if (headers is! Map) return;
    for (final key in headers.keys.toList()) {
      if (rule.names.contains((key as String).toLowerCase())) {
        headers[key] = (headers[key] as List)
            .map((_) => redactionMarker)
            .toList();
      }
    }
  }

  void _redactQueryParameters(
    Map<String, Object?> payload,
    QueryRedactionRule rule,
  ) {
    final uri = Uri.parse(payload['uri'] as String);
    if (!uri.queryParametersAll.keys.any(rule.names.contains)) return;
    final params = uri.queryParametersAll.map(
      (k, values) => MapEntry(
        k,
        rule.names.contains(k)
            ? values.map((_) => redactionMarker).toList()
            : values,
      ),
    );
    payload['uri'] = uri.replace(queryParameters: params).toString();
  }

  void _redactBodyFields(Object? value, BodyFieldRedactionRule rule) {
    if (value is! Map || value['state'] != 'captured') return;
    final isText = value['representation'] == 'text';
    if (!isText && value['representation'] != 'json') return;
    Object? data = value['data'];
    if (isText) {
      try {
        data = jsonDecode(data as String);
      } catch (_) {
        return;
      }
    }
    var changed = false;
    for (final path in rule.paths) {
      final keys = path.split('.');
      Object? parent = data;
      for (final key in keys.take(keys.length - 1)) {
        parent = parent is Map ? parent[key] : null;
      }
      if (parent is Map && parent.containsKey(keys.last)) {
        parent[keys.last] = redactionMarker;
        changed = true;
      }
    }
    if (changed) value['data'] = isText ? jsonEncode(data) : data;
  }

  void _applyTextRule(
    Map<String, Object?> map,
    Map<String, Object?> payload,
    TextRedactionRule rule,
  ) {
    if (map.containsKey('context')) {
      map['context'] = _redactJsonStrings(map['context'], rule);
    }
    _redactDiagnosticError(payload['error'], rule);
    if (payload['type'] == 'log') {
      payload['message'] = _redactText(payload['message'] as String, rule);
      if (payload['stackTrace'] is String) {
        payload['stackTrace'] = _redactText(
          payload['stackTrace'] as String,
          rule,
        );
      }
      return;
    }
    if (payload['requestHeaders'] != null) {
      payload['requestHeaders'] = _redactJsonStrings(
        payload['requestHeaders'],
        rule,
      );
    }
    if (payload['response'] is Map) {
      final response = payload['response'] as Map;
      if (response['headers'] != null) {
        response['headers'] = _redactJsonStrings(response['headers'], rule);
      }
    }
    _redactBodyText(payload['requestBody'], rule);
    if (payload['response'] is Map) {
      _redactBodyText((payload['response'] as Map)['body'], rule);
    }
    final uri = Uri.parse(payload['uri'] as String);
    final params = uri.queryParametersAll;
    if (params.values.expand((v) => v).any((v) => _redactText(v, rule) != v)) {
      payload['uri'] = uri
          .replace(
            queryParameters: params.map(
              (k, v) => MapEntry(k, v.map((s) => _redactText(s, rule)).toList()),
            ),
          )
          .toString();
    }
  }

  String _redactText(String value, TextRedactionRule rule) => value
      .split(redactionMarker)
      .map((piece) => piece.replaceAll(rule.pattern, redactionMarker))
      .join(redactionMarker);

  Object? _redactJsonStrings(Object? value, TextRedactionRule rule) =>
      value is String
      ? _redactText(value, rule)
      : value is List
      ? value.map((item) => _redactJsonStrings(item, rule)).toList()
      : value is Map
      ? value.map(
          (k, child) => MapEntry(k, _redactJsonStrings(child, rule)),
        )
      : value;

  void _redactDiagnosticError(Object? error, TextRedactionRule rule) {
    if (error is! Map) return;
    for (final key in ['message', 'stackTrace']) {
      if (error[key] is String) {
        error[key] = _redactText(error[key] as String, rule);
      }
    }
  }

  void _redactBodyText(Object? body, TextRedactionRule rule) {
    if (body is! Map || body['state'] != 'captured') return;
    if (body['representation'] == 'text') {
      // Parse JSON transiently so keys and JSON syntax are preserved.
      Object? parsed;
      var isJson = false;
      try {
        parsed = jsonDecode(body['data'] as String);
        isJson = true;
      } catch (_) {}
      if (isJson) {
        final changed = _redactJsonStrings(parsed, rule);
        if (jsonEncode(changed) != jsonEncode(parsed)) {
          body['data'] = jsonEncode(changed);
        }
      } else {
        body['data'] = _redactText(body['data'] as String, rule);
      }
    } else {
      body['data'] = _redactJsonStrings(body['data'], rule);
    }
  }
}
