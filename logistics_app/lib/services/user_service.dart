import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

/// نموذج المستخدم
class UserModel {
  final String id;
  final String name;
  final String phone;
  final String? email;
  final String type;
  final bool isApproved;
  final String? avatarUrl;
  final String createdAt;
  final String? driverLicense;
  final String? vehiclePlate;

  UserModel({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    required this.type,
    required this.isApproved,
    this.avatarUrl,
    required this.createdAt,
    this.driverLicense,
    this.vehiclePlate,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      email: json['email'],
      type: json['type'] ?? 'client',
      isApproved: json['is_approved'] ?? false,
      avatarUrl: json['avatar_url'],
      createdAt: json['created_at'] ?? '',
      driverLicense: json['driver_license'],
      vehiclePlate: json['vehicle_plate'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'type': type,
      'is_approved': isApproved,
      'avatar_url': avatarUrl,
      'created_at': createdAt,
      'driver_license': driverLicense,
      'vehicle_plate': vehiclePlate,
    };
  }

  UserModel copyWith({
    String? name,
    String? phone,
    String? email,
    String? avatarUrl,
  }) {
    return UserModel(
      id: id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      type: type,
      isApproved: isApproved,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt,
      driverLicense: driverLicense,
      vehiclePlate: vehiclePlate,
    );
  }
}

/// نموذج موقع السائق
class DriverLocation {
  final String driverId;
  final String driverName;
  final String? driverPhone;
  final double latitude;
  final double longitude;
  final DateTime lastUpdated;
  final String? vehiclePlate;

  DriverLocation({
    required this.driverId,
    required this.driverName,
    this.driverPhone,
    required this.latitude,
    required this.longitude,
    required this.lastUpdated,
    this.vehiclePlate,
  });

  factory DriverLocation.fromJson(Map<String, dynamic> json) {
    return DriverLocation(
      driverId: json['driver_id'] ?? '',
      driverName: json['driver_name'] ?? '',
      driverPhone: json['driver_phone'],
      latitude: (json['latitude'] ?? 0.0).toDouble(),
      longitude: (json['longitude'] ?? 0.0).toDouble(),
      lastUpdated: json['last_updated'] != null
          ? DateTime.parse(json['last_updated'])
          : DateTime.now(),
      vehiclePlate: json['vehicle_plate'],
    );
  }
}

/// استجابة تحديث الملف الشخصي
class ProfileUpdateResponse {
  final bool success;
  final String message;
  final UserModel? user;

  ProfileUpdateResponse({
    required this.success,
    required this.message,
    this.user,
  });

  factory ProfileUpdateResponse.fromJson(Map<String, dynamic> json) {
    return ProfileUpdateResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      user: json['user'] != null ? UserModel.fromJson(json['user']) : null,
    );
  }
}

/// خدمة المستخدمين
class UserService {
  static const String _baseUrl = 'https://longest-ice-production.up.railway.app/api';
  final AuthService _authService = AuthService();

  /// 👤 جلب الملف الشخصي
  Future<UserModel?> getProfile() async {
    try {
      final token = await _authService.getToken();
      
      final response = await http.get(
        Uri.parse('$_baseUrl/users/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return UserModel.fromJson(data['user']);
      }
      return null;
    } catch (e) {
      print('Error getting profile: $e');
      // بيانات تجريبية للاختبار
      return _getMockProfile();
    }
  }

  /// ✏️ تحديث الملف الشخصي
  Future<ProfileUpdateResponse> updateProfile({
    required String name,
    String? email,
    String? phone,
  }) async {
    try {
      final token = await _authService.getToken();
      
      final response = await http.put(
        Uri.parse('$_baseUrl/users/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'name': name,
          'email': email,
          'phone': phone,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return ProfileUpdateResponse.fromJson(data);
      } else {
        final data = jsonDecode(response.body);
        return ProfileUpdateResponse(
          success: false,
          message: data['message'] ?? 'فشل التحديث',
        );
      }
    } catch (e) {
      return ProfileUpdateResponse(
        success: false,
        message: 'خطأ في الاتصال: $e',
      );
    }
  }

  /// 🔑 تغيير كلمة المرور
  Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final token = await _authService.getToken();
      
      final response = await http.post(
        Uri.parse('$_baseUrl/users/change-password'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'current_password': currentPassword,
          'new_password': newPassword,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'message': data['message'] ?? 'تم تغيير كلمة المرور'};
      } else {
        final data = jsonDecode(response.body);
        return {'success': false, 'message': data['message'] ?? 'فشل تغيير كلمة المرور'};
      }
    } catch (e) {
      return {'success': false, 'message': 'خطأ في الاتصال: $e'};
    }
  }

  /// 📍 جلب موقع السائق
  Future<DriverLocation?> getDriverLocation(String driverId) async {
    try {
      final token = await _authService.getToken();
      
      final response = await http.get(
        Uri.parse('$_baseUrl/drivers/$driverId/location'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return DriverLocation.fromJson(data['location']);
      }
      return null;
    } catch (e) {
      print('Error getting driver location: $e');
      // بيانات تجريبية للاختبار
      return _getMockDriverLocation(driverId);
    }
  }

  /// 📋 جلب قائمة المستخدمين (للأدمن)
  Future<List<UserModel>> getUsers({
    String? type,
    bool? isApproved,
  }) async {
    try {
      final token = await _authService.getToken();
      
      // بناء معاملات الاستعلام
      final queryParams = <String, String>{};
      if (type != null) queryParams['type'] = type;
      if (isApproved != null) queryParams['is_approved'] = isApproved.toString();
      
      final uri = Uri.parse('$_baseUrl/users').replace(queryParameters: queryParams);
      
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> usersJson = data['users'] ?? [];
        return usersJson.map((json) => UserModel.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Error getting users: $e');
      // بيانات تجريبية للاختبار
      return _getMockUsers();
    }
  }

  /// ✅ الموافقة على مستخدم
  Future<Map<String, dynamic>> approveUser(String userId) async {
    try {
      final token = await _authService.getToken();
      
      final response = await http.post(
        Uri.parse('$_baseUrl/users/$userId/approve'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'message': data['message'] ?? 'تمت الموافقة'};
      } else {
        final data = jsonDecode(response.body);
        return {'success': false, 'message': data['message'] ?? 'فشلت الموافقة'};
      }
    } catch (e) {
      return {'success': false, 'message': 'خطأ في الاتصال: $e'};
    }
  }

  /// ❌ رفض مستخدم
  Future<Map<String, dynamic>> rejectUser(String userId, {String? reason}) async {
    try {
      final token = await _authService.getToken();
      
      final response = await http.post(
        Uri.parse('$_baseUrl/users/$userId/reject'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'reason': reason}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'message': data['message'] ?? 'تم الرفض'};
      } else {
        final data = jsonDecode(response.body);
        return {'success': false, 'message': data['message'] ?? 'فشل الرفض'};
      }
    } catch (e) {
      return {'success': false, 'message': 'خطأ في الاتصال: $e'};
    }
  }

  /// 🧪 بيانات تجريبية للملف الشخصي
  UserModel _getMockProfile() {
    return UserModel(
      id: '1',
      name: 'أحمد محمد',
      phone: '01012345678',
      email: 'ahmed@example.com',
      type: 'driver',
      isApproved: true,
      createdAt: DateTime.now().toIso8601String(),
      driverLicense: '123456789',
      vehiclePlate: 'أ ب ج 1234',
    );
  }

  /// 🧪 بيانات تجريبية لموقع السائق
  DriverLocation _getMockDriverLocation(String driverId) {
    return DriverLocation(
      driverId: driverId,
      driverName: 'أحمد محمد',
      driverPhone: '01012345678',
      latitude: 30.0444,
      longitude: 31.2357,
      lastUpdated: DateTime.now(),
      vehiclePlate: 'أ ب ج 1234',
    );
  }

  /// 🧪 بيانات تجريبية للمستخدمين
  List<UserModel> _getMockUsers() {
    return [
      UserModel(
        id: '1',
        name: 'أحمد محمد',
        phone: '01012345678',
        email: 'ahmed@example.com',
        type: 'driver',
        isApproved: true,
        createdAt: DateTime.now().toIso8601String(),
        vehiclePlate: 'أ ب ج 1234',
      ),
      UserModel(
        id: '2',
        name: 'محمد علي',
        phone: '01198765432',
        email: 'mohamed@example.com',
        type: 'driver',
        isApproved: false,
        createdAt: DateTime.now().toIso8601String(),
        vehiclePlate: 'د هـ و 5678',
      ),
      UserModel(
        id: '3',
        name: 'سارة أحمد',
        phone: '01234567890',
        email: 'sara@example.com',
        type: 'client',
        isApproved: true,
        createdAt: DateTime.now().toIso8601String(),
      ),
      UserModel(
        id: '4',
        name: 'Admin User',
        phone: '01555555555',
        email: 'admin@example.com',
        type: 'admin',
        isApproved: true,
        createdAt: DateTime.now().toIso8601String(),
      ),
    ];
  }
}
