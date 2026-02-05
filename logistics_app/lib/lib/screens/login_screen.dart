import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  // ✅ التحقق من رقم الموبايل المصري
  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'الرجاء إدخال رقم الموبايل';
    }
    // إزالة المسافات والرموز
    String phone = value.replaceAll(RegExp(r'\s+'), '');
    
    // التحقق من أنه أرقام فقط
    if (!RegExp(r'^[0-9]+$').hasMatch(phone)) {
      return 'رقم الموبايل يجب أن يحتوي على أرقام فقط';
    }
    
    // التحقق من الطول (11 رقم للمصرى)
    if (phone.length != 11) {
      return 'رقم الموبايل يجب أن يكون 11 رقماً';
    }
    
    // التحقق من أنه يبدأ بـ 01
    if (!phone.startsWith('01')) {
      return 'رقم الموبايل يجب أن يبدأ بـ 01';
    }
    
    return null;
  }

  // ✅ التحقق من كلمة المرور
  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'الرجاء إدخال كلمة المرور';
    }
    if (value.length < 6) {
      return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
    }
    return null;
  }

  // 🔓 تسجيل الدخول
  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // تنظيف رقم الموبايل
      String phone = _phoneController.text.trim().replaceAll(RegExp(r'\s+'), '');
      
      final result = await _authService.login(
        phone: phone,
        password: _passwordController.text,
      );

      if (result.success) {
        // حفظ التوكن
        await _authService.saveToken(result.token!);
        
        if (mounted) {
          // الانتقال للشاشة الرئيسية
          Navigator.pushReplacementNamed(
            context, 
            '/driver_dashboard',
          );
          
          // رسالة نجاح
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ تم تسجيل الدخول بنجاح'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        setState(() {
          _errorMessage = result.message ?? 'خطأ في تسجيل الدخول';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = '❌ خطأ في الاتصال. تأكد من تشغيل السيرفر.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // 📱 فتح واتساب (نسيت كلمة المرور)
  Future<void> _openWhatsApp() async {
    // رقم الدعم الفني (غيره للرقم بتاعك)
    const String supportPhone = '201206826801'; // غيره للرقم الفعلي
    const String message = 'مرحباً، نسيت كلمة المرور الخاصة بي في تطبيق اللوجستيات. رقمي: ';
    
    final Uri whatsappUri = Uri.parse(
      'https://wa.me/$supportPhone?text=${Uri.encodeComponent(message)}',
    );
    
    try {
      if (await canLaunchUrl(whatsappUri)) {
        await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
      } else {
        // لو مفتوحش، نفتح المتصفح
        await launchUrl(
          Uri.parse('https://web.whatsapp.com/send?phone=$supportPhone&text=${Uri.encodeComponent(message)}'),
          mode: LaunchMode.externalApplication,
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ لا يمكن فتح واتساب. تأكد من تثبيته.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        // ✅ خلفية متدرجة ألوان جذابة
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [
              Color(0xFF667eea), // بنفسجي فاتح
              Color(0xFF764ba2), // بنفسجي غامق
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 🚚 أيقونة التطبيق
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 15,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.local_shipping_rounded,
                        size: 70,
                        color: Color(0xFF667eea),
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    // 📝 عنوان التطبيق
                    const Text(
                      'نظام اللوجستيات',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: Colors.black26,
                            blurRadius: 10,
                            offset: Offset(0, 5),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'تسجيل دخول المندوب',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 48),
                    
                    // 📱 حقل رقم الموبايل
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        textDirection: TextDirection.ltr,
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 18),
                        decoration: InputDecoration(
                          labelText: 'رقم الموبايل',
                          hintText: 'مثال: 01012345678',
                          hintStyle: TextStyle(color: Colors.grey.shade400),
                          prefixIcon: Container(
                            margin: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF667eea).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.phone_android,
                              color: Color(0xFF667eea),
                            ),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.all(20),
                        ),
                        validator: _validatePhone,
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // 🔒 حقل كلمة المرور
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        textDirection: TextDirection.ltr,
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 18),
                        decoration: InputDecoration(
                          labelText: 'كلمة المرور',
                          prefixIcon: Container(
                            margin: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF667eea).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.lock_outline,
                              color: Color(0xFF667eea),
                            ),
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword 
                                ? Icons.visibility_off 
                                : Icons.visibility,
                              color: Colors.grey,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.all(20),
                        ),
                        validator: _validatePassword,
                      ),
                    ),
                    
                    // ⚠️ رسالة الخطأ
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, color: Colors.red.shade700),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(
                                  color: Colors.red.shade700,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    
                    const SizedBox(height: 12),
                    
                    // 📱 زر نسيت كلمة المرور (يفتح واتساب)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: _openWhatsApp,
                        icon: const Icon(
                          Icons.help_outline,
                          color: Colors.white70,
                          size: 20,
                        ),
                        label: const Text(
                          'نسيت كلمة المرور؟',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // 🔓 زر تسجيل الدخول
                    Container(
                      width: double.infinity,
                      height: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: const LinearGradient(
                          colors: [
                            Colors.orange,
                            Colors.deepOrange,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.orange.withOpacity(0.4),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: _isLoading ? null : _login,
                          child: Center(
                            child: _isLoading
                                ? const SizedBox(
                                    width: 28,
                                    height: 28,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 3,
                                    ),
                                  )
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.login, color: Colors.white),
                                      SizedBox(width: 12),
                                      Text(
                                        'دخول',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    // 📞 معلومات الدعم
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.headset_mic,
                            color: Colors.white70,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'للمساعدة: اضغط على "نسيت كلمة المرور"',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
