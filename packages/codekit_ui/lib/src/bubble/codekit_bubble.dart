import 'dart:async';

import 'package:codekit_core/codekit_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../records/codekit_diagnostics_screen.dart';
import '../search_history/search_history_store.dart';
import '../settings/codekit_viewer_settings.dart';
import '../settings/codekit_viewer_theme.dart';
import 'bubble_trigger_mode.dart';

/// Place in MaterialApp.builder with the same navigatorKey as MaterialApp.
class CodeKitBubble extends StatefulWidget {
  const CodeKitBubble({
    super.key,
    required this.child,
    required this.navigatorKey,
    required this.diagnostics,
    this.enabled = !kReleaseMode,
    this.triggerMode = BubbleTriggerMode.shakeToToggle,
    this.shakeStream,
    this.idleTimeout = const Duration(seconds: 3),
    this.idleOpacity = 0.25,
    this.viewerSettings = const CodeKitViewerSettings(),
  });

  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;
  final CodeKitDiagnostics diagnostics;

  /// Whether the diagnostic bubble is active and rendered on the screen.
  ///
  /// Defaults to `!kReleaseMode` (visible in Debug and Profile builds, hidden in
  /// Release builds). Callers can provide custom conditions (e.g. `kDebugMode`
  /// or role-based flags) or pass `false` to disable the bubble entirely in
  /// favor of direct screen navigation / secret gestures.
  final bool enabled;

  /// Defines how the diagnostic bubble reveals itself when [enabled] is true.
  final BubbleTriggerMode triggerMode;

  /// Optional stream emitting events when device shake is detected.
  final Stream<void>? shakeStream;

  /// Duration of user inactivity before the bubble dims to [idleOpacity].
  final Duration idleTimeout;

  /// Target opacity when the bubble has been idle for [idleTimeout].
  final double idleOpacity;

  final CodeKitViewerSettings viewerSettings;

  @override
  State<CodeKitBubble> createState() => _CodeKitBubbleState();
}

class _CodeKitBubbleState extends State<CodeKitBubble> {
  final SearchHistoryStore _history = SearchHistoryStore();
  late final ValueNotifier<ThemeMode> _theme = ValueNotifier(
    widget.viewerSettings.initialThemeMode,
  );
  late DevProxyConfig _sessionProxy =
      widget.viewerSettings.currentDevProxyConfig;

  Offset _inset = const Offset(16, 24);
  bool _open = false;
  late bool _revealed = !widget.triggerMode.startsHidden;
  bool _isIdle = false;
  bool _isDocked = false;
  AxisDirection _dockSide = AxisDirection.right;

  Timer? _idleTimer;
  StreamSubscription<void>? _shakeSubscription;

  @override
  void initState() {
    super.initState();
    _setupActivationListeners();
    if (widget.enabled && _revealed) {
      _resetIdleTimer();
    }
  }

  @override
  void didUpdateWidget(covariant CodeKitBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled ||
        oldWidget.triggerMode != widget.triggerMode ||
        oldWidget.shakeStream != widget.shakeStream) {
      _cleanupActivationListeners();
      _setupActivationListeners();
      if (widget.enabled) {
        if (oldWidget.triggerMode != widget.triggerMode) {
          _revealed = !widget.triggerMode.startsHidden;
        }
        if (_revealed) {
          _resetIdleTimer();
        }
      } else {
        _idleTimer?.cancel();
      }
    }
  }

  void _setupActivationListeners() {
    if (!widget.enabled) return;
    if (widget.shakeStream != null) {
      _shakeSubscription = widget.shakeStream!.listen((_) => _toggleRevealed());
    }
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  void _cleanupActivationListeners() {
    _shakeSubscription?.cancel();
    _shakeSubscription = null;
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (!widget.enabled || _open) return false;
    if (event is KeyDownEvent) {
      final isCtrlOrCmd =
          HardwareKeyboard.instance.isControlPressed ||
          HardwareKeyboard.instance.isMetaPressed;
      final isShift = HardwareKeyboard.instance.isShiftPressed;
      final isD = event.logicalKey == LogicalKeyboardKey.keyD;
      final isF12 = event.logicalKey == LogicalKeyboardKey.f12;
      if ((isCtrlOrCmd && isShift && isD) || isF12) {
        _toggleRevealed();
        return true;
      }
    }
    return false;
  }

  void _toggleRevealed() {
    if (!mounted || !widget.enabled) return;
    setState(() {
      _revealed = !_revealed;
      if (_revealed) {
        _resetIdleTimer();
      } else {
        _idleTimer?.cancel();
      }
    });
  }

  void _resetIdleTimer() {
    _idleTimer?.cancel();
    if (_isIdle) {
      setState(() => _isIdle = false);
    }
    if (widget.idleTimeout > Duration.zero) {
      _idleTimer = Timer(widget.idleTimeout, () {
        if (mounted && !_open) {
          setState(() => _isIdle = true);
        }
      });
    }
  }

  @override
  void dispose() {
    _cleanupActivationListeners();
    _idleTimer?.cancel();
    _history.dispose();
    _theme.dispose();
    super.dispose();
  }

  Future<void> _showViewer() async {
    final navigator = widget.navigatorKey.currentState;
    if (navigator == null || _open) return;
    _idleTimer?.cancel();
    setState(() => _open = true);
    try {
      await navigator.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => CodeKitViewerTheme(
            controller: _theme,
            child: CodeKitDiagnosticsScreen(
              diagnostics: widget.diagnostics,
              searchHistory: _history,
              viewerSettings: widget.viewerSettings.copyWith(
                devProxyProvider: () => _sessionProxy,
                onDevProxyConfigChanged: (updated) {
                  _sessionProxy = updated;
                  widget.viewerSettings.onDevProxyConfigChanged?.call(updated);
                },
              ),
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _open = false);
        _resetIdleTimer();
      }
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      const bubbleDiameter = 48.0;
      const dockWidth = 8.0;
      const dockHeight = 38.0;
      final currentWidth = _isDocked ? dockWidth : bubbleDiameter;
      final currentHeight = _isDocked ? dockHeight : bubbleDiameter;

      final maxX = (constraints.maxWidth - currentWidth).clamp(
        0.0,
        double.infinity,
      );
      final maxY = (constraints.maxHeight - currentHeight).clamp(
        0.0,
        double.infinity,
      );

      final double left;
      if (_isDocked) {
        left = _dockSide == AxisDirection.left ? 0.0 : maxX;
      } else {
        left = (constraints.maxWidth - _inset.dx - bubbleDiameter).clamp(
          0.0,
          maxX,
        );
      }
      final top = (constraints.maxHeight - _inset.dy - currentHeight).clamp(
        0.0,
        maxY,
      );

      final isVisible = widget.enabled && !_open && _revealed;

      return Stack(
        fit: StackFit.expand,
        children: [
          widget.child,
          if (isVisible)
            Positioned(
              left: left,
              top: top,
              child: AnimatedOpacity(
                opacity: _isIdle ? widget.idleOpacity.clamp(0.0, 1.0) : 1.0,
                duration: const Duration(milliseconds: 250),
                child: Listener(
                  onPointerDown: (_) => _resetIdleTimer(),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (_) => _resetIdleTimer(),
                    onPanStart: (_) => _resetIdleTimer(),
                    onPanUpdate: (details) {
                      setState(() {
                        _isDocked = false;
                        _inset = Offset(
                          (_inset.dx - details.delta.dx).clamp(0.0, maxX),
                          (_inset.dy - details.delta.dy).clamp(0.0, maxY),
                        );
                      });
                      _resetIdleTimer();
                    },
                    onPanEnd: (details) {
                      final currentLeft =
                          constraints.maxWidth - _inset.dx - bubbleDiameter;
                      const snapThreshold = 32.0;
                      if (currentLeft < snapThreshold) {
                        setState(() {
                          _isDocked = true;
                          _dockSide = AxisDirection.left;
                          _inset = Offset(
                            constraints.maxWidth - dockWidth,
                            _inset.dy,
                          );
                        });
                      } else if (constraints.maxWidth -
                              (currentLeft + bubbleDiameter) <
                          snapThreshold) {
                        setState(() {
                          _isDocked = true;
                          _dockSide = AxisDirection.right;
                          _inset = Offset(0.0, _inset.dy);
                        });
                      } else {
                        setState(() {
                          _isDocked = false;
                        });
                      }
                      _resetIdleTimer();
                    },
                    child: _buildBubbleContent(context),
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );

  Widget _buildBubbleContent(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_isDocked) {
      return Semantics(
        button: true,
        label: 'Expand CodeKit diagnostics bubble',
        child: GestureDetector(
          onTap: () {
            setState(() => _isDocked = false);
            _resetIdleTimer();
          },
          child: Container(
            key: const Key('codekit-bubble-docked-indicator'),
            width: 8.0,
            height: 38.0,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.85),
              borderRadius: _dockSide == AxisDirection.left
                  ? const BorderRadius.horizontal(right: Radius.circular(4))
                  : const BorderRadius.horizontal(left: Radius.circular(4)),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withValues(alpha: 0.25),
                  blurRadius: 4,
                  offset: Offset(_dockSide == AxisDirection.left ? 1 : -1, 1),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Semantics(
      button: true,
      label: 'Open CodeKit diagnostics',
      child: FloatingActionButton.small(
        heroTag: 'codekit-diagnostics-bubble',
        onPressed: () {
          _resetIdleTimer();
          _showViewer();
        },
        child: const Icon(Icons.bug_report_outlined),
      ),
    );
  }
}
