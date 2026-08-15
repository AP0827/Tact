import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/tact_client.dart';

final tactClientProvider = Provider<TactClient>((ref) {
  final client = TactClient();
  ref.onDispose(client.dispose);
  return client;
});

final connectionStatusProvider = StreamProvider<TactConnectionStatus>((ref) {
  return ref.watch(tactClientProvider).status;
});
