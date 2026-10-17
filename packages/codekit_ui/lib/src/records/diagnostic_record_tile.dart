import 'package:codekit_core/codekit_core.dart';
import 'package:flutter/material.dart';

import '../shared/codekit_tag.dart';

class DiagnosticRecordTile extends StatelessWidget {
  const DiagnosticRecordTile({
    super.key,
    required this.record,
    required this.selectionMode,
    required this.selected,
    required this.onSelect,
    required this.onOpen,
    required this.onLongPress,
  });

  final DiagnosticRecord record;
  final bool selectionMode;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onOpen;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final payload = record.payload;
    final time = TimeOfDay.fromDateTime(record.recordedAt.toLocal());
    final timestamp = time.format(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor = selected
        ? colors.primaryContainer.withValues(alpha: isDark ? 0.24 : 0.35)
        : (isDark ? colors.surfaceContainerLow : colors.surfaceContainerLowest);
    final borderColor = selected
        ? colors.primary
        : colors.outlineVariant.withValues(alpha: selectionMode ? 0.65 : 0.35);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: backgroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: borderColor, width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: selectionMode ? onSelect : onOpen,
          onLongPress: selectionMode ? null : onLongPress,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CodeKitTag.recordKind(
                      recordType: payload is HttpPayload
                          ? DiagnosticRecordType.http
                          : DiagnosticRecordType.log,
                    ),
                    if (payload is HttpPayload) ...[
                      const SizedBox(width: 4),
                      CodeKitTag.tonal(
                        label: payload.response?.statusCode?.toString() ?? '—',
                        tone: HttpStatusGroup.fromCode(
                          payload.response?.statusCode,
                        ).tone,
                      ),
                      if (payload.duration != null) ...[
                        const SizedBox(width: 4),
                        CodeKitTag.duration(
                          label: '${payload.duration!.inMilliseconds} ms',
                          durationLevel: DurationThresholds().classify(
                            payload.duration,
                          ),
                        ),
                      ],
                    ] else if (payload is LogPayload) ...[
                      const SizedBox(width: 4),
                      CodeKitTag.tonal(
                        label: payload.level.name.toUpperCase(),
                        tone: payload.level.tone,
                      ),
                      if (payload.tags != null)
                        for (final tag in payload.tags!.take(2)) ...[
                          const SizedBox(width: 4),
                          CodeKitTag.customTag(tag: tag),
                        ],
                    ],
                    const Spacer(),
                    Text(
                      timestamp,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                if (payload is HttpPayload) ...[
                  Text(
                    '${payload.method} ${payload.uri}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (payload.error != null)
                    Text(
                      payload.error!.message,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.error,
                      ),
                    ),
                ] else if (payload is LogPayload) ...[
                  Text(
                    payload.message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (record.source != null)
                    Text(
                      record.source!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
