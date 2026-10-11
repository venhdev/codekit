import 'dart:convert';

import 'package:codekit_core/codekit_core.dart';

import '../webhook_sink_options.dart';

Map<String, Object?> telegramPayload(
  DiagnosticRecord record, {
  required String chatId,
  required TelegramSinkOptions? options,
  required DiagnosticContentOptions? contentOptions,
}) {
  final text = _truncateHtml(
    escapeTelegramHtml(recordDetails(record, contentOptions)),
  );
  return {
    'chat_id': chatId,
    'text': text,
    'parse_mode': 'HTML',
    if (options?.messageThreadId != null)
      'message_thread_id': options!.messageThreadId,
    if (options?.disableNotification != null)
      'disable_notification': options!.disableNotification,
    if (options?.protectContent != null)
      'protect_content': options!.protectContent,
    if (options?.disableLinkPreview != null)
      'link_preview_options': {'is_disabled': options!.disableLinkPreview},
  };
}

String escapeTelegramHtml(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');

String _truncateHtml(String value) {
  const suffix = '\n… (truncated)';
  final runes = value.runes.toList(growable: false);
  if (runes.length <= 4096) return value;
  return '${String.fromCharCodes(runes.take(4096 - suffix.length))}$suffix';
}

List<int> encodeTelegramPayload(Map<String, Object?> payload) =>
    utf8.encode(jsonEncode(payload));
