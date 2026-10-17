import 'package:flutter/material.dart';

import '../shared/codekit_tag.dart';

/// Keeps the viewer's theme separate from the host application's theme.
class CodeKitViewerTheme extends StatefulWidget {
  const CodeKitViewerTheme({
    super.key,
    required this.child,
    this.controller,
    this.initialMode = ThemeMode.system,
  });

  final Widget child;
  final ValueNotifier<ThemeMode>? controller;
  final ThemeMode initialMode;

  static ValueNotifier<ThemeMode>? controllerOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ViewerThemeScope>()?.notifier;

  /// Routes and sheets share the originating viewer's theme state.
  static Widget wrap(BuildContext context, Widget child) {
    final controller = controllerOf(context);
    return controller == null
        ? child
        : CodeKitViewerTheme(controller: controller, child: child);
  }

  @override
  State<CodeKitViewerTheme> createState() => _CodeKitViewerThemeState();
}

class _CodeKitViewerThemeState extends State<CodeKitViewerTheme> {
  late final ValueNotifier<ThemeMode> _ownedController = ValueNotifier(
    widget.initialMode,
  );

  @override
  void dispose() {
    _ownedController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller ?? _ownedController;
    final seed = Theme.of(context).colorScheme.primary;
    final systemBrightness = MediaQuery.platformBrightnessOf(context);
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: controller,
      builder: (context, mode, child) {
        final brightness = switch (mode) {
          ThemeMode.system => systemBrightness,
          ThemeMode.light => Brightness.light,
          ThemeMode.dark => Brightness.dark,
        };
        return _ViewerThemeScope(
          notifier: controller,
          child: Theme(
            data: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: seed,
                brightness: brightness,
              ),
              extensions: [
                brightness == Brightness.dark
                    ? const CodeKitTagTheme.dark()
                    : const CodeKitTagTheme.light(),
              ],
            ),
            child: child!,
          ),
        );
      },
      child: widget.child,
    );
  }
}

class _ViewerThemeScope extends InheritedNotifier<ValueNotifier<ThemeMode>> {
  const _ViewerThemeScope({required super.notifier, required super.child});
}
