import 'dart:convert';

import '../models/records.dart';
import '../redaction/redaction.dart';
import '../storage/storage.dart';
import 'http_curl_formatter.dart';

enum ExportRepresentation { redacted, asStored }

enum ExportStatus { success, empty, failed }

enum HttpFragment { body, headers, curl }

class ExportResult {
  final ExportStatus status;
  final String? text;
  final int recordCount;
  final String? error;
  const ExportResult._(this.status, this.text, this.recordCount, this.error);
  const ExportResult.empty() : this._(ExportStatus.empty, null, 0, null);
  const ExportResult.failed(String error)
    : this._(ExportStatus.failed, null, 0, error);
  const ExportResult.success(String text, int count)
    : this._(ExportStatus.success, text, count, null);
}

/// Service handling record export packaging and fragment formatting.
class DiagnosticExporter {
  final DiagnosticStore store;
  final void Function(String code, String message)? onWarning;

  const DiagnosticExporter({required this.store, this.onWarning});

  Future<ExportResult> exportRecords(
    List<String> ids, {
    ExportRepresentation representation = ExportRepresentation.redacted,
    required RedactionPolicy policy,
  }) async {
    try {
      final records = await store.getByIds(ids);
      if (records.isEmpty) return const ExportResult.empty();
      final copies = records
          .map(
            (r) => representation == ExportRepresentation.redacted
                ? policy.apply(r)
                : r,
          )
          .toList();
      final text = copies
          .map((r) => const JsonEncoder.withIndent('  ').convert(r.toJson()))
          .join('\n\n');
      return ExportResult.success(text, copies.length);
    } catch (_) {
      onWarning?.call('exportFailed', 'Export failed');
      return const ExportResult.failed('Query or redaction failed');
    }
  }

  Future<ExportResult> exportTraceSession(
    String id, {
    ExportRepresentation representation = ExportRepresentation.redacted,
    required RedactionPolicy policy,
  }) async {
    try {
      final sessions = await store.listTraceSessions();
      final session = sessions.where((s) => s.id == id).firstOrNull;
      if (session == null) return const ExportResult.empty();
      return await exportRecords(
        session.recordIds,
        representation: representation,
        policy: policy,
      );
    } catch (_) {
      return const ExportResult.failed('Trace query failed');
    }
  }

  Future<ExportResult> formatHttpFragment(
    String id,
    HttpFragment fragment, {
    ExportRepresentation representation = ExportRepresentation.redacted,
    required RedactionPolicy policy,
    HeaderTarget target = HeaderTarget.both,
  }) async {
    try {
      var record = await store.getById(id);
      if (record == null) return const ExportResult.empty();
      if (representation == ExportRepresentation.redacted) {
        record = policy.apply(record);
      }
      final p = record.payload;
      if (p is! HttpPayload) {
        return const ExportResult.failed('Not an HTTP record');
      }
      String encode(Object? value) => value is String
          ? value
          : const JsonEncoder.withIndent('  ').convert(value);
      final String text;
      switch (fragment) {
        case HttpFragment.headers:
          text = encode({
            if (target.includesRequest) 'request': p.requestHeaders,
            if (target.includesResponse) 'response': p.response?.headers,
          });
        case HttpFragment.body:
          String bodyText(BodySnapshot? body) =>
              body?.state == BodyCaptureState.captured
              ? encode(body!.data)
              : '[Body ${body?.state.name ?? 'absent'}]';
          if (target == HeaderTarget.request) {
            text = bodyText(p.requestBody);
          } else if (target == HeaderTarget.response) {
            text = bodyText(p.response?.body);
          } else {
            text =
                'Request body:\n${bodyText(p.requestBody)}\n\nResponse body:\n${bodyText(p.response?.body)}';
          }
        case HttpFragment.curl:
          final body = p.requestBody;
          final unreplayableBody =
              body != null &&
              body.state != BodyCaptureState.absent &&
              (body.state != BodyCaptureState.captured ||
                  body.representation == BodyRepresentation.media);
          final incomplete =
              record.recordMode == RecordMode.redactBeforeRecording ||
              representation == ExportRepresentation.redacted ||
              unreplayableBody;
          text =
              '${incomplete ? '# Diagnostic representation; replay may be incomplete\n' : ''}${formatHttpCurl(p)}';
      }
      return ExportResult.success(text, 1);
    } catch (_) {
      return const ExportResult.failed('Fragment formatting failed');
    }
  }
}
