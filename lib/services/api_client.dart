import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'ble_service.dart';

class ApiClient {
  ApiClient({required this.portalUrl});
  final String portalUrl;

  String? lastError;
  int? lastStatusCode;

  Future<bool> postBlePacket(GeometrisBlePacket pkt) async {
    final uri = Uri.parse('$portalUrl/api/ingest/ble');
    try {
      final resp = await http
          .post(
            uri,
            headers: {'content-type': 'application/json'},
            body: jsonEncode(pkt.toJson()),
          )
          .timeout(const Duration(seconds: 8));
      lastStatusCode = resp.statusCode;
      final ok = resp.statusCode >= 200 && resp.statusCode < 300;
      if (!ok) {
        lastError = 'HTTP ${resp.statusCode}: ${resp.body}';
        if (kDebugMode) debugPrint('[API] $lastError');
      } else {
        lastError = null;
      }
      return ok;
    } catch (e) {
      lastError = e.toString();
      lastStatusCode = null;
      if (kDebugMode) debugPrint('[API] post failed: $e');
      return false;
    }
  }
}
