import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

/// 📦 نموذج الشحنة
class Shipment {
  final String id;
  final String trackingNumber;
  final String status;
  final String? description;
  final double weight;
  final double amount;
  final DateTime createdAt;
  final DateTime? pickupDate;
  final DateTime? deliveryDate;
  final DateTime? estimatedDeliveryDate;
  
  // العميل
  final String customerId;
  final String customerName;
  final String customerPhone;
  final String? customerEmail;
  
  // السائق
  final String? driverId;
  final String? driverName;
  final String? driverPhone;
  final String? driverAvatarUrl;
  
  // العناوين
  final String pickupAddress;
  final double pickupLat;
  final double pickupLng;
  final String deliveryAddress;
  final double deliveryLat;
  final double deliveryLng;
  
  // المسؤول
  final String? createdBy;
  final String? createdByName;

  Shipment({
    required this.id,
    required this.trackingNumber,
    required this.status,
    this.description,
    required this.weight,
    required this.amount,
    required this.createdAt,
    this.pickupDate,
    this.deliveryDate,
    this.estimatedDeliveryDate,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    this.customerEmail,
    this.driverId,
    this.driverName,
    this.driverPhone,
    this.driverAvatarUrl,
    required this.pickupAddress,
    required this.pickupLat,
    required this.pickupLng,
    required this.deliveryAddress,
    required this.deliveryLat,
    required this.deliveryLng,
    this.createdBy,
    this.createdByName,
  });

  factory Shipment.fromJson(Map<String, dynamic> json) {
    return Shipment(
      id: json['id'] ?? '',
      trackingNumber: json['tracking_number'] ?? '',
      status: json['status'] ?? 'pending',
      description: json['description'],
      weight: (json['weight'] ?? 0.0).toDouble(),
      amount: (json['amount'] ?? 0.0).toDouble(),
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.now(),
      pickupDate: json['pickup_date'] != null 
          ? DateTime.parse(json['pickup_date']) 
          : null,
      deliveryDate: json['delivery_date'] != null 
          ? DateTime.parse(json['delivery_date']) 
          : null,
      estimatedDeliveryDate: json['estimated_delivery_date'] != null 
          ? DateTime.parse(json['estimated_delivery_date']) 
          : null,
      customerId: json['customer_id'] ?? '',
      customerName: json['customer_name'] ?? '',
      customerPhone: json['customer_phone'] ?? '',
      customerEmail: json['customer_email'],
      driverId: json['driver_id'],
      driverName: json['driver_name'],
      driverPhone: json['driver_phone'],
      driverAvatarUrl: json['driver_avatar_url'],
      pickupAddress: json['pickup_address'] ?? '',
      pickupLat: (json['pickup_lat'] ?? 0.0).toDouble(),
      pickupLng: (json['pickup_lng'] ?? 0.0).toDouble(),
      deliveryAddress: json['delivery_address'] ?? '',
      deliveryLat: (json['delivery_lat'] ?? 0.0).toDouble(),
      deliveryLng: (json['delivery_lng'] ?? 0.0).toDouble(),
      createdBy: json['created_by'],
      createdByName: json['created_by_name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tracking_number': trackingNumber,
      'status': status,
      'description': description,
      'weight': weight,
      'amount': amount,
      'created_at': createdAt.toIso8601String(),
      'pickup_date': pickupDate?.toIso8601String(),
      'delivery_date': deliveryDate?.toIso8601String(),
      'estimated_delivery_date': estimatedDeliveryDate?.toIso8601String(),
      'customer_id': customerId,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'customer_email': customerEmail,
      'driver_id': driverId,
      'driver_name': driverName,
      'driver_phone': driverPhone,
      'driver_avatar_url': driverAvatarUrl,
      'pickup_address': pickupAddress,
      'pickup_lat': pickupLat,
      'pickup_lng': pickupLng,
      'delivery_address': deliveryAddress,
      'delivery_lat': deliveryLat,
      'delivery_lng': deliveryLng,
      'created_by': createdBy,
      'created_by_name': createdByName,
    };
  }

  Shipment copyWith({
    String? status,
    DateTime? pickupDate,
    DateTime? deliveryDate,
    String? driverId,
    String? driverName,
    String? driverPhone,
  }) {
    return Shipment(
      id: id,
      trackingNumber: trackingNumber,
      status: status ?? this.status,
      description: description,
      weight: weight,
      amount: amount,
      createdAt: createdAt,
      pickupDate: pickupDate ?? this.pickupDate,
      deliveryDate: deliveryDate ?? this.deliveryDate,
      estimatedDeliveryDate: estimatedDeliveryDate,
      customerId: customerId,
      customerName: customerName,
      customerPhone: customerPhone,
      customerEmail: customerEmail,
      driverId: driverId ?? this.driverId,
      driverName: driverName ?? this.driverName,
      driverPhone: driverPhone ?? this.driverPhone,
      driverAvatarUrl: driverAvatarUrl,
      pickupAddress: pickupAddress,
      pickupLat: pickupLat,
      pickupLng: pickupLng,
      deliveryAddress: deliveryAddress,
      deliveryLat: deliveryLat,
      deliveryLng: deliveryLng,
      createdBy: createdBy,
      createdByName: createdByName,
    );
  }
}

/// 📝 نموذج حالة الشحنة (للتايم لاين)
class ShipmentStatus {
  final String status;
  final String description;
  final DateTime timestamp;
  final String? location;
  final String? updatedBy;

  ShipmentStatus({
    required this.status,
    required this.description,
    required this.timestamp,
    this.location,
    this.updatedBy,
  });

  factory ShipmentStatus.fromJson(Map<String, dynamic> json) {
    return ShipmentStatus(
      status: json['status'] ?? '',
      description: json['description'] ?? '',
      timestamp: json['timestamp'] != null 
          ? DateTime.parse(json['timestamp']) 
          : DateTime.now(),
      location: json['location'],
      updatedBy: json['updated_by'],
    );
  }
}

/// خدمة الشحنات
class ShipmentService {
  static const String _baseUrl = 'https://longest-ice-production.up.railway.app/api';
  final AuthService _authService = AuthService();

  /// 📋 جلب الشحنات
  Future<List<Shipment>> getShipments({
    String? status,
    String? customerId,
    String? driverId,
  }) async {
    try {
      final token = await _authService.getToken();
      
      final queryParams = <String, String>{};
      if (status != null) queryParams['status'] = status;
      if (customerId != null) queryParams['customer_id'] = customerId;
      if (driverId != null) queryParams['driver_id'] = driverId;
      
      final uri = Uri.parse('$_baseUrl/shipments').replace(queryParameters: queryParams);
      
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> shipmentsJson = data['shipments'] ?? [];
        return shipmentsJson.map((json) => Shipment.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Error getting shipments: $e');
      return _getMockShipments();
    }
  }

  /// 📦 جلب تفاصيل شحنة
  Future<Shipment?> getShipmentDetails(String shipmentId) async {
    try {
      final token = await _authService.getToken();
      
      final response = await http.get(
        Uri.parse('$_baseUrl/shipments/$shipmentId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return Shipment.fromJson(data['shipment']);
      }
      return null;
    } catch (e) {
      print('Error getting shipment details: $e');
      return _getMockShipment(shipmentId);
    }
  }

  /// 📜 جلب تاريخ حالات الشحنة
  Future<List<ShipmentStatus>> getShipmentTimeline(String shipmentId) async {
    try {
      final token = await _authService.getToken();
      
      final response = await http.get(
        Uri.parse('$_baseUrl/shipments/$shipmentId/timeline'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> timelineJson = data['timeline'] ?? [];
        return timelineJson.map((json) => ShipmentStatus.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Error getting shipment timeline: $e');
      return _getMockTimeline();
    }
  }

  /// ✅ تحديث حالة الشحنة
  Future<Map<String, dynamic>> updateShipmentStatus({
    required String shipmentId,
    required String status,
    String? note,
  }) async {
    try {
      final token = await _authService.getToken();
      
      final response = await http.post(
        Uri.parse('$_baseUrl/shipments/$shipmentId/status'),
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
        return {'success': true, 'message': data['message'] ?? 'تم التحديث'};
      } else {
        final data = jsonDecode(response.body);
        return {'success': false, 'message': data['message'] ?? 'فشل التحديث'};
      }
    } catch (e) {
      return {'success': false, 'message': 'خطأ في الاتصال: $e'};
    }
  }

  /// 🚚 تعيين سائق للشحنة
  Future<Map<String, dynamic>> assignDriver({
    required String shipmentId,
    required String driverId,
  }) async {
    try {
      final token = await _authService.getToken();
      
      final response = await http.post(
        Uri.parse('$_baseUrl/shipments/$shipmentId/assign'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'driver_id': driverId}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'message': data['message'] ?? 'تم التعيين'};
      } else {
        final data = jsonDecode(response.body);
        return {'success': false, 'message': data['message'] ?? 'فشل التعيين'};
      }
    } catch (e) {
      return {'success': false, 'message': 'خطأ في الاتصال: $e'};
    }
  }

  /// 🧪 بيانات تجريبية للشحنات
  List<Shipment> _getMockShipments() {
    return [
      _getMockShipment('1'),
      _getMockShipment('2'),
      _getMockShipment('3'),
    ];
  }

  /// 🧪 بيانات تجريبية لشحنة
  Shipment _getMockShipment(String id) {
    return Shipment(
      id: id,
      trackingNumber: 'TRK${DateTime.now().year}$id${id.padLeft(4, '0')}',
      status: id == '1' ? 'pending' : id == '2' ? 'in_transit' : 'delivered',
      description: 'شحنة إلكترونيات',
      weight: 5.5,
      amount: 250.0,
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      pickupDate: DateTime.now().subtract(const Duration(days: 1)),
      estimatedDeliveryDate: DateTime.now().add(const Duration(days: 1)),
      customerId: 'c$id',
      customerName: 'عميل $id',
      customerPhone: '0101234567$id',
      customerEmail: 'customer$id@example.com',
      driverId: 'd1',
      driverName: 'أحمد محمد',
      driverPhone: '01098765432',
      pickupAddress: 'القاهرة، مدينة نصر، شارع مصطفى النحاس',
      pickupLat: 30.0444,
      pickupLng: 31.2357,
      deliveryAddress: 'الجيزة، الدقي، شارع التحرير',
      deliveryLat: 29.9773,
      deliveryLng: 31.2086,
      createdBy: 'admin1',
      createdByName: 'المدير',
    );
  }

  /// 🧪 بيانات تجريبية للتايم لاين
  List<ShipmentStatus> _getMockTimeline() {
    return [
      ShipmentStatus(
        status: 'created',
        description: 'تم إنشاء الشحنة',
        timestamp: DateTime.now().subtract(const Duration(days: 2)),
        location: 'القاهرة',
        updatedBy: 'النظام',
      ),
      ShipmentStatus(
        status: 'pending',
        description: 'في انتظار التوصيل',
        timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 12)),
        location: 'القاهرة',
        updatedBy: 'المدير',
      ),
      ShipmentStatus(
        status: 'in_transit',
        description: 'الشحنة في الطريق',
        timestamp: DateTime.now().subtract(const Duration(hours: 6)),
        location: 'الجيزة',
        updatedBy: 'أحمد محمد',
      ),
    ];
  }
}
