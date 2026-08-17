import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/telemetry_provider.dart';
import '../../theme.dart';

/// Phase 2 context surface: a slim, always-visible strip showing what the
/// developer is doing right now (active app · project · branch · workflow).
/// This is the "Context" layer of the Tact Surface model — the rest of the
/// UI becomes contextual on top of this in Phase 3.
class ContextBanner extends ConsumerWidget {
  const ContextBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(tactStateProvider);
    final contextData = (state?['context'] as Map?)?.cast<String, dynamic>();
    if (contextData == null || contextData['available'] != true) {
      return const SizedBox.shrink();
    }

    final app = contextData['active_app'] as String?;
    final project = contextData['project'] as String?;
    final branch = contextData['branch'] as String?;
    final workflow = contextData['workflow'] as String?;

    final projectName = project == null
        ? null
        : project.split('/').last.isEmpty
            ? project
            : project.split('/').last;

    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Icon(_appIcon(app), size: 16, color: AppTheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              [
                if (app != null) _titleCase(app),
                if (projectName != null) projectName,
                if (branch != null) branch,
              ].join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          if (workflow != null) ...[
            const SizedBox(width: 8),
            _WorkflowChip(workflow: workflow),
          ],
        ],
      ),
    );
  }

  IconData _appIcon(String? app) {
    switch (app) {
      case 'vscode':
        return Icons.code;
      case 'terminal':
        return Icons.terminal;
      case 'chrome':
      case 'edge':
      case 'firefox':
        return Icons.public;
      case 'spotify':
        return Icons.music_note;
      case 'teams':
      case 'slack':
      case 'discord':
        return Icons.forum;
      case 'figma':
        return Icons.design_services;
      default:
        return Icons.apps;
    }
  }

  String _titleCase(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1);
  }
}

class _WorkflowChip extends StatelessWidget {
  final String workflow;

  const _WorkflowChip({required this.workflow});

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (workflow) {
      'development' => (AppTheme.primary, Icons.construction),
      'meeting' => (AppTheme.accent, Icons.videocam),
      'media' => (const Color(0xFF9C7BFF), Icons.headphones),
      'communication' => (const Color(0xFF34D1B2), Icons.chat_bubble),
      'design' => (const Color(0xFFFF6FA5), Icons.palette),
      _ => (AppTheme.muted, Icons.apps),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            workflow,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}
