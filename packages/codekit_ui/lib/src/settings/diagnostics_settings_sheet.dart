import 'package:codekit_core/codekit_core.dart';
import 'package:flutter/material.dart';

import '../shared/codekit_bottom_sheet.dart';
import 'codekit_viewer_settings.dart';
import 'codekit_viewer_theme.dart';

Future<void> showDiagnosticsSettingsSheet(
  BuildContext context, {
  required CodeKitDiagnostics diagnostics,
  required CodeKitViewerSettings settings,
}) => showCodeKitBottomSheet<void>(
  context,
  body: _DiagnosticsSettingsSheet(diagnostics: diagnostics, settings: settings),
);

class _DiagnosticsSettingsSheet extends StatefulWidget {
  const _DiagnosticsSettingsSheet({
    required this.diagnostics,
    required this.settings,
  });

  final CodeKitDiagnostics diagnostics;
  final CodeKitViewerSettings settings;

  @override
  State<_DiagnosticsSettingsSheet> createState() =>
      _DiagnosticsSettingsSheetState();
}

class _DiagnosticsSettingsSheetState extends State<_DiagnosticsSettingsSheet> {
  @override
  Widget build(BuildContext context) {
    final policy = widget.diagnostics.redactionPolicy;
    final theme = CodeKitViewerTheme.controllerOf(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('CodeKit settings', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        Text('Theme', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        SegmentedButton<ThemeMode>(
          segments: const [
            ButtonSegment(value: ThemeMode.system, label: Text('System')),
            ButtonSegment(value: ThemeMode.light, label: Text('Light')),
            ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
          ],
          selected: {theme.value},
          onSelectionChanged: (selection) => theme.value = selection.single,
        ),
        const SizedBox(height: 16),
        Text('Recording mode', style: Theme.of(context).textTheme.titleMedium),
        if (widget.settings.allowRuntimeRecordModeChanges)
          RadioGroup<RecordMode>(
            groupValue: widget.diagnostics.recordMode,
            onChanged: (mode) {
              if (mode == null) return;
              setState(() => widget.diagnostics.recordMode = mode);
            },
            child: const Column(
              children: [
                RadioListTile<RecordMode>(
                  value: RecordMode.storeRaw,
                  title: Text('Store raw'),
                ),
                RadioListTile<RecordMode>(
                  value: RecordMode.redactBeforeRecording,
                  title: Text('Redact before recording'),
                ),
              ],
            ),
          )
        else
          Text(_recordModeLabel(widget.diagnostics.recordMode)),
        const Text('Applies to records accepted after this change.'),
        const SizedBox(height: 16),
        if (widget.settings.setupDetails.isNotEmpty) ...[
          Text('Active setup', style: Theme.of(context).textTheme.titleMedium),
          for (final detail in widget.settings.setupDetails)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(detail.label),
              subtitle: Text(detail.description ?? detail.value),
              trailing: Text(detail.value),
            ),
          const SizedBox(height: 16),
        ],
        Text(
          'Redaction policy',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Text(
          'Authorization: ${_enabled(policy.authorization)} · '
          'Cookie: ${_enabled(policy.cookie)} · '
          'Set-Cookie: ${_enabled(policy.setCookie)}',
        ),
        if (policy.rules == null || policy.rules!.isEmpty)
          const Text('No additional rules')
        else
          for (final rule in policy.rules!) Text(_describeRule(rule)),
      ],
    );
  }
}

String _recordModeLabel(RecordMode mode) => switch (mode) {
  RecordMode.storeRaw => 'Store raw',
  RecordMode.redactBeforeRecording => 'Redact before recording',
};

String _enabled(bool value) => value ? 'on' : 'off';

String _describeRule(RedactionRule rule) => switch (rule) {
  HeaderRedactionRule() => 'Headers: ${rule.names.join(', ')}',
  QueryRedactionRule() => 'Query parameters: ${rule.names.join(', ')}',
  BodyFieldRedactionRule() => 'Body fields: ${rule.paths.join(', ')}',
  TextRedactionRule() => 'Text pattern: ${rule.pattern.pattern}',
};
