import 'package:flutter/material.dart';

import '../settings/codekit_viewer_theme.dart';

/// Standard container for CodeKit modal sheets.
///
/// Callers supply the scrollable content and any persistent actions. The
/// container owns modal presentation, sizing, dismissal affordances and
/// scrolling so every sheet behaves consistently.
Future<T?> showCodeKitBottomSheet<T>(
  BuildContext context, {
  Widget? body,
  List<Widget> actions = const [],
  Widget? sheet,
}) {
  assert(body != null || sheet != null);
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    enableDrag: true,
    showDragHandle: false,
    backgroundColor: Colors.transparent,
    builder: (_) => CodeKitViewerTheme.wrap(
      context,
      sheet ?? CodeKitBottomSheet(body: body!, actions: actions),
    ),
  );
}

/// Standard dialog launcher that preserves the active [CodeKitViewerTheme].
Future<T?> showCodeKitDialog<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) => showDialog<T>(
  context: context,
  builder: (dialogContext) =>
      CodeKitViewerTheme.wrap(context, Builder(builder: builder)),
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
    child: Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      shape:
          Theme.of(context).bottomSheetTheme.shape ??
          const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Center(
                child: Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: body,
              ),
            ),
            if (actions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: actions,
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
