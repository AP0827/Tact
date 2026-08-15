import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/connection_provider.dart';
import '../../state/telemetry_provider.dart';
import 'action_button.dart';

const _knownSystemActions = <String, (String, IconData)>{
  'system.lock_screen': (
    'Lock Screen',
    Icons.lock,
  ),
  'system.open_terminal': (
    'Terminal',
    Icons.terminal,
  ),
  'system.open_url': (
    'Open URL',
    Icons.public,
  ),
  'system.open_project': (
    'Open Project',
    Icons.folder_open,
  ),
  'system.screenshot': (
    'Screenshot',
    Icons.screenshot,
  ),
};

class ActionsGrid extends ConsumerWidget {
  const ActionsGrid({
    super.key,
  });

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    final state =
        ref.watch(tactStateProvider);

    final actionIds =
        (state?['actions'] as List?)
                ?.whereType<String>()
                .toList() ??
            const <String>[];

    final available =
        _knownSystemActions.keys
            .where(actionIds.contains)
            .toList();

    if (available.isEmpty) {
      return const SizedBox.shrink();
    }

    return GridView.builder(
      shrinkWrap: true,
      physics:
          const NeverScrollableScrollPhysics(),
      itemCount: available.length,
      gridDelegate:
          const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.15,
      ),
      itemBuilder: (context, index) {
        final id = available[index];
        final config =
            _knownSystemActions[id]!;

        if (id == 'system.open_url') {
          return _OpenUrlButton(
            label: config.$1,
            icon: config.$2,
          );
        }

        return ActionButton(
          actionId: id,
          label: config.$1,
          icon: config.$2,
        );
      },
    );
  }
}

/// Prompts for a URL before firing `system.open_url` — mirrors the web
/// client which hardcodes an example URL otherwise.
class _OpenUrlButton extends ConsumerStatefulWidget {
  const _OpenUrlButton({
    required this.label,
    required this.icon,
  });

  final String label;
  final IconData icon;

  @override
  ConsumerState<_OpenUrlButton> createState() =>
      _OpenUrlButtonState();
}

class _OpenUrlButtonState
    extends ConsumerState<_OpenUrlButton> {
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
            onPressed: () =>
                Navigator.of(context).pop(_urlController.text.trim()),
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