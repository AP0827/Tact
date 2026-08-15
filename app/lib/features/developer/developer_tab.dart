import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/connection_provider.dart';
import '../../state/telemetry_provider.dart';

/// Unified Developer section: pick a repository, then run git operations and
/// VS Code actions against it in one place.
class DeveloperTab extends ConsumerStatefulWidget {
  const DeveloperTab({super.key});

  @override
  ConsumerState<DeveloperTab> createState() => _DeveloperTabState();
}

class _DeveloperTabState extends ConsumerState<DeveloperTab> {
  String? _selectedRepo;
  String? _selectedBranch;
  final _commitController = TextEditingController();
  bool _showCommitGraph = false;
  bool _busy = false;
  String? _pushStatus;
  String? _pushDetail;

  @override
  void dispose() {
    _commitController.dispose();
    super.dispose();
  }

  String? _currentWorkspace(Map<String, dynamic>? workspace) =>
      (workspace?['current_workspace'] as String?) ??
      (workspace?['cwd'] as String?) ??
      (workspace?['git_root'] as String?);

  List<String> _repoOptions(Map<String, dynamic>? workspace) {
    final ws = (workspace?['vscode_workspaces'] as Map?)?.cast<String, dynamic>();
    final list = (ws?['workspaces'] as List?)?.whereType<String>().toList() ??
        <String>[];
    final gitRoot = workspace?['git_root'] as String?;
    if (gitRoot != null && !list.contains(gitRoot)) {
      list.insert(0, gitRoot);
    }
    final current = _currentWorkspace(workspace);
    if (current != null && current.isNotEmpty && !list.contains(current)) {
      list.insert(0, current);
    }
    return list;
  }

  Future<void> _guard(Future<void> Function() fn) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await fn();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _selectRepo(String path) async {
    if (_selectedRepo == path) return;
    setState(() => _selectedRepo = path);
    await _guard(() async {
      try {
        final client = ref.read(tactClientProvider);
        await client.sendAction('system.set_workspace', {'path': path});
        await client.sendAction('git.status', {'path': path});
        await client.sendAction('git.branches', {'path': path});
        await client.sendAction('git.log', {'path': path});
        _snack('Switched to $path');
      } catch (e) {
        _snack('$e');
      }
    });
  }

  Future<void> _refresh(String path) async {
    await _guard(() async {
      try {
        final client = ref.read(tactClientProvider);
        await client.sendAction('git.status', {'path': path});
        await client.sendAction('git.branches', {'path': path});
        await client.sendAction('git.log', {'path': path});
        await client.sendAction('vscode.workspaces');
      } catch (e) {
        _snack('$e');
      }
    });
  }

  Future<void> _switchBranch(String path, String branch) async {
    await _guard(() async {
      try {
        await ref
            .read(tactClientProvider)
            .sendAction('git._switch_branch', {'path': path, 'branch': branch});
        await _refresh(path);
      } catch (e) {
        _snack('$e');
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
        _snack(failed ? 'Commit failed: ${result['error']}' : 'Committed');
        if (!failed) await _refresh(path);
      } catch (e) {
        _snack('$e');
      }
    });
  }

  Future<void> _push(String path) async {
    setState(() {
      _pushStatus = null;
      _pushDetail = null;
    });
    await _guard(() async {
      try {
        final result =
            await ref.read(tactClientProvider).sendAction('git.push', {'path': path});
        final inner = result is Map ? (result['result'] as Map?) ?? result : null;
        final ok = inner?['ok'] == true;
        final stdout = (inner?['stdout'] as String?) ?? '';
        final stderr = (inner?['stderr'] as String?) ?? '';
        if (ok) {
          final upToDate = stdout.contains('Everything up-to-date') ||
              stdout.contains('up to date');
          setState(() {
            _pushStatus = upToDate ? 'Up to date' : 'Pushed';
            _pushDetail = upToDate ? null : stdout;
          });
          _snack(upToDate ? 'Already up to date' : 'Pushed successfully');
        } else {
          setState(() {
            _pushStatus = 'Push failed';
            _pushDetail = stderr.isNotEmpty ? stderr : stdout;
          });
          _snack('Push failed: $stderr');
        }
        await _refresh(path);
      } catch (e) {
        _snack('$e');
      }
    });
  }

  Future<void> _openInVscode(String path) async {
    try {
      await ref.read(tactClientProvider).sendAction('vscode.open_workspace', {'path': path});
      _snack('Opened in VS Code');
    } catch (e) {
      _snack('$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tactStateProvider);
    final workspace = (state?['workspace'] as Map?)?.cast<String, dynamic>();
    final git = (workspace?['git'] as Map?)?.cast<String, dynamic>();
    final branches = (workspace?['git_branches'] as Map?)?.cast<String, dynamic>();
    final tree = (workspace?['git_tree'] as Map?)?.cast<String, dynamic>();
    final log = (workspace?['git_log'] as Map?)?.cast<String, dynamic>();
    final vscode = (workspace?['vscode'] as Map?)?.cast<String, dynamic>();

    final repos = _repoOptions(workspace);
    if (repos.isEmpty && git?['available'] != true) {
      return const Center(
        child: Card(
          margin: EdgeInsets.all(16),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text('No repository or VS Code workspace detected'),
          ),
        ),
      );
    }

    _selectedRepo ??= repos.contains(_currentWorkspace(workspace))
        ? _currentWorkspace(workspace)
        : (repos.isNotEmpty ? repos.first : null);
    final path = _selectedRepo ?? _currentWorkspace(workspace) ?? '';

    final branch = git?['branch'] as String? ?? 'detached HEAD';
    final clean = git?['clean'] == true;
    final changed = git?['changed_files'] as int? ?? 0;
    final ahead = git?['ahead'] as int? ?? 0;
    final behind = git?['behind'] as int? ?? 0;
    final commit = git?['commit'] as String?;
    final branchList =
        (branches?['branches'] as List?)?.whereType<String>().toList() ??
            <String>[];

    _selectedBranch ??= branch;
    if (branchList.isNotEmpty &&
        (_selectedBranch == null || !branchList.contains(_selectedBranch))) {
      _selectedBranch = branchList.contains(branch) ? branch : branchList.first;
    }

    final vscodeRunning = vscode?['running'] == true;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _RepoSelector(
          repos: repos,
          selected: _selectedRepo,
          busy: _busy,
          onChanged: _selectRepo,
          onRefresh: path.isEmpty ? null : () => _refresh(path),
        ),
        if (path.isNotEmpty) ...[
          const SizedBox(height: 16),
          _GitOpsCard(
            path: path,
            branch: branch,
            clean: clean,
            changed: changed,
            ahead: ahead,
            behind: behind,
            commit: commit,
            branchList: branchList,
            selectedBranch: _selectedBranch,
            pushStatus: _pushStatus,
            pushDetail: _pushDetail,
            busy: _busy,
            onBranchChanged: (v) => setState(() => _selectedBranch = v),
            onSwitchBranch: () => _switchBranch(path, _selectedBranch!),
            onStageAll: () => _guard(() async {
              try {
                await ref
                    .read(tactClientProvider)
                    .sendAction('git.add', {'path': path});
                _snack('Staged all changes');
                await _refresh(path);
              } catch (e) {
                _snack('$e');
              }
            }),
            onCommit: () => _commit(path),
            onPull: () => _guard(() async {
              try {
                final result = await ref
                    .read(tactClientProvider)
                    .sendAction('git.pull', {'path': path});
                final inner = result is Map
                    ? (result['result'] as Map?) ?? result
                    : null;
                _snack(inner?['ok'] == true ? 'Pulled' : 'Pull failed');
                await _refresh(path);
              } catch (e) {
                _snack('$e');
              }
            }),
            onPush: () => _push(path),
            commitController: _commitController,
          ),
          const SizedBox(height: 16),
          _VscodeSection(
            path: path,
            running: vscodeRunning,
            vscodeAvailable: vscode?['available'] == true,
            busy: _busy,
            onOpen: () => _openInVscode(path),
            onStatus: () => _guard(() async {
              try {
                await ref.read(tactClientProvider).sendAction('vscode.status');
              } catch (e) {
                _snack('$e');
              }
            }),
          ),
          const SizedBox(height: 16),
          _TreeSection(
            showCommitGraph: _showCommitGraph,
            tree: tree,
            log: log,
            onViewChanged: (v) => setState(() => _showCommitGraph = v),
            onRefresh: () => _guard(() async {
              try {
                await ref
                    .read(tactClientProvider)
                    .sendAction('git.tree', {'path': path});
                await ref
                    .read(tactClientProvider)
                    .sendAction('git.log', {'path': path});
              } catch (e) {
                _snack('$e');
              }
            }),
          ),
        ],
      ],
    );
  }
}

class _RepoSelector extends StatelessWidget {
  final List<String> repos;
  final String? selected;
  final bool busy;
  final ValueChanged<String> onChanged;
  final VoidCallback? onRefresh;

  const _RepoSelector({
    required this.repos,
    required this.selected,
    required this.busy,
    required this.onChanged,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Repository',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: selected,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      hintText: 'Select a repository',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    items: repos
                        .map((r) => DropdownMenuItem(
                            value: r,
                            child: _RepoLabel(path: r)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) onChanged(v);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: busy || onRefresh == null ? null : onRefresh,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RepoLabel extends StatelessWidget {
  final String path;
  const _RepoLabel({required this.path});

  @override
  Widget build(BuildContext context) {
    final folder = path.split('/').last;
    return Row(
      children: [
        Icon(Icons.folder,
            size: 16, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            folder,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}

class _GitOpsCard extends StatelessWidget {
  final String path;
  final String branch;
  final bool clean;
  final int changed;
  final int ahead;
  final int behind;
  final String? commit;
  final List<String> branchList;
  final String? selectedBranch;
  final String? pushStatus;
  final String? pushDetail;
  final bool busy;
  final ValueChanged<String?> onBranchChanged;
  final VoidCallback onSwitchBranch;
  final VoidCallback onStageAll;
  final VoidCallback onCommit;
  final VoidCallback onPull;
  final VoidCallback onPush;
  final TextEditingController commitController;

  const _GitOpsCard({
    required this.path,
    required this.branch,
    required this.clean,
    required this.changed,
    required this.ahead,
    required this.behind,
    required this.commit,
    required this.branchList,
    required this.selectedBranch,
    required this.pushStatus,
    required this.pushDetail,
    required this.busy,
    required this.onBranchChanged,
    required this.onSwitchBranch,
    required this.onStageAll,
    required this.onCommit,
    required this.onPull,
    required this.onPush,
    required this.commitController,
  });

  @override
  Widget build(BuildContext context) {
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
                Expanded(
                  child: Text(branch,
                      style: Theme.of(context).textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis),
                ),
                if (commit != null)
                  Text(commit!,
                      style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 4),
            Text(clean ? 'Clean' : '$changed file(s) changed'),
            if (ahead > 0 || behind > 0)
              Text('$ahead ahead, $behind behind',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            if (pushStatus != null) ...[
              const SizedBox(height: 8),
              Text(pushStatus!,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: pushStatus == 'Push failed'
                        ? Theme.of(context).colorScheme.error
                        : Colors.green,
                  )),
              if (pushDetail != null && pushDetail!.isNotEmpty)
                Text(pushDetail!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall),
            ],
            const SizedBox(height: 12),
            if (branchList.isNotEmpty) ...[
              DropdownButtonFormField<String>(
                initialValue: selectedBranch,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Branch',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                items: branchList
                    .map((b) => DropdownMenuItem(
                        value: b, child: Text(b, overflow: TextOverflow.ellipsis)))
                    .toList(),
                onChanged: onBranchChanged,
              ),
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: busy ||
                        selectedBranch == null ||
                        selectedBranch == branch
                    ? null
                    : onSwitchBranch,
                child: const Text('Switch Branch'),
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: busy ? null : onStageAll,
                    child: const Text('Stage All'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: busy ? null : onPull,
                    child: const Text('Pull'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: busy ? null : onPush,
                    child: const Text('Push'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: commitController,
              decoration: const InputDecoration(
                labelText: 'Commit message',
                hintText: 'Describe the change…',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => onCommit(),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonal(
                onPressed: busy ? null : onCommit,
                child: const Text('Commit'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VscodeSection extends StatelessWidget {
  final String path;
  final bool running;
  final bool vscodeAvailable;
  final bool busy;
  final VoidCallback onOpen;
  final VoidCallback onStatus;

  const _VscodeSection({
    required this.path,
    required this.running,
    required this.vscodeAvailable,
    required this.busy,
    required this.onOpen,
    required this.onStatus,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
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
                  vscodeAvailable
                      ? (running ? 'VS Code running' : 'VS Code not running')
                      : 'VS Code not detected',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(path,
                style: Theme.of(context).textTheme.bodySmall,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: busy || !vscodeAvailable ? null : onOpen,
                    child: const Text('Open in VS Code'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Check status',
                  onPressed: busy ? null : onStatus,
                  icon: const Icon(Icons.manage_search),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TreeSection extends StatelessWidget {
  final bool showCommitGraph;
  final Map<String, dynamic>? tree;
  final Map<String, dynamic>? log;
  final ValueChanged<bool> onViewChanged;
  final VoidCallback onRefresh;

  const _TreeSection({
    required this.showCommitGraph,
    required this.tree,
    required this.log,
    required this.onViewChanged,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Repository',
                        style: Theme.of(context).textTheme.titleMedium),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Refresh tree',
                      onPressed: onRefresh,
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<bool>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: false,
                        label: Text('Files'),
                        icon: Icon(Icons.folder_outlined, size: 16),
                      ),
                      ButtonSegment(
                        value: true,
                        label: Text('Commits'),
                        icon: Icon(Icons.account_tree_outlined, size: 16),
                      ),
                    ],
                    selected: {showCommitGraph},
                    onSelectionChanged: (s) => onViewChanged(s.first),
                  ),
                ),
              ],
            ),
          ),
          if (showCommitGraph)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: log?['available'] == true
                  ? CommitGraph(commits: (log?['commits'] as List?) ?? const [])
                  : const Text('Not a git repository'),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: tree?['available'] == true
                  ? RepoTree(nodes: (tree?['tree'] as List?) ?? const [])
                  : const Text('Not a git repository'),
            ),
        ],
      ),
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

class CommitGraph extends StatelessWidget {
  final List<dynamic> commits;
  const CommitGraph({super.key, required this.commits});

  @override
  Widget build(BuildContext context) {
    if (commits.isEmpty) {
      return const Text('No commits yet');
    }
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: commits.map((c) => _CommitLine(line: c.toString())).toList(),
      ),
    );
  }
}

class _CommitLine extends StatelessWidget {
  final String line;
  const _CommitLine({required this.line});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // A commit line from `git log --graph --oneline --decorate=short` looks
    // like: "* abc1234 (HEAD -> main) subject". Graph-only lines (e.g. "|\")
    // carry no commit hash.
    final hashStart = line.indexOf('*');
    final hashEnd = hashStart == -1 ? -1 : line.indexOf(' ', hashStart + 2);
    final hasHash = hashStart != -1 && hashEnd != -1;
    final hash =
        hasHash ? line.substring(hashStart + 2, hashEnd) : '';

    return Text.rich(
      TextSpan(
        style: theme.textTheme.bodySmall?.copyWith(
          fontFamily: 'monospace',
          fontSize: 12,
        ),
        children: [
          if (hasHash) ...[
            TextSpan(
              text: line.substring(0, hashStart + 2),
              style: TextStyle(color: theme.colorScheme.outline),
            ),
            TextSpan(
              text: hash,
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextSpan(
              text: line.substring(hashEnd),
              style: TextStyle(
                color: theme.colorScheme.onSurface,
              ),
            ),
          ] else
            TextSpan(
              text: line,
              style: TextStyle(color: theme.colorScheme.outline),
            ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}