import 'dart:developer' as developer;
import 'dart:convert';

import 'package:codekit_core/codekit_core.dart';

/// Selects optional fields from an already prepared diagnostic record.
final class DiagnosticContentOptions {
  final bool? requestHeaders;
  final bool? requestBody;
  final bool? responseHeaders;
  final bool? responseBody;
  final bool? curl;
  final bool? context;
  final bool? error;
  final bool? stackTrace;

  const DiagnosticContentOptions({
    this.requestHeaders,
    this.requestBody,
    this.responseHeaders,
    this.responseBody,
    this.curl,
    this.context,
    this.error,
    this.stackTrace,
  });
}

/// Discord identity and embed presentation overrides.
final class DiscordSinkOptions {
  final String? username;
  final Uri? avatarUrl;
  final String? title;
  final int? color;
  final String? footer;
  final bool? includeTimestamp;

  const DiscordSinkOptions({
    this.username,
    this.avatarUrl,
    this.title,
    this.color,
    this.footer,
    this.includeTimestamp,
  });
}

/// Telegram sendMessage options supported by the MVP.
final class TelegramSinkOptions {
  final int? messageThreadId;
  final bool? disableNotification;
  final bool? protectContent;
  final bool? disableLinkPreview;

  const TelegramSinkOptions({
    this.messageThreadId,
    this.disableNotification,
    this.protectContent,
    this.disableLinkPreview,
  });
}

/// Per-sink consecutive failure and cooldown configuration.
final class SinkCircuitBreakerOptions {
  final int? failureThreshold;
  final Duration? cooldown;

  const SinkCircuitBreakerOptions({this.failureThreshold, this.cooldown});

  int get effectiveFailureThreshold => failureThreshold ?? 5;
  Duration get effectiveCooldown => cooldown ?? const Duration(minutes: 1);

  void validate() {
    if (effectiveFailureThreshold < 1) {
      throw ArgumentError.value(failureThreshold, 'failureThreshold');
    }
    if (effectiveCooldown <= Duration.zero) {
      throw ArgumentError.value(cooldown, 'cooldown');
    }
  }
}

/// Safe warning details; webhook URLs and credentials must never be included.
final class WebhookWarning {
  final String code;
  final String message;

  const WebhookWarning(this.code, this.message);
}

typedef WebhookWarningCallback = void Function(WebhookWarning warning);

void reportWebhookWarning(
  WebhookWarningCallback? callback,
  String code,
  String message,
) {
  try {
    if (callback == null) {
      developer.log(message, name: 'codekit.webhook.$code', level: 900);
    } else {
      callback(WebhookWarning(code, message));
    }
  } catch (_) {
    // Warning handlers are isolated from application and sink delivery paths.
  }
}

String recordSummary(DiagnosticRecord record) => switch (record.payload) {
  LogPayload payload =>
    '${payload.level.name.toUpperCase()}: ${payload.message}',
  HttpPayload payload =>
    '${payload.method} ${payload.uri} · ${payload.response?.statusCode ?? 'no response'} · ${payload.duration?.inMilliseconds ?? 'unknown'} ms',
};

String recordDetails(
  DiagnosticRecord record,
  DiagnosticContentOptions? options,
) {
  final sections = <String>[];
  switch (record.payload) {
    case LogPayload payload:
      sections.add(recordSummary(record));
      if ((options?.error ?? true) && payload.error != null) {
        final error = payload.error!;
        sections.add('${error.type}: ${error.message}');
      }
      if ((options?.stackTrace ?? true) && payload.stackTrace != null) {
        sections.add(payload.stackTrace!);
      }
    case HttpPayload payload:
      sections.add(recordSummary(record));
      if (options?.curl ?? false) {
        final curl = _formatCurl(payload);
        if (curl != null) sections.add('cURL:\n$curl');
      }
      if ((options?.requestHeaders ?? false) &&
          payload.requestHeaders != null) {
        sections.add(
          'Request headers:\n${_formatHeaders(payload.requestHeaders!)}',
        );
      }
      if ((options?.requestBody ?? false) && payload.requestBody != null) {
        sections.add('Request body:\n${_formatBody(payload.requestBody!)}');
      }
      if ((options?.responseHeaders ?? false) &&
          payload.response?.headers != null) {
        sections.add(
          'Response headers:\n${_formatHeaders(payload.response!.headers!)}',
        );
      }
      if ((options?.responseBody ?? false) && payload.response?.body != null) {
        sections.add('Response body:\n${_formatBody(payload.response!.body!)}');
      }
      if ((options?.error ?? true) && payload.error != null) {
        final error = payload.error!;
        sections.add('${error.type}: ${error.message}');
      }
      if ((options?.stackTrace ?? true) && payload.error?.stackTrace != null) {
        sections.add(payload.error!.stackTrace!);
      }
  }
  if ((options?.context ?? false) && record.context != null) {
    sections.add('Context:\n${record.context}');
  }
  return sections.join('\n\n');
}

String _formatHeaders(Map<String, List<String>> headers) => headers.entries
    .map((entry) => '${entry.key}: ${entry.value.join(', ')}')
    .join('\n');

String _formatBody(BodySnapshot body) => switch (body.state) {
  BodyCaptureState.captured => body.data.toString(),
  BodyCaptureState.absent => '(absent)',
  BodyCaptureState.disabled => '(capture disabled)',
  BodyCaptureState.unsupported => '(unsupported body)',
};

String? _formatCurl(HttpPayload payload) {
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
    final value = body!.representation == BodyRepresentation.json
        ? jsonEncode(body.data)
        : body.data.toString();
    parts.addAll(['--data-raw', _shellQuote(value)]);
  }
  return parts.join(' ');
}

String _shellQuote(String value) => "'${value.replaceAll("'", "'\\''")}'";
