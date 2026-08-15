import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:web_socket_channel/web_socket_channel.dart';

import '../protocol/message.dart';

enum TactConnectionStatus {
  disconnected,
  connecting,
  connected,
  reconnecting,
}

class TactClient {
  WebSocketChannel? _channel;
  StreamSubscription? _sub;

  String? _host;
  int? _port;
  String? _token;

  int _backoffMs = 500;
  bool _manuallyDisconnected = false;
  int _requestCounter = 0;

  final _messages = StreamController<TactMessage>.broadcast();
  final _status = StreamController<TactConnectionStatus>.broadcast();
  final Map<String, Completer<dynamic>> _pending = {};

  Stream<TactMessage> get messages => _messages.stream;
  Stream<TactConnectionStatus> get status => _status.stream;

  Duration? lastRoundTrip;

  Future<void> connect({
    required String host,
    required int port,
    required String token,
  }) async {
    _host = host.trim();
    _port = port;
    _token = token.trim();
    _manuallyDisconnected = false;
    _backoffMs = 500;

    await _openSocket();
  }

  Future<void> _openSocket() async {
    final host = _host;
    final port = _port;
    final token = _token;

    if (_manuallyDisconnected || host == null || port == null || token == null) {
      return;
    }

    _status.add(
      _backoffMs == 500
          ? TactConnectionStatus.connecting
          : TactConnectionStatus.reconnecting,
    );

    try {
      await _sub?.cancel();
      await _channel?.sink.close();

      final uri = Uri(
        scheme: 'ws',
        host: host,
        port: port,
        path: '/ws',
      );

      final channel = WebSocketChannel.connect(uri);
      _channel = channel;

      await channel.ready;

      channel.sink.add(
        jsonEncode({
          'type': 'auth',
          'token': token,
          'label': 'flutter-client',
        }),
      );

      _sub = channel.stream.listen(
        _onRaw,
        onDone: _handleDisconnect,
        onError: (_, __) => _handleDisconnect(),
        cancelOnError: true,
      );

      _backoffMs = 500;
      _status.add(TactConnectionStatus.connected);
    } catch (e) {
      _handleDisconnect();
    }
  }

  void _onRaw(dynamic raw) {
    try {
      final decoded = raw is String ? jsonDecode(raw) : raw;

      if (decoded is! Map) return;

      final json = Map<String, dynamic>.from(decoded);
      final msg = TactMessage.fromJson(json);

      if (msg is TactActionResult) {
        final requestId = msg.requestId;
        final actionId = msg.actionId;

        Completer<dynamic>? completer;

        if (requestId != null) {
          completer = _pending.remove(requestId);
        }

        completer ??= _pending.remove(actionId);

        // Remove the alias too when both keys were registered.
        if (requestId != null) {
          _pending.removeWhere(
            (key, value) => identical(value, completer),
          );
        }

        if (completer != null && !completer.isCompleted) {
          completer.complete(msg.result);
        }
      }

      _messages.add(msg);
    } catch (e) {
      // Ignore malformed messages without killing the WebSocket.
    }
  }

  Future<dynamic> sendAction(
    String actionId, [
    Map<String, dynamic>? payload,
  ]) {
    final channel = _channel;

    if (channel == null) {
      return Future.error(
        StateError('Not connected to Tact agent'),
      );
    }

    final requestId = 'r${_requestCounter++}';
    final completer = Completer<dynamic>();

    _pending[requestId] = completer;

    // Only use actionId as a fallback for the older agent protocol.
    _pending[actionId] = completer;

    channel.sink.add(
      jsonEncode({
        'type': 'action',
        'action_id': actionId,
        'request_id': requestId,
        'payload': payload ?? {},
      }),
    );

    return completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        _pending.removeWhere(
          (key, value) => identical(value, completer),
        );
        throw TimeoutException(
          'No response for $actionId',
        );
      },
    );
  }

  Future<Duration> ping() async {
    final sentAt = DateTime.now();
    final completer = Completer<void>();

    late StreamSubscription<TactMessage> sub;

    sub = messages.listen((message) {
      if (message is TactPong && !completer.isCompleted) {
        completer.complete();
        unawaited(sub.cancel());
      }
    });

    _channel?.sink.add(
      jsonEncode({
        'type': 'ping',
        't': sentAt.millisecondsSinceEpoch,
      }),
    );

    try {
      await completer.future.timeout(
        const Duration(seconds: 3),
      );
    } finally {
      await sub.cancel();
    }

    lastRoundTrip = DateTime.now().difference(sentAt);
    return lastRoundTrip!;
  }

  void _handleDisconnect() {
    if (_manuallyDisconnected) {
      _status.add(TactConnectionStatus.disconnected);
      return;
    }

    _status.add(TactConnectionStatus.reconnecting);

    final delay = _backoffMs;
    _backoffMs = math.min(_backoffMs * 2, 8000);

    Future<void>.delayed(
      Duration(milliseconds: delay),
      () {
        if (!_manuallyDisconnected) {
          _openSocket();
        }
      },
    );
  }

  void disconnect() {
    _manuallyDisconnected = true;

    _sub?.cancel();
    _sub = null;

    _channel?.sink.close();
    _channel = null;

    for (final completer in _pending.values) {
      if (!completer.isCompleted) {
        completer.completeError(
          StateError('Disconnected from Tact agent'),
        );
      }
    }
    _pending.clear();

    _status.add(TactConnectionStatus.disconnected);
  }

  void dispose() {
    disconnect();
    _messages.close();
    _status.close();
  }
}
