import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// نموذج استجابة تسجيل الدخول
class LoginResponse {
  final bool success;
  final String? token;
  final String? userType;
  final String? message;

  LoginResponse({
    required this.success,
    this.token,
    this.userType,
    this.message,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      success: json['success'] ?? false,
      token: json['token'],
      userType: json['user_type'],
      message: json['message'],
    );
  }
}

/// نموذج بيانات المستخدم
class User {
  final String id;
  final String phone;
  final String name;
  final String type; // driver, customer, admin
  final String? email;
  final String? avatarUrl;

  User({
    required this.id,
    required this.phone,
    required this.name,
    required this.type,
    this.email,
    this.avatarUrl,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      phone: json['phone'],
      name: json['name'],
      type: json['type'],
      email: json['email'],
      avatarUrl: json['avatar_url'],
    );
  }
}

/// خدمة المصادقة والتوثيق
class AuthService {
  // 🔗 رابط الـ API على Railway
  static const String _baseUrl = 'https://longest-ice-production.up.railway.app/api';
  
  // 🔑 مفتاح التخزين المحلي للتوكن
  static const String _tokenKey = 'jwt_token';
  static const String _userKey = 'user_data';

  /// ✅ تسجيل الدخول
  Future<LoginResponse> login({
    required String phone,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': phone,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // حفظ التوكن والمستخدم
        if (data['token'] != null) {
          await saveToken(data['token']);
          if (data['user'] != null) {
            await _saveUserData(data['user']);
          }
        }
        
        return LoginResponse.fromJson(data);
      } else {
        final data = jsonDecode(response.body);
        return LoginResponse(
          success: false,
          message: data['message'] ?? 'خطأ في تسجيل الدخول',
        );
      }
    } catch (e) {
      return LoginResponse(
        success: false,
        message: 'خطأ في الاتصال بالخادم: $e',
      );
    }
  }

  /// 💾 حفظ التوكن (JWT) في التخزين المحلي
  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  /// 📖 قراءة التوكن المحفوظ
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  /// 🗑️ حذف التوكن (تسجيل الخروج)
  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }

  /// 👤 حفظ بيانات المستخدم
  Future<void> _saveUserData(Map<String, dynamic> userData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(userData));
  }

  /// 👤 قراءة بيانات المستخدم المحفوظة
  Future<User?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(_userKey);
    if (userJson != null) {
      return User.fromJson(jsonDecode(userJson));
    }
    return null;
  }

  /// 🔍 التحقق مما إذا كان المستخدم مسجل دخول
  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  /// 🚪 تسجيل الخروج
  Future<void> logout() async {
    await clearToken();
  }

  /// 📱 إرسال كود التحقق عبر واتساب (بدل SMS)
  Future<bool> sendWhatsAppCode({
    required String phone,
  }) async {
    try {
      // توليد كود عشوائي 6 أرقام
      final code = _generateVerificationCode();
      
      // حفظ الكود مؤقتاً (للتحقق لاحقاً)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('verify_code_$phone', code);
      await prefs.setInt('verify_time_$phone', DateTime.now().millisecondsSinceEpoch);

      // 🔔 إرسال الكود عبر WhatsApp API الخاص بـ Clawdbot
      // هنا بنستخدم الـ API اللي احنا شغالين عليه
      final response = await http.post(
        Uri.parse('$_baseUrl/whatsapp/send'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': phone,
          'message': 'كود التحقق الخاص بك هو: $code\n\nصلاحية الكود 10 دقائق.',
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error sending WhatsApp code: $e');
      return false;
    }
  }

  /// ✅ التحقق من كود واتساب
  Future<bool> verifyCode({
    required String phone,
    required String code,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final savedCode = prefs.getString('verify_code_$phone');
    final savedTime = prefs.getInt('verify_time_$phone');
    
    if (savedCode == null || savedTime == null) {
      return false;
    }
    
    // التحقق من صلاحية الكود (10 دقائق)
    final now = DateTime.now().millisecondsSinceEpoch;
    final diff = now - savedTime;
    if (diff > 10 * 60 * 1000) { // 10 دقائق
      return false;
    }
    
    return savedCode == code;
  }

  /// 🔑 تغيير كلمة المرور
  Future<bool> resetPassword({
    required String phone,
    required String newPassword,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/reset-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': phone,
          'new_password': newPassword,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// 📝 تسجيل حساب جديد
  Future<LoginResponse> register({
    required String phone,
    required String password,
    required String name,
    required String userType,
    String? email,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': phone,
          'password': password,
          'name': name,
          'type': userType,
          'email': email,
        }),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return LoginResponse.fromJson(data);
      } else {
        final data = jsonDecode(response.body);
        return LoginResponse(
          success: false,
          message: data['message'] ?? 'خطأ في التسجيل',
        );
      }
    } catch (e) {
      return LoginResponse(
        success: false,
        message: 'خطأ في الاتصال: $e',
      );
    }
  }

  /// 🔢 توليد كود تحقق عشوائي
  String _generateVerificationCode() {
    return (100000 + DateTime.now().millisecond * 9000 ~/ 1000).toString();
  }

  /// 📝 تقديم شكوى
  Future<Map<String, dynamic>> submitComplaint({
    required String title,
    required String description,
    required String complaintType,
    required String priority,
    int? shipmentId,
  }) async {
    try {
      final token = await getToken();
      final response = await http.post(
        Uri.parse('$_baseUrl/complaints'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'title': title,
          'description': description,
          'complaint_type': complaintType,
          'priority': priority,
          'shipment_id': shipmentId,
        }),
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'خطأ في الاتصال: $e'};
    }
  }

  /// 📍 تحديث موقع السائق
  Future<Map<String, dynamic>> updateLocation({
    required double latitude,
    required double longitude,
    double? accuracy,
    double? speed,
    double? heading,
    int? batteryLevel,
  }) async {
    try {
      final token = await getToken();
      final response = await http.post(
        Uri.parse('$_baseUrl/location/update'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'latitude': latitude,
          'longitude': longitude,
          'accuracy': accuracy,
          'speed': speed,
          'heading': heading,
          'battery_level': batteryLevel,
        }),
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'خطأ في الاتصال: $e'};
    }
  }

  /// 🔑 الحصول على التوكن
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }
}
