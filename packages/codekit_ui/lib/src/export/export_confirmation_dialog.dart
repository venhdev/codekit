import 'package:codekit_core/codekit_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../platform/export_delivery.dart';

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
    } catch (_) {
      if (mounted) {
        setState(() => error = share ? 'Share unavailable' : 'Copy failed');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Confirm export'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.selectedCount != null)
          Text('${widget.selectedCount} records selected'),
        RadioGroup<ExportRepresentation>(
          groupValue: representation,
          onChanged: busy
              ? (_) {}
              : (value) {
                  if (value != null) setState(() => representation = value);
                },
          child: const Column(
            children: [
              RadioListTile<ExportRepresentation>(
                title: Text('Redacted'),
                value: ExportRepresentation.redacted,
              ),
              RadioListTile<ExportRepresentation>(
                title: Text('As stored'),
                value: ExportRepresentation.asStored,
              ),
            ],
          ),
        ),
        if (error != null)
          Text(
            error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      TextButton(
        onPressed: busy ? null : () => _run(share: false),
        child: const Text('COPY'),
      ),
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
            onPressed: busy ? null : () => _run(share: true),
            child: const Text('SHARE'),
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
    ],
  );
}
