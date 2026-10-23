import 'dart:convert';

import 'package:codekit_core/codekit_core.dart';
import 'package:flutter/material.dart';

import 'json_tree_view.dart';

/// Checks if [body] has displayable and copyable content.
bool hasCopyableBody(BodySnapshot? body) {
  if (body == null || body.state != BodyCaptureState.captured) return false;
  final data = body.data;
  if (data == null) return false;
  if (data is String) return data.isNotEmpty;
  if (data is Iterable) return data.isNotEmpty;
  if (data is Map) return data.isNotEmpty;
  return true;
}

/// Inspects captured text, JSON and media metadata without reading file bytes.
class BodyInspector extends StatefulWidget {
  const BodyInspector({super.key, required this.body});

  final BodySnapshot? body;

  @override
  State<BodyInspector> createState() => _BodyInspectorState();
}

class _BodyInspectorState extends State<BodyInspector> {
  String _mode = 'Pretty';
  String _search = '';
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final body = widget.body;
    if (body == null || body.state != BodyCaptureState.captured) {
      return Text(switch (body?.state) {
        BodyCaptureState.unsupported =>
          'Body unavailable: the client did not capture a supported body.',
        BodyCaptureState.disabled => 'Body capture was disabled.',
        BodyCaptureState.overflow =>
          'Body omitted: payload exceeded maxBodyCaptureBytes limit${(body?.data is Map && (body!.data as Map).containsKey('sizeBytes')) ? ' (${((body.data as Map)['sizeBytes'] as int) ~/ 1024} KB)' : ''}.',
        _ => 'No body captured.',
      });
    }
    final data = body.data;
    final raw = data is String ? data : jsonEncode(data);
    final pretty = data is String
        ? data
        : const JsonEncoder.withIndent('  ').convert(data);
    final isJson = body.representation == BodyRepresentation.json;
    final isMedia = body.representation == BodyRepresentation.media;
    final visible = _mode == 'Raw' ? raw : pretty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isMedia)
          const Text('Media metadata only; file contents were not captured.'),
        if (isJson)
          Wrap(
            spacing: 8,
            children: [
              for (final mode in ['Tree', 'Pretty', 'Raw'])
                ChoiceChip(
                  label: Text(mode),
                  selected: _mode == mode,
                  onSelected: (_) => setState(() => _mode = mode),
                ),
              if (_mode == 'Tree')
                TextButton(
                  onPressed: () => setState(() => _expanded = !_expanded),
                  child: Text(_expanded ? 'Collapse' : 'Expand'),
                ),
            ],
          ),
        TextField(
          decoration: const InputDecoration(labelText: 'Search body'),
          onChanged: (value) => setState(() => _search = value),
        ),
        if (_search.isNotEmpty)
          Text(
            visible.toLowerCase().contains(_search.toLowerCase())
                ? 'Match found'
                : 'No match',
          ),
        if (_mode == 'Tree' && isJson)
          JsonTreeView(value: data, expanded: _expanded)
        else ...[
          if (visible.length > 100 * 1024)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                'Showing 100 KB preview of ${(visible.length / 1024).toStringAsFixed(1)} KB. Use "Copy body" to get complete content.',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: Theme.of(context).colorScheme.primary),
              ),
            ),
          SelectableText(
            visible.length > 100 * 1024
                ? visible.substring(0, 100 * 1024)
                : visible,
          ),
        ],
      ],
    );
  }
}
