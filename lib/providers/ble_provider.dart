import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../services/ble_service.dart';
import '../services/api_client.dart';

class BleProvider extends ChangeNotifier {
  BleProvider({required String portalUrl})
      : _api = ApiClient(portalUrl: portalUrl);

  final BleService _ble = BleService();
  final ApiClient _api;

  List<ScanResult> _scanResults = [];
  bool _scanning = false;
  bool _connecting = false;
  bool _connected = false;
  GeometrisBlePacket? _last;
  String _status = 'Idle';
  StreamSubscription<GeometrisBlePacket>? _packetSub;

  int _packetsReceived = 0;
  int _packetsPosted = 0;
  int _packetsFailed = 0;

  List<ScanResult> get scanResults => List.unmodifiable(_scanResults);
  bool get scanning => _scanning;
  bool get connecting => _connecting;
  bool get connected => _connected;
  GeometrisBlePacket? get lastPacket => _last;
  String get status => _status;
  int get packetsReceived => _packetsReceived;
  int get packetsPosted => _packetsPosted;
  int get packetsFailed => _packetsFailed;
  String? get lastApiError => _api.lastError;
  Set<int> get seenTlvIds => _ble.seenTlvIds;

  Future<void> scan() async {
    _scanning = true;
    _status = 'Scanning…';
    _scanResults = [];
    notifyListeners();
    try {
      _scanResults = await _ble.scan();
      _status = '${_scanResults.length} device(s) found';
    } catch (e) {
      _status = 'Scan failed: $e';
    } finally {
      _scanning = false;
      notifyListeners();
    }
  }

  Future<void> connect(BluetoothDevice device) async {
    _connecting = true;
    _status = 'Connecting to ${device.platformName}…';
    notifyListeners();
    try {
      await _ble.connect(device);
      _connected = true;
      _status = 'Connected';
      _packetSub = _ble.packets.listen((pkt) async {
        _last = pkt;
        _packetsReceived++;
        notifyListeners();
        final ok = await _api.postBlePacket(pkt);
        if (ok) {
          _packetsPosted++;
        } else {
          _packetsFailed++;
        }
        notifyListeners();
      });
    } catch (e) {
      _status = 'Connect failed: $e';
      _connected = false;
    } finally {
      _connecting = false;
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    await _packetSub?.cancel();
    _packetSub = null;
    await _ble.disconnect();
    _connected = false;
    _status = 'Disconnected';
    notifyListeners();
  }

  @override
  void dispose() {
    _packetSub?.cancel();
    _ble.dispose();
    super.dispose();
  }
}
