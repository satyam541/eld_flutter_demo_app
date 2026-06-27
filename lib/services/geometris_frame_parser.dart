import 'dart:typed_data';
import 'dart:developer' as developer;

/// Parser for Geometris whereQube BLE protocol frames.
/// Separates raw byte slicing and TLV validation from decoding logic.
class GeometrisFrameParser {
  /// Parses a complete reconstructed payload starting at offset 0.
  /// Returns a map of raw field IDs to raw value byte arrays.
  static Map<int, Uint8List> parseFrame(Uint8List frame) {
    final fields = <int, Uint8List>{};
    int offset = 0;

    while (offset < frame.length) {
      if (offset + 2 > frame.length) {
        // Incomplete field ID at the end of the frame
        break;
      }

      final int startOffset = offset;
      final int fieldId = frame[offset] | (frame[offset + 1] << 8);
      offset += 2;

      // fieldId 0 indicates padding/end of frame
      if (fieldId == 0) {
        break;
      }

      // Check if it is a variable-length field (VIN: 0x01, Serial: 0x0F)
      if (fieldId == 0x01 || fieldId == 0x0F) {
        if (offset + 2 > frame.length) {
          _logUnexpectedStop(fieldId, startOffset, frame.sublist(startOffset));
          // Attempt to recover by advancing by 4 bytes (the standard fixed field size)
          if (offset + 4 <= frame.length) {
            offset += 4;
            continue;
          } else {
            break;
          }
        }
        final int charLen = frame[offset] | (frame[offset + 1] << 8);
        offset += 2;

        final int byteLen = charLen * 2;
        if (offset + byteLen > frame.length) {
          _logUnexpectedStop(fieldId, startOffset, frame.sublist(startOffset));
          // Attempt to recover by advancing
          if (offset + byteLen <= frame.length) {
            offset += byteLen;
            continue;
          } else {
            break;
          }
        }

        final rawBytes = Uint8List.sublistView(frame, offset, offset + byteLen);
        fields[fieldId] = rawBytes;

        _logField(
          offset: startOffset,
          fieldId: fieldId,
          fieldType: 'Variable-Length',
          length: byteLen,
          rawBytes: rawBytes,
          offsetAfter: offset + byteLen,
        );

        offset += byteLen;
      }
      // Check if it is a known fixed-length field (matching OBDDataInfo.java switch cases)
      else if (fieldId == 0x02 || fieldId == 0x03 || fieldId == 0x04 || 
               fieldId == 0x05 || fieldId == 0x06 || fieldId == 0x07 || 
               fieldId == 0x08 || fieldId == 0x09 || fieldId == 0x0A || 
               fieldId == 0x0B || fieldId == 0x0C || fieldId == 0x0D || 
               fieldId == 0x0E || fieldId == 0x10 || fieldId == 0x11 || 
               fieldId == 0x12 || fieldId == 0x13 || fieldId == 0x14 || 
               fieldId == 0x15 || fieldId == 0x1F || 
               (fieldId >= 0x16 && fieldId <= 0x1E)) {
        
        if (offset + 4 > frame.length) {
          _logUnexpectedStop(fieldId, startOffset, frame.sublist(startOffset));
          // Attempt to recover
          if (offset + 4 <= frame.length) {
            offset += 4;
            continue;
          } else {
            break;
          }
        }

        final rawBytes = Uint8List.sublistView(frame, offset, offset + 4);
        fields[fieldId] = rawBytes;

        _logField(
          offset: startOffset,
          fieldId: fieldId,
          fieldType: 'Fixed-Length',
          length: 4,
          rawBytes: rawBytes,
          offsetAfter: offset + 4,
        );

        offset += 4;
      }
      // Default: unknown or unexpected field ID
      else {
        _logUnexpectedStop(fieldId, startOffset, frame.sublist(startOffset));
        // Attempt to recover cursor assuming a standard 4-byte fixed field value size
        if (offset + 4 <= frame.length) {
          offset += 4;
        } else {
          break;
        }
      }
    }

    return fields;
  }

  static void _logField({
    required int offset,
    required int fieldId,
    required String fieldType,
    required int length,
    required Uint8List rawBytes,
    required int offsetAfter,
  }) {
    final rawHex = rawBytes.map((e) => e.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
    final fieldIdHex = '0x${fieldId.toRadixString(16).padLeft(2, '0').toUpperCase()}';

    final logMsg = 'Current Offset : $offset\n\n'
        'Offset : $offset\n\n'
        'Field ID : $fieldIdHex\n\n'
        'Field Type : $fieldType\n\n'
        'Length : $length\n\n'
        'Raw Bytes :\n\n'
        '$rawHex\n\n'
        'Cursor Before : $offset\n\n'
        'Cursor After :\n\n'
        '$offsetAfter';
    
    developer.log(logMsg, name: 'GEOMETRIS_PARSER');
    print('[GEOMETRIS_PARSER] $logMsg');
  }

  static void _logUnexpectedStop(int fieldId, int offset, Uint8List remaining) {
    final remainingHex = remaining.map((e) => e.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
    final fieldIdHex = '0x${fieldId.toRadixString(16).padLeft(2, '0').toUpperCase()}';

    final logMsg = 'Unknown Field\n\n'
        'Field ID : $fieldIdHex\n\n'
        'Offset : $offset\n\n'
        'Remaining Payload :\n\n'
        '$remainingHex';
    
    developer.log(logMsg, name: 'GEOMETRIS_PARSER');
    print('[GEOMETRIS_PARSER] $logMsg');
  }
}
