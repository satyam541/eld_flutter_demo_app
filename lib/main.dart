import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:provider/provider.dart';
import 'providers/ble_provider.dart';
import 'screens/home_screen.dart';

// Override at build time:
//   flutter build apk --release --dart-define=PORTAL_URL=https://other.example.com
const String _portalUrl = String.fromEnvironment(
  'PORTAL_URL',
  defaultValue: 'https://eld-reboot.satyamsuri.com',
);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterBluePlus.setLogLevel(LogLevel.none, color: false);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const FleetTrackerApp());
}

class FleetTrackerApp extends StatelessWidget {
  const FleetTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => BleProvider(portalUrl: _portalUrl),
      child: MaterialApp(
        title: 'Pacific ELD — Driver',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF0F172A),
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF3B82F6),
            brightness: Brightness.dark,
            surface: const Color(0xFF1E293B),
          ),
          useMaterial3: true,
        ),
        home: const HomeScreen(),
      ),
    );
  }
}

