import 'package:flutter/foundation.dart';
import '../models/vehicle_location.dart';
import '../services/mqtt_service.dart';

class LocationProvider extends ChangeNotifier {
  VehicleLocation? _currentLocation;
  final List<VehicleLocation> _locationHistory = [];
  bool _isConnected = false;
  bool _isConnecting = false;
  String _statusMessage = 'Not started';

  final MqttService _mqttService = MqttService();

  // ── Getters ──────────────────────────────────────────────────────────────
  VehicleLocation? get currentLocation => _currentLocation;
  List<VehicleLocation> get locationHistory =>
      List.unmodifiable(_locationHistory);
  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;
  String get statusMessage => _statusMessage;

  // ── Start / Stop ─────────────────────────────────────────────────────────
  Future<void> startTracking() async {
    if (_isConnecting || _isConnected) return;

    _isConnecting = true;
    _statusMessage = 'Connecting to broker…';
    notifyListeners();

    _mqttService.onLocationReceived = (VehicleLocation location) {
      _currentLocation = location;
      _locationHistory.add(location);
      // Keep the trail to the last 500 points
      if (_locationHistory.length > 500) {
        _locationHistory.removeAt(0);
      }
      notifyListeners();
    };

    _mqttService.onConnectionChanged = (bool connected) {
      _isConnected = connected;
      _isConnecting = false;
      _statusMessage = connected ? 'Live' : 'Disconnected — reconnecting…';
      notifyListeners();
    };

    await _mqttService.connect();
  }

  void stopTracking() {
    _mqttService.disconnect();
    _isConnected = false;
    _isConnecting = false;
    _statusMessage = 'Stopped';
    notifyListeners();
  }

  void clearHistory() {
    _locationHistory.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _mqttService.disconnect();
    super.dispose();
  }
}
