import 'package:codekit_core/codekit_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../records/codekit_diagnostics_screen.dart';
import '../search_history/search_history_store.dart';
import '../settings/codekit_viewer_settings.dart';
import '../settings/codekit_viewer_theme.dart';

/// Place in MaterialApp.builder with the same navigatorKey as MaterialApp.
class CodeKitBubble extends StatefulWidget {
  const CodeKitBubble({
    super.key,
    required this.child,
    required this.navigatorKey,
    required this.diagnostics,
    this.debugOnly = false,
    this.viewerSettings = const CodeKitViewerSettings(),
  });

  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;
  final CodeKitDiagnostics diagnostics;
  final bool debugOnly;
  final CodeKitViewerSettings viewerSettings;

  @override
  State<CodeKitBubble> createState() => _CodeKitBubbleState();
}

class _CodeKitBubbleState extends State<CodeKitBubble> {
  final SearchHistoryStore _history = SearchHistoryStore();
  late final ValueNotifier<ThemeMode> _theme = ValueNotifier(
    widget.viewerSettings.initialThemeMode,
  );
  Offset _inset = const Offset(16, 24);
  bool _open = false;

  @override
  void dispose() {
    _history.dispose();
    _theme.dispose();
    super.dispose();
  }

  Future<void> _showViewer() async {
    final navigator = widget.navigatorKey.currentState;
    if (navigator == null || _open) return;
    setState(() => _open = true);
    try {
      await navigator.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => CodeKitViewerTheme(
            controller: _theme,
            child: CodeKitDiagnosticsScreen(
              diagnostics: widget.diagnostics,
              searchHistory: _history,
              viewerSettings: widget.viewerSettings,
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _open = false);
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      const diameter = 48.0;
      final maxX = (constraints.maxWidth - diameter).clamp(
        0.0,
        double.infinity,
      );
      final maxY = (constraints.maxHeight - diameter).clamp(
        0.0,
        double.infinity,
      );
      final left = (constraints.maxWidth - _inset.dx - diameter).clamp(
        0.0,
        maxX,
      );
      final top = (constraints.maxHeight - _inset.dy - diameter).clamp(
        0.0,
        maxY,
      );
      return Stack(
        fit: StackFit.expand,
        children: [
          widget.child,
          if (!_open && (!widget.debugOnly || kDebugMode))
            Positioned(
              left: left,
              top: top,
              child: GestureDetector(
                onPanUpdate: (details) => setState(() {
                  _inset = Offset(
                    (_inset.dx - details.delta.dx).clamp(0.0, maxX),
                    (_inset.dy - details.delta.dy).clamp(0.0, maxY),
                  );
                }),
                child: Semantics(
                  button: true,
                  label: 'Open CodeKit diagnostics',
                  child: FloatingActionButton.small(
                    heroTag: 'codekit-diagnostics-bubble',
                    onPressed: _showViewer,
                    child: const Icon(Icons.bug_report_outlined),
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}
