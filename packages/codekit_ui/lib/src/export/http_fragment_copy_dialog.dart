import 'package:codekit_core/codekit_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../shared/codekit_bottom_sheet.dart';

Future<void> showHttpFragmentCopyDialog(
  BuildContext context, {
  required CodeKitDiagnostics diagnostics,
  required String recordId,
  required HttpFragment fragment,
  HeaderTarget target = HeaderTarget.both,
}) => showCodeKitDialog<void>(
  context,
  builder: (context) => _HttpFragmentCopyDialog(
    diagnostics: diagnostics,
    recordId: recordId,
    fragment: fragment,
    target: target,
  ),
);

class _HttpFragmentCopyDialog extends StatefulWidget {
  const _HttpFragmentCopyDialog({
    required this.diagnostics,
    required this.recordId,
    required this.fragment,
    required this.target,
  });
  final CodeKitDiagnostics diagnostics;
  final String recordId;
  final HttpFragment fragment;
  final HeaderTarget target;

  @override
  State<_HttpFragmentCopyDialog> createState() =>
      _HttpFragmentCopyDialogState();
}

class _HttpFragmentCopyDialogState extends State<_HttpFragmentCopyDialog> {
  ExportRepresentation representation = ExportRepresentation.redacted;
  String? error;
  bool busy = false;

  Future<void> _copy() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await widget.diagnostics.formatHttpFragment(
        widget.recordId,
        widget.fragment,
        target: widget.target,
        representation: representation,
      );
      if (result.status != ExportStatus.success || result.text == null) {
        if (mounted) {
          setState(() => error = result.error ?? 'No data available');
        }
        return;
      }
      await Clipboard.setData(ClipboardData(text: result.text!));
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() => error = 'Copy failed');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Copy ${widget.fragment.name}'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
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
        onPressed: busy ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      TextButton(onPressed: busy ? null : _copy, child: const Text('Copy')),
    ],
  );
}
