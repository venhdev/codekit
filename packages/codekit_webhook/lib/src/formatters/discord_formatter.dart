import 'package:codekit_core/codekit_core.dart';

import '../webhook_sink_options.dart';

Map<String, Object?> discordPayload(
  DiagnosticRecord record, {
  required DiscordSinkOptions? options,
  required DiagnosticContentOptions? contentOptions,
}) {
  final title = options?.title;
  final footer = options?.footer;
  final descriptionLimit =
      6000 -
      (title == null ? 0 : _limitDiscord(title, 256).runes.length) -
      (footer == null ? 0 : _limitDiscord(footer, 2048).runes.length);
  final description = _limitDiscord(
    recordDetails(record, contentOptions),
    descriptionLimit,
  );
  final embed = <String, Object?>{
    'description': description,
    if (title != null) 'title': _limitDiscord(title, 256),
    if (options?.color != null) 'color': options!.color,
    if (footer != null) 'footer': {'text': _limitDiscord(footer, 2048)},
    if (options?.includeTimestamp ?? false)
      'timestamp': record.recordedAt.toIso8601String(),
  };
  return {
    if (options?.username != null) 'username': options!.username,
    if (options?.avatarUrl != null) 'avatar_url': options!.avatarUrl.toString(),
    'allowed_mentions': {'parse': <String>[]},
    'embeds': [embed],
  };
}

String _limitDiscord(String value, int limit) {
  if (limit <= 0) return '';
  final runes = value.runes.toList(growable: false);
  if (runes.length <= limit) return value;
  const suffix = '\n… (truncated)';
  final count = limit > suffix.runes.length
      ? limit - suffix.runes.length
      : limit;
  return '${String.fromCharCodes(runes.take(count))}${count == limit ? '' : suffix}';
}
