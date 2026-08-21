import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/connection_provider.dart';
import '../../state/telemetry_provider.dart';
import '../../theme.dart';
import '../actions/action_button.dart';
import '../actions/prompt_button.dart';
import 'surface_icons.dart';
import 'state_card.dart';

/// Phase 3: the Context Surface — the primary, contextual home tab.
///
/// Renders the active surface from the agent's snapshot (`context.surface`):
/// a header with the app + workflow, the surface's action grid, the live
/// state card, the active-project card (Phase 3.10), and a compact glance
/// row (workspace mini-display + staleness). Unknown apps and unavailable
/// detection fall back to the Desktop surface so this tab is never empty.
class SurfaceTab extends ConsumerWidget {
  const SurfaceTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(tactStateProvider);
    final notifier = ref.read(tactStateProvider.notifier);
    final contextData = (state?['context'] as Map?)?.cast<String, dynamic>();
    final surface = contextData?['surface'] as Map<String, dynamic>?;

    if (surface == null) {
      return const _SurfacePlaceholder();
    }

    final actions = (surface['actions'] as List?)?.whereType<Map>() ?? const [];
    final stateCardKind = surface['state_card'] as String?;
    final project = contextData?['project'] as String?;
    final staleSeconds =
        notifier.lastUpdated == null ? null : DateTime.now().difference(notifier.lastUpdated!).inSeconds;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _SurfaceHeader(
          surface: surface,
          contextData: contextData,
        ),
        const SizedBox(height: 12),
        _ActionGrid(actions: actions),
        const SizedBox(height: 12),
        SurfaceStateCard(kind: stateCardKind),
        if (project != null) ...[
          const SizedBox(height: 12),
          ProjectCard(project: project),
        ],
        const SizedBox(height: 12),
        _GlanceRow(state: state, staleSeconds: staleSeconds),
      ],
    );
  }
}

class _SurfacePlaceholder extends StatelessWidget {
  const _SurfacePlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bolt, size: 40, color: AppTheme.muted),
            SizedBox(height: 12),
            Text(
              'Waiting for the agent…',
              style: TextStyle(color: AppTheme.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _SurfaceHeader extends ConsumerStatefulWidget {
  const _SurfaceHeader({required this.surface, required this.contextData});

  final Map<String, dynamic> surface;
  final Map<String, dynamic>? contextData;

  @override
  ConsumerState<_SurfaceHeader> createState() => _SurfaceHeaderState();
}

class _SurfaceHeaderState extends ConsumerState<_SurfaceHeader> {
  bool _pinning = false;

  Future<void> _togglePin() async {
    if (_pinning) return;
    final override = widget.contextData?['override'] as Map?;
    final pinned = override != null && override['app'] == widget.surface['id'];
    final activeApp = widget.contextData?['active_app'] as String?;
    final project = widget.contextData?['project'] as String?;

    setState(() => _pinning = true);
    try {
      if (pinned) {
        await ref.read(tactClientProvider).sendAction('context.clear_override', {});
      } else if (activeApp != null) {
        await ref
            .read(tactClientProvider)
            .sendAction('context.override', {'app': activeApp, 'project': project});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _pinning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final iconName = widget.surface['icon'] as String? ?? 'apps';
    final title = widget.surface['title'] as String? ?? 'Desktop';
    final workflow = widget.surface['workflow'] as String?;
    final override = widget.contextData?['override'] as Map?;
    final pinned = override != null && override['app'] == widget.surface['id'];
    final project = widget.contextData?['project'] as String?;
    final projectName = project == null
        ? null
        : project.split('/').last.isEmpty ? project : project.split('/').last;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceHigh,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(surfaceIcon(iconName), size: 26, color: AppTheme.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppTheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                if (projectName != null)
                  Text(
                    projectName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.muted),
                  ),
              ],
            ),
          ),
          if (workflow != null) ...[
            _workflowChip(workflow),
            const SizedBox(width: 8),
          ],
          IconButton(
            tooltip: pinned ? 'Unpin surface' : 'Pin surface',
            icon: _pinning
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    pinned ? Icons.push_pin : Icons.push_pin_outlined,
                    color: pinned ? AppTheme.accent : AppTheme.muted,
                  ),
            onPressed: _pinning ? null : _togglePin,
          ),
        ],
      ),
    );
  }

  Widget _workflowChip(String workflow) {
    final (color, icon) = switch (workflow) {
      'development' => (AppTheme.primary, Icons.construction),
      'meeting' => (AppTheme.accent, Icons.videocam),
      'media' => (const Color(0xFF9C7BFF), Icons.headphones),
      'communication' => (const Color(0xFF34D1B2), Icons.chat_bubble),
      'design' => (const Color(0xFFFF6FA5), Icons.palette),
      _ => (AppTheme.muted, Icons.apps),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            workflow,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}

class _ActionGrid extends StatelessWidget {
  const _ActionGrid({required this.actions});

  final Iterable<Map> actions;

  @override
  Widget build(BuildContext context) {
    final items = actions.toList();
    if (items.isEmpty) return const SizedBox.shrink();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.15,
      ),
      itemBuilder: (context, index) {
        final action = items[index].cast<String, dynamic>();
        final id = action['id'] as String? ?? '';
        final label = action['label'] as String? ?? id;
        final iconName = action['icon'] as String? ?? 'bolt';
        final prompt = action['prompt'] as String?;

        if (prompt != null) {
          return PromptButton(
            actionId: id,
            field: prompt,
            label: label,
            icon: surfaceIcon(iconName),
          );
        }
        return ActionButton(
          actionId: id,
          label: label,
          icon: surfaceIcon(iconName),
        );
      },
    );
  }
}

/// Phase 3.10 — active-project card: open the full environment with one tap,
/// plus per-project resource buttons from the agent's `project.resources`.
class ProjectCard extends ConsumerWidget {
  const ProjectCard({super.key, required this.project});

  final String project;

  Future<void> _send(WidgetRef ref, BuildContext context, String action,
      [Map<String, dynamic>? payload]) async {
    try {
      await ref.read(tactClientProvider).sendAction(action, payload);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(tactStateProvider);
    final projectState = (state?['project'] as Map?)?.cast<String, dynamic>();
    final resources =
        (projectState?['resources'] as List?)?.whereType<Map>() ?? const [];
    final projectName =
        project.split('/').last.isEmpty ? project : project.split('/').last;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceHigh.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.folder, size: 20, color: AppTheme.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  projectName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ActionButton(
            actionId: 'project.open',
            label: 'Open environment',
            icon: Icons.rocket_launch,
            payload: {'path': project},
          ),
          if (resources.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final resource in resources)
                  _ResourceChip(
                    resource: resource.cast<String, dynamic>(),
                    project: project,
                    onOpen: () => _send(
                      ref,
                      context,
                      _actionFor(resource['id'] as String? ?? ''),
                      _payloadFor(resource, project),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _actionFor(String id) => switch (id) {
        'repo' => 'system.open_url',
        'workspace' => 'vscode.open_workspace',
        'terminal' => 'system.open_terminal',
        'browser' => 'system.open_url',
        'folder' => 'system.open_project',
        _ => 'system.open_url',
      };

  Map<String, dynamic>? _payloadFor(Map resource, String project) {
    final url = resource['url'] as String?;
    return switch (resource['id'] as String?) {
      'repo' => url == null ? null : {'url': url},
      'workspace' => {'path': project},
      'terminal' => {'path': project},
      'browser' => {'url': 'http://localhost'},
      'folder' => {'path': project},
      _ => null,
    };
  }
}

class _ResourceChip extends StatelessWidget {
  final Map<String, dynamic> resource;
  final String project;
  final VoidCallback onOpen;

  const _ResourceChip({
    required this.resource,
    required this.project,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final label = resource['label'] as String? ?? resource['id'] as String? ?? '?';
    final hasUrl = resource['url'] is String && (resource['url'] as String).isNotEmpty;
    final disabled = resource['id'] == 'repo' && !hasUrl;

    return ActionChip(
      avatar: Icon(
        _iconFor(resource['id'] as String? ?? ''),
        size: 15,
        color: AppTheme.primary,
      ),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      backgroundColor: AppTheme.surfaceHigh.withValues(alpha: 0.5),
      onPressed: disabled ? null : onOpen,
      tooltip: disabled ? 'No remote configured' : null,
    );
  }

  IconData _iconFor(String id) => switch (id) {
        'repo' => Icons.link,
        'workspace' => Icons.code,
        'terminal' => Icons.terminal,
        'browser' => Icons.public,
        'folder' => Icons.folder_open,
        _ => Icons.bolt,
      };
}

class _GlanceRow extends StatelessWidget {
  const _GlanceRow({required this.state, this.staleSeconds});

  final Map<String, dynamic>? state;
  final int? staleSeconds;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];

    if (staleSeconds != null) {
      chips.add(_GlanceChip(
        icon: Icons.schedule,
        label: staleSeconds! < 60 ? 'updated ${staleSeconds}s ago' : 'updated ${(staleSeconds! / 60).round()}m ago',
        color: staleSeconds! < 20 ? AppTheme.muted : AppTheme.accent,
      ));
    }

    final docker = (state?['docker'] as Map?)?.cast<String, dynamic>();
    if (docker != null && docker['available'] == true) {
      final containers = (docker['containers'] as List?) ?? const [];
      final running =
          containers.where((c) => (c as Map)['state'] == 'running').length;
      chips.add(_GlanceChip(
        icon: Icons.developer_mode,
        label: running > 0 ? '$running containers running' : 'docker idle',
        color: running > 0 ? AppTheme.success : AppTheme.muted,
      ));
    }

    final battery = (state?['system']?['battery'] as Map?)?.cast<String, dynamic>();
    if (battery != null && battery['ok'] == true) {
      final percent = (battery['percent'] as num?)?.round() ?? 0;
      final charging = battery['charging'] == true;
      chips.add(_GlanceChip(
        icon: charging ? Icons.battery_charging_full : Icons.battery_full,
        label: '$percent%',
        color: AppTheme.primary,
      ));
    }

    final git = (state?['workspace']?['git'] as Map?)?.cast<String, dynamic>();
    if (git != null && git['available'] == true) {
      final branch = git['branch'] as String?;
      if (branch != null) {
        chips.add(_GlanceChip(
          icon: Icons.alt_route,
          label: branch,
          color: AppTheme.primary,
        ));
      }
      final changed = git['changed_files'] as int? ?? 0;
      if (changed > 0) {
        chips.add(_GlanceChip(
          icon: Icons.edit,
          label: '$changed changed',
          color: AppTheme.accent,
        ));
      }
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'WORKSPACE',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppTheme.muted,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
        ),
        const SizedBox(height: 6),
        Wrap(spacing: 8, runSpacing: 8, children: chips),
      ],
    );
  }
}

class _GlanceChip extends StatelessWidget {
  const _GlanceChip({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}