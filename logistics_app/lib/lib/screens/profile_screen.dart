import 'package:flutter/material.dart';
import '../services/auth_service.dart';

/// صفحة حسابي - عرض وتعديل بيانات المستخدم
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  bool _isEditing = false;

  // Controllers
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    try {
      final result = await _authService.getUserData();
      if (result['success'] && mounted) {
        setState(() {
          _userData = result['user'];
          _nameController.text = _userData?['name'] ?? '';
          _phoneController.text = _userData?['phone'] ?? '';
          _emailController.text = _userData?['email'] ?? '';
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateProfile() async {
    // TODO: Implement update profile API
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('جاري حفظ التغييرات...')),
    );
    setState(() => _isEditing = false);
  }

  void _showChangePasswordDialog() {
    final oldPassController = TextEditingController();
    final newPassController = TextEditingController();
    final confirmPassController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تغيير كلمة المرور'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: oldPassController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'كلمة المرور الحالية',
              ),
            ),
            TextField(
              controller: newPassController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'كلمة المرور الجديدة',
              ),
            ),
            TextField(
              controller: confirmPassController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'تأكيد كلمة المرور الجديدة',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              // TODO: Implement password change
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم تغيير كلمة المرور')),
              );
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('حسابي'),
        backgroundColor: Colors.green.shade700,
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.save : Icons.edit),
            onPressed: () {
              if (_isEditing) {
                _updateProfile();
              } else {
                setState(() => _isEditing = true);
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // صورة الحساب
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.green.shade100,
                    child: Icon(
                      Icons.person,
                      size: 60,
                      color: Colors.green.shade700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // نوع الحساب
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _userData?['type'] == 'client' ? 'عميل' : 
                      _userData?['type'] == 'driver' ? 'سائق' : 'مشرف',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // البيانات
                  _buildInfoCard(
                    title: 'البيانات الشخصية',
                    children: [
                      _buildTextField(
                        label: 'الاسم',
                        controller: _nameController,
                        enabled: _isEditing,
                        icon: Icons.person,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        label: 'رقم الهاتف',
                        controller: _phoneController,
                        enabled: false, // Phone cannot be changed
                        icon: Icons.phone,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        label: 'البريد الإلكتروني',
                        controller: _emailController,
                        enabled: _isEditing,
                        icon: Icons.email,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // الإعدادات
                  _buildInfoCard(
                    title: 'الإعدادات',
                    children: [
                      ListTile(
                        leading: const Icon(Icons.lock),
                        title: const Text('تغيير كلمة المرور'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: _showChangePasswordDialog,
                      ),
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.notifications),
                        title: const Text('الإشعارات'),
                        trailing: Switch(
                          value: true,
                          onChanged: (value) {},
                        ),
                      ),
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.language),
                        title: const Text('اللغة'),
                        trailing: const Text('العربية'),
                        onTap: () {},
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // معلومات إضافية
                  _buildInfoCard(
                    title: 'معلومات الحساب',
                    children: [
                      _buildInfoRow('تاريخ التسجيل', _formatDate(_userData?['created_at'])),
                      _buildInfoRow('آخر دخول', _formatDate(_userData?['last_login'])),
                      _buildInfoRow('حالة الحساب', 
                        _userData?['is_active'] == true ? 'نشط' : 'معطل'),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // زر تسجيل الخروج
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await _authService.logout();
                        if (mounted) {
                          Navigator.pushReplacementNamed(context, '/login');
                        }
                      },
                      icon: const Icon(Icons.logout),
                      label: const Text('تسجيل الخروج'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoCard({required String title, required List<Widget> children}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required bool enabled,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: !enabled,
        fillColor: enabled ? null : Colors.grey.shade100,
      ),
    );
  }

  Widget _buildInfoRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value ?? '-', style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '-';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return '-';
    }
  }
}