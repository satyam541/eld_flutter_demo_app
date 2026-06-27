/// BLE service for the Geometris whereQube ELD.
library;

import 'dart:async';
import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../debug/frame_analyzer.dart';
import '../debug/frame_compare.dart';
import '../debug/parser_audit.dart';
import 'geometris_decoder.dart';
import 'geometris_frame_parser.dart';

class GeometrisBlePacket {
  final int? frameId;
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
    this.frameId,
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
        if (frameId != null) 'frameId': frameId,
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
  static final Guid chrObdControl = Guid('00002a57-0000-1000-8000-00805f9b34fb');
  static final Guid chrObdData = Guid('00002a5b-0000-1000-8000-00805f9b34fb');

  BluetoothDevice? _device;
  StreamSubscription<List<int>>? _notifySub;
  final _packetController = StreamController<GeometrisBlePacket>.broadcast();
  String? _serialNumber;
  int? _lastTs;
  final Set<int> _seenTlvIds = <int>{};
  int _frameIdCounter = 0;
  Uint8List? _lastFrame;
  DateTime? _frameStartTime;

  // ── Reassembly State ────────────────────────────────────────────────
  final Map<int, Uint8List> _packets = {};
  int _protocolId = -1;
  int _totalPacketCount = 0;
  int _expectedPayloadLength = 0;

  int _notificationCounter = 0;
  int _frameCounter = 0;
  final Map<Guid, int> _notificationCounts = {};
  final List<StreamSubscription<List<int>>> _diagnosticSubs = [];
  Timer? _statsTimer;

  Stream<GeometrisBlePacket> get packets => _packetController.stream;
  bool get connected => _device?.isConnected ?? false;
  String? get serialNumber => _serialNumber;
  Set<int> get seenTlvIds => Set.unmodifiable(_seenTlvIds);

  @visibleForTesting
  void handleNotifyForTesting(List<int> bytes) {
    _onNotify(bytes);
  }

  Future<List<ScanResult>> scan({Duration timeout = const Duration(seconds: 8)}) async {
    final results = <ScanResult>[];
    final sub = FlutterBluePlus.scanResults.listen((r) {
      for (final s in r) {
        if (s.device.platformName.startsWith(namePrefix) && !results.any((x) => x.device.remoteId == s.device.remoteId)) {
          results.add(s);
        }
      }
    });
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
    await device.connect(timeout: const Duration(seconds: 12));
    final services = await device.discoverServices();

    // 1. Log All BLE Services
    final servicesBuffer = StringBuffer();
    servicesBuffer.writeln('================ BLE SERVICES ================\n');
    for (final svc in services) {
      servicesBuffer.writeln('SERVICE:\n${svc.uuid}\n');
    }
    servicesBuffer.writeln('==============================================');
    print(servicesBuffer.toString());

    // 2. Log Every Characteristic
    final charBuffer = StringBuffer();
    charBuffer.writeln('================ CHARACTERISTICS ================\n');
    final allChars = services.expand((s) => s.characteristics).toList();
    for (int i = 0; i < allChars.length; i++) {
      final c = allChars[i];
      charBuffer.writeln('Characteristic:\n${_formatUuid(c.uuid)}\n\n'
          'Read: ${c.properties.read}\n'
          'Write: ${c.properties.write}\n'
          'WriteWithoutResponse: ${c.properties.writeWithoutResponse}\n'
          'Notify: ${c.properties.notify}\n'
          'Indicate: ${c.properties.indicate}');
      if (i < allChars.length - 1) {
        charBuffer.writeln('\n------------------------------------\n');
      } else {
        charBuffer.writeln();
      }
    }
    charBuffer.write('=================================================');
    print(charBuffer.toString());

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
      throw StateError('OBD_DATA characteristic not found on ${device.platformName}');
    }

    try {
      await data.setNotifyValue(true);
    } catch (e) {
      if (!kIsWeb) rethrow;
    }
    _notifySub = data.lastValueStream.listen(_onNotify);

    // Reset stats
    _notificationCounter = 0;
    _notificationCounts.clear();
    for (final sub in _diagnosticSubs) {
      await sub.cancel();
    }
    _diagnosticSubs.clear();
    _statsTimer?.cancel();

    // 3. Subscribe to Every Notify Characteristic
    for (final svc in services) {
      for (final c in svc.characteristics) {
        if (c.properties.notify || c.properties.indicate) {
          _notificationCounts[c.uuid] = 0;
          try {
            await c.setNotifyValue(true);
            final sub = c.lastValueStream.listen((bytes) {
              if (bytes.isEmpty) return;
              _notificationCounter++;
              _notificationCounts[c.uuid] = (_notificationCounts[c.uuid] ?? 0) + 1;

              final timestamp = DateTime.now().toUtc().toIso8601String();
              final hexPayload = bytes.map((e) => e.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');

              print('Notification #$_notificationCounter\n\n'
                  'Characteristic: ${_formatUuid(c.uuid)}\n\n'
                  'Length: ${bytes.length}\n\n'
                  'Hex:\n\n'
                  '$hexPayload\n\n'
                  'Timestamp:\n\n'
                  '$timestamp\n\n'
                  '----------------------------------');
            });
            _diagnosticSubs.add(sub);
          } catch (e) {
            print('Failed to subscribe/notify for diagnostic characteristic ${c.uuid}: $e');
          }
        }
      }
    }

    // 5. Maintain Per-Characteristic Statistics
    _statsTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      final buffer = StringBuffer();
      buffer.writeln('=========== BLE STATISTICS ===========\n');
      final entries = _notificationCounts.entries.toList();
      for (int i = 0; i < entries.length; i++) {
        final entry = entries[i];
        buffer.writeln('${_formatUuid(entry.key)}\n\n'
            'Notifications:\n'
            '${entry.value}');
        if (i < entries.length - 1) {
          buffer.writeln('\n--------------------------------\n');
        } else {
          buffer.writeln();
        }
      }
      buffer.write('======================================');
      print(buffer.toString());
    });

    if (control != null && control.properties.write) {
      try {
        await _writeCharacteristic(control, [0x01, 0x02], withoutResponse: false);
      } catch (_) {}
    }
  }

  Future<void> disconnect() async {
    await _notifySub?.cancel();
    _notifySub = null;
    _statsTimer?.cancel();
    _statsTimer = null;
    for (final sub in _diagnosticSubs) {
      await sub.cancel();
    }
    _diagnosticSubs.clear();
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

    final int packetIndex = bytes[0];
    final timestamp = DateTime.now();

    // 1. Packet 0 validation
    if (packetIndex == 0) {
      _packets.clear();
      _protocolId = -1;
      _totalPacketCount = 0;
      _expectedPayloadLength = 0;
      _frameStartTime = timestamp;

      if (bytes.length > 1 && bytes[1] == 0xCB) {
        if (bytes.length > 3) {
          _protocolId = bytes[2];
          _totalPacketCount = bytes[3];
        }
        if (bytes.length > 6) {
          final int totalDataLength = bytes[5] | (bytes[6] << 8);
          // Since Total Data Length includes the length bytes and is in words,
          // the payload length is (totalDataLength * 2) - 2.
          _expectedPayloadLength = (totalDataLength * 2) - 2;
        }
      } else {
        _log('Legacy frame detected', name: 'BLE_REASSEMBLY');
        // Do not insert or parse, ignore it for protocol v1 parsing
        return;
      }
    } else {
      // Ignore packets > 0 if we haven't received Packet 0 yet
      if (_packets.isEmpty) {
        _log('Ignoring packet index $packetIndex because Packet 0 has not been received yet.', name: 'BLE_REASSEMBLY');
        return;
      }
    }

    // Insert packet into map
    _packets[packetIndex] = Uint8List.fromList(bytes);

    // Compute missing packets
    final List<int> missingPackets = [];
    if (_totalPacketCount > 0) {
      for (int i = 0; i < _totalPacketCount; i++) {
        if (!_packets.containsKey(i)) {
          missingPackets.add(i);
        }
      }
    }

    final bool completed = _totalPacketCount > 0 && _packets.length == _totalPacketCount;

    _log(
      '========== BLE Packet Received ==========\n'
      'Packet Index           : $packetIndex\n'
      'Protocol ID            : $_protocolId\n'
      'Total Packet Count     : $_totalPacketCount\n'
      'Expected Payload Length: $_expectedPayloadLength\n'
      'Packets Received       : ${_packets.keys.toList()..sort()}\n'
      'Missing Packet Indexes : ${missingPackets.isEmpty ? "None" : missingPackets.join(", ")}\n'
      'Frame Completed        : $completed\n'
      'Raw Hex                : ${bytes.map((e) => e.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ')}\n'
      '==========================================',
      name: 'BLE_REASSEMBLY',
    );

    if (completed) {
      _processReassembledFrame();
    }
  }

  void _processReassembledFrame() {
    final List<int> payloadList = [];

    // Packet 0: copy bytes from offset 7 onward
    final packet0 = _packets[0];
    if (packet0 != null && packet0.length > 7) {
      payloadList.addAll(packet0.sublist(7));
    }

    // Packets 1..N: copy bytes from offset 1 onward
    for (int i = 1; i < _totalPacketCount; i++) {
      final packetN = _packets[i];
      if (packetN != null && packetN.length > 1) {
        payloadList.addAll(packetN.sublist(1));
      }
    }

    final Uint8List payload = Uint8List.fromList(payloadList);
    final String payloadHex = payload.map((e) => e.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');

    _log(
      '========== Reassembled Payload ==========\n'
      'Expected Payload Length: $_expectedPayloadLength\n'
      'Payload Length         : ${payload.length}\n'
      'Payload Hex            : $payloadHex\n'
      '==========================================',
      name: 'BLE_REASSEMBLY',
    );

    if (payload.length != _expectedPayloadLength) {
      _log(
        'Payload length mismatch: expected $_expectedPayloadLength bytes, got ${payload.length} bytes. Aborting parse.',
        name: 'BLE_REASSEMBLY',
      );
      return;
    }

    // 7. Log Complete Frames
    _frameCounter++;
    print('================ FRAME =================\n\n'
        'Frame Number:\n\n'
        '$_frameCounter\n\n'
        'Fragments Received:\n\n'
        '${_packets.length} / $_totalPacketCount\n\n'
        'Payload Length:\n\n'
        '${payload.length}\n\n'
        'Payload:\n\n'
        '$payloadHex\n\n'
        '========================================');

    final fields = GeometrisFrameParser.parseFrame(payload);
    _log('Frame Parsed Successfully: ${fields.isNotEmpty}', name: 'BLE_REASSEMBLY');

    // 8. Log Parsed Field IDs
    final fieldsBuffer = StringBuffer();
    fieldsBuffer.writeln('============= RAW FIELDS ==============\n\n'
        'Frame:\n\n'
        '$_frameCounter\n\n'
        'Field Count:\n\n'
        '${fields.length}\n\n'
        'Fields:\n');
    for (final fieldId in fields.keys) {
      fieldsBuffer.writeln('0x${fieldId.toRadixString(16).padLeft(2, '0').toUpperCase()}\n');
    }
    fieldsBuffer.write('=======================================');
    print(fieldsBuffer.toString());

    // 9. Track Raw RPM Bytes
    if (fields.containsKey(0x03)) {
      final rawBytes = fields[0x03]!;
      final decoded = GeometrisDecoder.readInt32(rawBytes);
      final rawHex = rawBytes.map((e) => e.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
      print('Frame:\n\n'
          '$_frameCounter\n\n'
          'Field:\n\n'
          '0x03\n\n'
          'Raw:\n\n'
          '$rawHex\n\n'
          'Decoded:\n\n'
          '$decoded');
    }

    final frameId = ++_frameIdCounter;
    _seenTlvIds.addAll(fields.keys);

    final serial = _serialNumber ?? 'UNKNOWN';
    final fallbackTs = _lastTs ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000);

    final packet = GeometrisDecoder.decode(
      fields,
      fallbackSerial: serial,
      fallbackTimestamp: fallbackTs,
      frameId: frameId,
    );

    _lastTs = packet.eventUnixTime;

    // Trigger diagnostics on payload
    FrameAnalyzer.analyzeFrame(payload, frameId);
    if (_lastFrame != null) {
      FrameCompare.compareFrames(_lastFrame!, payload, frameId - 1, frameId);
    }
    _lastFrame = payload;

    ParserAudit.printParserAudit(packet, frameId, payload);
    ParserAudit.printParsedPacket(packet, frameId);

    final streamAddTimestamp = DateTime.now();
    if (_frameStartTime != null) {
      ParserAudit.printTimingAudit(frameId, _frameStartTime!, streamAddTimestamp);
    }

    _log(
      'Sending packet to stream: frameId=$frameId, ignition=${packet.ignition == true ? "ON" : "OFF"}, rpm=${packet.rpm ?? "null"}, speed=${packet.speedMph ?? "null"}, odometer=${packet.odometerMiles ?? "null"}',
      name: 'STREAM_AUDIT',
    );

    _packetController.add(packet);

    // Reset state ready for next frame
    _packets.clear();
    _protocolId = -1;
    _totalPacketCount = 0;
    _expectedPayloadLength = 0;
  }

  void _log(String message, {required String name}) {
    developer.log(message, name: name);
    print('[$name] $message');
  }

  String? _serialFromName(String name) {
    if (!name.startsWith(namePrefix)) return null;
    return name.substring(namePrefix.length);
  }

  String _formatUuid(Guid uuid) {
    final str = uuid.toString().toUpperCase();
    if (str.startsWith('0000') && str.endsWith('-0000-1000-8000-00805F9B34FB')) {
      return str.substring(4, 8);
    }
    return str;
  }

  Future<void> _writeCharacteristic(BluetoothCharacteristic characteristic, List<int> value, {bool withoutResponse = false}) async {
    final timestamp = DateTime.now().toUtc().toIso8601String();
    final hexPayload = value.map((e) => e.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');

    print('=============== BLE WRITE ===============\n\n'
        'Characteristic:\n\n'
        '${_formatUuid(characteristic.uuid)}\n\n'
        'Payload:\n\n'
        '$hexPayload\n\n'
        'Without Response:\n\n'
        '$withoutResponse\n\n'
        'Timestamp:\n\n'
        '$timestamp\n\n'
        '=========================================');

    await characteristic.write(value, withoutResponse: withoutResponse);
  }
}
