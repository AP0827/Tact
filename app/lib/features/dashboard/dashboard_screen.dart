import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/connection_provider.dart';
import '../../state/telemetry_provider.dart';
import '../../theme.dart';
import '../../widgets/gauge.dart';
import '../actions/actions_grid.dart';
import '../developer/developer_tab.dart';
import '../events/event_feed.dart';
import '../media/media_tab.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(connectionStatusProvider);
    final state = ref.watch(tactStateProvider);

    return Scaffold(
      appBar: AppBar(title: Text('Tact — ${status.value?.name ?? '...'}')),
      body: state == null
          ? const Center(child: CircularProgressIndicator())
          : IndexedStack(
              index: _tab,
              children: const [
                _SystemTab(),
                DeveloperTab(),
                MediaTab(),
                EventFeed(),
              ],
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (index) => setState(() => _tab = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.monitor), label: 'System'),
          NavigationDestination(icon: Icon(Icons.developer_mode), label: 'Developer'),
          NavigationDestination(icon: Icon(Icons.headphones), label: 'Media'),
          NavigationDestination(icon: Icon(Icons.notifications), label: 'Events'),
        ],
      ),
    );
  }
}

class _SystemTab extends ConsumerWidget {
  const _SystemTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(tactStateProvider);
    final system =
        (state?['system'] as Map?)?.cast<String, dynamic>() ?? const {};

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SystemSummary(system: system),
        const SizedBox(height: 16),
        const ActionsGrid(),
      ],
    );
  }
}

class _SystemSummary extends StatelessWidget {
  final Map<String, dynamic> system;
  const _SystemSummary({required this.system});

  @override
  Widget build(BuildContext context) {
    final cpu = (system['cpu'] as num?)?.toDouble() ?? 0;
    final mem = (system['memory'] as num?)?.toDouble() ?? 0;
    final disk = (system['disk'] as num?)?.toDouble();

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Gauge(
              label: 'CPU',
              value: cpu,
              color: _gaugeColor(cpu),
              icon: Icons.memory,
            ),
            Gauge(
              label: 'RAM',
              value: mem,
              color: _gaugeColor(mem),
              icon: Icons.developer_board,
            ),
            Gauge(
              label: 'Disk',
              value: disk ?? 0,
              color: disk == null ? AppTheme.muted : _gaugeColor(disk),
              icon: Icons.storage,
            ),
          ],
        ),
      ),
    );
  }

  Color _gaugeColor(double value) {
    if (value >= 85) return const Color(0xFFFF4D5E);
    if (value >= 60) return AppTheme.accent;
    return AppTheme.primary;
  }
}