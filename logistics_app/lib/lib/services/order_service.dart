import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/order_model.dart';
import 'auth_service.dart';

/// نموذج استجابة التحديث
class UpdateResponse {
  final bool success;
  final String message;

  UpdateResponse({
    required this.success,
    required this.message,
  });
}

/// خدمة إدارة الطلبات
class OrderService {
  // 🔗 رابط السيرفر على Railway
  static const String _baseUrl = 'https://longest-ice-production.up.railway.app/api';
  
  final AuthService _authService = AuthService();

  /// 📋 جلب طلبات المندوب
  Future<List<Order>> getDriverOrders() async {
    try {
      final token = await _authService.getToken();
      
      final response = await http.get(
        Uri.parse('$_baseUrl/shipments'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> ordersJson = data['shipments'] ?? [];
        return ordersJson.map((json) => Order.fromJson(json)).toList();
      } else {
        throw Exception('فشل في تحميل الطلبات');
      }
    } catch (e) {
      print('Error getting orders: $e');
      // بيانات تجريبية للاختبار
      return _getMockOrders();
    }
  }

  /// 📦 جلب شحنات العميل
  Future<Map<String, dynamic>> getClientShipments() async {
    try {
      final token = await _authService.getToken();
      
      final response = await http.get(
        Uri.parse('$_baseUrl/shipments'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      return jsonDecode(response.body);
    } catch (e) {
      print('Error getting client shipments: $e');
      return {'success': false, 'message': 'خطأ في الاتصال'};
    }
  }

  /// ✅ تحديث حالة الطلب
  Future<UpdateResponse> updateOrderStatus({
    required String orderId,
    required String status,
    String? note,
  }) async {
    try {
      final token = await _authService.getToken();
      
      final response = await http.post(
        Uri.parse('$_baseUrl/orders/$orderId/status'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'status': status,
          'note': note,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return UpdateResponse(
          success: true,
          message: data['message'] ?? 'تم التحديث بنجاح',
        );
      } else {
        final data = jsonDecode(response.body);
        return UpdateResponse(
          success: false,
          message: data['message'] ?? 'فشل التحديث',
        );
      }
    } catch (e) {
      print('Error updating order: $e');
      return UpdateResponse(
        success: false,
        message: 'خطأ في الاتصال بالسيرفر',
      );
    }
  }

  /// 📦 جلب تفاصيل طلب معين
  Future<Order?> getOrderDetails(String orderId) async {
    try {
      final token = await _authService.getToken();
      
      final response = await http.get(
        Uri.parse('$_baseUrl/orders/$orderId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return Order.fromJson(data['order']);
      }
      return null;
    } catch (e) {
      print('Error getting order details: $e');
      return null;
    }
  }

  /// 📦 جلب تفاصيل الشحنة (للتتبع)
  Future<Map<String, dynamic>> getShipmentDetails(int shipmentId) async {
    try {
      final token = await _authService.getToken();
      
      final response = await http.get(
        Uri.parse('$_baseUrl/shipments/$shipmentId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      return jsonDecode(response.body);
    } catch (e) {
      print('Error getting shipment details: $e');
      return {'success': false, 'message': 'خطأ في الاتصال'};
    }
  }

  /// 📦 جلب شحنات العميل
  Future<Map<String, dynamic>> getClientShipments() async {
    try {
      final token = await _authService.getToken();
      
      final response = await http.get(
        Uri.parse('$_baseUrl/shipments'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      return jsonDecode(response.body);
    } catch (e) {
      print('Error getting shipments: $e');
      return {'success': false, 'message': 'خطأ في الاتصال'};
    }
  }

  /// 📦 إنشاء شحنة جديدة
  Future<Map<String, dynamic>> createShipment({
    required String customerName,
    required String customerPhone,
    required String destination,
    required String serviceType,
    double? weight,
    double? cost,
    String? notes,
    double? pickupLat,
    double? pickupLng,
    String? pickupAddress,
  }) async {
    try {
      final token = await _authService.getToken();
      
      final response = await http.post(
        Uri.parse('$_baseUrl/shipments'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'customer_name': customerName,
          'customer_phone': customerPhone,
          'destination': destination,
          'service_type': serviceType,
          'weight': weight,
          'cost': cost,
          'notes': notes,
          'pickup_lat': pickupLat,
          'pickup_lng': pickupLng,
          'pickup_address': pickupAddress,
        }),
      );

      return jsonDecode(response.body);
    } catch (e) {
      print('Error creating shipment: $e');
      return {'success': false, 'message': 'خطأ في الاتصال'};
    }
  }

  /// 📷 مسح QR Code مع موقع
  Future<Map<String, dynamic>> scanQRWithLocation({
    required int shipmentId,
    required String scanType,
    required String qrData,
    required double latitude,
    required double longitude,
    double? accuracy,
    String? photoUrl,
    String? notes,
  }) async {
    try {
      final token = await _authService.getToken();
      
      final response = await http.post(
        Uri.parse('$_baseUrl/qr/scan'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'shipment_id': shipmentId,
          'scan_type': scanType,
          'qr_data': qrData,
          'latitude': latitude,
          'longitude': longitude,
          'accuracy': accuracy,
          'photo_url': photoUrl,
          'notes': notes,
        }),
      );

      return jsonDecode(response.body);
    } catch (e) {
      print('Error scanning QR: $e');
      return {'success': false, 'message': 'خطأ في الاتصال'};
    }
  }

  /// ✅ تحديث حالة الشحنة (للسائق)
  Future<Map<String, dynamic>> updateShipmentStatus({
    required int shipmentId,
    required String status,
    double? lat,
    double? lng,
    String? notes,
  }) async {
    try {
      final token = await _authService.getToken();
      
      final response = await http.put(
        Uri.parse('$_baseUrl/shipments/$shipmentId/status'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'status': status,
          'lat': lat,
          'lng': lng,
          'notes': notes,
        }),
      );

      return jsonDecode(response.body);
    } catch (e) {
      print('Error updating shipment status: $e');
      return {'success': false, 'message': 'خطأ في الاتصال'};
    }
  }

  /// 🧪 بيانات تجريبية للاختبار
  List<Order> _getMockOrders() {
    return [
      Order(
        id: '12345',
        customerName: 'أحمد محمد',
        customerPhone: '01012345678',
        address: 'القاهرة، مدينة نصر، شارع مصطفى النحاس',
        latitude: 30.0444,
        longitude: 31.2357,
        amount: 250.0,
        status: 'pending',
        createdAt: '2024-01-15 10:30',
        items: [
          OrderItem(name: 'منتج 1', quantity: 2, price: 100),
          OrderItem(name: 'منتج 2', quantity: 1, price: 50),
        ],
      ),
    ];
  }
}
