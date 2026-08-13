import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/telemetry_provider.dart';
import '../actions/action_button.dart';

/// Reads state.workspace.git, matching GitIntegration.status()'s exact
/// shape: available, branch, commit, changed_files, clean, ahead, behind,
/// upstream, root.
class GitCard extends ConsumerWidget {
  const GitCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(tactStateProvider);
    final git = (state?['workspace']?['git'] as Map?)?.cast<String, dynamic>();

    if (git == null || git['available'] != true) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No git repository detected'),
        ),
      );
    }

    final branch = git['branch'] as String? ?? 'detached HEAD';
    final clean = git['clean'] == true;
    final changed = git['changed_files'] as int? ?? 0;
    final ahead = git['ahead'] as int? ?? 0;
    final behind = git['behind'] as int? ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(clean ? Icons.check_circle : Icons.circle,
                    size: 12, color: clean ? Colors.green : Colors.orange),
                const SizedBox(width: 8),
                Text(branch, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 4),
            Text(clean ? 'Clean' : '$changed file(s) changed'),
            if (ahead > 0 || behind > 0) Text('$ahead ahead, $behind behind'),
            const SizedBox(height: 12),
            const Wrap(
              spacing: 8,
              children: [
                ActionButton(actionId: 'git.pull', label: 'Pull', icon: Icons.arrow_downward),
                ActionButton(actionId: 'git.push', label: 'Push', icon: Icons.arrow_upward),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
