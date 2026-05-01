"""
simulate_gps.py — Fake GPS movement for testing FleetTrack without real hardware.

Usage:
  1. pip install paho-mqtt
  2. Edit the BROKER / USERNAME / PASSWORD / TOPIC below to match your HiveMQ cluster.
  3. python simulate_gps.py

The script publishes a new location every 2 seconds, driving the marker in a
small circle around Ludhiana, Punjab.  Watch the Flutter app update live.
"""

import paho.mqtt.client as mqtt
import json
import time
import math

# ── Configure these ──────────────────────────────────────────────────────────
BROKER   = "xxxx.s2.eu.hivemq.cloud"   # ← Your HiveMQ hostname
PORT     = 8883                          # TLS port
USERNAME = "fleet_user"
PASSWORD = "YourSecurePassword123"
TOPIC    = "fleet/88X150380033/location" # matches _deviceSerial in mqtt_service.dart
# ─────────────────────────────────────────────────────────────────────────────

# Starting point: Ludhiana, Punjab
BASE_LAT = 30.9010
BASE_LNG = 75.8573

def on_connect(client, userdata, flags, reason_code, properties):
    if reason_code == 0:
        print(f"[✓] Connected to {BROKER}:{PORT}")
        print(f"[→] Publishing to topic: {TOPIC}")
        print("     Press Ctrl+C to stop.\n")
    else:
        print(f"[✗] Connection failed — reason code {reason_code}")

def on_publish(client, userdata, mid, reason_code, properties):
    pass  # silent on success

client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2)
client.username_pw_set(USERNAME, PASSWORD)
client.tls_set()          # Enable TLS — required for HiveMQ Cloud port 8883
client.on_connect  = on_connect
client.on_publish  = on_publish

print(f"[…] Connecting to {BROKER}:{PORT} …")
client.connect(BROKER, PORT, keepalive=60)
client.loop_start()

time.sleep(2)   # wait for connection handshake

odometer = 12300.0
i = 0

try:
    while True:
        angle      = (i * 3) % 360
        lat_offset = 0.0015 * math.sin(math.radians(angle))
        lng_offset = 0.0015 * math.cos(math.radians(angle))
        speed      = round(30 + 20 * math.sin(math.radians(i * 9)), 1)
        odometer  += speed * (2 / 3600)   # 2-second interval → km

        payload = {
            "lat":       round(BASE_LAT + lat_offset, 6),
            "lng":       round(BASE_LNG + lng_offset, 6),
            "speed":     speed,
            "heading":   angle,
            "timestamp": int(time.time()),
            "ignition":  True,
            "odometer":  round(odometer, 1),
        }

        result = client.publish(TOPIC, json.dumps(payload), qos=1)
        print(
            f"  lat={payload['lat']:.6f}  lng={payload['lng']:.6f}"
            f"  spd={speed:5.1f} km/h  hdg={angle:3d}°"
            f"  odo={odometer:.1f} km"
        )

        i += 1
        time.sleep(2)

except KeyboardInterrupt:
    print("\n[■] Stopped.")

finally:
    client.loop_stop()
    client.disconnect()
