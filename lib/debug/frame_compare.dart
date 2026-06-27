import 'dart:typed_data';
import 'dart:developer' as developer;

/// Static helper to compare differences between subsequent reassembled Geometris frames.
class FrameCompare {
  static void compareFrames(Uint8List previous, Uint8List current, int prevId, int currId) {
    if (previous.length != current.length) {
      final msg = '══════════════════════════════════════════════\n'
          '🔄 Frame Difference (Frame #$prevId → #$currId)\n'
          '══════════════════════════════════════════════\n'
          'Warning: Frame length changed from ${previous.length} to ${current.length} bytes.\n'
          '══════════════════════════════════════════════';
      developer.log(msg, name: 'FRAME_DIFF');
      print('[FRAME_DIFF] $msg');
      return;
    }

    final diffs = <String>[];
    for (int i = 0; i < current.length; i++) {
      if (previous[i] != current[i]) {
        final isEven = (i % 2 == 0);
        final u16Offset = isEven ? i : i - 1;
        final u32Offset = i - (i % 4);

        String notes = '';
        if (u32Offset + 3 < current.length) {
          final prevVal32 =
              previous[u32Offset] | (previous[u32Offset + 1] << 8) | (previous[u32Offset + 2] << 16) | (previous[u32Offset + 3] << 24);
          final prevVal32Signed = prevVal32 > 0x7FFFFFFF ? prevVal32 - 0x100000000 : prevVal32;
          final currVal32 =
              current[u32Offset] | (current[u32Offset + 1] << 8) | (current[u32Offset + 2] << 16) | (current[u32Offset + 3] << 24);
          final currVal32Signed = currVal32 > 0x7FFFFFFF ? currVal32 - 0x100000000 : currVal32;

          final prevVal16 = previous[u16Offset] | (previous[u16Offset + 1] << 8);
          final currVal16 = current[u16Offset] | (current[u16Offset + 1] << 8);

          notes = ' (UInt16 LE at off$u16Offset: $prevVal16 → $currVal16 | Int32 LE at off$u32Offset: $prevVal32Signed → $currVal32Signed)';
        } else if (u16Offset + 1 < current.length) {
          final prevVal16 = previous[u16Offset] | (previous[u16Offset + 1] << 8);
          final currVal16 = current[u16Offset] | (current[u16Offset + 1] << 8);
          notes = ' (UInt16 LE at off$u16Offset: $prevVal16 → $currVal16)';
        }

        diffs.add('${i.toString().padRight(8)}'
            '0x${previous[i].toRadixString(16).padLeft(2, '0').toUpperCase().padRight(11)}'
            '0x${current[i].toRadixString(16).padLeft(2, '0').toUpperCase().padRight(11)}'
            '$notes');
      }
    }

    final String message;
    if (diffs.isEmpty) {
      message = '══════════════════════════════════════════════\n'
          '🔄 Frame Difference (Frame #$prevId → #$currId)\n'
          '══════════════════════════════════════════════\n'
          'No changes detected.\n'
          '══════════════════════════════════════════════';
    } else {
      message = '══════════════════════════════════════════════\n'
          '🔄 Frame Difference (Frame #$prevId → #$currId)\n'
          '══════════════════════════════════════════════\n'
          'Offset   Previous    Current     Delta / Notes\n'
          '${diffs.join('\n')}\n'
          '══════════════════════════════════════════════';
    }
    developer.log(message, name: 'FRAME_DIFF');
    print('[FRAME_DIFF] $message');
  }
}
