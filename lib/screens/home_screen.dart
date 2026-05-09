import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/ble_provider.dart';
import 'ble_pairing_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ble = context.watch<BleProvider>();
    final pkt = ble.lastPacket;

    return Scaffold(
      appBar: AppBar(title: const Text('Pacific ELD — Driver')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: ListTile(
                leading: Icon(
                  ble.connected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                  color: ble.connected ? Colors.green : Colors.grey,
                ),
                title: Text(ble.connected ? 'Connected' : 'Not connected'),
                subtitle: Text(ble.status),
                trailing: ElevatedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const BlePairingScreen()),
                  ),
                  child: const Text('Pair'),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Upload status', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('Packets received: ${ble.packetsReceived}'),
                    Text('Posted to portal: ${ble.packetsPosted}'),
                    Text('Failed: ${ble.packetsFailed}'),
                    if (ble.lastApiError != null) ...[
                      const SizedBox(height: 8),
                      Text('Last error: ${ble.lastApiError}',
                          style: const TextStyle(color: Colors.redAccent)),
                    ],
                    if (ble.seenTlvIds.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text('TLV IDs seen: ${(ble.seenTlvIds.toList()..sort()).join(", ")}',
                          style: const TextStyle(fontSize: 12)),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (pkt != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Last packet', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('Serial: ${pkt.serialNumber}'),
                      Text('Reason: ${pkt.reasonText ?? "—"}'),
                      Text('Lat/Lon: ${pkt.latitude?.toStringAsFixed(5) ?? "—"}, ${pkt.longitude?.toStringAsFixed(5) ?? "—"}'),
                      Text('Speed: ${pkt.speedMph?.toStringAsFixed(1) ?? "0"} mph'),
                      Text('Heading: ${pkt.heading?.toStringAsFixed(0) ?? "—"}°'),
                      Text('Ignition: ${pkt.ignition == true ? "ON" : "OFF"}'),
                      Text('RPM: ${pkt.rpm ?? "—"}'),
                      Text('VIN: ${pkt.vin ?? "—"}'),
                      Text('Satellites: ${pkt.numSatellites ?? "—"}'),
                      Text('Coolant: ${pkt.coolantTempC ?? "—"}°C'),
                      Text('Fuel: ${pkt.fuelLevelPct?.toStringAsFixed(1) ?? "—"}%'),
                      Text('Throttle: ${pkt.throttlePct?.toStringAsFixed(1) ?? "—"}%'),
                      Text('Odometer: ${pkt.odometerMiles?.toStringAsFixed(1) ?? "—"} mi'),
                      Text('DTC: ${pkt.dtc ?? "—"}'),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: const [
                _Tile(icon: Icons.assignment, label: 'DVIR'),
                _Tile(icon: Icons.history, label: 'HOS Log'),
                _Tile(icon: Icons.person, label: 'Driver'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100,
      height: 100,
      child: Card(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32),
            const SizedBox(height: 8),
            Text(label),
          ],
        ),
      ),
    );
  }
}
