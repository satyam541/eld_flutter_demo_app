import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'ble_service.dart';

class ApiClient {
  ApiClient({required this.portalUrl});
  final String portalUrl;

  String? lastError;
  int? lastStatusCode;

  Future<bool> postBlePacket(GeometrisBlePacket pkt) async {
    final uri = Uri.parse('https://eld-reboot.satyamsuri.com/api/data');
    final innerJsonString = jsonEncode(pkt.toJson());
    final bodyJson = jsonEncode({
      'data': innerJsonString,
    });

    print('================ API REQUEST ================\n'
        'URL: $uri\n'
        'Method: POST\n'
        'Headers: {content-type: application/json}\n'
        'Body: $bodyJson\n'
        '=============================================');

    try {
      final resp = await http
          .post(
            uri,
            headers: {'content-type': 'application/json'},
            body: bodyJson,
          )
          .timeout(const Duration(seconds: 8));

      print('================ API RESPONSE ================\n'
          'URL: $uri\n'
          'Status Code: ${resp.statusCode}\n'
          'Body: ${resp.body}\n'
          '==============================================');

      lastStatusCode = resp.statusCode;
      final ok = resp.statusCode >= 200 && resp.statusCode < 300;
      if (!ok) {
        lastError = 'HTTP ${resp.statusCode}: ${resp.body}';
      } else {
        lastError = null;
      }
      return ok;
    } catch (e) {
      print('================ API EXCEPTION ================\n'
          'URL: $uri\n'
          'Error: $e\n'
          '===============================================');
      lastError = e.toString();
      lastStatusCode = null;
      return false;
    }
  }
}
