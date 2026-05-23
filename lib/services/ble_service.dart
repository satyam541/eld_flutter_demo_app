/// BLE service for the Geometris whereQube ELD.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
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
  final int? numSatellites;
  final int? coolantTempC;
  final double? fuelLevelPct;
  final double? throttlePct;
  final int? ignitionOnSec;
  final int? totalIdleSec;
  final String? dtc;
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
    this.numSatellites,
    this.coolantTempC,
    this.fuelLevelPct,
    this.throttlePct,
    this.ignitionOnSec,
    this.totalIdleSec,
    this.dtc,
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
        'numSatellites': numSatellites,
        'coolantTempC': coolantTempC,
        'fuelLevelPct': fuelLevelPct,
        'throttlePct': throttlePct,
        'ignitionOnSec': ignitionOnSec,
        'totalIdleSec': totalIdleSec,
        'dtc': dtc,
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
  int? _lastTs;
  final Set<int> _seenTlvIds = <int>{};

  Stream<GeometrisBlePacket> get packets => _packetController.stream;
  bool get connected => _device?.isConnected ?? false;
  String? get serialNumber => _serialNumber;
  Set<int> get seenTlvIds => Set.unmodifiable(_seenTlvIds);

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
    // On web, the browser only allows GATT access to services declared up
    // front. Without this, discoverServices() throws a SecurityError:
    // "Origin is not allowed to access any service".
    await FlutterBluePlus.startScan(
      timeout: timeout,
      webOptionalServices: [svcCsc],
    );
    await FlutterBluePlus.isScanning.where((s) => s == false).first;
    await sub.cancel();
    return results;
  }

  Future<void> connect(BluetoothDevice device) async {
    _device = device;
    _serialNumber = _serialFromName(device.platformName);
    debugPrint('[BLE] connecting to ${device.platformName} (${device.remoteId})...');
    await device.connect(timeout: const Duration(seconds: 12));
    debugPrint('[BLE] connected, discovering services...');
    final services = await device.discoverServices();
    debugPrint('[BLE] discovered ${services.length} service(s):');
    for (final svc in services) {
      debugPrint('[BLE]   service ${svc.uuid}');
      for (final c in svc.characteristics) {
        final p = c.properties;
        debugPrint('[BLE]     char ${c.uuid} '
            'notify=${p.notify} indicate=${p.indicate} '
            'write=${p.write} writeNR=${p.writeWithoutResponse} read=${p.read}');
      }
    }

    BluetoothCharacteristic? control;
    BluetoothCharacteristic? data;
    for (final svc in services) {
      for (final c in svc.characteristics) {
        if (c.uuid == chrObdControl) control = c;
        if (c.uuid == chrObdData) data = c;
      }
    }
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
    debugPrint('[BLE] selected data char ${data.uuid} '
        '(notify=${data.properties.notify} indicate=${data.properties.indicate}); '
        'control char ${control?.uuid}');

    // Enable notifications. NOTE: on web, flutter_blue_plus_web's
    // setNotifyValue successfully calls Chrome's startNotifications() (the
    // subscription goes live) but never emits the onDescriptorWritten/CCCD
    // event that the package's Dart layer waits for, so setNotifyValue always
    // throws a timeout even though notifications ARE active. We therefore treat
    // a timeout on web as success. On native we let the error propagate.
    debugPrint('[BLE] enabling notifications on ${data.uuid}...');
    try {
      await data.setNotifyValue(true);
      debugPrint('[BLE] notifications enabled');
    } catch (e) {
      if (kIsWeb) {
        debugPrint('[BLE] setNotifyValue timed out on web; subscription is '
            'active, proceeding: $e');
      } else {
        rethrow;
      }
    }
    _notifySub = data.lastValueStream.listen(_onNotify);

    // Start the OBD data stream. On Android this runs after notifications are
    // enabled; on web we reach here once startNotifications() has succeeded.
    if (control != null && control.properties.write) {
      debugPrint('[BLE] writing control [0x01,0x02] to ${control.uuid}...');
      try {
        await control.write([0x01, 0x02], withoutResponse: false);
        debugPrint('[BLE] control write ok');
      } catch (e) {
        debugPrint('[BLE] control write failed: $e');
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

  void _onNotify(List<int> bytes) {
    if (bytes.isEmpty) return;
    final tlv = _decodeTlv(Uint8List.fromList(bytes));
    if (tlv.isEmpty) return;

    _seenTlvIds.addAll(tlv.keys);
    if (kDebugMode) {
      debugPrint('[BLE] frame TLV IDs: ${tlv.keys.toList()..sort()}');
    }

    double? lat, lon, speed, heading, odo, fuel, throttle;
    int? ts, rpm, sats, coolant, ignOn, idleTotal;
    bool? ignition;
    String? vin, reason, dtc;

    tlv.forEach((id, value) {
      switch (id) {
        case 3:  lat = _bytesToDouble(value); break;
        case 4:  lon = _bytesToDouble(value); break;
        case 9:  reason = utf8.decode(value, allowMalformed: true).trim(); break;
        case 11: ignition = value.isNotEmpty && value[0] != 0; break;
        case 14: speed = _bytesToDouble(value); break;
        case 17: heading = _bytesToDouble(value); break;
        case 19: sats = _bytesToInt(value); break;
        case 24: odo = _bytesToDouble(value); break;
        case 36: ts = _bytesToInt(value); break;
        case 49: ignOn = _bytesToInt(value); break;
        case 50: idleTotal = _bytesToInt(value); break;
        case 70: rpm = _bytesToInt(value); break;
        case 71: coolant = _bytesToInt(value); break;
        case 74: vin = utf8.decode(value, allowMalformed: true).trim(); break;
        case 75: fuel = _bytesToDouble(value); break;
        case 76: dtc = utf8.decode(value, allowMalformed: true).trim(); break;
        case 77: throttle = _bytesToDouble(value); break;
      }
    });

    // FIX: don't drop frames missing timestamp — use last-known or device clock
    if (ts != null) {
      _lastTs = ts;
    } else {
      ts = _lastTs ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000);
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
        numSatellites: sats,
        coolantTempC: coolant,
        fuelLevelPct: fuel,
        throttlePct: throttle,
        ignitionOnSec: ignOn,
        totalIdleSec: idleTotal,
        dtc: dtc,
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
    if (v.length == 4) return ByteData.sublistView(v).getFloat32(0, Endian.little);
    if (v.length == 8) return ByteData.sublistView(v).getFloat64(0, Endian.little);
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
    if (!name.startsWith(namePrefix)) return null;
    return name.substring(namePrefix.length);
  }
}
