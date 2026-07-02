# CLAUDE.md — ELD Driver App (Flutter)

> Project memory for the **driver app**. Read this first, then continue the flow.
> The backend portal has its own `CLAUDE.md` at
> `../eld_platform_laravel/eld-portal-laravel/CLAUDE.md`.

## What this is
`live_location_demo` — a Flutter app titled **"Pacific ELD — Driver"** (Android + web).
It is the driver-side companion for an ELD fleet system built around the **Geometris
whereQube** OBD device. `pubspec.yaml` name is `live_location_demo`.

It has **two independent data paths**:
1. **BLE → portal (HTTP):** scan/connect to a `WQ-` whereQube over GATT, decode telemetry
   packets, and HTTP-POST each packet to the portal.
   - `lib/services/ble_service.dart` (scan, connect, TLV decode → `GeometrisBlePacket`)
   - `lib/providers/ble_provider.dart` (state + wiring)
   - `lib/services/api_client.dart` (POSTs the packet)
2. **MQTT → live map:** subscribe to a HiveMQ Cloud topic and render a live Google Map trail.
   - `lib/services/mqtt_service.dart`, `lib/providers/location_provider.dart`,
     `lib/screens/map_screen.dart`, `lib/models/vehicle_location.dart`

## Structure
`lib/{services,providers,screens,models}`, `main.dart`. State management via `provider`.
Screens: `home_screen.dart`, `ble_pairing_screen.dart`, `map_screen.dart`.

## Portal target & build
- Portal URL is compiled in `lib/main.dart`: default `https://eld-reboot.satyamsuri.com`,
  override at build time with `--dart-define=PORTAL_URL=https://…`.
- Build APK: `build-apk.ps1` (or `flutter build apk --release --dart-define=PORTAL_URL=…`).
- GPS simulator helper: `simulate_gps.py`.

## Current state & gotchas (critical for continuity)
- **Only the BLE path is live.** `main.dart` mounts `HomeScreen` only; the MQTT/map path is
  **dormant** and ships **placeholder** HiveMQ credentials in `mqtt_service.dart`
  (`xxxx.s2.eu.hivemq.cloud`, `fleet_user` / `YourSecurePassword123`).
- **App↔portal contract mismatch:** `api_client.dart` posts to `POST /api/ingest/ble` with
  **no auth**. The current portal does **not** define that route — it exposes
  `POST /api/ingest/telemetry` (HMAC- or device-token-authenticated). So packets from this
  app would 404 today. Reconciling this is an open integration task.
- **BLE decoder ≠ documented Geometris protocol:** the TLV decode in `ble_service.dart`
  (`_onNotify` / `_decodeTlv`) uses a different item-ID dictionary, plain little-endian
  IEEE floats, and does **no multi-packet reassembly**. The authoritative whereQube protocol
  (`../docs/vendor/geometris-ble-protocol.md`) specifies packet reassembly (`0xCB` id,
  index framing), a different item dictionary, and **byte-swapped** integer decoding
  `(D1<<24)|(D0<<16)|(D3<<8)|D2`. The current decoder looks aimed at a simulator/other
  firmware and likely won't decode real hardware as-is. Verify on first real scan.

## Dependencies (pubspec.yaml)
`google_maps_flutter`, `flutter_blue_plus`, `permission_handler`, `http`,
`pusher_channels_flutter` (declared, minimal wiring), `mqtt_client`, `provider`, `intl`,
`shared_preferences`.

## Related paths
- Backend portal (its own repo + `CLAUDE.md`): `../eld_platform_laravel/eld-portal-laravel/`
- Off-host ingest bridge: a documented component in the portal contract (HMAC-signed
  device→portal); the local `../eld_platform_laravel/bridge/` skeleton folder was removed
  from the tree.
- Vendor hardware protocol docs: `../docs/vendor/` (BLE protocol, packet format, transport options)
- Original whole-system phase plan: `../execution-plan/`

## When continuing work here
- If wiring the app to the real portal: align `api_client.dart` with the portal's
  `/api/ingest/telemetry` shape + HMAC/token auth (see portal `app/Support/Hmac.php` and
  `IngestController`), or add a `/api/ingest/ble` endpoint on the portal side.
- If targeting real hardware: reimplement the BLE parser against
  `../docs/vendor/geometris-ble-protocol.md` (reassembly + byte-swapped ints).
