import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';

/// شاشة قفل GPS - إجبارية لتشغيل التطبيق
class GPSLockScreen extends StatefulWidget {
  final VoidCallback onGPSEnabled;

  const GPSLockScreen({Key? key, required this.onGPSEnabled}) : super(key: key);

  @override
  State<GPSLockScreen> createState() => _GPSLockScreenState();
}

class _GPSLockScreenState extends State<GPSLockScreen> {
  bool _isChecking = false;
  String _status = 'جاري التحقق من الموقع...';
  Timer? _locationTimer;

  @override
  void initState() {
    super.initState();
    _checkLocation();
    // فحص دوري كل 5 ثواني
    _locationTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _checkLocation();
    });
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkLocation() async {
    if (_isChecking) return;
    setState(() => _isChecking = true);

    try {
      // التحقق من تفعيل الخدمة
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _status = 'خدمة الموقع مغلقة - افتح GPS';
          _isChecking = false;
        });
        return;
      }

      // التحقق من الصلاحيات
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _status = 'الصلاحية مرفوضة - اسمح بالوصول للموقع';
            _isChecking = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _status = 'الصلاحية مرفوضة نهائياً - عدل من إعدادات الجهاز';
          _isChecking = false;
        });
        return;
      }

      // محاولة الحصول على الموقع
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (position.latitude != 0 && position.longitude != 0) {
        // ✅ الموقع شغال
        widget.onGPSEnabled();
      }
    } catch (e) {
      setState(() {
        _status = 'خطأ في الحصول على الموقع: $e';
      });
    }

    setState(() => _isChecking = false);
  }

  Future<void> _openSettings() async {
    await Geolocator.openLocationSettings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.red.shade700,
              Colors.red.shade900,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // أيقونة كبيرة
              Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.2),
                  border: Border.all(color: Colors.white, width: 3),
                ),
                child: const Icon(
                  Icons.location_off,
                  size: 80,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 40),
              
              // عنوان
              const Text(
                'الموقع مطلوب!',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              
              // وصف
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  'يجب تفعيل خدمة الموقع (GPS) للمتابعة واستخدام التطبيق',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              
              // حالة التحقق
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isChecking)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    else
                      const Icon(Icons.info_outline, color: Colors.white),
                    const SizedBox(width: 10),
                    Text(
                      _status,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              
              // زرار فتح الإعدادات
              ElevatedButton.icon(
                onPressed: _openSettings,
                icon: const Icon(Icons.settings),
                label: const Text('فتح إعدادات الموقع'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.red.shade900,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  textStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              // زرار إعادة المحاولة
              TextButton.icon(
                onPressed: _checkLocation,
                icon: const Icon(Icons.refresh, color: Colors.white70),
                label: const Text(
                  'إعادة المحاولة',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}