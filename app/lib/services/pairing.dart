import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

/// Handles the agent's existing OTP pairing flow:
/// POST /api/pair/request -> laptop operator approves in /admin/pair/pending
/// -> poll /api/pair/me until paired -> persist device_id as the WS token.
class PairingService {
  static const _storage = FlutterSecureStorage();
  static const _deviceIdKey = 'tact_stable_device_id';
  static const _tokenKey = 'tact_pair_token';

  Future<String> _stableDeviceId() async {
    var id = await _storage.read(key: _deviceIdKey);
    if (id == null) {
      id = const Uuid().v4();
      await _storage.write(key: _deviceIdKey, value: id);
    }
    return id;
  }

  Future<String?> savedToken() => _storage.read(key: _tokenKey);

  Future<String> pairWithOtp({
    required String host,
    required int port,
    required String otp,
  }) async {
    final deviceId = await _stableDeviceId();
    final res = await http.post(
      Uri.parse('http://$host:$port/api/pair/request'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'token': otp, 'device_id': deviceId, 'label': 'Flutter client'}),
    );
    if (res.statusCode != 200) {
      throw Exception('Pairing request failed: ${res.body}');
    }

    final approved = await _pollUntilPaired(host: host, port: port, deviceId: deviceId);
    if (!approved) throw Exception('Pairing was not approved in time');

    await _storage.write(key: _tokenKey, value: deviceId);
    return deviceId;
  }

  Future<bool> _pollUntilPaired({
    required String host,
    required int port,
    required String deviceId,
    Duration timeout = const Duration(minutes: 5),
    Duration interval = const Duration(seconds: 2),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      final res = await http.get(Uri.parse('http://$host:$port/api/pair/me?device_id=$deviceId'));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        if (body['paired'] == true) return true;
      }
      await Future.delayed(interval);
    }
    return false;
  }

  Future<void> forget() async {
    await _storage.delete(key: _tokenKey);
  }
}
