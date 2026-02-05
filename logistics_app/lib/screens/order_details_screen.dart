import 'package:flutter/material.dart';
import '../models/order_model.dart';
import '../services/order_service.dart';
import 'map_screen.dart';

class OrderDetailsScreen extends StatefulWidget {
  final Order order;
  
  const OrderDetailsScreen({
    Key? key,
    required this.order,
  }) : super(key: key);

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  final OrderService _orderService = OrderService();
  late Order _order;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _order = widget.order;
  }

  // ✅ تحديث حالة الطلب
  Future<void> _updateOrderStatus(String status, {String? note}) async {
    setState(() => _isLoading = true);

    try {
      final result = await _orderService.updateOrderStatus(
        orderId: _order.id,
        status: status,
        note: note,
      );

      if (result.success) {
        setState(() {
          _order = _order.copyWith(status: status);
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message),
              backgroundColor: Colors.green,
            ),
          );
          
          // الرجوع للخلف بعد نجاح العملية
          if (status == 'delivered') {
            Future.delayed(const Duration(seconds: 1), () {
              Navigator.pop(context, true);
            });
          }
        }
      } else {
        _showError(result.message);
      }
    } catch (e) {
      _showError('❌ خطأ في الاتصال بالسيرفر');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ✅ تم التسليم
  void _markAsDelivered() {
    _showConfirmationDialog(
      title: 'تأكيد التسليم',
      message: 'هل تم تسليم الطلب واستلام المبلغ ${_order.amount} ج؟',
      icon: Icons.check_circle,
      color: Colors.green,
      onConfirm: () => _updateOrderStatus('delivered'),
    );
  }

  // 📞 العميل لم يرد
  void _markAsNoAnswer() {
    _showNoteDialog(
      title: 'العميل لم يرد',
      hint: 'اكتب ملاحظة (اختياري): مثال: رن 3 مرات ولم يرد',
      icon: Icons.phone_disabled,
      color: Colors.orange,
      onConfirm: (note) => _updateOrderStatus('no_answer', note: note),
    );
  }

  // ⏰ تأجيل
  void _markAsPostponed() {
    _showNoteDialog(
      title: 'تأجيل الطلب',
      hint: 'سبب التأجيل: مثال: العميل طلب توصيل غداً الساعة 5',
      icon: Icons.schedule,
      color: Colors.blue,
      onConfirm: (note) => _updateOrderStatus('postponed', note: note),
    );
  }

  // ❌ إظهار خطأ
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  // 💬 dialog تأكيد
  void _showConfirmationDialog({
    required String title,
    required String message,
    required IconData icon,
    required Color color,
    required VoidCallback onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(width: 12),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            icon: const Icon(Icons.check),
            label: const Text('تأكيد'),
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // 📝 dialog مع ملاحظة
  void _showNoteDialog({
    required String title,
    required String hint,
    required IconData icon,
    required Color color,
    required Function(String) onConfirm,
  }) {
    final noteController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(width: 12),
            Text(title),
          ],
        ),
        content: TextField(
          controller: noteController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              onConfirm(noteController.text);
            },
            icon: const Icon(Icons.send),
            label: const Text('إرسال'),
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // 📞 الاتصال بالعميل
  Future<void> _callCustomer() async {
    // فتح تطبيق الاتصال
    final Uri phoneUri = Uri(scheme: 'tel', path: _order.customerPhone);
    // TODO: implement url_launcher
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل الطلب'),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF667eea), Color(0xFF764ba2)],
            ),
          ),
        ),
        actions: [
          // 📞 زر الاتصال
          IconButton(
            icon: const Icon(Icons.phone),
            onPressed: _callCustomer,
            tooltip: 'اتصال بالعميل',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 🏷️ رقم الطلب والحالة
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'طلب #${_order.id.substring(_order.id.length - 6)}',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              _buildStatusBadge(_order.status),
                            ],
                          ),
                          const Divider(height: 32),
                          // ⏰ تاريخ الطلب
                          Row(
                            children: [
                              Icon(Icons.access_time, color: Colors.grey.shade600),
                              const SizedBox(width: 8),
                              Text(
                                'تاريخ الطلب: ${_order.createdAt}',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // 👤 بيانات العميل
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'بيانات العميل',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildInfoRow(
                            icon: Icons.person,
                            label: 'الاسم',
                            value: _order.customerName,
                          ),
                          const SizedBox(height: 12),
                          _buildInfoRow(
                            icon: Icons.phone,
                            label: 'رقم الموبايل',
                            value: _order.customerPhone,
                            valueColor: Colors.blue,
                            onTap: _callCustomer,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // 📍 العنوان
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'عنوان التوصيل',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              // 🗺️ زر الخريطة
                              ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => MapScreen(
                                        destination: _order.address,
                                        lat: _order.latitude,
                                        lng: _order.longitude,
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.map),
                                label: const Text('الخريطة'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF667eea),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(Icons.location_on, color: Colors.red.shade400),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _order.address,
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // 📦 تفاصيل الطلب
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'تفاصيل الطلب',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (_order.items != null)
                            ..._order.items!.map((item) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  Icon(Icons.check_circle, 
                                    size: 16, 
                                    color: Colors.green.shade400
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text('${item.name} × ${item.quantity}'),
                                  ),
                                ],
                              ),
                            )),
                          const Divider(height: 24),
                          // 💰 المبلغ الإجمالي
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'المبلغ المطلوب تحصيله:',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '${_order.amount.toStringAsFixed(2)} ج',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // 🎮 أزرار الإجراءات (مخفية لو الطلب تم تسليمه)
                  if (_order.status != 'delivered') ...[
                    const Text(
                      'إجراءات الطلب',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // ✅ زر تم التسليم
                    _buildActionButton(
                      label: '✅ تم التسليم واستلام المبلغ',
                      icon: Icons.check_circle,
                      color: Colors.green,
                      onPressed: _markAsDelivered,
                    ),
                    const SizedBox(height: 12),
                    
                    // 📞 زر العميل لم يرد
                    _buildActionButton(
                      label: '❌ العميل لم يرد',
                      icon: Icons.phone_disabled,
                      color: Colors.orange,
                      onPressed: _markAsNoAnswer,
                    ),
                    const SizedBox(height: 12),
                    
                    // ⏰ زر تأجيل
                    _buildActionButton(
                      label: '⏰ تأجيل الطلب',
                      icon: Icons.schedule,
                      color: Colors.blue,
                      onPressed: _markAsPostponed,
                    ),
                  ],
                  
                  // ✅ رسالة نجاح لو تم التسليم
                  if (_order.status == 'delivered')
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green, size: 32),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '✅ تم تسليم هذا الطلب بنجاح!',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  // 🏷️ شارة الحالة
  Widget _buildStatusBadge(String status) {
    Color color;
    String text;
    IconData icon;
    
    switch (status) {
      case 'pending':
        color = Colors.orange;
        text = 'جديد';
        icon = Icons.new_releases;
        break;
      case 'in_progress':
        color = Colors.blue;
        text = 'قيد التوصيل';
        icon = Icons.local_shipping;
        break;
      case 'delivered':
        color = Colors.green;
        text = 'تم التسليم';
        icon = Icons.check_circle;
        break;
      default:
        color = Colors.grey;
        text = 'غير معروف';
        icon = Icons.help;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // 📋 صف معلومات
  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Text(
            '$label: ',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: valueColor,
              ),
            ),
          ),
          if (onTap != null)
            Icon(Icons.arrow_forward_ios, size: 16, color: valueColor),
        ],
      ),
    );
  }

  // 🎮 زر إجراء
  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.8)],
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.4),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onPressed,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 28),
              const SizedBox(width: 12),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
