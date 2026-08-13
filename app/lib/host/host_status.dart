import 'dart:io';

class PendingPairing {
  final String pendingId;
  final String deviceId;
  final String label;
  final DateTime? createdAt;

  const PendingPairing({
    required this.pendingId,
    required this.deviceId,
    required this.label,
    this.createdAt,
  });
}

class HostStatus {
  final String hostname;
  final String ip;
  final int port;
  final String? otp;
  final String otpExpiresIn;
  final List<PendingPairing> pendingPairings;
  final int pairedDeviceCount;

  const HostStatus({
    required this.hostname,
    required this.ip,
    required this.port,
    required this.otp,
    required this.otpExpiresIn,
    required this.pendingPairings,
    required this.pairedDeviceCount,
  });

  factory HostStatus.fromDebugConfig(
    Map<String, dynamic> json, {
    required String ip,
    required int port,
  }) {
    final pending = <PendingPairing>[];

    final rawPending = json['pending_pairings'];

    if (rawPending is List) {
      for (final raw in rawPending) {
        if (raw is! Map) continue;

        final pendingId =
            raw['pending_id']?.toString() ?? '';

        if (pendingId.isEmpty) continue;

        final deviceId =
            raw['device_id']?.toString() ?? 'unknown';

        final rawLabel =
            raw['label']?.toString().trim();

        final label = rawLabel != null &&
                rawLabel.isNotEmpty
            ? rawLabel
            : deviceId;

        DateTime? createdAt;

        final rawCreated =
            raw['created_at'];

        if (rawCreated is String) {
          createdAt = DateTime.tryParse(
            rawCreated,
          )?.toLocal();
        }

        pending.add(
          PendingPairing(
            pendingId: pendingId,
            deviceId: deviceId,
            label: label,
            createdAt: createdAt,
          ),
        );
      }
    }

    final rawDevices = json['paired_devices'];

    final pairedDeviceCount =
        rawDevices is List
            ? rawDevices.length
            : 0;

    final rawOtp = json['pairing_token'];

    final otp = rawOtp is String &&
            rawOtp.isNotEmpty
        ? rawOtp
        : null;

    return HostStatus(
      hostname: Platform.localHostname,
      ip: ip,
      port: port,
      otp: otp,
      otpExpiresIn:
          _formatExpiry(
        json['pairing_token_expires'],
      ),
      pendingPairings: pending,
      pairedDeviceCount:
          pairedDeviceCount,
    );
  }

  static String _formatExpiry(dynamic raw) {
    if (raw == null) {
      return 'expired';
    }

    DateTime? expires;

    if (raw is num) {
      final seconds = raw.toDouble();

      if (seconds.isFinite && seconds > 0) {
        expires =
            DateTime.fromMillisecondsSinceEpoch(
          (seconds * 1000).round(),
          isUtc: true,
        ).toLocal();
      }
    } else if (raw is String) {
      final value = raw.trim();

      final numeric =
          double.tryParse(value);

      if (numeric != null &&
          numeric.isFinite &&
          numeric > 0) {
        expires =
            DateTime.fromMillisecondsSinceEpoch(
          (numeric * 1000).round(),
          isUtc: true,
        ).toLocal();
      } else {
        expires =
            DateTime.tryParse(value)?.toLocal();
      }
    }

    if (expires == null) {
      return 'expired';
    }

    final remaining =
        expires.difference(DateTime.now());

    if (remaining.isNegative ||
        remaining.inSeconds <= 0) {
      return 'expired';
    }

    if (remaining.inMinutes < 1) {
      return '<1m left';
    }

    return '${remaining.inMinutes}m left';
  }
}

Future<String> localIp() async {
  final candidates = <String>[];

  for (final iface
      in await NetworkInterface.list(
    type: InternetAddressType.IPv4,
  )) {
    for (final address
        in iface.addresses) {
      if (!address.isLoopback) {
        candidates.add(
          address.address,
        );
      }
    }
  }

  if (candidates.isEmpty) {
    return 'unknown';
  }

  final lan = candidates.where(
    (address) =>
        address.startsWith('192.168.') ||
        address.startsWith('10.') ||
        address.startsWith('172.16.') ||
        address.startsWith('172.17.') ||
        address.startsWith('172.18.') ||
        address.startsWith('172.19.') ||
        address.startsWith('172.2') ||
        address.startsWith('172.3'),
  );

  return lan.isNotEmpty
      ? lan.first
      : candidates.first;
}