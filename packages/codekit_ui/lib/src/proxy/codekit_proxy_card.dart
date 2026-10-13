import 'package:codekit_core/codekit_core.dart';
import 'package:flutter/material.dart';

import 'codekit_proxy_dialog.dart';

/// Embeddable card widget to monitor, toggle, and edit developer HTTP proxy settings.
class CodeKitProxyCard extends StatelessWidget {
  final DevProxyConfig config;
  final ValueChanged<DevProxyConfig> onConfigChanged;
  final String title;
  final EdgeInsetsGeometry padding;

  const CodeKitProxyCard({
    super.key,
    required this.config,
    required this.onConfigChanged,
    this.title = 'Dev Proxy (Proxyman / Charles)',
    this.padding = const EdgeInsets.all(16),
  });

  String _subtitleText() {
    if (config.isEnabled && config.isValid) {
      return 'ON: PROXY ${config.sanitizedHost}:${config.port}';
    }
    if (config.isEnabled && !config.isValid) {
      return 'ON: Invalid host or port';
    }
    return 'OFF: DIRECT (No proxy)';
  }

  Color? _subtitleColor(BuildContext context) {
    if (config.isEnabled && config.isValid) {
      return Colors.green[700];
    }
    return Theme.of(context).colorScheme.onSurfaceVariant;
  }

  Future<void> _openEditDialog(BuildContext context) async {
    final updated = await showCodeKitProxyDialog(
      context,
      initialConfig: config,
    );
    if (updated != null) {
      onConfigChanged(updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const Key('codekit-proxy-card'),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              key: const Key('codekit-proxy-toggle'),
              contentPadding: EdgeInsets.zero,
              title: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                _subtitleText(),
                style: TextStyle(color: _subtitleColor(context), fontSize: 13),
              ),
              value: config.isEnabled,
              onChanged: (enabled) {
                if (enabled && !config.isValid) {
                  // If enabling with empty or invalid host, prompt for configuration
                  _openEditDialog(context);
                } else {
                  onConfigChanged(config.copyWith(isEnabled: enabled));
                }
              },
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                key: const Key('codekit-proxy-edit-btn'),
                icon: const Icon(Icons.settings, size: 16),
                label: const Text('Configure Host & Port'),
                onPressed: () => _openEditDialog(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
