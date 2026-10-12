import 'package:codekit_core/codekit_core.dart';
import 'package:flutter/material.dart';

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
    return InkWell(
      onTap: selectionMode ? onSelect : onOpen,
      onLongPress: selectionMode ? null : onLongPress,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
        decoration: selected
            ? BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary,
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(8),
              )
            : null,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _tag(context, payload is HttpPayload ? 'HTTP' : 'LOG'),
                      if (payload is HttpPayload) ...[
                        const SizedBox(width: 4),
                        _tag(
                          context,
                          payload.response?.statusCode?.toString() ?? '—',
                          color: _statusColor(
                            context,
                            HttpStatusGroup.fromCode(
                              payload.response?.statusCode,
                            ),
                          ),
                        ),
                        if (payload.duration != null) ...[
                          const SizedBox(width: 4),
                          _tag(
                            context,
                            '${payload.duration!.inMilliseconds} ms',
                            color: _durationColor(
                              context,
                              DurationThresholds().classify(payload.duration),
                            ),
                          ),
                        ],
                      ] else if (payload is LogPayload) ...[
                        const SizedBox(width: 4),
                        _tag(context, payload.level.name.toUpperCase()),
                      ],
                      const Spacer(),
                      Text(
                        timestamp,
                        style: Theme.of(context).textTheme.labelSmall,
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
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tag(BuildContext context, String text, {Color? color}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: color ?? Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      text,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color:
            color == null ||
                color == Theme.of(context).colorScheme.surfaceContainerHighest
            ? Theme.of(context).colorScheme.onSurface
            : Colors.black87,
      ),
    ),
  );

  Color _statusColor(BuildContext context, HttpStatusGroup group) =>
      switch (group) {
        HttpStatusGroup.success => Colors.green.shade200,
        HttpStatusGroup.redirection => Colors.blue.shade200,
        HttpStatusGroup.clientError => Colors.orange.shade200,
        HttpStatusGroup.serverError => Colors.red.shade200,
        _ => Theme.of(context).colorScheme.surfaceContainerHighest,
      };

  Color _durationColor(BuildContext context, DurationLevel level) =>
      switch (level) {
        DurationLevel.fast => Colors.green.shade200,
        DurationLevel.normal => Colors.blue.shade200,
        DurationLevel.warn => Colors.orange.shade200,
        DurationLevel.slow => Colors.red.shade200,
        DurationLevel.unknown => Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest,
      };
}
