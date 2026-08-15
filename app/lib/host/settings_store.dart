import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Small persisted-settings wrapper for the host companion. Reuses
/// flutter_secure_storage since it's already a project dependency for
/// the pairing token — no need for a second storage package just for
/// one integer.
class SettingsStore {
  static const _storage = FlutterSecureStorage();
  static const _portKey = 'tact_host_agent_port';

  Future<int> loadPort({int fallback = 8000}) async {
    final raw = await _storage.read(key: _portKey);
    if (raw == null) return fallback;
    return int.tryParse(raw) ?? fallback;
  }

  Future<void> savePort(int port) => _storage.write(key: _portKey, value: '$port');
}
