// Smoke test for the FleetTracker app.
//
// Verifies the app boots, renders the map scaffold without throwing, and
// shows the waiting overlay before any MQTT message has been received.

import 'package:flutter_test/flutter_test.dart';

import 'package:live_location_demo/main.dart';

void main() {
  testWidgets('FleetTrackerApp boots and shows the waiting overlay',
      (WidgetTester tester) async {
    await tester.pumpWidget(const FleetTrackerApp());
    // Let one frame settle (MQTT connect is fired post-frame; we don't await it).
    await tester.pump();

    // Before any location arrives, the waiting overlay should be visible.
    expect(find.textContaining('Waiting'), findsOneWidget);
  });
}
