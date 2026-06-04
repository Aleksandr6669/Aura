import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'ring_ble_manager.dart';
import 'dashboard_view.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => RingBleManager()..startAutoconnectLoop(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ring Connect - AccelScope',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF74C7EC),
        scaffoldBackgroundColor: const Color(0xFF0F0F17),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF74C7EC),
          secondary: Color(0xFF89B4FA),
          surface: Color(0xFF161622),
        ),
        useMaterial3: true,
      ),
      home: const DashboardView(),
    );
  }
}
