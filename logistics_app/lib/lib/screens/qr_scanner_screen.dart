import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import '../services/order_service.dart';

/// شاشة مسح QR Code مع GPS إجباري
class QRScannerScreen extends StatefulWidget {
  final int? shipmentId;
  final String scanType; // 'pickup', 'delivery', 'transfer'

  const QRScannerScreen({
    Key? key,
    this.shipmentId,
    required this.scanType,
  }) : super(key: key);

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  bool _isScanning = true;
  bool _isProcessing = false;
  Position? _currentPosition;
  String _status = 'جاري تحميل الموقع...';
  Timer? _locationTimer;

  @override
  void initState() {
    super.initState();
    _initLocation();
    // تحديث الموقع كل 5 ثواني
    _locationTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _updateLocation();
    });
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    super.dispose();
  }

  Future<void> _initLocation() async {
    setState(() => _status = 'جاري التحقق من GPS...');
    
    // التحقق من تفعيل الخدمة
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => _status = '⚠️ يجب تفعيل GPS أولاً');
      _showEnableGPSDialog();
      return;
    }

    // التحقق من الصلاحيات
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() => _status = '⚠️ يجب السماح بالوصول للموقع');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() => _status = '⚠️ الصلاحية مرفوضة من الإعدادات');
      return;
    }

    await _updateLocation();
  }

  Future<void> _updateLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      if (mounted) {
        setState(() {
          _currentPosition = position;
          _status = '✅ الموقع متاح - دقة ${position.accuracy.toStringAsFixed(1)} متر';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _status = '⚠️ خطأ في الحصول على الموقع');
      }
    }
  }

  void _showEnableGPSDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.location_off, color: Colors.red),
            SizedBox(width: 10),
            Text('GPS مغلق'),
          ],
        ),
        content: const Text(
          'يجب تفعيل خدمة الموقع (GPS) لمسح الكود\n'
          'البيانات سترسل مع الموقع للتحقق',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Geolocator.openLocationSettings();
            },
            child: const Text('فتح الإعدادات'),
          ),
        ],
      ),
    );
  }

  Future<void> _onQRCodeDetected(String qrData) async {
    if (_isProcessing) return;
    
    // التحقق من الموقع
    if (_currentPosition == null) {
      _showError('يجب الحصول على الموقع أولاً - تأكد من تفعيل GPS');
      return;
    }

    setState(() {
      _isProcessing = true;
      _isScanning = false;
    });

    try {
      final orderService = OrderService();
      final result = await orderService.scanQRWithLocation(
        shipmentId: widget.shipmentId ?? _extractShipmentId(qrData),
        scanType: widget.scanType,
        qrData: qrData,
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
        accuracy: _currentPosition!.accuracy,
      );

      if (result['success']) {
        _showSuccessDialog(result);
      } else {
        _showError(result['message'] ?? 'فشل في مسح الكود');
        setState(() {
          _isProcessing = false;
          _isScanning = true;
        });
      }
    } catch (e) {
      _showError('خطأ: $e');
      setState(() {
        _isProcessing = false;
        _isScanning = true;
      });
    }
  }

  int? _extractShipmentId(String qrData) {
    // استخراج ID من QR Code
    try {
      // QR format: TRK123 or QR123
      final match = RegExp(r'(TRK|QR)(\d+)').firstMatch(qrData);
      if (match != null) {
        return int.parse(match.group(2)!);
      }
    } catch (e) {
      print('Error extracting shipment ID: $e');
    }
    return null;
  }

  void _showSuccessDialog(dynamic result) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 10),
            Text('تم بنجاح!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('✅ تم مسح الكود بنجاح'),
            const SizedBox(height: 10),
            Text(
              '📍 الموقع المرسل:\n'
              'خط العرض: ${result['location']?['lat']?.toStringAsFixed(6) ?? '-'}\n'
              'خط الطول: ${result['location']?['lng']?.toStringAsFixed(6) ?? '-'}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context, true); // Return success
            },
            child: const Text('حسناً'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('مسح QR Code'),
        backgroundColor: Colors.blue.shade700,
      ),
      body: Column(
        children: [
          // شريط حالة الموقع
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: _currentPosition != null ? Colors.green.shade100 : Colors.orange.shade100,
            child: Row(
              children: [
                Icon(
                  _currentPosition != null ? Icons.location_on : Icons.location_off,
                  color: _currentPosition != null ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _status,
                    style: TextStyle(
                      color: _currentPosition != null ? Colors.green.shade800 : Colors.orange.shade800,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (_currentPosition != null)
                  const Icon(Icons.check_circle, color: Colors.green),
              ],
            ),
          ),
          
          // مساحة الكاميرا
          Expanded(
            child: _isScanning && _currentPosition != null
                ? MobileScanner(
                    onDetect: (capture) {
                      final List<Barcode> barcodes = capture.barcodes;
                      for (final barcode in barcodes) {
                        if (barcode.rawValue != null) {
                          _onQRCodeDetected(barcode.rawValue!);
                          break;
                        }
                      }
                    },
                  )
                : _isProcessing
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 20),
                            Text('جاري إرسال البيانات...'),
                          ],
                        ),
                      )
                    : Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.qr_code_scanner,
                              size: 100,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 20),
                            Text(
                              _currentPosition == null
                                  ? 'يجب تفعيل GPS أولاً'
                                  : 'تم إيقاف المسح',
                              style: const TextStyle(
                                fontSize: 18,
                                color: Colors.grey,
                              ),
                            ),
                            if (_currentPosition == null)
                              ElevatedButton.icon(
                                onPressed: _initLocation,
                                icon: const Icon(Icons.refresh),
                                label: const Text('إعادة المحاولة'),
                              ),
                          ],
                        ),
                      ),
          ),
          
          // إرشادات
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade100,
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'ضع الكود داخل الإطار\n'
                    'تأكد من تفعيل GPS لإرسال الموقع مع البيانات',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}