/// BLE service for the Geometris whereQube ELD.
///
/// Protocol reference: docs/vendor/geometris-ble-protocol.md
///
/// Flow:
///   1. Scan for a peripheral whose name starts with "WQ-" advertising
///      service 0x1816 (Cycling Speed and Cadence — repurposed by the vendor).
///   2. Connect, discover services.
///   3. Discover the OBD service. Write [0x01, 0x02] to OBD_CONTROL
///      to request the current data dictionary.
///   4. Subscribe to OBD_DATA notifications. Each notification is a TLV
///      frame: [item_id (1B), len (1B), value (len B)] repeated.
///
/// NOTE: The OBD_DATA UUID printed in the vendor PDF is missing one hex
/// character ("0002a5b…" → likely "00002a5b-…"). We try the canonical
/// 128-bit form first, then fall back to a tolerant scan that subscribes
/// to every characteristic with NOTIFY support on the OBD service.

library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class GeometrisBlePacket {
  final String serialNumber;
  final int eventUnixTime;
  final double? latitude;
  final double? longitude;
  final double? speedMph;
  final double? heading;
  final bool? ignition;
  final double? odometerMiles;
  final int? rpm;
  final String? vin;
  final Map<int, dynamic> raw;
  final String? reasonText;

  GeometrisBlePacket({
    required this.serialNumber,
    required this.eventUnixTime,
    this.latitude,
    this.longitude,
    this.speedMph,
    this.heading,
    this.ignition,
    this.odometerMiles,
    this.rpm,
    this.vin,
    this.reasonText,
    required this.raw,
  });

  Map<String, dynamic> toJson() => {
        'serialNumber': serialNumber,
        'eventUnixTime': eventUnixTime,
        'latitude': latitude,
        'longitude': longitude,
        'speedMph': speedMph,
        'heading': heading,
        'ignition': ignition,
        'odometerMiles': odometerMiles,
        'rpm': rpm,
        'vin': vin,
        'reasonText': reasonText,
        'raw': raw.map((k, v) => MapEntry(k.toString(), v)),
      };
}

class BleService {
  static const String namePrefix = 'WQ-';
  static final Guid svcCsc = Guid('00001816-0000-1000-8000-00805f9b34fb');
  static final Guid chrObdControl =
      Guid('00002a57-0000-1000-8000-00805f9b34fb');
  static final Guid chrObdData = Guid('00002a5b-0000-1000-8000-00805f9b34fb');

  BluetoothDevice? _device;
  StreamSubscription<List<int>>? _notifySub;
  final _packetController = StreamController<GeometrisBlePacket>.broadcast();
  String? _serialNumber;

  Stream<GeometrisBlePacket> get packets => _packetController.stream;
  bool get connected => _device?.isConnected ?? false;
  String? get serialNumber => _serialNumber;

  Future<List<ScanResult>> scan(
      {Duration timeout = const Duration(seconds: 8)}) async {
    final results = <ScanResult>[];
    final sub = FlutterBluePlus.scanResults.listen((r) {
      for (final s in r) {
        if (s.device.platformName.startsWith(namePrefix) &&
            !results.any((x) => x.device.remoteId == s.device.remoteId)) {
          results.add(s);
        }
      }
    });
    await FlutterBluePlus.startScan(timeout: timeout);
    await FlutterBluePlus.isScanning.where((s) => s == false).first;
    await sub.cancel();
    return results;
  }

  Future<void> connect(BluetoothDevice device) async {
    _device = device;
    _serialNumber = _serialFromName(device.platformName);
    await device.connect(timeout: const Duration(seconds: 12));
    final services = await device.discoverServices();

    BluetoothCharacteristic? control;
    BluetoothCharacteristic? data;
    for (final svc in services) {
      for (final c in svc.characteristics) {
        if (c.uuid == chrObdControl) control = c;
        if (c.uuid == chrObdData) data = c;
      }
    }
    // Fallback: pick first NOTIFY characteristic on the CSC service.
    if (data == null) {
      for (final svc in services.where((s) => s.uuid == svcCsc)) {
        for (final c in svc.characteristics) {
          if (c.properties.notify) {
            data = c;
            break;
          }
        }
      }
    }
    if (data == null) {
      throw StateError(
        'OBD_DATA characteristic not found on ${device.platformName}',
      );
    }

    await data.setNotifyValue(true);
    _notifySub = data.lastValueStream.listen(_onNotify);

    // Request data dictionary if control characteristic exists.
    if (control != null && control.properties.write) {
      try {
        await control.write([0x01, 0x02], withoutResponse: false);
      } catch (_) {
        // Some firmware revisions reject the cmd silently — non-fatal.
      }
    }
  }

  Future<void> disconnect() async {
    await _notifySub?.cancel();
    _notifySub = null;
    final d = _device;
    _device = null;
    if (d != null && d.isConnected) {
      await d.disconnect();
    }
  }

  Future<void> dispose() async {
    await disconnect();
    await _packetController.close();
  }

  // ── Decoding ────────────────────────────────────────────────────────────

  void _onNotify(List<int> bytes) {
    if (bytes.isEmpty) return;
    final tlv = _decodeTlv(Uint8List.fromList(bytes));
    if (tlv.isEmpty) return;

    double? lat, lon, speed, heading, odo;
    int? ts, rpm;
    bool? ignition;
    String? vin, reason;

    tlv.forEach((id, value) {
      switch (id) {
        case 3:
          lat = _bytesToDouble(value);
          break;
        case 4:
          lon = _bytesToDouble(value);
          break;
        case 9:
          reason = utf8.decode(value, allowMalformed: true).trim();
          break;
        case 11:
          ignition = value.isNotEmpty && value[0] != 0;
          break;
        case 14:
          speed = _bytesToDouble(value);
          break;
        case 17:
          heading = _bytesToDouble(value);
          break;
        case 24:
          odo = _bytesToDouble(value);
          break;
        case 36:
          ts = _bytesToInt(value);
          break;
        case 70:
          rpm = _bytesToInt(value);
          break;
        case 74:
          vin = utf8.decode(value, allowMalformed: true).trim();
          break;
      }
    });

    if (ts == null) {
      // Some frames are partial; drop until we have a timestamp.
      return;
    }

    _packetController.add(
      GeometrisBlePacket(
        serialNumber: _serialNumber ?? 'UNKNOWN',
        eventUnixTime: ts!,
        latitude: lat,
        longitude: lon,
        speedMph: speed,
        heading: heading,
        ignition: ignition,
        odometerMiles: odo,
        rpm: rpm,
        vin: vin,
        reasonText: reason,
        raw: tlv.map((k, v) => MapEntry(k, v.toList())),
      ),
    );
  }

  Map<int, Uint8List> _decodeTlv(Uint8List bytes) {
    final out = <int, Uint8List>{};
    var i = 0;
    while (i + 2 <= bytes.length) {
      final id = bytes[i];
      final len = bytes[i + 1];
      if (i + 2 + len > bytes.length) break;
      out[id] = Uint8List.sublistView(bytes, i + 2, i + 2 + len);
      i += 2 + len;
    }
    return out;
  }

  double? _bytesToDouble(Uint8List v) {
    if (v.length == 4) {
      return ByteData.sublistView(v).getFloat32(0, Endian.little);
    }
    if (v.length == 8) {
      return ByteData.sublistView(v).getFloat64(0, Endian.little);
    }
    final i = _bytesToInt(v);
    return i?.toDouble();
  }

  int? _bytesToInt(Uint8List v) {
    if (v.isEmpty) return null;
    var n = 0;
    for (var i = v.length - 1; i >= 0; i--) {
      n = (n << 8) | v[i];
    }
    return n;
  }

  String? _serialFromName(String name) {
    // "WQ-88X150380033" → "88X150380033"
    if (!name.startsWith(namePrefix)) return null;
    return name.substring(namePrefix.length);
  }
}
