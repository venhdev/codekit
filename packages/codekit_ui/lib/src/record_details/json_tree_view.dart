import 'dart:convert';

import 'package:flutter/material.dart';

/// Recursive interactive collapsible tree viewer for structured JSON objects.
class JsonTreeView extends StatefulWidget {
  const JsonTreeView({
    super.key,
    required this.value,
    required this.expanded,
    this.label,
  });

  final Object? value;
  final bool expanded;
  final String? label;

  @override
  State<JsonTreeView> createState() => _JsonTreeViewState();
}

class _JsonTreeViewState extends State<JsonTreeView> {
  late bool _open = widget.expanded;

  @override
  void didUpdateWidget(covariant JsonTreeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expanded != widget.expanded) _open = widget.expanded;
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.value;
    if (value is! Map && value is! List) {
      return Align(
        alignment: Alignment.centerLeft,
        child: SelectableText(
          '${widget.label ?? 'Value'}: ${jsonEncode(value)}',
        ),
      );
    }
    final length = value is Map ? value.length : (value as List).length;
    return ExpansionTile(
      key: ValueKey((widget.label, widget.expanded)),
      title: Text('${widget.label ?? 'Root'} ($length)'),
      initiallyExpanded: _open,
      onExpansionChanged: (open) => setState(() => _open = open),
      children: _open
          ? [
              if (value is Map)
                for (final entry in value.entries)
                  JsonTreeView(
                    key: ValueKey(entry.key),
                    label: entry.key.toString(),
                    value: entry.value,
                    expanded: widget.expanded,
                  ),
              if (value is List)
                for (var i = 0; i < value.length; i++)
                  JsonTreeView(
                    key: ValueKey(i),
                    label: '[$i]',
                    value: value[i],
                    expanded: widget.expanded,
                  ),
            ]
          : const [],
    );
  }
}
