import 'dart:convert';
import 'dart:typed_data';
import 'ble_service.dart';

/// Decoder for Geometris whereQube protocol values.
/// Implements D1 D0 D3 D2 endianness swapping and handles type parsing/scaling.
class GeometrisDecoder {
  /// Reorders the 4-byte value array [D0, D1, D2, D3] to [D1, D0, D3, D2].
  static Uint8List fixEndian(Uint8List v) {
    if (v.length < 4) return v;
    final out = Uint8List(4);
    out[0] = v[1];
    out[1] = v[0];
    out[2] = v[3];
    out[3] = v[2];
    return out;
  }

  /// Reads standard big-endian uint32 of fixed bytes.
  static int readUint32(Uint8List v) {
    if (v.length < 4) return 0;
    final fixed = fixEndian(v);
    return ByteData.sublistView(fixed).getUint32(0, Endian.big);
  }

  /// Reads signed big-endian int32 of fixed bytes.
  static int readInt32(Uint8List v) {
    if (v.length < 4) return 0;
    final fixed = fixEndian(v);
    return ByteData.sublistView(fixed).getInt32(0, Endian.big);
  }

  /// Decodes UTF-16LE string and trims enclosing quotes.
  static String readUtf16(Uint8List v) {
    if (v.isEmpty) return '';
    // Check if it looks like UTF-16LE (every other byte is 0x00 for ASCII range)
    if (v.length >= 2 && v.length.isEven) {
      var isUtf16 = true;
      for (var i = 1; i < v.length; i += 2) {
        if (v[i] != 0) {
          isUtf16 = false;
          break;
        }
      }
      if (isUtf16) {
        final chars = <int>[];
        for (var i = 0; i < v.length - 1; i += 2) {
          if (v[i] == 0 && v[i + 1] == 0) break; // null terminator
          chars.add(v[i] | (v[i + 1] << 8));
        }
        final rawStr = String.fromCharCodes(chars).trim();
        return rawStr.replaceAll(RegExp(r'^"|"$'), '').trim();
      }
    }
    final rawStr = utf8.decode(v, allowMalformed: true).trim();
    return rawStr.replaceAll(RegExp(r'^"|"$'), '').trim();
  }

  /// Decodes little-endian float32.
  static double readFloat(Uint8List v) {
    if (v.length < 4) return 0.0;
    return ByteData.sublistView(v).getFloat32(0, Endian.little);
  }

  /// Decodes fields into a [GeometrisBlePacket].
  static GeometrisBlePacket decode(
    Map<int, Uint8List> fields, {
    required String fallbackSerial,
    required int fallbackTimestamp,
    int? frameId,
  }) {
    double? lat;
    double? lon;
    double? speed;
    double? heading;
    double? odo;
    double? fuel;
    double? throttle;
    int? ts;
    int? rpm;
    int? sats;
    int? coolant;
    int? ignOn;
    int? idleTotal;
    bool? ignition;
    String? vin;
    String? reason;
    String? dtc;
    String serial = fallbackSerial;

    fields.forEach((id, value) {
      switch (id) {
        case 0x01: // VIN (Variable length string)
          vin = readUtf16(value);
          break;
        case 0x02: // Odometer (Fixed uint32, in km)
          final odoKm = readInt32(value);
          odo = odoKm * 0.621371; // Convert km to miles
          break;
        case 0x03: // Engine RPM (Fixed uint32)
          rpm = readInt32(value);
          break;
        case 0x04: // Engine Coolant Temp (Fixed int32)
          coolant = readInt32(value);
          break;
        case 0x05: // Speed (Fixed uint32, in km/h)
          final speedKmh = readInt32(value);
          speed = speedKmh * 0.621371; // Convert km/h to MPH
          break;
        case 0x06: // Fuel Level (Fixed uint32, percentage 0-100)
          fuel = readInt32(value).toDouble();
          break;
        case 0x08: // Throttle Position (Fixed uint32, percentage 0-100)
          throttle = readInt32(value).toDouble();
          break;
        case 0x0F: // Serial Number (Variable length string)
          serial = readUtf16(value);
          break;
        case 0x11: // Engine Hours (Fixed uint32, scaled by 1/10)
          final engHrsTenths = readInt32(value);
          ignOn = engHrsTenths * 360; // Convert tenths of hour to seconds
          break;
        case 0x13: // Latitude (Fixed int32, scaled by 1/100,000)
          final latRaw = readInt32(value);
          lat = latRaw / 100000.0;
          break;
        case 0x14: // Longitude (Fixed int32, scaled by 1/100,000)
          final lonRaw = readInt32(value);
          lon = lonRaw / 100000.0;
          break;
        case 0x15: // LocTime (Fixed uint32, event Unix timestamp)
          ts = readInt32(value);
          break;
        case 0x16: // Unidentified Driving Reason code
          final reasonCode = readInt32(value);
          reason = 'UDRV_$reasonCode';
          break;
        case 0x1F: // Heading (Fixed uint32, degrees 0-359)
          heading = readInt32(value).toDouble();
          break;
      }
    });

    // Derive ignition state from RPM > 0
    if (rpm != null) {
      ignition = rpm! > 0;
    }

    final finalTs = ts ?? fallbackTimestamp;

    return GeometrisBlePacket(
      frameId: frameId,
      serialNumber: serial,
      eventUnixTime: finalTs,
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
      raw: fields.map((k, v) => MapEntry(k, v.toList())),
    );
  }
}
