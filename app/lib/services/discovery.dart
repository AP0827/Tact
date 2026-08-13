import 'package:multicast_dns/multicast_dns.dart';

/// Looks for a Tact agent advertising itself via mDNS as `_tact._tcp.local`.
///
/// NOTE: the current Python agent does NOT advertise mDNS yet, so this will
/// return an empty list until the agent side adds `zeroconf` registration
/// (see NOTES.md for the ~6-line backend addition). Until then, use
/// PairingService with a manually-entered host — it works fine on LAN.
class TactDiscovery {
  static const _serviceType = '_tact._tcp.local';

  Future<List<DiscoveredAgent>> discover({Duration timeout = const Duration(seconds: 4)}) async {
    final client = MDnsClient();
    final found = <DiscoveredAgent>[];
    await client.start();
    try {
      await for (final ptr in client
          .lookup<PtrResourceRecord>(ResourceRecordQuery.serverPointer(_serviceType))
          .timeout(timeout, onTimeout: (sink) => sink.close())) {
        await for (final srv
        in client.lookup<SrvResourceRecord>(ResourceRecordQuery.service(ptr.domainName))) {
          await for (final ip in client
              .lookup<IPAddressResourceRecord>(ResourceRecordQuery.addressIPv4(srv.target))) {
            found.add(DiscoveredAgent(host: ip.address.address, port: srv.port));
          }
        }
      }
    } finally {
      client.stop();
    }
    return found;
  }
}

class DiscoveredAgent {
  final String host;
  final int port;
  const DiscoveredAgent({required this.host, required this.port});
}
