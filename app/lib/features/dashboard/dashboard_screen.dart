import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/connection_provider.dart';
import '../../state/telemetry_provider.dart';
import '../actions/actions_grid.dart';
import '../git/git_card.dart';
import '../vscode/vscode_card.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(connectionStatusProvider);
    final state = ref.watch(tactStateProvider);

    return Scaffold(
      appBar: AppBar(title: Text('Tact — ${status.value?.name ?? '...'}')),
      body: state == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SystemSummary(system: (state['system'] as Map).cast<String, dynamic>()),
          const SizedBox(height: 16),
          const ActionsGrid(),
          const SizedBox(height: 16),
          const GitCard(),
          const SizedBox(height: 16),
          const VscodeCard(),
        ],
      ),
    );
  }
}

class _SystemSummary extends StatelessWidget {
  final Map<String, dynamic> system;
  const _SystemSummary({required this.system});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _Stat(label: 'CPU', value: system['cpu']),
            _Stat(label: 'RAM', value: system['memory']),
            _Stat(label: 'Disk', value: system['disk']),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final dynamic value; // nullable — e.g. disk is null if cwd doesn't exist
  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final text = value == null ? '—' : '${(value as num).toDouble().toStringAsFixed(0)}%';
    return Column(
      children: [
        Text(text, style: Theme.of(context).textTheme.headlineSmall),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
