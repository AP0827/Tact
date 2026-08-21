import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/connection_provider.dart';
import '../../state/telemetry_provider.dart';
import '../../theme.dart';

/// Phase 3.8/3.9 — app launcher + window/workspace controls.
class AppsTab extends ConsumerWidget {
  const AppsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(tactStateProvider);
    final system = (state?['system'] as Map?)?.cast<String, dynamic>();
    final appsState = (system?['apps'] as Map?)?.cast<String, dynamic>();
    final groups = (appsState?['groups'] as Map?)?.cast<String, dynamic>() ?? {};
    final recentApps = (state?['context'] as Map?)?.cast<String, dynamic>()['recent_apps'] as List? ?? const [];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (recentApps.isNotEmpty) ...[
          Text('Recent', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          _RecentRow(apps: recentApps.cast<String>()),
          const SizedBox(height: 16),
        ],
        for (final entry in groups.entries) ...[
          Text(
            _groupLabel(entry.key),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          _AppGrid(apps: entry.value.cast()),
          const SizedBox(height: 16),
        ],
        const SizedBox(height: 8),
        const _WindowSection(),
      ],
    );
  }

  String _groupLabel(String key) => switch (key) {
        'development' => 'Development',
        'communication' => 'Communication',
        'media' => 'Media',
        _ => key,
      };
}

class _RecentRow extends ConsumerWidget {
  final List<String> apps;
  const _RecentRow({required this.apps});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.watch(tactClientProvider);
    return Row(
      children: [
        for (final id in apps.reversed) ...[
          Expanded(
            child: _AppTile(
              id: id,
              icon: _AppGrid.iconFor(id),
              label: _AppGrid.labelFor(id),
              running: false,
              onTap: () async {
                try {
                  await client.sendAction('system.open_app', {'app': id});
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('$e')));
                }
              },
            ),
          ),
          const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _AppGrid extends StatelessWidget {
  final List<dynamic> apps;
  const _AppGrid({required this.apps});

  static IconData iconFor(String id) => _icons[id] ?? Icons.apps;

  static String labelFor(String id) => switch (id) {
        'vscode' => 'VS Code',
        'terminal' => 'Terminal',
        'docker' => 'Docker',
        'chrome' => 'Chrome',
        'teams' => 'Teams',
        'spotify' => 'Spotify',
        'files' => 'Files',
        _ => id,
      };

  static const _icons = <String, IconData>{
    'vscode': Icons.code,
    'terminal': Icons.terminal,
    'docker': Icons.developer_mode,
    'chrome': Icons.public,
    'teams': Icons.groups,
    'spotify': Icons.music_note,
    'files': Icons.folder_open,
  };

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.15,
      children: [
        for (final app in apps.cast<Map>())
          _AppTile(
            id: app['id'] as String? ?? '',
            icon: iconFor(app['id'] as String? ?? ''),
            label: app['label'] as String? ?? app['id'] as String? ?? '',
            running: app['running'] == true,
            onTap: null,
          ),
      ],
    );
  }
}

class _AppTile extends ConsumerWidget {
  final String id;
  final IconData icon;
  final String label;
  final bool running;
  final VoidCallback? onTap;

  const _AppTile({
    required this.id,
    required this.icon,
    required this.label,
    required this.running,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.watch(tactClientProvider);

    Future<void> open() async {
      try {
        await client.sendAction('system.open_app', {'app': id});
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }

    Future<void> focus() async {
      try {
        await client.sendAction('system.focus_app', {'app': id});
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }

    return Material(
      color: AppTheme.surfaceHigh.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: running ? focus : open,
        onLongPress: running ? null : focus,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: running
                  ? AppTheme.success.withValues(alpha: 0.5)
                  : AppTheme.surfaceHigh,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(icon,
                      size: 26, color: Theme.of(context).colorScheme.primary),
                  if (running)
                    Positioned(
                      right: -6,
                      top: -6,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppTheme.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Phase 3.9 — window list, window state actions, and layout presets.
class _WindowSection extends ConsumerWidget {
  const _WindowSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(tactStateProvider);
    final windowState = (state?['window'] as Map?)?.cast<String, dynamic>();
    final windows =
        (windowState?['windows'] as List?)?.cast<Map>() ?? const [];
    final client = ref.watch(tactClientProvider);

    Future<void> run(String action, [Map<String, dynamic>? payload]) async {
      try {
        await client.sendAction(action, payload);
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.window,
                    size: 20, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text('Windows & layouts',
                    style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            if (windows.isEmpty)
              Text('No windows detected (wmctrl unavailable).',
                  style: Theme.of(context).textTheme.bodySmall)
            else
              ...windows.map((w) => _WindowTile(
                    window: w,
                    onFocus: () => run('window.focus', {'title': w['title']}),
                    onMinimize: () =>
                        run('window.minimize', {'title': w['title']}),
                    onMaximize: () =>
                        run('window.maximize', {'title': w['title']}),
                    onClose: () => run('window.close', {'title': w['title']}),
                  )),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Text('Workspace presets',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _LayoutChip(
                  label: 'Coding',
                  icon: Icons.code,
                  onTap: () => run('window.apply_layout', {'name': 'coding'}),
                ),
                _LayoutChip(
                  label: 'Meeting',
                  icon: Icons.groups,
                  onTap: () => run('window.apply_layout', {'name': 'meeting'}),
                ),
                _LayoutChip(
                  label: 'Media',
                  icon: Icons.music_note,
                  onTap: () => run('window.apply_layout', {'name': 'media'}),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WindowTile extends StatelessWidget {
  final Map window;
  final VoidCallback onFocus;
  final VoidCallback onMinimize;
  final VoidCallback onMaximize;
  final VoidCallback onClose;

  const _WindowTile({
    required this.window,
    required this.onFocus,
    required this.onMinimize,
    required this.onMaximize,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final title = window['title'] as String? ?? '';
    final wmClass = window['wm_class'] as String? ?? '';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: Icon(Icons.crop_din, size: 18, color: AppTheme.muted),
      title: Text(title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13)),
      subtitle: Text(wmClass,
          style: TextStyle(fontSize: 11, color: AppTheme.muted)),
      onTap: onFocus,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove, size: 18),
            tooltip: 'Minimize',
            onPressed: onMinimize,
          ),
          IconButton(
            icon: const Icon(Icons.open_in_full, size: 16),
            tooltip: 'Maximize',
            onPressed: onMaximize,
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            tooltip: 'Close',
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}

class _LayoutChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _LayoutChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 16, color: AppTheme.primary),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      backgroundColor: AppTheme.surfaceHigh.withValues(alpha: 0.5),
      onPressed: onTap,
    );
  }
}