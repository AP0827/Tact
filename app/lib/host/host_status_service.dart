import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'host_status.dart';

class HostStatusService extends ChangeNotifier {
  HostStatusService({
    int port = 8000,
    this.pollInterval = const Duration(seconds: 4),
  }) : _port = port;

  int _port;
  final Duration pollInterval;

  HostStatus? status;
  Object? lastError;

  Timer? _timer;
  String _ip = 'unknown';
  bool _disposed = false;
  Future<void>? _refreshInFlight;

  int get port => _port;

  Future<void> start() async {
    if (_disposed) return;

    try {
      _ip = await localIp();
    } catch (e) {
      _ip = 'unknown';
      debugPrint('Unable to determine local IP: $e');
    }

    if (_disposed) return;

    await refreshNow();

    if (_disposed) return;

    _timer?.cancel();

    _timer = Timer.periodic(
      pollInterval,
      (_) => refreshNow(),
    );
  }

  Future<void> updatePort(int newPort) async {
    if (_disposed || newPort == _port) return;

    _port = newPort;
    status = null;
    lastError = null;

    notifyListeners();

    await refreshNow();
  }

  Future<void> regenerateOtp() async {
    if (_disposed) return;

    try {
      final response = await http
          .post(
            Uri.parse(
              'http://127.0.0.1:$_port/api/debug/regenerate-otp',
            ),
          )
          .timeout(const Duration(seconds: 3));

      if (response.statusCode != 200) {
        throw HttpException(
          'Agent returned HTTP ${response.statusCode}',
        );
      }

      await refreshNow();
    } catch (e) {
      lastError = e;

      debugPrint(
        'Failed to regenerate OTP: $e',
      );

      if (!_disposed) {
        notifyListeners();
      }

      rethrow;
    }
  }

  Future<void> approvePairing(String pendingId) async {
    if (_disposed) return;

    final response = await http
        .post(
          Uri.parse(
            'http://127.0.0.1:$_port/api/pair/approve',
          ),
          headers: {
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'pending_id': pendingId,
          }),
        )
        .timeout(const Duration(seconds: 3));

    if (response.statusCode != 200) {
      throw HttpException(
        'Approval failed (${response.statusCode}): ${response.body}',
      );
    }

    await refreshNow();
  }

  Future<void> rejectPairing(String pendingId) async {
    if (_disposed) return;

    final response = await http
        .post(
          Uri.parse(
            'http://127.0.0.1:$_port/api/pair/reject',
          ),
          headers: {
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'pending_id': pendingId,
          }),
        )
        .timeout(const Duration(seconds: 3));

    if (response.statusCode != 200) {
      throw HttpException(
        'Rejection failed (${response.statusCode}): ${response.body}',
      );
    }

    await refreshNow();
  }

  Future<void> approveAllPairings() async {
    final pending = status?.pendingPairings ?? const [];

    for (final pairing in List<PendingPairing>.from(pending)) {
      try {
        await approvePairing(pairing.pendingId);
      } catch (e) {
        debugPrint(
          'Failed to approve ${pairing.pendingId}: $e',
        );
      }
    }

    await refreshNow();
  }

  Future<void> refreshNow() {
    if (_disposed) return Future.value();

    final existing = _refreshInFlight;

    if (existing != null) {
      return existing;
    }

    final future = _refresh();

    _refreshInFlight = future;

    return future.whenComplete(() {
      if (identical(_refreshInFlight, future)) {
        _refreshInFlight = null;
      }
    });
  }

  Future<void> _refresh() async {
    try {
      final response = await http
          .get(
            Uri.parse(
              'http://127.0.0.1:$_port/api/debug/config',
            ),
          )
          .timeout(const Duration(seconds: 3));

      if (response.statusCode != 200) {
        throw HttpException(
          'Agent returned HTTP ${response.statusCode}',
        );
      }

      final decoded = jsonDecode(response.body);

      if (decoded is! Map) {
        throw const FormatException(
          'Agent returned an invalid JSON object',
        );
      }

      final json = Map<String, dynamic>.from(decoded);

      final newStatus = HostStatus.fromDebugConfig(
        json,
        ip: _ip,
        port: _port,
      );

      if (_disposed) return;

      status = newStatus;
      lastError = null;
    } catch (e) {
      if (_disposed) return;

      lastError = e;

      debugPrint(
        'HostStatusService refresh failed: $e',
      );
    }

    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;

    _timer?.cancel();
    _timer = null;

    super.dispose();
  }
}