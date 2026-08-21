import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/telemetry_provider.dart';
import '../../theme.dart';

/// Renders the active surface's state card from live snapshot data.
/// The agent sends only a `kind` string; the phone pulls the matching
/// section out of the same snapshot it already holds, so there's no
/// duplicated data over the wire.
class SurfaceStateCard extends ConsumerWidget {
  const SurfaceStateCard({super.key, required this.kind});

  final String? kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(tactStateProvider);
    if (state == null || kind == null || kind!.isEmpty) {
      return const SizedBox.shrink();
    }

    return switch (kind) {
      'git' => _GitCard(state: state),
      'media' => _MediaCard(state: state),
      'terminal' => _TerminalCard(state: state),
      _ => const SizedBox.shrink(),
    };
  }
}

class _CardShell extends StatelessWidget {
  const _CardShell({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _GitCard extends StatelessWidget {
  const _GitCard({required this.state});

  final Map<String, dynamic> state;

  @override
  Widget build(BuildContext context) {
    final git = (state['workspace']?['git'] as Map?)?.cast<String, dynamic>();
    if (git == null || git['available'] != true) {
      return const SizedBox.shrink();
    }

    final branch = git['branch'] as String?;
    final dirty = git['clean'] != true;
    final changed = git['changed_files'] as int? ?? 0;
    final ahead = git['ahead'] as int? ?? 0;
    final behind = git['behind'] as int? ?? 0;

    return _CardShell(
      title: 'Git status',
      icon: Icons.call_split,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _chip(
                icon: Icons.alt_route,
                label: branch ?? 'no branch',
                color: AppTheme.primary,
              ),
              if (dirty)
                _chip(
                  icon: Icons.edit,
                  label: '$changed changed',
                  color: AppTheme.accent,
                )
              else
                _chip(
                  icon: Icons.check,
                  label: 'clean',
                  color: AppTheme.success,
                ),
              if (ahead > 0)
                _chip(
                  icon: Icons.arrow_upward,
                  label: '$ahead ahead',
                  color: AppTheme.success,
                ),
              if (behind > 0)
                _chip(
                  icon: Icons.arrow_downward,
                  label: '$behind behind',
                  color: AppTheme.muted,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MediaCard extends StatelessWidget {
  const _MediaCard({required this.state});

  final Map<String, dynamic> state;

  @override
  Widget build(BuildContext context) {
    final media = (state['media'] as Map?)?.cast<String, dynamic>();
    final active = media?['active'] as Map<String, dynamic>?;
    if (media == null || media['available'] != true || active == null) {
      return const SizedBox.shrink();
    }

    final status = active['status'] as String? ?? 'Stopped';
    final title = active['title'] as String? ?? 'Unknown title';
    final artist = active['artist'] as String?;
    final playing = status == 'Playing';

    return _CardShell(
      title: 'Now playing',
      icon: Icons.music_note,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (artist != null && artist.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppTheme.muted),
            ),
          ],
          const SizedBox(height: 8),
          _chip(
            icon: playing ? Icons.pause_circle : Icons.play_circle,
            label: playing ? 'Playing' : 'Paused',
            color: playing ? AppTheme.success : AppTheme.muted,
          ),
        ],
      ),
    );
  }
}

/// Terminal card: the window title (most terminals put the running command
/// there), plus project + branch from the Context Engine. Real job tracking
/// (name + elapsed) lands with Phase 9 terminal jobs.
class _TerminalCard extends StatelessWidget {
  const _TerminalCard({required this.state});

  final Map<String, dynamic> state;

  @override
  Widget build(BuildContext context) {
    final contextData = (state['context'] as Map?)?.cast<String, dynamic>();
    if (contextData == null || contextData['available'] != true) {
      return const SizedBox.shrink();
    }

    final title = contextData['window_title'] as String? ?? '';
    final project = contextData['project'] as String?;
    final branch = contextData['branch'] as String?;
    final projectName =
        project == null
            ? null
            : (project.split('/').last.isEmpty
                ? project
                : project.split('/').last);

    return _CardShell(
      title: 'Terminal',
      icon: Icons.terminal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.isEmpty ? 'Focused terminal' : title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.onSurface,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (projectName != null)
                _chip(
                  icon: Icons.folder,
                  label: projectName,
                  color: AppTheme.primary,
                ),
              if (branch != null)
                _chip(
                  icon: Icons.alt_route,
                  label: branch,
                  color: AppTheme.success,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

Widget _chip({
  required IconData icon,
  required String label,
  required Color color,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: 0.4)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    ),
  );
}
