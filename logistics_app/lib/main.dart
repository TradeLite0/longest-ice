import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/driver_dashboard.dart';
import 'screens/map_screen.dart';

void main() {
  runApp(const LogisticsApp());
}

class LogisticsApp extends StatelessWidget {
  const LogisticsApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'نظام اللوجستيات',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF667eea),
        primarySwatch: Colors.blue,
        useMaterial3: true,
        fontFamily: 'Cairo',
        // ستايل عام للأزرار
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        // ستايل عام لحقول الإدخال
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          fillColor: Colors.grey.shade50,
        ),
      ),
      // الرoutes
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/driver_dashboard': (context) => const DriverDashboard(),
        '/map': (context) => const MapScreen(
          destination: 'الموقع',
          lat: 30.0444,
          lng: 31.2357,
        ),
      },
    );
  }
}
