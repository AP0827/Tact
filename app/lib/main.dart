import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/dashboard/dashboard_screen.dart';
import 'services/pairing.dart';
import 'state/connection_provider.dart';
import 'theme.dart';

void main() => runApp(const ProviderScope(child: TactApp()));

class TactApp extends StatelessWidget {
  const TactApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tact',
      theme: AppTheme.dark(),
      home: const ConnectScreen(),
    );
  }
}

/// Pairing entry point. Hands off to DashboardScreen (features/dashboard/)
/// once connected.
class ConnectScreen extends ConsumerStatefulWidget {
  const ConnectScreen({super.key});

  @override
  ConsumerState<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends ConsumerState<ConnectScreen> {
  final _host = TextEditingController();
  final _otp = TextEditingController();
  final _pairing = PairingService();
  bool _connecting = false;

  Future<void> _connect() async {
    setState(() => _connecting = true);
    try {
      var token = await _pairing.savedToken();
      token ??= await _pairing.pairWithOtp(host: _host.text, port: 8000, otp: _otp.text);
      await ref.read(tactClientProvider).connect(host: _host.text, port: 8000, token: token);
      if (mounted) {
        Navigator.of(context)
            .pushReplacement(MaterialPageRoute(builder: (_) => const DashboardScreen()));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Connect to Tact')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(controller: _host, decoration: const InputDecoration(labelText: 'Laptop IP')),
            TextField(controller: _otp, decoration: const InputDecoration(labelText: '6-digit OTP')),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _connecting ? null : _connect,
              child: _connecting
                  ? const SizedBox(
                  width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Connect'),
            ),
          ],
        ),
      ),
    );
  }
}
