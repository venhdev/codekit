import 'package:codekit_core/codekit_core.dart';
import 'package:flutter/material.dart';

/// Preset proxy port definitions.
const List<({int port, String label})> _proxyPortPresets = [
  (port: 9090, label: '9090 (Proxyman)'),
  (port: 8888, label: '8888 (Charles)'),
  (port: 8080, label: '8080 (Mitmproxy)'),
];

/// Displays a modal dialog to edit the host and port for [DevProxyConfig].
Future<DevProxyConfig?> showCodeKitProxyDialog(
  BuildContext context, {
  required DevProxyConfig initialConfig,
}) => showDialog<DevProxyConfig>(
  context: context,
  builder: (context) => CodeKitProxyDialog(initialConfig: initialConfig),
);

class CodeKitProxyDialog extends StatefulWidget {
  final DevProxyConfig initialConfig;

  const CodeKitProxyDialog({super.key, required this.initialConfig});

  @override
  State<CodeKitProxyDialog> createState() => _CodeKitProxyDialogState();
}

class _CodeKitProxyDialogState extends State<CodeKitProxyDialog> {
  late final TextEditingController _hostController;
  late final TextEditingController _portController;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _hostController = TextEditingController(text: widget.initialConfig.host);
    _portController = TextEditingController(
      text: widget.initialConfig.port > 0
          ? widget.initialConfig.port.toString()
          : '9090',
    );
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  void _onSave() {
    final rawHost = _hostController.text.trim();
    final rawPort = int.tryParse(_portController.text.trim()) ?? 0;

    final updated = DevProxyConfig(
      isEnabled: true,
      host: rawHost,
      port: rawPort,
    );

    if (!updated.isValid) {
      setState(() {
        _errorMessage = 'Please enter a valid host IP and port (1–65535).';
      });
      return;
    }

    Navigator.of(context).pop(updated);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Configure Dev Proxy'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Route app HTTP traffic through a debugging proxy running on your LAN computer.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('codekit-proxy-host-input'),
              controller: _hostController,
              decoration: const InputDecoration(
                labelText: 'Proxy Host / LAN IP',
                hintText: 'e.g. 192.168.1.50',
                border: OutlineInputBorder(),
              ),
              autocorrect: false,
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('codekit-proxy-port-input'),
              controller: _portController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Port',
                hintText: '9090',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Presets:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                for (final preset in _proxyPortPresets)
                  ActionChip(
                    key: Key('codekit-preset-${preset.port}'),
                    label: Text(preset.label),
                    onPressed: () {
                      _portController.text = preset.port.toString();
                    },
                  ),
              ],
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red, fontSize: 13),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('codekit-proxy-cancel-btn'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('codekit-proxy-save-btn'),
          onPressed: _onSave,
          child: const Text('Save & Enable'),
        ),
      ],
    );
  }
}
