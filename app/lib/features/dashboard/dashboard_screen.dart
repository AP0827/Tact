import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/connection_provider.dart';
import '../../state/telemetry_provider.dart';
import '../../theme.dart';
import '../../widgets/gauge.dart';
import '../actions/actions_grid.dart';
import '../apps/apps_tab.dart';
import '../clipboard/clipboard_card.dart';
import '../context/context_banner.dart';
import '../developer/developer_tab.dart';
import '../events/event_feed.dart';
import '../media/media_tab.dart';
import '../strip/control_strip.dart';
import '../surface/surface_tab.dart';

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
          : Column(
              children: [
                const ContextBanner(),
                Expanded(
                  child: IndexedStack(
                    index: _tab,
                    children: const [
                      SurfaceTab(),
                      AppsTab(),
                      _SystemTab(),
                      DeveloperTab(),
                      MediaTab(),
                      EventFeed(),
                    ],
                  ),
                ),
              ],
            ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ControlStrip(),
          NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (index) => setState(() => _tab = index),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.bolt), label: 'Surface'),
              NavigationDestination(icon: Icon(Icons.apps), label: 'Apps'),
              NavigationDestination(icon: Icon(Icons.monitor), label: 'System'),
              NavigationDestination(icon: Icon(Icons.developer_mode), label: 'Developer'),
              NavigationDestination(icon: Icon(Icons.headphones), label: 'Media'),
              NavigationDestination(icon: Icon(Icons.notifications), label: 'Events'),
            ],
          ),
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
        const SizedBox(height: 16),
        const ClipboardCard(),
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
    final battery = (system['battery'] as Map?)?.cast<String, dynamic>();
    final batteryOk = battery?['ok'] == true;
    final batteryPercent =
        (battery?['percent'] as num?)?.toDouble() ?? 0;
    final charging = battery?['charging'] == true;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            Row(
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
            if (batteryOk) ...[
              const SizedBox(height: 16),
              _BatteryChip(percent: batteryPercent, charging: charging),
            ],
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

class _BatteryChip extends StatelessWidget {
  final double percent;
  final bool charging;

  const _BatteryChip({required this.percent, required this.charging});

  @override
  Widget build(BuildContext context) {
    final color = percent <= 20
        ? const Color(0xFFFF4D5E)
        : percent <= 40
            ? AppTheme.accent
            : AppTheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceHigh.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            charging ? Icons.battery_charging_full : Icons.battery_std,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 8),
          Text(
            charging
                ? 'Charging · ${percent.round()}%'
                : 'Battery · ${percent.round()}%',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
          ),
        ],
      ),
    );
  }
}