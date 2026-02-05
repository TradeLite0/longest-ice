import 'package:flutter/material.dart';
import '../services/user_service.dart';

class AdminUsersListScreen extends StatefulWidget {
  const AdminUsersListScreen({Key? key}) : super(key: key);

  @override
  State<AdminUsersListScreen> createState() => _AdminUsersListScreenState();
}

class _AdminUsersListScreenState extends State<AdminUsersListScreen> {
  final UserService _userService = UserService();
  
  List<UserModel> _users = [];
  List<UserModel> _filteredUsers = [];
  bool _isLoading = true;
  String? _errorMessage;
  
  // الفلاتر
  String? _selectedType;
  bool? _selectedApprovalStatus;
  String _searchQuery = '';

  // أنواع المستخدمين
  final List<Map<String, dynamic>> _userTypes = [
    {'value': null, 'label': 'الكل', 'icon': Icons.people},
    {'value': 'client', 'label': 'العملاء', 'icon': Icons.person},
    {'value': 'driver', 'label': 'السائقين', 'icon': Icons.local_shipping},
    {'value': 'admin', 'label': 'المشرفين', 'icon': Icons.admin_panel_settings},
  ];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  /// 📥 تحميل المستخدمين
  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final users = await _userService.getUsers();
      setState(() {
        _users = users;
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '❌ خطأ في تحميل المستخدمين';
        _isLoading = false;
      });
    }
  }

  /// 🔍 تطبيق الفلاتر
  void _applyFilters() {
    _filteredUsers = _users.where((user) {
      // فلتر النوع
      if (_selectedType != null && user.type != _selectedType) {
        return false;
      }
      
      // فلتر الحالة
      if (_selectedApprovalStatus != null && 
          user.isApproved != _selectedApprovalStatus) {
        return false;
      }
      
      // فلتر البحث
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        return user.name.toLowerCase().contains(query) ||
               user.phone.contains(query) ||
               (user.email?.toLowerCase().contains(query) ?? false);
      }
      
      return true;
    }).toList();
  }

  /// ✅ الموافقة على مستخدم
  Future<void> _approveUser(UserModel user) async {
    final confirmed = await _showConfirmDialog(
      'الموافقة على المستخدم',
      'هل تريد الموافقة على ${user.name}؟',
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    
    final result = await _userService.approveUser(user.id);
    
    setState(() => _isLoading = false);

    if (result['success']) {
      _showSnackBar(result['message'], Colors.green);
      _loadUsers();
    } else {
      _showSnackBar(result['message'], Colors.red);
    }
  }

  /// ❌ رفض مستخدم
  Future<void> _rejectUser(UserModel user) async {
    final reasonController = TextEditingController();
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(Icons.cancel, color: Colors.red.shade400),
            const SizedBox(width: 12),
            const Text('رفض المستخدم'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('هل تريد رفض ${user.name}؟'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                labelText: 'سبب الرفض (اختياري)',
                hintText: 'اكتب سبب الرفض هنا',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.cancel),
            label: const Text('رفض'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    
    final result = await _userService.rejectUser(
      user.id,
      reason: reasonController.text.isEmpty ? null : reasonController.text,
    );
    
    setState(() => _isLoading = false);

    if (result['success']) {
      _showSnackBar(result['message'], Colors.green);
      _loadUsers();
    } else {
      _showSnackBar(result['message'], Colors.red);
    }
  }

  /// 👀 عرض تفاصيل المستخدم
  void _showUserDetails(UserModel user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(24),
          child: ListView(
            controller: scrollController,
            children: [
              // مؤشر السحب
              Center(
                child: Container(
                  width: 50,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // الصورة والاسم
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: user.type == 'driver'
                              ? [Colors.orange, Colors.orange.shade700]
                              : user.type == 'admin'
                                  ? [Colors.purple, Colors.purple.shade700]
                                  : [Colors.green, Colors.green.shade700],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.person,
                        color: Colors.white,
                        size: 50,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      user.name,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _getTypeColor(user.type).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _getTypeLabel(user.type),
                        style: TextStyle(
                          color: _getTypeColor(user.type),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              
              // المعلومات
              _buildDetailSection('المعلومات الأساسية', [
                _buildDetailItem(
                  icon: Icons.phone,
                  label: 'رقم الموبايل',
                  value: user.phone,
                ),
                if (user.email != null)
                  _buildDetailItem(
                    icon: Icons.email,
                    label: 'البريد الإلكتروني',
                    value: user.email!,
                  ),
                _buildDetailItem(
                  icon: Icons.calendar_today,
                  label: 'تاريخ التسجيل',
                  value: _formatDate(user.createdAt),
                ),
              ]),
              
              if (user.type == 'driver') ...[
                const SizedBox(height: 24),
                _buildDetailSection('معلومات السائق', [
                  if (user.driverLicense != null)
                    _buildDetailItem(
                      icon: Icons.badge,
                      label: 'رقم الرخصة',
                      value: user.driverLicense!,
                    ),
                  if (user.vehiclePlate != null)
                    _buildDetailItem(
                      icon: Icons.directions_car,
                      label: 'رقم اللوحة',
                      value: user.vehiclePlate!,
                    ),
                ]),
              ],
              
              const SizedBox(height: 24),
              
              // حالة الموافقة
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: user.isApproved 
                      ? Colors.green.shade50 
                      : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: user.isApproved 
                        ? Colors.green.shade200 
                        : Colors.orange.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      user.isApproved ? Icons.check_circle : Icons.pending,
                      color: user.isApproved ? Colors.green : Colors.orange,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.isApproved ? 'تمت الموافقة' : 'في انتظار الموافقة',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: user.isApproved 
                                  ? Colors.green.shade700 
                                  : Colors.orange.shade700,
                            ),
                          ),
                          if (!user.isApproved)
                            Text(
                              'هذا المستخدم ينتظر موافقتك',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange.shade600,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              // أزرار الإجراءات
              if (!user.isApproved) ...[
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _approveUser(user);
                        },
                        icon: const Icon(Icons.check),
                        label: const Text('موافقة'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _rejectUser(user);
                        },
                        icon: const Icon(Icons.cancel),
                        label: const Text('رفض'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
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

  /// 💬 dialog تأكيد
  Future<bool?> _showConfirmDialog(String title, String message) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF667eea),
            ),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
  }

  /// 🎨 لون النوع
  Color _getTypeColor(String type) {
    switch (type) {
      case 'driver':
        return Colors.orange;
      case 'admin':
        return Colors.purple;
      case 'client':
      default:
        return Colors.green;
    }
  }

  /// 📝 تسمية النوع
  String _getTypeLabel(String type) {
    switch (type) {
      case 'driver':
        return 'سائق';
      case 'admin':
        return 'مدير';
      case 'client':
      default:
        return 'عميل';
    }
  }

  /// 📅 تنسيق التاريخ
  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'إدارة المستخدمين',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
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
            onPressed: _loadUsers,
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: Column(
        children: [
          // 🔍 شريط البحث والفلاتر
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF667eea), Color(0xFF764ba2)],
              ),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(30),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF667eea).withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                // حقل البحث
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: TextField(
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                        _applyFilters();
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'ابحث بالاسم أو رقم الهاتف...',
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.all(16),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // فلاتر النوع
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _userTypes.map((type) {
                      final isSelected = _selectedType == type['value'];
                      return Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: ChoiceChip(
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                type['icon'] as IconData,
                                size: 18,
                                color: isSelected 
                                    ? Colors.white 
                                    : Colors.grey.shade600,
                              ),
                              const SizedBox(width: 8),
                              Text(type['label'] as String),
                            ],
                          ),
                          selected: isSelected,
                          selectedColor: const Color(0xFF667eea),
                          labelStyle: TextStyle(
                            color: isSelected 
                                ? Colors.white 
                                : Colors.grey.shade700,
                          ),
                          backgroundColor: Colors.white,
                          onSelected: (selected) {
                            setState(() {
                              _selectedType = selected ? type['value'] : null;
                              _applyFilters();
                            });
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 8),
                
                // فلاتر الحالة
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ChoiceChip(
                        label: const Text('الكل'),
                        selected: _selectedApprovalStatus == null,
                        selectedColor: const Color(0xFF667eea),
                        labelStyle: TextStyle(
                          color: _selectedApprovalStatus == null 
                              ? Colors.white 
                              : Colors.grey.shade700,
                        ),
                        backgroundColor: Colors.white,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _selectedApprovalStatus = null;
                              _applyFilters();
                            });
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('تمت الموافقة'),
                        selected: _selectedApprovalStatus == true,
                        selectedColor: Colors.green,
                        labelStyle: TextStyle(
                          color: _selectedApprovalStatus == true 
                              ? Colors.white 
                              : Colors.grey.shade700,
                        ),
                        backgroundColor: Colors.white,
                        onSelected: (selected) {
                          setState(() {
                            _selectedApprovalStatus = selected ? true : null;
                            _applyFilters();
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('في الانتظار'),
                        selected: _selectedApprovalStatus == false,
                        selectedColor: Colors.orange,
                        labelStyle: TextStyle(
                          color: _selectedApprovalStatus == false 
                              ? Colors.white 
                              : Colors.grey.shade700,
                        ),
                        backgroundColor: Colors.white,
                        onSelected: (selected) {
                          setState(() {
                            _selectedApprovalStatus = selected ? false : null;
                            _applyFilters();
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // 📊 عدد النتائج
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(
                  'عدد المستخدمين: ${_filteredUsers.length}',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (_selectedType != null || _selectedApprovalStatus != null)
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _selectedType = null;
                        _selectedApprovalStatus = null;
                        _applyFilters();
                      });
                    },
                    icon: const Icon(Icons.clear, size: 18),
                    label: const Text('مسح الفلاتر'),
                  ),
              ],
            ),
          ),
          
          // 📋 قائمة المستخدمين
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? _buildErrorWidget()
                    : _filteredUsers.isEmpty
                        ? _buildEmptyWidget()
                        : RefreshIndicator(
                            onRefresh: _loadUsers,
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: _filteredUsers.length,
                              itemBuilder: (context, index) {
                                final user = _filteredUsers[index];
                                return _buildUserCard(user);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  /// 👤 كارت المستخدم
  Widget _buildUserCard(UserModel user) {
    final typeColor = _getTypeColor(user.type);
    final typeLabel = _getTypeLabel(user.type);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showUserDetails(user),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  // الصورة
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [typeColor, typeColor.withOpacity(0.7)],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 16),
                  
                  // المعلومات
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.phone, 
                                size: 14, color: Colors.grey.shade600),
                            const SizedBox(width: 4),
                            Text(
                              user.phone,
                              style: TextStyle(
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            // نوع المستخدم
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: typeColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                typeLabel,
                                style: TextStyle(
                                  color: typeColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            
                            // حالة الموافقة
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: user.isApproved 
                                    ? Colors.green.withOpacity(0.1)
                                    : Colors.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    user.isApproved 
                                        ? Icons.check_circle 
                                        : Icons.pending,
                                    size: 12,
                                    color: user.isApproved 
                                        ? Colors.green 
                                        : Colors.orange,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    user.isApproved ? 'تمت' : 'قيد الانتظار',
                                    style: TextStyle(
                                      color: user.isApproved 
                                          ? Colors.green 
                                          : Colors.orange,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // سهم
                  Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.grey.shade400,
                    size: 16,
                  ),
                ],
              ),
              
              // أزرار الإجراءات
              if (!user.isApproved) ...[
                const Divider(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _approveUser(user),
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('موافقة'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _rejectUser(user),
                        icon: const Icon(Icons.cancel, size: 18),
                        label: const Text('رفض'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 📋 قسم التفاصيل
  Widget _buildDetailSection(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 12),
        ...items,
      ],
    );
  }

  /// 📄 عنصر التفاصيل
  Widget _buildDetailItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Text(
            '$label: ',
            style: TextStyle(
              color: Colors.grey.shade600,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
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
            onPressed: _loadUsers,
            icon: const Icon(Icons.refresh),
            label: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }

  /// 📭 ويدجت فارغ
  Widget _buildEmptyWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'لا يوجد مستخدمين مطابقين للفلاتر',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}
