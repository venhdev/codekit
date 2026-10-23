@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Directory _resolveDir(String workspaceRelative, String packageRelative) {
  final fromRoot = Directory(workspaceRelative);
  if (fromRoot.existsSync()) return fromRoot;
  final fromPackage = Directory(packageRelative);
  if (fromPackage.existsSync()) return fromPackage;
  throw StateError('Could not locate $workspaceRelative');
}

Iterable<File> _dartFiles(Directory root) => root
    .listSync(recursive: true)
    .whereType<File>()
    .where((file) => file.path.endsWith('.dart'));

String _posixPath(String path) => path.replaceAll(r'\', '/');

void main() {
  group('CodeKit UI & Core Architectural Perimeter Guards', () {
    test('Boundary 1: forbids raw Colors.* and Color(...) literals outside sanctioned theme primitives', () {
      final uiLib = _resolveDir('packages/codekit_ui/lib', 'lib');
      final rawColorPattern = RegExp(r'\bColors\.|\bColor\s*\(');
      final violations = <String>[];

      for (final file in _dartFiles(uiLib)) {
        final path = _posixPath(file.path);
        if (path.endsWith('src/shared/codekit_tag.dart') ||
            path.endsWith('src/shared/codekit_bottom_sheet.dart')) {
          continue;
        }
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          if (rawColorPattern.hasMatch(lines[i])) {
            violations.add('$path:${i + 1}: ${lines[i].trim()}');
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason:
            'Feature widgets must use CodeKitTagTheme.of(context) or '
            'Theme.of(context).colorScheme instead of hardcoded Colors/Color.',
      );
    });

    test('Boundary 2: forbids raw showModalBottomSheet and showDialog outside codekit_bottom_sheet.dart', () {
      final uiLib = _resolveDir('packages/codekit_ui/lib', 'lib');
      final rawModalPattern = RegExp(
        r'\bshowModalBottomSheet\b|\bshowDialog\b',
      );
      final violations = <String>[];

      for (final file in _dartFiles(uiLib)) {
        final path = _posixPath(file.path);
        if (path.endsWith('src/shared/codekit_bottom_sheet.dart')) {
          continue;
        }
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          if (rawModalPattern.hasMatch(lines[i])) {
            violations.add('$path:${i + 1}: ${lines[i].trim()}');
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason:
            'All sheets and dialogs must use showCodeKitBottomSheet or '
            'showCodeKitDialog so CodeKitViewerTheme is preserved.',
      );
    });

    test('Boundary 3: forbids full-bleed Divider in records list subsystem', () {
      final recordsDir = _resolveDir(
        'packages/codekit_ui/lib/src/records',
        'lib/src/records',
      );
      final dividerPattern = RegExp(r'\bDivider\s*\(');
      final violations = <String>[];

      for (final file in _dartFiles(recordsDir)) {
        final path = _posixPath(file.path);
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          if (dividerPattern.hasMatch(lines[i])) {
            violations.add('$path:${i + 1}: ${lines[i].trim()}');
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason:
            'Records list must use Contained Rows without full-bleed Dividers '
            'to prevent border/divider collisions in multi-select mode.',
      );
    });

    test('Boundary 4: forbids Flutter, dart:ui, or dart:io imports in codekit_core', () {
      final coreLib = _resolveDir(
        'packages/codekit_core/lib',
        '../codekit_core/lib',
      );
      final bannedImportPattern = RegExp(
        r'''import\s+['"](package:flutter/|dart:ui|dart:io)''',
      );
      final violations = <String>[];

      for (final file in _dartFiles(coreLib)) {
        final path = _posixPath(file.path);
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          if (bannedImportPattern.hasMatch(lines[i])) {
            violations.add('$path:${i + 1}: ${lines[i].trim()}');
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'codekit_core must remain platform-neutral.',
      );
    });

    test(
      'Boundary 5: enforces single-sourced DiagnosticCursorCodec across stores',
      () {
        final driftLib = _resolveDir(
          'packages/codekit_drift_diagnostic_store/lib',
          '../codekit_drift_diagnostic_store/lib',
        );
        final rawBase64CursorPattern = RegExp(
          r'\bbase64Url\.(encode|decode)\b',
        );
        final violations = <String>[];

        for (final file in _dartFiles(driftLib)) {
          final path = _posixPath(file.path);
          final lines = file.readAsLinesSync();
          for (var i = 0; i < lines.length; i++) {
            if (rawBase64CursorPattern.hasMatch(lines[i])) {
              violations.add('$path:${i + 1}: ${lines[i].trim()}');
            }
          }
        }

        expect(
          violations,
          isEmpty,
          reason:
              'DriftDiagnosticStore must delegate cursor encoding/decoding to '
              'DiagnosticCursorCodec in codekit_core.',
        );
      },
    );

    test('Boundary 6: enforces single-sourced formatHttpCurl across diagnostics and webhook sinks', () {
      final coreLib = _resolveDir(
        'packages/codekit_core/lib',
        '../codekit_core/lib',
      );
      final webhookLib = _resolveDir(
        'packages/codekit_webhook/lib',
        '../codekit_webhook/lib',
      );
      final rawCurlFlagPattern = RegExp(r'''['"]--data-raw['"]''');
      final violations = <String>[];

      for (final file in [..._dartFiles(coreLib), ..._dartFiles(webhookLib)]) {
        final path = _posixPath(file.path);
        if (path.endsWith('src/recorder/http_curl_formatter.dart')) {
          continue;
        }
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          if (rawCurlFlagPattern.hasMatch(lines[i])) {
            violations.add('$path:${i + 1}: ${lines[i].trim()}');
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason:
            'cURL flag and shell-quoting construction must be single-sourced '
            'in http_curl_formatter.dart.',
      );
    });
  });
}
