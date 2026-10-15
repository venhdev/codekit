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
      Object? mask(Object? value) {
        if (value is String) {
          return isBase64Image(value) ? redactionMarker : value;
        }
        if (value is List) return value.map(mask).toList();
        if (value is Map) {
          return value.map((key, child) => MapEntry(key, mask(child)));
        }
        return value;
      }

      void body(Object? value) {
        if (value is! Map || value['state'] != 'captured') return;
        if (value['representation'] == 'json') {
          value['data'] = mask(value['data']);
        } else if (value['representation'] == 'text') {
          final original = value['data'] as String;
          if (isBase64Image(original)) {
            value['data'] = redactionMarker;
            return;
          }
          try {
            final parsed = jsonDecode(original);
            final masked = mask(parsed);
            if (jsonEncode(parsed) != jsonEncode(masked)) {
              value['data'] = jsonEncode(masked);
            }
          } on FormatException {
            // Ordinary text is preserved exactly.
          }
        }
      }

      body(payload['requestBody']);
      if (payload['response'] is Map) {
        body((payload['response'] as Map)['body']);
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
          void redactHeaders(Object? h) {
            if (h is Map) {
              for (final key in h.keys.toList()) {
                if (rule.names.contains((key as String).toLowerCase())) {
                  h[key] = (h[key] as List)
                      .map((_) => redactionMarker)
                      .toList();
                }
              }
            }
          }
          if (rule.target.includesRequest) {
            redactHeaders(payload['requestHeaders']);
          }
          if (rule.target.includesResponse && payload['response'] is Map) {
            redactHeaders((payload['response'] as Map)['headers']);
          }
        case QueryRedactionRule():
          if (payload['type'] != 'http') continue;
          final uri = Uri.parse(payload['uri'] as String);
          if (!uri.queryParametersAll.keys.any(rule.names.contains)) continue;
          final params = uri.queryParametersAll.map(
            (k, values) => MapEntry(
              k,
              rule.names.contains(k)
                  ? values.map((_) => redactionMarker).toList()
                  : values,
            ),
          );
          payload['uri'] = uri.replace(queryParameters: params).toString();
        case BodyFieldRedactionRule():
          void redactBody(Object? value) {
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
          if (payload['type'] == 'http') {
            redactBody(payload['requestBody']);
            if (payload['response'] is Map) {
              redactBody((payload['response'] as Map)['body']);
            }
          }
        case TextRedactionRule():
          String text(String s) => s
              .split(redactionMarker)
              .map((piece) => piece.replaceAll(rule.pattern, redactionMarker))
              .join(redactionMarker);
          Object? strings(Object? v) => v is String
              ? text(v)
              : v is List
              ? v.map(strings).toList()
              : v is Map
              ? v.map((k, value) => MapEntry(k, strings(value)))
              : v;
          void error(Object? e) {
            if (e is Map) {
              for (final key in ['message', 'stackTrace']) {
                if (e[key] is String) {
                  e[key] = text(e[key] as String);
                }
              }
            }
          }
          if (map.containsKey('context')) {
            map['context'] = strings(map['context']);
          }
          error(payload['error']);
          if (payload['type'] == 'log') {
            payload['message'] = text(payload['message'] as String);
            if (payload['stackTrace'] is String) {
              payload['stackTrace'] = text(payload['stackTrace'] as String);
            }
          } else {
            if (payload['requestHeaders'] != null) {
              payload['requestHeaders'] = strings(payload['requestHeaders']);
            }
            if (payload['response'] is Map) {
              final response = payload['response'] as Map;
              if (response['headers'] != null) {
                response['headers'] = strings(response['headers']);
              }
            }
            void body(Object? b) {
              if (b is Map && b['state'] == 'captured') {
                if (b['representation'] == 'text') {
                  // Parse JSON transiently so keys and JSON syntax are preserved.
                  Object? parsed;
                  var json = false;
                  try {
                    parsed = jsonDecode(b['data'] as String);
                    json = true;
                  } catch (_) {}
                  if (json) {
                    final changed = strings(parsed);
                    if (jsonEncode(changed) != jsonEncode(parsed)) {
                      b['data'] = jsonEncode(changed);
                    }
                  } else {
                    b['data'] = text(b['data'] as String);
                  }
                } else {
                  b['data'] = strings(b['data']);
                }
              }
            }

            body(payload['requestBody']);
            if (payload['response'] is Map) {
              body((payload['response'] as Map)['body']);
            }
            final uri = Uri.parse(payload['uri'] as String);
            final params = uri.queryParametersAll;
            if (params.values.expand((v) => v).any((v) => text(v) != v)) {
              payload['uri'] = uri
                  .replace(
                    queryParameters: params.map(
                      (k, v) => MapEntry(k, v.map(text).toList()),
                    ),
                  )
                  .toString();
            }
          }
      }
    }
    return DiagnosticRecord.fromJson(map);
  }
}
