import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/telemetry_provider.dart';
import '../actions/action_button.dart';

/// Reads state.workspace.vscode, matching VSCodeIntegration.status()'s
/// exact shape: available, running, command, workspace.
class VscodeCard extends ConsumerWidget {
  const VscodeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(tactStateProvider);
    final vscode = (state?['workspace']?['vscode'] as Map?)?.cast<String, dynamic>();

    if (vscode == null || vscode['available'] != true) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('VS Code not detected'),
        ),
      );
    }

    final running = vscode['running'] == true;
    final workspace = vscode['workspace'] as String? ?? '';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.circle, size: 12, color: running ? Colors.green : Colors.grey),
                const SizedBox(width: 8),
                Text(running ? 'VS Code running' : 'VS Code not running'),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              workspace,
              style: Theme.of(context).textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            ActionButton(
              actionId: 'vscode.open_workspace',
              label: 'Open Workspace',
              icon: Icons.code,
              payload: {'path': workspace},
            ),
          ],
        ),
      ),
    );
  }
}
