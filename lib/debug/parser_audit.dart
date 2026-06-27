import 'dart:typed_data';
import 'dart:developer' as developer;
import '../services/ble_service.dart';

/// Static helper to perform dashboard validation checks and format parsed packet/timing logs.
class ParserAudit {
  /// Prints comparison against expected dashboard references.
  static void printParserAudit(GeometrisBlePacket pkt, int frameId, Uint8List frame) {
    final buffer = StringBuffer();
    buffer.writeln('══════════════════════════════════════════════');
    buffer.writeln('📋 Parser & Dashboard Audit (Frame #$frameId)');
    buffer.writeln('══════════════════════════════════════════════');
    buffer.writeln('Comparing parsed telemetry against known dashboard values:');
    buffer.writeln('Engine: RUNNING | Odometer: 14132 km (~8781 mi) | Fuel: 80-90% | Speed: 0');

    void auditField({
      required String property,
      required String rawBytes,
      required String decoder,
      required dynamic expected,
      required dynamic actual,
      required bool status,
      required String source,
    }) {
      buffer.writeln('\nProperty   : $property');
      buffer.writeln('Raw Bytes  : $rawBytes');
      buffer.writeln('Decoder    : $decoder');
      buffer.writeln('Source     : $source');
      buffer.writeln('Expected   : $expected');
      buffer.writeln('Actual     : ${actual ?? "--"}');
      buffer.writeln('Status     : ${status ? "✅ Correct" : "❌ Incorrect"}');
    }

    // 1. RPM
    final hasRpm = pkt.raw.containsKey(0x03);
    final rpmBytes = hasRpm ? (pkt.raw[0x03] as List<int>).map((e) => e.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ') : '—';
    final isRpmOk = pkt.rpm != null && pkt.rpm! >= 350 && pkt.rpm! <= 900;
    auditField(
      property: 'Engine RPM',
      rawBytes: rpmBytes,
      decoder: 'Word-swapped Int32 (Field 0x03)',
      expected: '750 - 900 RPM (or test 400 RPM)',
      actual: pkt.rpm,
      status: isRpmOk,
      source: 'BLE Field 0x03',
    );

    // 2. Speed
    final hasSpeed = pkt.raw.containsKey(0x05);
    final speedBytes =
        hasSpeed ? (pkt.raw[0x05] as List<int>).map((e) => e.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ') : '—';
    final isSpeedOk = pkt.speedMph != null && pkt.speedMph! >= 0.0;
    auditField(
      property: 'GPS Speed',
      rawBytes: speedBytes,
      decoder: 'Word-swapped Int32 (Field 0x05)',
      expected: '0 mph or test 50 mph',
      actual: pkt.speedMph,
      status: isSpeedOk,
      source: 'BLE Field 0x05',
    );

    // 3. Odometer
    final hasOdo = pkt.raw.containsKey(0x02);
    final odoBytes = hasOdo ? (pkt.raw[0x02] as List<int>).map((e) => e.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ') : '—';
    final isOdoOk = pkt.odometerMiles != null && ((pkt.odometerMiles! / 0.621371) > 300.0);
    auditField(
      property: 'Odometer',
      rawBytes: odoBytes,
      decoder: 'Word-swapped Int32 (Field 0x02)',
      expected: '14132 km or test 597 km',
      actual: pkt.odometerMiles != null ? pkt.odometerMiles! / 0.621371 : null,
      status: isOdoOk,
      source: 'BLE Field 0x02',
    );

    // 4. Fuel Level
    final hasFuel = pkt.raw.containsKey(0x06);
    final fuelBytes = hasFuel ? (pkt.raw[0x06] as List<int>).map((e) => e.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ') : '—';
    final isFuelOk = pkt.fuelLevelPct == null || (pkt.fuelLevelPct! >= 80 && pkt.fuelLevelPct! <= 90);
    auditField(
      property: 'Fuel Level',
      rawBytes: fuelBytes,
      decoder: 'Word-swapped Int32 (Field 0x06)',
      expected: '80 - 90 %',
      actual: pkt.fuelLevelPct,
      status: isFuelOk,
      source: 'BLE Field 0x06',
    );

    // 5. Ignition
    final isIgnOk = pkt.ignition == true;
    auditField(
      property: 'Ignition',
      rawBytes: '—',
      decoder: 'RPM > 0',
      expected: 'true (ON)',
      actual: pkt.ignition,
      status: isIgnOk,
      source: 'Derived from RPM',
    );

    // 6. VIN
    final hasVin = pkt.raw.containsKey(0x01);
    final isVinOk = pkt.vin == '1N6DD26T44CD41733' || pkt.vin == '1N6DD26T44C441733';
    auditField(
      property: 'VIN',
      rawBytes: hasVin ? 'See UTF-16 representation' : '—',
      decoder: 'UTF-16LE String (Field 0x01)',
      expected: '1N6DD26T44CD41733 or 1N6DD26T44C441733',
      actual: pkt.vin,
      status: isVinOk,
      source: 'BLE Field 0x01',
    );

    // Log sequentially parsed fields
    buffer.writeln('\n--- SEQUENTIALLY PARSED FIELDS ---');
    pkt.raw.forEach((id, val) {
      buffer.writeln('Field 0x${id.toRadixString(16).padLeft(2, '0').toUpperCase()} (${id.toString().padRight(3)}): ${val.toString()}');
    });

    buffer.writeln('\n--- OTHER PROPERTIES ---');
    buffer.writeln('Latitude      : ${pkt.latitude != null ? "${pkt.latitude}°" : "--"}');
    buffer.writeln('Longitude     : ${pkt.longitude != null ? "${pkt.longitude}°" : "--"}');
    buffer.writeln('Heading       : ${pkt.heading != null ? "${pkt.heading}°" : "--"}');
    buffer.writeln('Coolant Temp  : ${pkt.coolantTempC != null ? "${pkt.coolantTempC}°C" : "--"}');
    buffer.writeln('Throttle      : ${pkt.throttlePct != null ? "${pkt.throttlePct}%" : "--"}');
    buffer.writeln('Engine Hours  : ${pkt.ignitionOnSec != null ? (pkt.ignitionOnSec! / 3600.0).toStringAsFixed(1) : "--"} hours');
    buffer.writeln('Event Time    : ${pkt.eventUnixTime}');

    buffer.writeln('══════════════════════════════════════════════');

    final message = buffer.toString();
    developer.log(message, name: 'PARSER_AUDIT');
    print('[PARSER_AUDIT] $message');
  }

  /// Prints the final Geometris packet values, formatting missing values with double dashes `--`.
  static void printParsedPacket(GeometrisBlePacket pkt, int? frameId) {
    final ignitionStr = pkt.ignition == null ? '--' : (pkt.ignition == true ? 'ON' : 'OFF');
    final message = '========== Parsed Packet (Frame #${frameId ?? "N/A"}) ==========\n'
        'Serial Number : ${pkt.serialNumber.isEmpty ? "--" : pkt.serialNumber}\n'
        'VIN           : ${pkt.vin ?? "--"}\n'
        'Ignition      : $ignitionStr\n'
        'Latitude      : ${pkt.latitude ?? "--"}\n'
        'Longitude     : ${pkt.longitude ?? "--"}\n'
        'Speed         : ${pkt.speedMph != null ? pkt.speedMph!.toStringAsFixed(1) : "--"}\n'
        'RPM           : ${pkt.rpm ?? "--"}\n'
        'Fuel          : ${pkt.fuelLevelPct ?? "--"}\n'
        'Odometer      : ${pkt.odometerMiles != null ? pkt.odometerMiles! / 0.621371 : "--"}\n'
        'Heading       : ${pkt.heading ?? "--"}\n'
        'Satellites    : ${pkt.numSatellites ?? "--"}\n'
        'Timestamp     : ${pkt.eventUnixTime}\n'
        '==============================================================';
    developer.log(message, name: 'PARSED_PACKET');
    // print('[PARSED_PACKET] $message');
  }

  /// Prints timing/latency diagnostics.
  static void printTimingAudit(int frameId, DateTime frameStartTime, DateTime streamAddTimestamp) {
    final totalLatency = streamAddTimestamp.difference(frameStartTime);
    final message = '========== Timing / Latency Audit (Frame #$frameId) ==========\n'
        'BLE Notification Arrival   : ${frameStartTime.toIso8601String()}\n'
        'Stream Addition / Parsed   : ${streamAddTimestamp.toIso8601String()}\n'
        'Reassembly & Parse Latency : ${totalLatency.inMilliseconds} ms\n'
        '==============================================================';
    developer.log(message, name: 'TIMING_AUDIT');
    print('[TIMING_AUDIT] $message');
  }
}
