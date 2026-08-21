import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/connection_provider.dart';
import 'action_button.dart';

/// Button that prompts for a URL before firing `system.open_url`.
/// Shared by the ActionsGrid and the Phase 3 surface tab.
class OpenUrlButton extends ConsumerStatefulWidget {
  const OpenUrlButton({
    super.key,
    required this.label,
    this.icon,
  });

  final String label;
  final IconData? icon;

  @override
  ConsumerState<OpenUrlButton> createState() => _OpenUrlButtonState();
}

class _OpenUrlButtonState extends ConsumerState<OpenUrlButton> {
  final _urlController = TextEditingController();

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    final url = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Open URL'),
        content: TextField(
          controller: _urlController,
          autofocus: true,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            labelText: 'https://…',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_urlController.text.trim()),
            child: const Text('Open'),
          ),
        ],
      ),
    );

    if (url == null || url.isEmpty || !mounted) return;

    try {
      await ref
          .read(tactClientProvider)
          .sendAction('system.open_url', {'url': url});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ActionButton(
      actionId: 'system.open_url',
      label: widget.label,
      icon: widget.icon,
      onPressed: _open,
    );
  }
}