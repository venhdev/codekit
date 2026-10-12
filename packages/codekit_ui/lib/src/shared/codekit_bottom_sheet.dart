import 'package:flutter/material.dart';

/// Standard container for CodeKit modal sheets.
///
/// Callers supply the scrollable content and any persistent actions. The
/// container owns modal presentation, sizing, dismissal affordances and
/// scrolling so every sheet behaves consistently.
Future<T?> showCodeKitBottomSheet<T>(
  BuildContext context, {
  required Widget body,
  List<Widget> actions = const [],
}) => showModalBottomSheet<T>(
  context: context,
  isScrollControlled: true,
  enableDrag: true,
  showDragHandle: true,
  builder: (context) => CodeKitBottomSheet(body: body, actions: actions),
);

class CodeKitBottomSheet extends StatelessWidget {
  const CodeKitBottomSheet({
    super.key,
    required this.body,
    this.actions = const [],
  });

  final Widget body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: MediaQuery.sizeOf(context).height * .55,
    child: SafeArea(
      top: false,
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              tooltip: 'Close sheet',
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: body,
            ),
          ),
          if (actions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: actions,
              ),
            ),
        ],
      ),
    ),
  );
}
