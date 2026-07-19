import 'package:flutter/material.dart';

class AiHubCredentialsChange {
  const AiHubCredentialsChange.save(this.apiToken) : clear = false;

  const AiHubCredentialsChange.remove() : apiToken = null, clear = true;

  final String? apiToken;
  final bool clear;
}

/// Owns its text controller so dismissal cannot dispose it while TextField is
/// still being removed from the dialog route.
class AiHubCredentialsDialog extends StatefulWidget {
  const AiHubCredentialsDialog({
    super.key,
    required this.hasSavedApiKey,
    required this.requiredForDownload,
  });

  final bool hasSavedApiKey;
  final bool requiredForDownload;

  @override
  State<AiHubCredentialsDialog> createState() => _AiHubCredentialsDialogState();
}

class _AiHubCredentialsDialogState extends State<AiHubCredentialsDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.requiredForDownload
            ? 'AI Hub API key required'
            : 'Connect Qualcomm AI Hub',
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.requiredForDownload
                ? 'Enter your personal AI Hub API token to continue with this download. It is stored encrypted on this device and is never shown again.'
                : 'Enter your personal AI Hub API token. It is stored encrypted on this device and is never shown again.',
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            obscureText: true,
            enableSuggestions: false,
            autocorrect: false,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'AI Hub API token',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        if (widget.hasSavedApiKey)
          TextButton(
            onPressed: () => Navigator.of(
              context,
            ).pop(const AiHubCredentialsChange.remove()),
            child: const Text('Remove'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _controller.text.trim().isEmpty
              ? null
              : () => Navigator.of(
                  context,
                ).pop(AiHubCredentialsChange.save(_controller.text)),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
