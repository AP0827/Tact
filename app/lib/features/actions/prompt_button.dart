import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/connection_provider.dart';
import 'action_button.dart';

/// Button that prompts for a single text value before firing an action.
/// The prompt string is the payload field name (`url` for system.open_url,
/// `path` for vscode.open_file, ...). Shared by the ActionsGrid and the
/// Phase 3 surface tab.
class PromptButton extends ConsumerStatefulWidget {
  const PromptButton({
    super.key,
    required this.actionId,
    required this.label,
    required this.field,
    this.icon,
    this.hint,
  });

  final String actionId;
  final String label;
  final String field;
  final IconData? icon;
  final String? hint;

  @override
  ConsumerState<PromptButton> createState() => _PromptButtonState();
}

class _PromptButtonState extends ConsumerState<PromptButton> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.label),
        content: TextField(
          controller: _controller,
          autofocus: true,
          keyboardType: widget.field == 'url'
              ? TextInputType.url
              : TextInputType.text,
          decoration: InputDecoration(
            labelText: widget.hint ?? widget.field,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
            child: const Text('Send'),
          ),
        ],
      ),
    );

    if (value == null || value.isEmpty || !mounted) return;

    try {
      await ref
          .read(tactClientProvider)
          .sendAction(widget.actionId, {widget.field: value});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ActionButton(
      actionId: widget.actionId,
      label: widget.label,
      icon: widget.icon,
      onPressed: _run,
    );
  }
}