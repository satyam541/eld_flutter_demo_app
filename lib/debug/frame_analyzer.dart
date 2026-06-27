import 'dart:typed_data';
import 'dart:developer' as developer;

/// Static helper to print detailed binary/numeric visualizations of Geometris frames.
class FrameAnalyzer {
  static void analyzeFrame(Uint8List frame, int frameId) {
    final buffer = StringBuffer();
    buffer.writeln('══════════════════════════════════════════════');
    buffer.writeln('🔍 Binary Frame Analyzer (Frame #$frameId)');
    buffer.writeln('══════════════════════════════════════════════');
    buffer.writeln('Frame Length: ${frame.length} bytes');

    buffer.writeln('\n--- RAW BYTES WITH OFFSETS ---');
    for (int i = 0; i < frame.length; i += 16) {
      final end = (i + 16 < frame.length) ? i + 16 : frame.length;
      final bytesStr = frame.sublist(i, end).map((e) => e.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
      final asciiStr = String.fromCharCodes(frame.sublist(i, end).map((b) => (b >= 32 && b <= 126) ? b : 46));
      buffer.writeln('${i.toString().padLeft(3)}: ${bytesStr.padRight(48)} | $asciiStr');
    }

    buffer.writeln('\n--- NUMERIC INTERPRETATIONS ---');
    buffer.writeln('Offset   UInt16(LE)  Int16(LE)   UInt32(LE)  Int32(LE)   Float32(LE)  Float64(LE)');
    for (int i = 0; i < frame.length - 1; i += 2) {
      final u16 = frame[i] | (frame[i + 1] << 8);
      final i16 = u16 > 0x7FFF ? u16 - 0x10000 : u16;

      String u32Str = '—'.padRight(12);
      String i32Str = '—'.padRight(12);
      String f32Str = '—'.padRight(12);
      String f64Str = '—'.padRight(12);

      if (i + 3 < frame.length) {
        final u32 = frame[i] | (frame[i + 1] << 8) | (frame[i + 2] << 16) | (frame[i + 3] << 24);
        final i32 = u32 > 0x7FFFFFFF ? u32 - 0x100000000 : u32;
        u32Str = u32.toString().padRight(12);
        i32Str = i32.toString().padRight(12);

        try {
          final f32 = ByteData.sublistView(frame, i, i + 4).getFloat32(0, Endian.little);
          f32Str = f32.toStringAsExponential(3).padRight(12);
        } catch (_) {}
      }

      if (i + 7 < frame.length) {
        try {
          final f64 = ByteData.sublistView(frame, i, i + 8).getFloat64(0, Endian.little);
          f64Str = f64.toStringAsExponential(3).padRight(12);
        } catch (_) {}
      }

      buffer.writeln('${i.toString().padRight(9)}'
          '${u16.toString().padRight(12)}'
          '${i16.toString().padRight(12)}'
          '$u32Str'
          '$i32Str'
          '$f32Str'
          '$f64Str');
    }

    buffer.writeln('\n--- UTF-16 STRINGS SCAN ---');
    for (int start = 0; start < frame.length - 3; start++) {
      final chars = <int>[];
      for (int i = start; i + 1 < frame.length; i += 2) {
        final code = frame[i] | (frame[i + 1] << 8);
        if (code == 0) break;
        if (code < 32 || code > 126) break;
        chars.add(code);
      }
      if (chars.length >= 4) {
        buffer.writeln('Offset ${start.toString().padLeft(2)}: "${String.fromCharCodes(chars)}"');
        start += chars.length * 2 - 1; // skip past this string
      }
    }

    buffer.writeln('\n--- UNIX TIMESTAMP CANDIDATES (UInt32 LE) ---');
    for (int i = 0; i < frame.length - 3; i += 2) {
      final val = frame[i] | (frame[i + 1] << 8) | (frame[i + 2] << 16) | (frame[i + 3] << 24);
      if (val >= 1262304000 && val <= 2208988800) {
        final date = DateTime.fromMillisecondsSinceEpoch(val * 1000, isUtc: true);
        buffer.writeln('Offset ${i.toString().padLeft(2)}: $val -> $date UTC');
      }
    }

    buffer.writeln('\n--- GPS COORDINATE CANDIDATES (Int32 LE * 1e-5) ---');
    for (int i = 0; i < frame.length - 3; i += 2) {
      final u32 = frame[i] | (frame[i + 1] << 8) | (frame[i + 2] << 16) | (frame[i + 3] << 24);
      final i32 = u32 > 0x7FFFFFFF ? u32 - 0x100000000 : u32;
      final deg = i32 / 100000.0;
      if (deg.abs() > 0.001 && deg.abs() <= 180.0) {
        buffer.writeln('Offset ${i.toString().padLeft(2)}: $i32 -> $deg°');
      }
    }

    buffer.writeln('══════════════════════════════════════════════');
    
    final message = buffer.toString();
    developer.log(message, name: 'FRAME_ANALYZER');
    print('[FRAME_ANALYZER] $message');
  }
}
