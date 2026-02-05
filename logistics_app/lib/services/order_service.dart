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
        Uri.parse('$_baseUrl/orders/driver'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> ordersJson = data['orders'] ?? [];
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
      Order(
        id: '12346',
        customerName: 'محمد علي',
        customerPhone: '01198765432',
        address: 'الجيزة، الدقي، شارع التحرير',
        latitude: 29.9773,
        longitude: 31.2086,
        amount: 180.0,
        status: 'in_progress',
        createdAt: '2024-01-15 11:00',
      ),
      Order(
        id: '12347',
        customerName: 'سارة أحمد',
        customerPhone: '01234567890',
        address: 'الإسكندرية، سموحة، شارع جمال عبد الناصر',
        latitude: 31.2001,
        longitude: 29.9187,
        amount: 320.0,
        status: 'delivered',
        createdAt: '2024-01-14 09:00',
      ),
    ];
  }
}
