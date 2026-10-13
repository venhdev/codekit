import 'package:codekit_core/codekit_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../platform/export_delivery.dart';
import '../shared/guarded_action.dart';

/// Confirms the representation at the point where data leaves CodeKit.
Future<void> showExportConfirmation(
  BuildContext context, {
  required Future<ExportResult> Function(ExportRepresentation) export,
  int? selectedCount,
}) => showDialog<void>(
  context: context,
  builder: (context) =>
      _ExportConfirmation(export: export, selectedCount: selectedCount),
);

class _ExportConfirmation extends StatefulWidget {
  const _ExportConfirmation({required this.export, this.selectedCount});
  final Future<ExportResult> Function(ExportRepresentation) export;
  final int? selectedCount;

  @override
  State<_ExportConfirmation> createState() => _ExportConfirmationState();
}

class _ExportConfirmationState extends State<_ExportConfirmation> {
  ExportRepresentation representation = ExportRepresentation.redacted;
  bool asFile = false;
  bool busy = false;
  String? error;

  Future<void> _run({required bool share}) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await guardAction(
        () async {
          final result = await widget.export(representation);
          if (result.status != ExportStatus.success || result.text == null) {
            if (mounted) {
              setState(
                () => error = result.status == ExportStatus.empty
                    ? 'No records available'
                    : result.error ?? 'Export failed',
              );
            }
            return;
          }
          if (share) {
            final bool delivered;
            if (asFile) {
              delivered = await shareDiagnosticFile(result.text!);
            } else {
              delivered = await shareDiagnosticText(result.text!);
            }
            if (!delivered) return;
          } else {
            await Clipboard.setData(ClipboardData(text: result.text!));
          }
          if (mounted) {
            final messenger = ScaffoldMessenger.of(context);
            Navigator.of(context).pop();
            messenger.showSnackBar(
              SnackBar(
                content: Text(share ? 'Shared diagnostics' : 'Copied diagnostics'),
              ),
            );
          }
        },
        onError: (e, st) {
          if (mounted) {
            setState(() => error = share ? 'Share unavailable' : 'Copy failed');
          }
        },
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Confirm export'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.selectedCount != null)
            Text('${widget.selectedCount} records selected'),
          RadioGroup<ExportRepresentation>(
            groupValue: representation,
            onChanged: busy
                ? (_) {}
                : (value) {
                    if (value != null) {
                      setState(() => representation = value);
                    }
                  },
            child: const Column(
              children: [
                RadioListTile<ExportRepresentation>(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Redacted'),
                  value: ExportRepresentation.redacted,
                ),
                RadioListTile<ExportRepresentation>(
                  contentPadding: EdgeInsets.zero,
                  title: Text('As stored'),
                  value: ExportRepresentation.asStored,
                ),
              ],
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(error!, style: TextStyle(color: colors.error)),
          ],
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: busy ? null : () => _run(share: false),
            style: OutlinedButton.styleFrom(
              backgroundColor: colors.secondaryContainer,
              foregroundColor: colors.onSecondaryContainer,
            ),
            icon: const Icon(Icons.copy_outlined),
            label: const Text('COPY'),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: busy ? null : () => _run(share: true),
            icon: const Icon(Icons.share_outlined),
            label: const Text('SHARE'),
          ),
          CheckboxListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text('Share as file (.txt)'),
            value: asFile,
            onChanged: busy
                ? null
                : (value) => setState(() => asFile = value ?? false),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
