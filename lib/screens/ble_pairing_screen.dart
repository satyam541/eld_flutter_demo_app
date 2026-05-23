import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../providers/ble_provider.dart';

class BlePairingScreen extends StatefulWidget {
  const BlePairingScreen({super.key});
  @override
  State<BlePairingScreen> createState() => _BlePairingScreenState();
}

class _BlePairingScreenState extends State<BlePairingScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _ensurePermissions();
    });
  }

  Future<void> _ensurePermissions() async {
    // On web there are no runtime BLE permissions — the browser's device
    // chooser handles consent. permission_handler throws "Unsupported
    // operation" for bluetoothScan on web, so skip it.
    if (kIsWeb) return;
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();
  }

  @override
  Widget build(BuildContext context) {
    final ble = context.watch<BleProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Pair whereQube')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(child: Text(ble.status)),
                ElevatedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: Text(ble.scanning ? 'Scanning…' : 'Scan'),
                  onPressed: ble.scanning ? null : ble.scan,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              itemCount: ble.scanResults.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (ctx, i) {
                final r = ble.scanResults[i];
                return ListTile(
                  leading: const Icon(Icons.bluetooth),
                  title: Text(r.device.platformName),
                  subtitle: Text(
                    '${r.device.remoteId.str}  ·  ${r.rssi} dBm',
                  ),
                  trailing: ble.connecting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : ElevatedButton(
                          onPressed: () => ble.connect(r.device),
                          child: const Text('Connect'),
                        ),
                );
              },
            ),
          ),
          if (ble.connected)
            Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: ble.disconnect,
                  child: const Text('Disconnect'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
