import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/location_provider.dart';
import '../models/vehicle_location.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  final Completer<GoogleMapController> _mapController = Completer();
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  bool _followVehicle = true;
  MapType _mapType = MapType.normal;

  static const CameraPosition _defaultPosition = CameraPosition(
    target: LatLng(30.9010, 75.8573), // Ludhiana, Punjab — default start
    zoom: 14,
  );

  @override
  void initState() {
    super.initState();

    // Pulse animation for the "LIVE" badge
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Begin MQTT tracking after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LocationProvider>().startTracking();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  // ── Camera ────────────────────────────────────────────────────────────────

  Future<void> _animateCameraTo(VehicleLocation loc) async {
    if (!_followVehicle) return;
    final ctrl = await _mapController.future;
    ctrl.animateCamera(
      CameraUpdate.newLatLng(LatLng(loc.lat, loc.lng)),
    );
  }

  // ── Map elements ──────────────────────────────────────────────────────────

  void _rebuildMapElements(LocationProvider provider) {
    _markers.clear();

    final loc = provider.currentLocation;
    if (loc == null) return;

    _markers.add(
      Marker(
        markerId: const MarkerId('vehicle'),
        position: LatLng(loc.lat, loc.lng),
        rotation: loc.heading,
        anchor: const Offset(0.5, 0.5),
        infoWindow: InfoWindow(
          title: 'Vehicle',
          snippet: '${loc.speed.toStringAsFixed(1)} km/h  •  '
              '${DateFormat('HH:mm:ss').format(loc.timestamp)}',
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          loc.ignition ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueRed,
        ),
      ),
    );

    // Route polyline trail
    if (provider.locationHistory.length > 1) {
      final points =
          provider.locationHistory.map((l) => LatLng(l.lat, l.lng)).toList();
      _polylines
        ..clear()
        ..add(
          Polyline(
            polylineId: const PolylineId('route'),
            points: points,
            color: const Color(0xFF3B82F6),
            width: 4,
            jointType: JointType.round,
            endCap: Cap.roundCap,
            startCap: Cap.roundCap,
          ),
        );
    }

    _animateCameraTo(loc);
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Consumer<LocationProvider>(
        builder: (context, provider, _) {
          _rebuildMapElements(provider);
          return Stack(
            children: [
              // ── Google Map ───────────────────────────────────────────────
              GoogleMap(
                initialCameraPosition: _defaultPosition,
                markers: Set.from(_markers),
                polylines: Set.from(_polylines),
                mapType: _mapType,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                compassEnabled: true,
                onMapCreated: (ctrl) => _mapController.complete(ctrl),
                onCameraMoveStarted: () {
                  // Disable follow when user pans manually
                },
              ),

              // ── Top header bar ───────────────────────────────────────────
              _TopBar(
                isConnected: provider.isConnected,
                isConnecting: provider.isConnecting,
                statusMessage: provider.statusMessage,
                pulseAnimation: _pulseAnimation,
                mapType: _mapType,
                onMapTypeToggle: () {
                  setState(() {
                    _mapType = _mapType == MapType.normal
                        ? MapType.satellite
                        : MapType.normal;
                  });
                },
                onClearTrail: () => provider.clearHistory(),
              ),

              // ── Waiting indicator ─────────────────────────────────────────
              if (provider.currentLocation == null) const _WaitingOverlay(),

              // ── Bottom info card ──────────────────────────────────────────
              if (provider.currentLocation != null)
                Positioned(
                  bottom: 32,
                  left: 16,
                  right: 16,
                  child: _InfoCard(location: provider.currentLocation!),
                ),

              // ── Follow / zoom FABs ────────────────────────────────────────
              Positioned(
                bottom: provider.currentLocation != null ? 148 : 32,
                right: 16,
                child: Column(
                  children: [
                    _MapFab(
                      icon: _followVehicle
                          ? Icons.gps_fixed
                          : Icons.gps_not_fixed,
                      tooltip: _followVehicle ? 'Following' : 'Follow vehicle',
                      active: _followVehicle,
                      onTap: () {
                        setState(() => _followVehicle = !_followVehicle);
                        if (_followVehicle &&
                            provider.currentLocation != null) {
                          _animateCameraTo(provider.currentLocation!);
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    _MapFab(
                      icon: Icons.add,
                      tooltip: 'Zoom in',
                      onTap: () async {
                        final ctrl = await _mapController.future;
                        ctrl.animateCamera(CameraUpdate.zoomIn());
                      },
                    ),
                    const SizedBox(height: 10),
                    _MapFab(
                      icon: Icons.remove,
                      tooltip: 'Zoom out',
                      onTap: () async {
                        final ctrl = await _mapController.future;
                        ctrl.animateCamera(CameraUpdate.zoomOut());
                      },
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Top App Bar
// ─────────────────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final bool isConnected;
  final bool isConnecting;
  final String statusMessage;
  final Animation<double> pulseAnimation;
  final MapType mapType;
  final VoidCallback onMapTypeToggle;
  final VoidCallback onClearTrail;

  const _TopBar({
    required this.isConnected,
    required this.isConnecting,
    required this.statusMessage,
    required this.pulseAnimation,
    required this.mapType,
    required this.onMapTypeToggle,
    required this.onClearTrail,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xE60F172A), Color(0x000F172A)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Row(
              children: [
                // App title + icon
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: const Color(0xFF334155), width: 1),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.directions_car,
                          color: Color(0xFF3B82F6), size: 20),
                      SizedBox(width: 8),
                      Text(
                        'FleetTrack',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Connection badge
                AnimatedBuilder(
                  animation: pulseAnimation,
                  builder: (_, __) => Opacity(
                    opacity: isConnected ? pulseAnimation.value : 1.0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isConnected
                            ? const Color(0xFF166534)
                            : isConnecting
                                ? const Color(0xFF92400E)
                                : const Color(0xFF7F1D1D),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: isConnected
                            ? [
                                BoxShadow(
                                  color:
                                      const Color(0xFF22C55E).withOpacity(0.4),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                )
                              ]
                            : [],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isConnected
                                ? Icons.radio_button_checked
                                : isConnecting
                                    ? Icons.sync
                                    : Icons.wifi_off,
                            color: isConnected
                                ? const Color(0xFF4ADE80)
                                : const Color(0xFFFCA5A5),
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            statusMessage,
                            style: TextStyle(
                              color: isConnected
                                  ? const Color(0xFF4ADE80)
                                  : const Color(0xFFFCA5A5),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // Map type toggle
                _IconBtn(
                  icon: mapType == MapType.normal
                      ? Icons.satellite_alt
                      : Icons.map,
                  tooltip: mapType == MapType.normal
                      ? 'Satellite view'
                      : 'Normal view',
                  onTap: onMapTypeToggle,
                ),

                const SizedBox(width: 8),

                // Clear trail
                _IconBtn(
                  icon: Icons.delete_sweep_outlined,
                  tooltip: 'Clear trail',
                  onTap: onClearTrail,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small icon button for the header
// ─────────────────────────────────────────────────────────────────────────────

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _IconBtn(
      {required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: Icon(icon, color: Colors.white70, size: 18),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Floating action button on the map
// ─────────────────────────────────────────────────────────────────────────────

class _MapFab extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool active;

  const _MapFab({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: active ? const Color(0xFF3B82F6) : const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: active ? const Color(0xFF60A5FA) : const Color(0xFF334155),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Waiting overlay (no signal yet)
// ─────────────────────────────────────────────────────────────────────────────

class _WaitingOverlay extends StatelessWidget {
  const _WaitingOverlay();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        decoration: BoxDecoration(
          color: const Color(0xCC1E293B),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF334155)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 24,
            ),
          ],
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              color: Color(0xFF3B82F6),
              strokeWidth: 3,
            ),
            SizedBox(height: 16),
            Text(
              'Waiting for vehicle signal…',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Run simulate_gps.py to test',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom info card
// ─────────────────────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final VehicleLocation location;

  const _InfoCard({required this.location});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xF01E293B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF334155)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Stat row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatTile(
                icon: Icons.speed_rounded,
                label: 'Speed',
                value: location.speed.toStringAsFixed(0),
                unit: 'km/h',
                color: _speedColor(location.speed),
              ),
              _divider(),
              _StatTile(
                icon: location.ignition
                    ? Icons.electric_bolt
                    : Icons.power_settings_new,
                label: 'Ignition',
                value: location.ignition ? 'ON' : 'OFF',
                unit: '',
                color: location.ignition
                    ? const Color(0xFF4ADE80)
                    : const Color(0xFFF87171),
              ),
              _divider(),
              _StatTile(
                icon: Icons.navigation_rounded,
                label: 'Heading',
                value: location.heading.toStringAsFixed(0),
                unit: '°',
                color: const Color(0xFFFBBF24),
              ),
              _divider(),
              _StatTile(
                icon: Icons.access_time_rounded,
                label: 'Updated',
                value: DateFormat('HH:mm').format(location.timestamp),
                unit: '${DateFormat('ss').format(location.timestamp)}s',
                color: const Color(0xFF60A5FA),
              ),
            ],
          ),

          const SizedBox(height: 14),
          const Divider(color: Color(0xFF334155), height: 1),
          const SizedBox(height: 10),

          // Coordinates row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.location_on_outlined,
                  color: Color(0xFF94A3B8), size: 14),
              const SizedBox(width: 4),
              Text(
                '${location.lat.toStringAsFixed(5)}, ${location.lng.toStringAsFixed(5)}',
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
              if (location.odometer > 0) ...[
                const SizedBox(width: 16),
                const Icon(Icons.straighten,
                    color: Color(0xFF94A3B8), size: 14),
                const SizedBox(width: 4),
                Text(
                  '${location.odometer.toStringAsFixed(0)} km',
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Color _speedColor(double speed) {
    if (speed < 30) return const Color(0xFF4ADE80);
    if (speed < 80) return const Color(0xFFFBBF24);
    return const Color(0xFFF87171);
  }

  Widget _divider() => Container(
        width: 1,
        height: 40,
        color: const Color(0xFF334155),
      );
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final Color color;

  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: TextStyle(
                    color: color,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (unit.isNotEmpty)
                  TextSpan(
                    text: ' $unit',
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
