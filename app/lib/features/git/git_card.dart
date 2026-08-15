import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/connection_provider.dart';
import '../../state/telemetry_provider.dart';
import '../actions/action_button.dart';

/// Git state + actions. Port of the web client's Git tab: branch switcher,
/// pull/push, commit form, and repository tree.
class GitCard extends ConsumerStatefulWidget {
  const GitCard({super.key});

  @override
  ConsumerState<GitCard> createState() => _GitCardState();
}

class _GitCardState extends ConsumerState<GitCard> {
  String? _selectedBranch;
  final _commitController = TextEditingController();
  bool _showTree = false;
  bool _busy = false;

  @override
  void dispose() {
    _commitController.dispose();
    super.dispose();
  }

  String _workspacePath(Map<String, dynamic>? workspace) =>
      (workspace?['current_workspace'] as String?) ??
      (workspace?['cwd'] as String?) ??
      '';

  Future<void> _guard(Future<void> Function() fn) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await fn();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _error(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$e')));
  }

  Future<void> _switchBranch(String path, String branch) async {
    await _guard(() async {
      try {
        await ref
            .read(tactClientProvider)
            .sendAction('git._switch_branch', {'path': path, 'branch': branch});
      } catch (e) {
        _error(e);
      }
    });
  }

  Future<void> _commit(String path) async {
    final message = _commitController.text.trim();
    if (message.isEmpty) return;
    await _guard(() async {
      try {
        final result = await ref
            .read(tactClientProvider)
            .sendAction('git.commit', {'path': path, 'message': message});
        final failed = result is Map && result['ok'] == false;
        _commitController.clear();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(failed ? 'Commit failed: ${result['error']}' : 'Committed'),
            ),
          );
        }
      } catch (e) {
        _error(e);
      }
    });
  }

  Future<void> _refresh(String path) async {
    await _guard(() async {
      try {
        await ref.read(tactClientProvider).sendAction('git.status', {'path': path});
        await ref.read(tactClientProvider).sendAction('git.branches', {'path': path});
        await ref.read(tactClientProvider).sendAction('git.tree', {'path': path});
      } catch (e) {
        _error(e);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tactStateProvider);
    final workspace = (state?['workspace'] as Map?)?.cast<String, dynamic>();
    final git = (workspace?['git'] as Map?)?.cast<String, dynamic>();
    final branches = (workspace?['git_branches'] as Map?)?.cast<String, dynamic>();
    final tree = (workspace?['git_tree'] as Map?)?.cast<String, dynamic>();

    if (git == null || git['available'] != true) {
      return const Center(
        child: Card(
          margin: EdgeInsets.all(16),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text('No git repository detected'),
          ),
        ),
      );
    }

    final branch = git['branch'] as String? ?? 'detached HEAD';
    final clean = git['clean'] == true;
    final changed = git['changed_files'] as int? ?? 0;
    final ahead = git['ahead'] as int? ?? 0;
    final behind = git['behind'] as int? ?? 0;
    final commit = git['commit'] as String?;
    final path = _workspacePath(workspace);
    final branchList = (branches?['branches'] as List?)?.whereType<String>().toList() ?? <String>[];

    _selectedBranch ??= git['branch'] as String?;
    // The dropdown's selected value must exist in its items. If the current
    // branch isn't in the list (e.g. detached HEAD or remote-only), fall back
    // to a valid item instead of asserting.
    if (branchList.isNotEmpty &&
        (_selectedBranch == null || !branchList.contains(_selectedBranch))) {
      _selectedBranch = branchList.contains(branch) ? branch : branchList.first;
    }

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
                    Icon(clean ? Icons.check_circle : Icons.circle,
                        size: 12, color: clean ? Colors.green : Colors.orange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(branch,
                          style: Theme.of(context).textTheme.titleMedium,
                          overflow: TextOverflow.ellipsis),
                    ),
                    if (commit != null)
                      Text(commit, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
                const SizedBox(height: 4),
                Text(clean ? 'Clean' : '$changed file(s) changed'),
                if (ahead > 0 || behind > 0)
                  Text('$ahead ahead, $behind behind',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                if (branchList.isNotEmpty) ...[
                  DropdownButtonFormField<String>(
                    initialValue: _selectedBranch,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Branch',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    items: branchList
                        .map((b) => DropdownMenuItem(value: b, child: Text(b, overflow: TextOverflow.ellipsis)))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedBranch = v),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.tonal(
                          onPressed: _busy || _selectedBranch == null || _selectedBranch == branch
                              ? null
                              : () => _switchBranch(path, _selectedBranch!),
                          child: const Text('Switch Branch'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Refresh',
                        onPressed: _busy ? null : () => _refresh(path),
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                const Wrap(
                  spacing: 8,
                  children: [
                    ActionButton(actionId: 'git.pull', label: 'Pull', icon: Icons.arrow_downward),
                    ActionButton(actionId: 'git.push', label: 'Push', icon: Icons.arrow_upward),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _commitController,
                  decoration: const InputDecoration(
                    labelText: 'Commit message',
                    hintText: 'Describe the change…',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _commit(path),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.tonal(
                    onPressed: _busy ? null : () => _commit(path),
                    child: const Text('Commit'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: () => setState(() => _showTree = !_showTree),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(_showTree ? Icons.expand_more : Icons.chevron_right),
                      const SizedBox(width: 8),
                      Text('Repository Tree',
                          style: Theme.of(context).textTheme.titleMedium),
                      const Spacer(),
                      if (tree?['file_count'] is int)
                        Text('${tree!['file_count']} files',
                            style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              ),
              if (_showTree)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: tree?['available'] == true
                      ? RepoTree(nodes: (tree?['tree'] as List?) ?? const [])
                      : const Text('Not a git repository'),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class RepoTree extends StatelessWidget {
  final List<dynamic> nodes;
  const RepoTree({super.key, required this.nodes});

  @override
  Widget build(BuildContext context) {
    if (nodes.isEmpty) {
      return const Text('No files');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: nodes.map((n) => _TreeTile(node: n)).toList(),
    );
  }
}

class _TreeTile extends StatefulWidget {
  final Map<String, dynamic> node;
  const _TreeTile({required this.node});

  @override
  State<_TreeTile> createState() => _TreeTileState();
}

class _TreeTileState extends State<_TreeTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final node = widget.node;
    final isDir = node['type'] == 'dir';
    final children = (node['children'] as List?) ?? const [];

    if (!isDir) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            const Icon(Icons.insert_drive_file, size: 14, color: Colors.grey),
            const SizedBox(width: 6),
            Expanded(
              child: Text(node['name']?.toString() ?? '',
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Row(
            children: [
              Icon(_expanded ? Icons.arrow_drop_down : Icons.arrow_right, size: 18),
              const Icon(Icons.folder, size: 15, color: Colors.orange),
              const SizedBox(width: 4),
              Expanded(
                child: Text(node['name']?.toString() ?? '',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
        if (_expanded && children.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children.map((c) => _TreeTile(node: c)).toList(),
            ),
          ),
      ],
    );
  }
}