import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/connection_provider.dart';
import '../../state/telemetry_provider.dart';
import '../actions/action_button.dart';

/// VS Code state + actions. Port of the web client's VS Code tab: status,
/// workspace dropdown, and open.
class VscodeCard extends ConsumerStatefulWidget {
  const VscodeCard({super.key});

  @override
  ConsumerState<VscodeCard> createState() => _VscodeCardState();
}

class _VscodeCardState extends ConsumerState<VscodeCard> {
  String? _selectedWorkspace;
  bool _busy = false;

  Future<void> _openWorkspace(String path) async {
    if (_busy || path.isEmpty) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(tactClientProvider)
          .sendAction('vscode.open_workspace', {'path': path});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tactStateProvider);
    final workspace = (state?['workspace'] as Map?)?.cast<String, dynamic>();
    final vscode = (workspace?['vscode'] as Map?)?.cast<String, dynamic>();
    final workspaces =
        (workspace?['vscode_workspaces'] as Map?)?.cast<String, dynamic>();

    if (vscode == null || vscode['available'] != true) {
      return const Center(
        child: Card(
          margin: EdgeInsets.all(16),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text('VS Code not detected'),
          ),
        ),
      );
    }

    final running = vscode['running'] == true;
    final currentWorkspace = vscode['workspace'] as String? ?? '';
    final wsList =
        (workspaces?['workspaces'] as List?)?.whereType<String>().toList() ??
            <String>[];

    // The dropdown's selected value must exist in its items. If the current
    // workspace isn't in the detected list (e.g. it was opened elsewhere),
    // fall back to a valid item instead of asserting.
    if (wsList.isNotEmpty && !wsList.contains(_selectedWorkspace)) {
      _selectedWorkspace = wsList.contains(currentWorkspace)
          ? currentWorkspace
          : wsList.first;
    }
    final selected = _selectedWorkspace;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.circle,
                        size: 12, color: running ? Colors.green : Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      running ? 'VS Code running' : 'VS Code not running',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  currentWorkspace,
                  style: Theme.of(context).textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
                if (wsList.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selected,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Workspace',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    items: wsList
                        .map((w) => DropdownMenuItem(
                            value: w,
                            child: Text(w, overflow: TextOverflow.ellipsis)))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedWorkspace = v),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.tonal(
                          onPressed: _busy || selected == null
                              ? null
                              : () => _openWorkspace(selected),
                          child: const Text('Open Workspace'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Refresh',
                        onPressed: _busy
                            ? null
                            : () {
                                ref
                                    .read(tactClientProvider)
                                    .sendAction('vscode.workspaces')
                                    .catchError((_) {});
                              },
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                ActionButton(
                  actionId: 'vscode.status',
                  label: 'Check Status',
                  icon: Icons.manage_search,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}