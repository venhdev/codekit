import 'package:codekit_core/codekit_core.dart';
import 'package:flutter/material.dart';

import 'records_controller.dart';

class FiltersSheet extends StatefulWidget {
  const FiltersSheet({super.key, required this.controller});
  final RecordsController controller;

  @override
  State<FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends State<FiltersSheet> {
  late Set<HttpStatusGroup> statuses;
  late Set<DurationLevel> durations;
  late Set<DiagnosticRecordType> types;
  DateTime? from;
  DateTime? to;

  @override
  void initState() {
    super.initState();
    statuses = Set.of(widget.controller.statusGroups);
    durations = Set.of(widget.controller.durationLevels);
    types = Set.of(widget.controller.types);
    from = widget.controller.from;
    to = widget.controller.to;
  }

  void _toggle<T>(Set<T> target, T value) => setState(() {
    if (!target.add(value)) target.remove(value);
  });

  Future<DateTime?> _pickDateTime(DateTime? initial) async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDate: initial ?? DateTime.now(),
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: initial == null
          ? TimeOfDay.now()
          : TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          Row(
            children: [
              Text('Filters', style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              TextButton(
                onPressed: () async {
                  if (from != null && to != null && from!.isAfter(to!)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('From must be before To')),
                    );
                    return;
                  }
                  await widget.controller.applyFilters(
                    statuses: statuses,
                    durations: durations,
                    recordTypes: types,
                    from: from,
                    to: to,
                  );
                  if (context.mounted) Navigator.of(context).pop();
                },
                child: const Text('Done'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('Status', style: Theme.of(context).textTheme.titleMedium),
          Wrap(
            spacing: 8,
            children: [
              for (final (group, label) in <(HttpStatusGroup, String)>[
                (HttpStatusGroup.informational, '1xx'),
                (HttpStatusGroup.success, '2xx'),
                (HttpStatusGroup.redirection, '3xx'),
                (HttpStatusGroup.clientError, '4xx'),
                (HttpStatusGroup.serverError, '5xx'),
                (HttpStatusGroup.unknown, 'Unknown'),
              ])
                FilterChip(
                  label: Text(label),
                  selected: statuses.contains(group),
                  onSelected: (_) => _toggle(statuses, group),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text('Time range', style: Theme.of(context).textTheme.titleMedium),
          ListTile(
            title: Text(from == null ? 'From' : 'From ${from!.toLocal()}'),
            onTap: () async {
              final chosen = await _pickDateTime(from);
              if (chosen != null && mounted) setState(() => from = chosen);
            },
            trailing: from == null
                ? null
                : IconButton(
                    tooltip: 'Clear From',
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(() => from = null),
                  ),
          ),
          ListTile(
            title: Text(to == null ? 'To' : 'To ${to!.toLocal()}'),
            onTap: () async {
              final chosen = await _pickDateTime(to);
              if (chosen != null && mounted) setState(() => to = chosen);
            },
            trailing: to == null
                ? null
                : IconButton(
                    tooltip: 'Clear To',
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(() => to = null),
                  ),
          ),
          const SizedBox(height: 12),
          Text('Duration', style: Theme.of(context).textTheme.titleMedium),
          Wrap(
            spacing: 8,
            children: [
              for (final (level, label) in <(DurationLevel, String)>[
                (DurationLevel.fast, 'Fast'),
                (DurationLevel.normal, 'Normal'),
                (DurationLevel.warn, 'Warn'),
                (DurationLevel.slow, 'Slow'),
                (DurationLevel.unknown, 'None'),
              ])
                FilterChip(
                  label: Text(label),
                  selected: durations.contains(level),
                  onSelected: (_) => _toggle(durations, level),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text('Record type', style: Theme.of(context).textTheme.titleMedium),
          Wrap(
            spacing: 8,
            children: [
              for (final (type, label) in <(DiagnosticRecordType, String)>[
                (DiagnosticRecordType.log, 'App log'),
                (DiagnosticRecordType.http, 'HTTP record'),
              ])
                FilterChip(
                  label: Text(label),
                  selected: types.contains(type),
                  onSelected: (_) => _toggle(types, type),
                ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => setState(() {
                statuses.clear();
                durations.clear();
                types.clear();
                from = null;
                to = null;
              }),
              child: const Text('Reset'),
            ),
          ),
        ],
      ),
    ),
  );
}
