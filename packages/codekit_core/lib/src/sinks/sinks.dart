import 'dart:async';

import '../models/records.dart';

class HttpDispatchPolicy {
  final List<RegExp>? includeUriPatterns;
  final List<RegExp>? excludeUriPatterns;
  final Set<HttpStatusGroup>? statusGroups;
  HttpDispatchPolicy({
    List<RegExp>? includeUriPatterns,
    List<RegExp>? excludeUriPatterns,
    Set<HttpStatusGroup>? statusGroups,
  }) : includeUriPatterns = includeUriPatterns == null
           ? null
           : List.unmodifiable(includeUriPatterns),
       excludeUriPatterns = excludeUriPatterns == null
           ? null
           : List.unmodifiable(excludeUriPatterns),
       statusGroups = statusGroups == null
           ? null
           : Set.unmodifiable(statusGroups);
  bool matches(HttpPayload payload) {
    final uri = payload.uri.toString();
    if (excludeUriPatterns?.any((p) => p.hasMatch(uri)) ?? false) return false;
    if (includeUriPatterns != null &&
        includeUriPatterns!.isNotEmpty &&
        !includeUriPatterns!.any((p) => p.hasMatch(uri))) {
      return false;
    }
    return statusGroups == null ||
        statusGroups!.contains(
          HttpStatusGroup.fromCode(payload.response?.statusCode),
        );
  }
}

class LogDispatchPolicy {
  final Set<LogLevel>? levels;
  final Set<String>? includeTags;
  final Set<String>? excludeTags;
  LogDispatchPolicy({
    Set<LogLevel>? levels,
    Set<String>? includeTags,
    Set<String>? excludeTags,
  }) : levels = levels == null ? null : Set.unmodifiable(levels),
       includeTags = includeTags == null ? null : Set.unmodifiable(includeTags),
       excludeTags = excludeTags == null ? null : Set.unmodifiable(excludeTags);
  bool matches(LogPayload payload) {
    final tags = payload.tags ?? const <String>{};
    if (excludeTags?.any(tags.contains) ?? false) return false;
    if (includeTags != null &&
        includeTags!.isNotEmpty &&
        !includeTags!.any(tags.contains)) {
      return false;
    }
    return levels == null || levels!.contains(payload.level);
  }
}

/// Receives redacted immutable records, never an unprocessed producer input.
abstract interface class DiagnosticSink {
  HttpDispatchPolicy? get httpDispatchPolicy;
  LogDispatchPolicy? get logDispatchPolicy;
  FutureOr<void> dispatch(DiagnosticRecord record);
  FutureOr<void> dispose();
}
