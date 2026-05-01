class VehicleLocation {
  final double lat;
  final double lng;
  final double speed; // km/h
  final double heading; // degrees 0–360
  final DateTime timestamp;
  final bool ignition;
  final double odometer;

  VehicleLocation({
    required this.lat,
    required this.lng,
    required this.speed,
    required this.heading,
    required this.timestamp,
    required this.ignition,
    required this.odometer,
  });

  factory VehicleLocation.fromJson(Map<String, dynamic> json) {
    return VehicleLocation(
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      speed: (json['speed'] as num?)?.toDouble() ?? 0.0,
      heading: (json['heading'] as num?)?.toDouble() ?? 0.0,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        ((json['timestamp'] as num) * 1000).toInt(),
      ),
      ignition: json['ignition'] as bool? ?? false,
      odometer: (json['odometer'] as num?)?.toDouble() ?? 0.0,
    );
  }

  @override
  String toString() =>
      'VehicleLocation(lat: $lat, lng: $lng, speed: $speed, heading: $heading)';
}
