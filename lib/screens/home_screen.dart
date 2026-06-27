import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/ble_provider.dart';
import 'ble_pairing_screen.dart';
import 'map_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _showDiagnostics = false;

  @override
  Widget build(BuildContext context) {
    final ble = context.watch<BleProvider>();
    final pkt = ble.lastPacket;

    return Scaffold(
      backgroundColor: const Color(0xFF0B1220),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: const Icon(
                Icons.directions_car_rounded,
                color: Color(0xFF3B82F6),
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pacific ELD',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  'Driver Companion',
                  style: TextStyle(
                    fontSize: 10,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Quick Connection status beacon in AppBar
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: _StatusBeacon(connected: ble.connected),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0F172A),
              Color(0xFF020617),
            ],
          ),
        ),
        child: RefreshIndicator(
          onRefresh: () async {
            if (ble.connected) {
              // Simulating checking status or refreshing list
              await Future.delayed(const Duration(milliseconds: 500));
            } else {
              await ble.scan();
            }
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Connection Card
                _buildConnectionCard(context, ble),
                const SizedBox(height: 16),

                // 2. Active Telemetry Dashboard OR Offline State
                if (pkt != null) ...[
                  _buildDashboard(context, pkt),
                  const SizedBox(height: 16),
                ] else ...[
                  _buildOfflineState(ble),
                  const SizedBox(height: 16),
                ],

                // 3. Collapsible Diagnostics / Uplink status
                _buildDiagnosticsCollapsible(ble),
                const SizedBox(height: 20),

                // 4. Quick Action Tiles
                const Text(
                  'Quick Navigation',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF94A3B8),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 10),
                _buildActionGrid(context),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Connection Panel Builder ──────────────────────────────────────────────
  Widget _buildConnectionCard(BuildContext context, BleProvider ble) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: ble.connected ? [const Color(0xFF1E293B), const Color(0xFF0F172A)] : [const Color(0xFF1E293B), const Color(0xFF1E293B)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: ble.connected ? const Color(0xFF10B981).withOpacity(0.3) : const Color(0xFF334155),
          width: 1,
        ),
        boxShadow: ble.connected
            ? [
                BoxShadow(
                  color: const Color(0xFF10B981).withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ]
            : [],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: ble.connected ? const Color(0xFF10B981).withOpacity(0.1) : const Color(0xFF334155).withOpacity(0.3),
                shape: BoxShape.circle,
                border: Border.all(
                  color: ble.connected ? const Color(0xFF10B981) : const Color(0xFF475569),
                  width: 1.5,
                ),
              ),
              child: Icon(
                ble.connected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                color: ble.connected ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ble.connected ? 'whereQube Active' : 'No ELD Connected',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    ble.connected && ble.connectedDevice != null
                        ? 'Device ID: ${ble.connectedDevice!.platformName.replaceAll("WQ-", "")}'
                        : ble.status,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BlePairingScreen()),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: ble.connected ? const Color(0xFF334155) : const Color(0xFF3B82F6),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                elevation: 0,
              ),
              child: Text(ble.connected ? 'Manage' : 'Pair'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Offline State Builder ──────────────────────────────────────────────────
  Widget _buildOfflineState(BleProvider ble) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          _AnimatedRadar(scanning: ble.scanning),
          const SizedBox(height: 20),
          const Text(
            'Waiting for Telemetry Stream',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'Connect to a whereQube device or run the BLE/GPS emulator to feed data.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],
      ),
    );
  }

  // ── Active Dashboard Builder ───────────────────────────────────────────────
  Widget _buildDashboard(BuildContext context, dynamic pkt) {
    final speed = pkt.speedMph ?? 0.0;
    final rpm = pkt.rpm ?? 0;
    final isIgnitionOn = pkt.ignition == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // A. Gauge & Main Specs Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: Column(
            children: [
              // Main Speed Gauge Arc
              SizedBox(
                height: 150,
                width: 150,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(150, 150),
                      painter: ModernGaugePainter(
                        value: speed,
                        maxVal: 160.0,
                        activeColor: const Color(0xFF3B82F6),
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          speed.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: -1,
                          ),
                        ),
                        const Text(
                          'MPH',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF64748B),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // RPM Bar Indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'RPM',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  Text(
                    '$rpm RPM',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: rpm > 0 ? const Color(0xFFF59E0B) : const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _buildRpmProgressLine(rpm),
              const SizedBox(height: 16),
              const Divider(color: Color(0xFF334155), height: 1),
              const SizedBox(height: 16),
              // Ignition State & Serial number row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildMiniStat(
                    icon: isIgnitionOn ? Icons.bolt_rounded : Icons.power_settings_new_rounded,
                    iconColor: isIgnitionOn ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                    label: 'Ignition',
                    value: isIgnitionOn ? 'ON' : 'OFF',
                    valColor: isIgnitionOn ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                  ),
                  Container(width: 1, height: 36, color: const Color(0xFF334155)),
                  _buildMiniStat(
                    icon: Icons.calendar_month_rounded,
                    iconColor: const Color(0xFF3B82F6),
                    label: 'Engine Hours',
                    value: pkt.ignitionOnSec != null ? '${(pkt.ignitionOnSec! / 3600.0).toStringAsFixed(1)} hrs' : '—',
                    valColor: Colors.white,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // B. Odometer Digital Baner
        _buildOdometerBanner(pkt),
        const SizedBox(height: 12),

        // C. Core Metrics Grid
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.45,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          children: [
            _buildGridMetric(
              icon: Icons.local_gas_station_rounded,
              color: const Color(0xFF10B981),
              label: 'Fuel Level',
              value: pkt.fuelLevelPct != null ? '${pkt.fuelLevelPct!.toStringAsFixed(1)}%' : '—',
              subtext: pkt.fuelLevelPct != null ? 'OBD Data' : 'Not Available',
              progress: pkt.fuelLevelPct != null ? pkt.fuelLevelPct! / 100.0 : null,
            ),
            _buildGridMetric(
              icon: Icons.speed_rounded,
              color: const Color(0xFFF59E0B),
              label: 'Throttle',
              value: pkt.throttlePct != null ? '${pkt.throttlePct!.toStringAsFixed(1)}%' : '—',
              subtext: pkt.throttlePct != null ? 'Pedal Position' : 'Not Available',
              progress: pkt.throttlePct != null ? pkt.throttlePct! / 100.0 : null,
            ),
            _buildGridMetric(
              icon: Icons.thermostat_rounded,
              color: const Color(0xFFEF4444),
              label: 'Coolant Temp',
              value: pkt.coolantTempC != null ? '${pkt.coolantTempC}°C' : '—',
              subtext: pkt.coolantTempC != null ? (pkt.coolantTempC! > 95 ? 'Hot Warning' : 'Normal Range') : 'Not Available',
            ),
            _buildGridMetric(
              icon: Icons.explore_rounded,
              color: const Color(0xFF8B5CF6),
              label: 'Heading / Sats',
              value: pkt.heading != null ? '${pkt.heading!.toStringAsFixed(0)}°' : '—',
              subtext: pkt.numSatellites != null ? '${pkt.numSatellites} Satellites' : 'GPS Tracking',
            ),
          ],
        ),
        const SizedBox(height: 12),

        // D. GPS Coordinates & VIN
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // GPS coordinates & view map button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded, color: Color(0xFF64748B), size: 18),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Vehicle Coordinates',
                            style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            pkt.latitude != null && pkt.longitude != null
                                ? '${pkt.latitude!.toStringAsFixed(5)}, ${pkt.longitude!.toStringAsFixed(5)}'
                                : 'Seeking Signal…',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              fontFamily: 'monospace',
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton.filledTonal(
                    onPressed: pkt.latitude != null && pkt.longitude != null
                        ? () async {
                            final url = Uri.parse(
                                'https://www.google.com/maps/search/?api=1&query=${pkt.latitude},${pkt.longitude}');
                            try {
                              final launched = await launchUrl(
                                url,
                                mode: LaunchMode.externalApplication,
                              );
                              if (!launched) {
                                await launchUrl(url);
                              }
                            } catch (e) {
                              try {
                                await launchUrl(url);
                              } catch (_) {}
                            }
                          }
                        : null,
                    style: IconButton.styleFrom(
                      backgroundColor: (pkt.latitude != null && pkt.longitude != null)
                          ? const Color(0xFF3B82F6).withOpacity(0.15)
                          : null,
                      foregroundColor: (pkt.latitude != null && pkt.longitude != null)
                          ? const Color(0xFF60A5FA)
                          : null,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.map_rounded, size: 18),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(color: Color(0xFF334155), height: 1),
              const SizedBox(height: 12),
              // VIN Section
              _buildVinRow(context, pkt.vin),
            ],
          ),
        ),
      ],
    );
  }

  // ── Odometer Banner Builder ───────────────────────────────────────────────
  Widget _buildOdometerBanner(dynamic pkt) {
    final odoVal = pkt.odometerMiles != null ? pkt.odometerMiles! / 0.621371 : 0.0;
    final odoStr = odoVal.toStringAsFixed(1).padLeft(8, '0');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.route_rounded, color: Color(0xFF3B82F6), size: 20),
              const SizedBox(width: 8),
              const Text(
                'Odometer',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
          // Custom mechanical roller-styled digit panels
          Row(
            children: [
              ...odoStr.split('').map((char) {
                final isDecimal = char == '.';
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  padding: EdgeInsets.symmetric(
                    horizontal: isDecimal ? 2.0 : 6.0,
                    vertical: 4.0,
                  ),
                  decoration: BoxDecoration(
                    color: isDecimal ? Colors.transparent : const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(3),
                    border: isDecimal ? null : Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Text(
                    char,
                    style: TextStyle(
                      color: isDecimal
                          ? const Color(0xFF3B82F6)
                          : (odoStr.indexOf(char) == odoStr.length - 1
                              ? const Color(0xFFEF4444) // last digit red
                              : Colors.white),
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                );
              }),
              const SizedBox(width: 6),
              const Text(
                'km',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Action Grid Builder ────────────────────────────────────────────────────
  Widget _buildActionGrid(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.1,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      children: [
        _buildActionTile(
          icon: Icons.map_rounded,
          iconColor: const Color(0xFF3B82F6),
          label: 'Live Map',
          subtext: 'Track Vehicle',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MapScreen()),
            );
          },
        ),
        _buildActionTile(
          icon: Icons.assignment_rounded,
          iconColor: const Color(0xFF10B981),
          label: 'DVIR',
          subtext: 'Inspections',
          onTap: () => _showNotImplemented(context, 'DVIR Module'),
        ),
        _buildActionTile(
          icon: Icons.history_rounded,
          iconColor: const Color(0xFFF59E0B),
          label: 'HOS Log',
          subtext: 'Hours of Service',
          onTap: () => _showNotImplemented(context, 'HOS Logs'),
        ),
        _buildActionTile(
          icon: Icons.person_rounded,
          iconColor: const Color(0xFFEC4899),
          label: 'Driver',
          subtext: 'Profile Settings',
          onTap: () => _showNotImplemented(context, 'Driver Settings'),
        ),
      ],
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String subtext,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtext,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Diagnostics / Uplink status Collapsible Builder ────────────────────────
  Widget _buildDiagnosticsCollapsible(BleProvider ble) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: ListTile(
              onTap: () {
                setState(() {
                  _showDiagnostics = !_showDiagnostics;
                });
              },
              leading: Icon(
                Icons.cloud_sync_rounded,
                color: ble.lastApiError != null ? const Color(0xFFEF4444) : const Color(0xFF3B82F6),
                size: 20,
              ),
              title: const Text(
                'Uplink & Network Diagnostics',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.white,
                ),
              ),
              trailing: Icon(
                _showDiagnostics ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                color: const Color(0xFF94A3B8),
              ),
            ),
          ),
          if (_showDiagnostics) ...[
            const Divider(color: Color(0xFF334155), height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildDiagnosticBadge(
                        label: 'Received',
                        value: ble.packetsReceived.toString(),
                        color: const Color(0xFF60A5FA),
                      ),
                      _buildDiagnosticBadge(
                        label: 'Uploaded',
                        value: ble.packetsPosted.toString(),
                        color: const Color(0xFF34D399),
                      ),
                      _buildDiagnosticBadge(
                        label: 'Failed',
                        value: ble.packetsFailed.toString(),
                        color: const Color(0xFFF87171),
                      ),
                    ],
                  ),
                  if (ble.lastApiError != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7F1D1D).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF991B1B).withOpacity(0.5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: Color(0xFFFCA5A5), size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Portal Error: ${ble.lastApiError}',
                              style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (ble.seenTlvIds.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'TLV IDs Captured:',
                      style: TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      (ble.seenTlvIds.toList()..sort()).map((id) => '0x${id.toRadixString(16).padLeft(2, "0").toUpperCase()}').join(', '),
                      style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Color(0xFF94A3B8)),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDiagnosticBadge({required String label, required String value, required Color color}) {
    return Container(
      width: 95,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helper Widgets ─────────────────────────────────────────────────────────
  Widget _buildRpmProgressLine(int rpm) {
    final double fraction = (rpm / 6000.0).clamp(0.0, 1.0);
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        return Container(
          height: 6,
          width: width,
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Row(
            children: [
              Container(
                height: 6,
                width: width * fraction,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF3B82F6),
                      Color(0xFFF59E0B),
                      Color(0xFFEF4444),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMiniStat({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required Color valColor,
  }) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: valColor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGridMetric({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
    required String subtext,
    double? progress,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 2),
              if (progress != null) ...[
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 3,
                    backgroundColor: const Color(0xFF0F172A),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ] else ...[
                Text(
                  subtext,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVinRow(BuildContext context, String? vin) {
    final displayVin = vin ?? '—';
    return Row(
      children: [
        const Icon(Icons.info_outline_rounded, color: Color(0xFF64748B), size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'VIN (Vehicle Identification Number)',
                style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 2),
              Text(
                displayVin,
                style: const TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        if (vin != null && vin.isNotEmpty)
          IconButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: vin));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('VIN copied to clipboard'),
                  duration: Duration(seconds: 2),
                  backgroundColor: Color(0xFF1E293B),
                ),
              );
            },
            icon: const Icon(Icons.copy_rounded, color: Color(0xFF60A5FA), size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
      ],
    );
  }

  void _showNotImplemented(BuildContext context, String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$title is not implemented yet in this demo.'),
        backgroundColor: const Color(0xFF334155),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

// ── Custom Status Beacon Widget ──────────────────────────────────────────────
class _StatusBeacon extends StatelessWidget {
  final bool connected;
  const _StatusBeacon({required this.connected});

  @override
  Widget build(BuildContext context) {
    final beaconColor = connected ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: beaconColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: beaconColor.withOpacity(0.6),
                blurRadius: 4,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Text(
          connected ? 'LIVE' : 'OFFLINE',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: beaconColor,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

// ── Circular Speedometer Arc Painter ─────────────────────────────────────────
class ModernGaugePainter extends CustomPainter {
  final double value;
  final double maxVal;
  final Color activeColor;

  ModernGaugePainter({
    required this.value,
    required this.maxVal,
    required this.activeColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 8;

    // Track arc
    final trackPaint = Paint()
      ..color = const Color(0xFF0F172A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      3.14 * 0.75, // starts at 135 deg
      3.14 * 1.5, // spans 270 deg
      false,
      trackPaint,
    );

    // Active arc representation
    final progress = (value / maxVal).clamp(0.0, 1.0);
    if (progress > 0) {
      // Glow base
      final glowPaint = Paint()
        ..color = activeColor.withOpacity(0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        3.14 * 0.75,
        3.14 * 1.5 * progress,
        false,
        glowPaint,
      );

      // Main active line
      final activePaint = Paint()
        ..color = activeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        3.14 * 0.75,
        3.14 * 1.5 * progress,
        false,
        activePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ── Animated Radar/Scanner Placeholder Widget ───────────────────────────────
class _AnimatedRadar extends StatefulWidget {
  final bool scanning;
  const _AnimatedRadar({required this.scanning});

  @override
  State<_AnimatedRadar> createState() => _AnimatedRadarState();
}

class _AnimatedRadarState extends State<_AnimatedRadar> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    if (widget.scanning) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _AnimatedRadar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.scanning && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.scanning && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Outer ring
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF3B82F6).withOpacity((1.0 - _controller.value).clamp(0.0, 1.0)),
                  width: 2,
                ),
              ),
            ),
            // Middle ring
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF3B82F6).withOpacity((0.6 - _controller.value * 0.5).clamp(0.0, 1.0)),
                  width: 2,
                ),
              ),
            ),
            // Core beacon icon
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF3B82F6), width: 1.5),
              ),
              child: const Icon(
                Icons.sensors_rounded,
                color: Color(0xFF60A5FA),
                size: 20,
              ),
            ),
          ],
        );
      },
    );
  }
}
