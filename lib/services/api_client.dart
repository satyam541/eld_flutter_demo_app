import 'dart:convert';
import 'package:http/http.dart' as http;
import 'ble_service.dart';

class ApiClient {
  ApiClient({required this.portalUrl});
  final String portalUrl;

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
      return resp.statusCode >= 200 && resp.statusCode < 300;
    } catch (_) {
      return false;
    }
  }
}
