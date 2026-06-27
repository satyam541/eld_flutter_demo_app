import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_location_demo/services/ble_service.dart';
import 'package:live_location_demo/services/geometris_frame_parser.dart';
import 'package:live_location_demo/services/geometris_decoder.dart';

void main() {
  test('GeometrisFrameParser and GeometrisDecoder Direct Test', () {
    final frameBytes = Uint8List.fromList([
      0x01, 0x00, // Field 0x01: VIN
      0x03, 0x00, // Length: 3 chars -> 6 bytes
      0x56, 0x00, 0x49, 0x00, 0x4E, 0x00, // "VIN" in UTF-16LE
      0x03, 0x00, // Field 0x03: RPM
      0x00, 0x00, 0x90, 0x01, // 400 in D1 D0 D3 D2
      0x02, 0x00, // Field 0x02: Odometer
      0x00, 0x00, 0x55, 0x02, // 597 in D1 D0 D3 D2
    ]);

    final fields = GeometrisFrameParser.parseFrame(frameBytes);
    expect(fields.length, equals(3));
    expect(fields[0x01], isNotNull);
    expect(fields[0x03], isNotNull);
    expect(fields[0x02], isNotNull);

    expect(GeometrisDecoder.readUtf16(fields[0x01]!), equals('VIN'));
    expect(GeometrisDecoder.readInt32(fields[0x03]!), equals(400));
    expect(GeometrisDecoder.readInt32(fields[0x02]!), equals(597));

    final packet = GeometrisDecoder.decode(
      fields,
      fallbackSerial: 'TEST_SERIAL',
      fallbackTimestamp: 123456,
    );

    expect(packet.vin, equals('VIN'));
    expect(packet.rpm, equals(400));
    expect(packet.odometerMiles, closeTo(370.96, 0.1));
    expect(packet.serialNumber, equals('TEST_SERIAL'));
    expect(packet.eventUnixTime, equals(123456));
  });

  test('Geometris BLE Protocol Audit Test', () async {
    final bleService = BleService();

    // Setup listener to verify emitted packet
    GeometrisBlePacket? lastPacket;
    final sub = bleService.packets.listen((pkt) {
      lastPacket = pkt;
    });

    // --- State A / Frame 1 (Engine OFF candidate) ---
    final frame1Bytes = [
      0xCB, 0x01, 0x05, 0x00, 0x2A, 0x00, 0x01, 0x00, 0x12, 0x00, 
      0x31, 0x00, 0x4E, 0x00, 0x36, 0x00, 0x44, 0x00, 0x44, 0x00, 
      0x32, 0x00, 0x36, 0x00, 0x54, 0x00, 0x34, 0x00, 0x34, 0x00, 
      0x43, 0x00, 0x44, 0x00, 0x34, 0x00, 0x31, 0x00, 0x37, 0x00, 
      0x33, 0x00, 0x33, 0x00, 0x22, 0x00, 0x02, 0x00, 0x00, 0x00, 
      0x55, 0x02, 0x03, 0x00, 0x00, 0x00, 0x90, 0x01, 0x05, 0x00, 
      0x00, 0x00, 0x50, 0x00, 0x11, 0x00, 0x00, 0x00, 0x7A, 0x01, // Note: index 62 is set to 0x50 for Speed = 80 km/h
      0x13, 0x00, 0x2E, 0x00, 0xAE, 0xE6, 0x14, 0x00, 0x74, 0x00, 
      0x47, 0xF9, 0x15, 0x00, 0x3D, 0x6A, 0x16, 0x80
    ];

    print('--- FEEDING STATE A (FRAME 1) ---');
    _feedFragments(bleService, frame1Bytes);

    // Give asynchronous listeners/timers a moment to process the frame
    await Future.delayed(const Duration(milliseconds: 600));

    expect(lastPacket, isNotNull);
    expect(lastPacket!.frameId, equals(1));
    expect(lastPacket!.rpm, equals(400));
    expect(lastPacket!.speedMph, closeTo(49.71, 0.1));
    expect(lastPacket!.odometerMiles, closeTo(370.96, 0.1));
    expect(lastPacket!.latitude, closeTo(30.7371, 0.001));
    expect(lastPacket!.longitude, closeTo(76.65991, 0.001));
    expect(lastPacket!.ignition, isTrue);

    // --- State B / Frame 2 (Engine ON candidate) ---
    // Change value of Engine RPM (index 56-57) from 90 01 (400) to 50 03 (848)
    // Change value of GPS Speed (index 62-63) from 50 00 (80 km/h) to 00 00 (0 km/h)
    final frame2Bytes = List<int>.from(frame1Bytes);
    frame2Bytes[56] = 0x50;
    frame2Bytes[57] = 0x03;
    frame2Bytes[62] = 0x00;
    frame2Bytes[63] = 0x00;

    print('\n--- FEEDING STATE B (FRAME 2) ---');
    _feedFragments(bleService, frame2Bytes);

    await Future.delayed(const Duration(milliseconds: 600));

    expect(lastPacket, isNotNull);
    expect(lastPacket!.frameId, equals(2));
    expect(lastPacket!.rpm, equals(848));
    expect(lastPacket!.speedMph, equals(0.0));
    expect(lastPacket!.odometerMiles, closeTo(370.96, 0.1));
    expect(lastPacket!.ignition, isTrue);

    await sub.cancel();
  });
}

void _feedFragments(BleService service, List<int> frameBytes) {
  int offset = 0;
  int fragIndex = 0;
  while (offset < frameBytes.length) {
    final chunkSize = (frameBytes.length - offset > 19) ? 19 : frameBytes.length - offset;
    final chunk = frameBytes.sublist(offset, offset + chunkSize);
    final notification = Uint8List(1 + chunk.length);
    notification[0] = fragIndex;
    notification.setRange(1, notification.length, chunk);
    service.handleNotifyForTesting(notification);
    
    offset += chunkSize;
    fragIndex++;
  }
}
