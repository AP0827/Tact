/// Dart mirror of the JSON messages sent over the Tact agent's /ws endpoint.
/// Kept hand-written (no codegen) on purpose so this compiles with zero
/// build_runner step — swap for freezed/json_serializable later if the
/// schema grows.
sealed class TactMessage {
  const TactMessage();

  factory TactMessage.fromJson(Map<String, dynamic> json) {
    switch (json['type'] as String?) {
      case 'init':
        return TactInit(Map<String, dynamic>.from(json['payload'] ?? {}));
      case 'telemetry':
        return TactTelemetry(Map<String, dynamic>.from(json['payload'] ?? {}));
      case 'event':
        return TactEvent(Map<String, dynamic>.from(json['payload'] ?? {}));
      case 'action_result':
        return TactActionResult(
          actionId: json['action_id'] as String? ?? '',
          requestId: json['request_id'] as String?,
          result: json['result'],
        );
      case 'pong':
        return TactPong(json['t']);
      case 'error':
        return TactError(json['message'] as String? ?? 'unknown_error');
      default:
        return TactUnknown(json);
    }
  }
}

class TactInit extends TactMessage {
  final Map<String, dynamic> state;
  const TactInit(this.state);
}

class TactTelemetry extends TactMessage {
  final Map<String, dynamic> state;
  const TactTelemetry(this.state);
}

class TactEvent extends TactMessage {
  final Map<String, dynamic> payload;
  const TactEvent(this.payload);
}

/// `request_id` is null until the agent-side patch (see NOTES.md) lands —
/// TactClient falls back to correlating on `action_id` alone until then.
class TactActionResult extends TactMessage {
  final String actionId;
  final String? requestId;
  final dynamic result;
  const TactActionResult({required this.actionId, this.requestId, this.result});
}

/// Only arrives once the agent implements the ping/pong echo (see NOTES.md).
class TactPong extends TactMessage {
  final dynamic t;
  const TactPong(this.t);
}

class TactError extends TactMessage {
  final String message;
  const TactError(this.message);
}

class TactUnknown extends TactMessage {
  final Map<String, dynamic> raw;
  const TactUnknown(this.raw);
}
