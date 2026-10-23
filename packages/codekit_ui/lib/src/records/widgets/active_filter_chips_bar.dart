import 'package:codekit_core/codekit_core.dart';
import 'package:flutter/material.dart';

import '../records_controller.dart';

/// Horizontal scrollable bar displaying active filter chips with deletion actions.
class ActiveFilterChipsBar extends StatelessWidget {
  const ActiveFilterChipsBar({super.key, required this.controller});

  final RecordsController controller;

  @override
  Widget build(BuildContext context) {
    if (!controller.hasActiveFilters) return const SizedBox.shrink();

    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        children: [
          for (final group in controller.statusGroups)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: InputChip(
                label: Text(group.label),
                onDeleted: () {
                  final next = Set<HttpStatusGroup>.of(controller.statusGroups)
                    ..remove(group);
                  controller.applyFilters(
                    statuses: next,
                    durations: controller.durationLevels,
                    recordTypes: controller.types,
                    from: controller.from,
                    to: controller.to,
                  );
                },
                visualDensity: VisualDensity.compact,
              ),
            ),
          for (final level in controller.durationLevels)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: InputChip(
                label: Text(level.label),
                onDeleted: () {
                  final next = Set<DurationLevel>.of(controller.durationLevels)
                    ..remove(level);
                  controller.applyFilters(
                    statuses: controller.statusGroups,
                    durations: next,
                    recordTypes: controller.types,
                    from: controller.from,
                    to: controller.to,
                  );
                },
                visualDensity: VisualDensity.compact,
              ),
            ),
          for (final type in controller.types)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: InputChip(
                label: Text(type.label),
                onDeleted: () {
                  final next = Set<DiagnosticRecordType>.of(controller.types)
                    ..remove(type);
                  final nextMethods =
                      next.length == 1 &&
                          next.contains(DiagnosticRecordType.log)
                      ? const <String>{}
                      : controller.methods;
                  controller.applyFilters(
                    statuses: controller.statusGroups,
                    durations: controller.durationLevels,
                    recordTypes: next,
                    methods: nextMethods,
                    from: controller.from,
                    to: controller.to,
                  );
                },
                visualDensity: VisualDensity.compact,
              ),
            ),
          for (final method in controller.methods)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: InputChip(
                label: Text(method),
                onDeleted: () {
                  final next = Set<String>.of(controller.methods)
                    ..remove(method);
                  controller.applyFilters(
                    statuses: controller.statusGroups,
                    durations: controller.durationLevels,
                    recordTypes: controller.types,
                    methods: next,
                    from: controller.from,
                    to: controller.to,
                  );
                },
                visualDensity: VisualDensity.compact,
              ),
            ),
          if (controller.from != null)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: InputChip(
                label: Text(
                  'From: ${controller.from!.toLocal().toString().split('.').first}',
                ),
                onDeleted: () => controller.applyFilters(
                  statuses: controller.statusGroups,
                  durations: controller.durationLevels,
                  recordTypes: controller.types,
                  from: null,
                  to: controller.to,
                ),
                visualDensity: VisualDensity.compact,
              ),
            ),
          if (controller.to != null)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: InputChip(
                label: Text(
                  'To: ${controller.to!.toLocal().toString().split('.').first}',
                ),
                onDeleted: () => controller.applyFilters(
                  statuses: controller.statusGroups,
                  durations: controller.durationLevels,
                  recordTypes: controller.types,
                  from: controller.from,
                  to: null,
                ),
                visualDensity: VisualDensity.compact,
              ),
            ),
        ],
      ),
    );
  }
}
