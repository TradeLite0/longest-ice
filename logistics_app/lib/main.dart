import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/driver_dashboard.dart';
import 'screens/map_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/shipment_details_screen.dart';
import 'screens/driver_location_screen.dart';
import 'screens/admin_users_list_screen.dart';
import 'screens/register_screen.dart';
import 'screens/tracking_screen.dart';

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
        // ستايل الـ AppBar
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          backgroundColor: Color(0xFF667eea),
          foregroundColor: Colors.white,
          titleTextStyle: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        // ستايل البطاقات
        cardTheme: CardTheme(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      // الرoutes
      initialRoute: '/login',
      routes: {
        // 🔐 المصادقة
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        
        // 🏠 لوحات التحكم
        '/driver_dashboard': (context) => const DriverDashboard(),
        
        // 🗺️ الخرائط والمواقع
        '/map': (context) {
          final args = ModalRoute.of(context)?.settings.arguments 
              as Map<String, dynamic>?;
          return MapScreen(
            destination: args?['destination'] ?? 'الموقع',
            lat: args?['lat'] ?? 30.0444,
            lng: args?['lng'] ?? 31.2357,
          );
        },
        
        // 👤 الملف الشخصي
        '/profile': (context) => const ProfileScreen(),
        
        // 📦 الشحنات
        '/tracking': (context) => const TrackingScreen(),
        
        // 👥 إدارة المستخدمين (للأدمن)
        '/admin/users': (context) => const AdminUsersListScreen(),
      },
      
      // معالجة المسارات غير المعروفة
      onGenerateRoute: (settings) {
        // مسار تفاصيل الشحنة
        if (settings.name == '/shipment_details') {
          final args = settings.arguments as Map<String, dynamic>?;
          return MaterialPageRoute(
            builder: (context) => ShipmentDetailsScreen(
              shipment: args?['shipment'],
              userType: args?['userType'] ?? 'client',
            ),
          );
        }
        
        // مسار موقع السائق
        if (settings.name == '/driver_location') {
          final args = settings.arguments as Map<String, dynamic>?;
          return MaterialPageRoute(
            builder: (context) => DriverLocationScreen(
              driverId: args?['driverId'] ?? '',
              driverName: args?['driverName'] ?? 'السائق',
              driverPhone: args?['driverPhone'],
              vehiclePlate: args?['vehiclePlate'],
            ),
          );
        }
        
        return null;
      },
      
      // صفحة الخطأ 404
      onUnknownRoute: (settings) {
        return MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: AppBar(
              title: const Text('صفحة غير موجودة'),
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 80,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'الصفحة غير موجودة',
                    style: TextStyle(
                      fontSize: 24,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pushNamed(context, '/login'),
                    icon: const Icon(Icons.home),
                    label: const Text('العودة للرئيسية'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
