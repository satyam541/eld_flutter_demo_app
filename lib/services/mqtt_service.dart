import 'dart:convert';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import '../models/vehicle_location.dart';

class MqttService {
  // ─────────────────────────────────────────────────────────────────────────
  // CONFIGURE THESE VALUES to match your HiveMQ Cloud cluster & credentials
  // ─────────────────────────────────────────────────────────────────────────
  static const String _broker =
      'xxxx.s2.eu.hivemq.cloud'; // ← Your HiveMQ hostname
  static const int _port = 8883; // TLS port
  static const String _username = 'fleet_user';
  static const String _password = 'YourSecurePassword123';
  // Change to PT30 serial when switching to client hardware:
  static const String _deviceSerial = '88X150380033';
  // ─────────────────────────────────────────────────────────────────────────

  late MqttServerClient _client;

  /// Called every time a valid location message arrives.
  Function(VehicleLocation)? onLocationReceived;

  /// Called when connection state changes (connected / disconnected).
  Function(bool)? onConnectionChanged;

  Future<void> connect() async {
    final clientId = 'flutter_tracker_${DateTime.now().millisecondsSinceEpoch}';

    _client = MqttServerClient.withPort(_broker, clientId, _port);

    _client.secure = true;
    _client.keepAlivePeriod = 30;
    _client.autoReconnect = true;
    _client.logging(on: false);

    _client.onConnected = _onConnected;
    _client.onDisconnected = _onDisconnected;
    _client.onAutoReconnected = () {
      // ignore: avoid_print
      print('[MQTT] Auto-reconnected');
      onConnectionChanged?.call(true);
    };

    final connMessage = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .authenticateAs(_username, _password)
        .withWillQos(MqttQos.atLeastOnce);

    _client.connectionMessage = connMessage;

    try {
      await _client.connect();
    } catch (e) {
      // ignore: avoid_print
      print('[MQTT] Connection failed: $e');
      _client.disconnect();
    }
  }

  void _onConnected() {
    // ignore: avoid_print
    print('[MQTT] Connected to broker');
    onConnectionChanged?.call(true);

    const topic = 'fleet/$_deviceSerial/location';
    _client.subscribe(topic, MqttQos.atLeastOnce);
    // ignore: avoid_print
    print('[MQTT] Subscribed to $topic');

    _client.updates?.listen((List<MqttReceivedMessage<MqttMessage>> messages) {
      for (final msg in messages) {
        final recMessage = msg.payload as MqttPublishMessage;
        final payload = MqttPublishPayload.bytesToStringAsString(
          recMessage.payload.message,
        );
        _handlePayload(payload);
      }
    });
  }

  void _handlePayload(String payload) {
    try {
      final json = jsonDecode(payload) as Map<String, dynamic>;
      final location = VehicleLocation.fromJson(json);
      onLocationReceived?.call(location);
    } catch (e) {
      // ignore: avoid_print
      print('[MQTT] Failed to parse payload: $e\nRaw: $payload');
    }
  }

  void _onDisconnected() {
    // ignore: avoid_print
    print('[MQTT] Disconnected');
    onConnectionChanged?.call(false);
  }

  void disconnect() {
    try {
      _client.disconnect();
    } catch (_) {}
  }
}
