import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/connection_provider.dart';
import '../../state/telemetry_provider.dart';
import '../../theme.dart';

/// Docker container status + lifecycle controls.
class DockerCard extends ConsumerStatefulWidget {
  const DockerCard({super.key});

  @override
  ConsumerState<DockerCard> createState() => _DockerCardState();
}

class _DockerCardState extends ConsumerState<DockerCard> {
  final Set<String> _busy = {};

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _run(String action, String name, {Map<String, dynamic>? payload}) async {
    setState(() => _busy.add('$action:$name'));
    try {
      final client = ref.read(tactClientProvider);
      await client.sendAction(action, payload ?? {'name': name});
      if (action == 'docker.start') _snack('Started $name');
      if (action == 'docker.stop') _snack('Stopped $name');
      if (action == 'docker.restart') _snack('Restarted $name');
    } catch (e) {
      _snack('$e');
    } finally {
      if (mounted) setState(() => _busy.remove('$action:$name'));
    }
  }

  Future<void> _showLogs(String name) async {
    try {
      final result = await ref
          .read(tactClientProvider)
          .sendAction('docker.logs', {'name': name, 'tail': 60});
      final inner =
          result is Map ? (result['result'] as Map?) ?? result : null;
      if (!mounted) return;
      final logs = (inner?['logs'] as String?) ?? 'No logs';
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppTheme.surface,
        builder: (context) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          builder: (context, controller) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$name — logs',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  controller: controller,
                  padding: const EdgeInsets.all(16),
                  child: SelectableText(
                    logs,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      height: 1.5,
                      color: AppTheme.onSurface,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      _snack('$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tactStateProvider);
    final docker = (state?['docker'] as Map?)?.cast<String, dynamic>();

    if (docker == null || docker['available'] != true) {
      final error = docker?['error'] as String?;
      final message = error == 'docker_permission_denied'
          ? 'Docker daemon unreachable — add your user to the docker group '
              'or start the daemon.'
          : (error ?? 'Docker unavailable');
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.view_agenda_outlined,
                  color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Docker: $message',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final containers =
        (docker['containers'] as List?)?.cast<Map<String, dynamic>>() ??
            const <Map<String, dynamic>>[];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Docker', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              containers.isEmpty ? 'No containers' : '${containers.length} containers',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (containers.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...containers.map((c) => _ContainerRow(
                    container: c,
                    busy: _busy,
                    onStart: () => _run('docker.start', c['name'] as String),
                    onStop: () => _run('docker.stop', c['name'] as String),
                    onRestart: () =>
                        _run('docker.restart', c['name'] as String),
                    onLogs: () => _showLogs(c['name'] as String),
                  )),
            ],
          ],
        ),
      ),
    );
  }
}

class _ContainerRow extends StatelessWidget {
  final Map<String, dynamic> container;
  final Set<String> busy;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onRestart;
  final VoidCallback onLogs;

  const _ContainerRow({
    required this.container,
    required this.busy,
    required this.onStart,
    required this.onStop,
    required this.onRestart,
    required this.onLogs,
  });

  @override
  Widget build(BuildContext context) {
    final name = container['name'] as String? ?? '?';
    final state = container['state'] as String? ?? 'unknown';
    final status = container['status'] as String? ?? '';
    final image = container['image'] as String? ?? '';

    final running = state == 'running';
    final color = running
        ? const Color(0xFF2ECC71)
        : state == 'restarting'
            ? AppTheme.accent
            : AppTheme.muted;

    final isBusy = busy.contains('docker.start:$name') ||
        busy.contains('docker.stop:$name') ||
        busy.contains('docker.restart:$name');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceHigh.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.surfaceHigh),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.circle, size: 10, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                if (isBusy)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.only(left: 18),
              child: Text(
                '$state · $image',
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            if (status.isNotEmpty) ...[
              const SizedBox(height: 2),
              Padding(
                padding: const EdgeInsets.only(left: 18),
                child: Text(
                  status,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                if (!running)
                  Expanded(
                    child: _RowButton(
                      label: 'Start',
                      icon: Icons.play_arrow,
                      onTap: onStart,
                    ),
                  )
                else ...[
                  Expanded(
                    child: _RowButton(
                      label: 'Stop',
                      icon: Icons.stop,
                      onTap: onStop,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _RowButton(
                      label: 'Restart',
                      icon: Icons.refresh,
                      onTap: onRestart,
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                Expanded(
                  child: _RowButton(
                    label: 'Logs',
                    icon: Icons.article_outlined,
                    onTap: onLogs,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RowButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _RowButton({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        side: BorderSide(color: AppTheme.surfaceHigh),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }
}
