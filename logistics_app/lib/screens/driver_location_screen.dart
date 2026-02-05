import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/user_service.dart';

class DriverLocationScreen extends StatefulWidget {
  final String driverId;
  final String driverName;
  final String? driverPhone;
  final String? vehiclePlate;

  const DriverLocationScreen({
    Key? key,
    required this.driverId,
    required this.driverName,
    this.driverPhone,
    this.vehiclePlate,
  }) : super(key: key);

  @override
  State<DriverLocationScreen> createState() => _DriverLocationScreenState();
}

class _DriverLocationScreenState extends State<DriverLocationScreen> {
  final UserService _userService = UserService();
  final MapController _mapController = MapController();
  
  DriverLocation? _driverLocation;
  bool _isLoading = true;
  String? _errorMessage;
  Timer? _refreshTimer;
  DateTime? _lastUpdated;

  @override
  void initState() {
    super.initState();
    _loadDriverLocation();
    
    // تحديث تلقائي كل 30 ثانية
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _loadDriverLocation(showLoading: false),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  /// 📍 تحميل موقع السائق
  Future<void> _loadDriverLocation({bool showLoading = true}) async {
    if (showLoading) {
      setState(() => _isLoading = true);
    }

    try {
      final location = await _userService.getDriverLocation(widget.driverId);
      
      if (location != null) {
        setState(() {
          _driverLocation = location;
          _lastUpdated = DateTime.now();
          _isLoading = false;
        });
        
        // تحريك الكاميرا للموقع الجديد
        _mapController.move(
          LatLng(location.latitude, location.longitude),
          _mapController.zoom,
        );
      } else {
        setState(() {
          _errorMessage = 'لم يتم العثور على موقع السائق';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (showLoading) {
        setState(() {
          _errorMessage = 'خطأ في تحميل الموقع';
          _isLoading = false;
        });
      }
    }
  }

  /// 📞 الاتصال بالسائق
  Future<void> _callDriver() async {
    final phone = _driverLocation?.driverPhone ?? widget.driverPhone;
    if (phone == null) {
      _showSnackBar('رقم الهاتف غير متوفر', Colors.orange);
      return;
    }

    final Uri phoneUri = Uri(scheme: 'tel', path: phone);
    try {
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        _showSnackBar('لا يمكن الاتصال', Colors.red);
      }
    } catch (e) {
      _showSnackBar('خطأ في الاتصال', Colors.red);
    }
  }

  /// 🗺️ فتح في خرائط Google
  Future<void> _openGoogleMaps() async {
    if (_driverLocation == null) return;
    
    final url = 'https://www.google.com/maps/dir/?api=1&destination='
        '${_driverLocation!.latitude},${_driverLocation!.longitude}';
    
    final Uri uri = Uri.parse(url);
    
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _showSnackBar('لا يمكن فتح الخرائط', Colors.red);
      }
    } catch (e) {
      _showSnackBar('خطأ في فتح الخرائط', Colors.red);
    }
  }

  /// 🔔 إظهار رسالة
  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
      ),
    );
  }

  /// ⏱️ حساب الوقت المنقضي
  String _getTimeAgo() {
    if (_lastUpdated == null) return 'غير معروف';
    
    final now = DateTime.now();
    final diff = now.difference(_lastUpdated!);
    
    if (diff.inSeconds < 60) {
      return 'منذ ${diff.inSeconds} ثانية';
    } else if (diff.inMinutes < 60) {
      return 'منذ ${diff.inMinutes} دقيقة';
    } else {
      return 'منذ ${diff.inHours} ساعة';
    }
  }

  /// 🎨 لون حالة التحديث
  Color _getUpdateStatusColor() {
    if (_lastUpdated == null) return Colors.grey;
    
    final diff = DateTime.now().difference(_lastUpdated!);
    if (diff.inMinutes < 5) return Colors.green;
    if (diff.inMinutes < 30) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('موقع السائق'),
        centerTitle: true,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF667eea), Color(0xFF764ba2)],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadDriverLocation(),
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null && _driverLocation == null
              ? _buildErrorWidget()
              : Column(
                  children: [
                    // 🗺️ الخريطة
                    Expanded(
                      flex: 2,
                      child: _buildMap(),
                    ),
                    
                    // 🎴 كارت معلومات السائق
                    _buildDriverInfoCard(),
                  ],
                ),
    );
  }

  /// 🗺️ الخريطة
  Widget _buildMap() {
    if (_driverLocation == null) {
      return const Center(
        child: Text('الموقع غير متوفر'),
      );
    }

    final driverLatLng = LatLng(
      _driverLocation!.latitude,
      _driverLocation!.longitude,
    );

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        center: driverLatLng,
        zoom: 15,
        minZoom: 5,
        maxZoom: 18,
      ),
      children: [
        // طبقة OpenStreetMap
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.logistics.app',
        ),
        
        // علامة موقع السائق
        MarkerLayer(
          markers: [
            Marker(
              point: driverLatLng,
              width: 120,
              height: 120,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: const Text(
                      'السائق هنا',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.local_shipping,
                    color: Colors.orange,
                    size: 50,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 🎴 كارت معلومات السائق
  Widget _buildDriverInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // مؤشر السحب
            Container(
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 20),
            
            // معلومات السائق
            Row(
              children: [
                // صورة السائق
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF667eea).withOpacity(0.4),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 35,
                  ),
                ),
                const SizedBox(width: 16),
                
                // التفاصيل
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.driverName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (widget.vehiclePlate != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.directions_car,
                                  size: 16, color: Colors.blue.shade700),
                              const SizedBox(width: 4),
                              Text(
                                widget.vehiclePlate!,
                                style: TextStyle(
                                  color: Colors.blue.shade700,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 8),
                      
                      // حالة التحديث
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: _getUpdateStatusColor(),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'آخر تحديث: ${_getTimeAgo()}',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // الأزرار
            Row(
              children: [
                // زر الاتصال
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _callDriver,
                    icon: const Icon(Icons.call),
                    label: const Text('اتصال'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                
                // زر التنقل
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _openGoogleMaps,
                    icon: const Icon(Icons.navigation),
                    label: const Text('تنقل'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF667eea),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // زر تحديث الموقع
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _loadDriverLocation(),
                icon: const Icon(Icons.refresh),
                label: const Text('تحديث الموقع'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ⚠️ ويدجت الخطأ
  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
          const SizedBox(height: 16),
          Text(
            _errorMessage!,
            style: TextStyle(color: Colors.red.shade700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _loadDriverLocation(),
            icon: const Icon(Icons.refresh),
            label: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }
}
