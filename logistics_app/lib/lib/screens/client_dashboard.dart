import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import '../services/auth_service.dart';
import '../services/order_service.dart';
import '../models/order_model.dart';
import 'complaint_screen.dart';
import 'tracking_screen.dart';
import 'profile_screen.dart';
import 'login_screen.dart';

/// لوحة تحكم العميل - الواجهة الرئيسية للعملاء
class ClientDashboard extends StatefulWidget {
  const ClientDashboard({Key? key}) : super(key: key);

  @override
  State<ClientDashboard> createState() => _ClientDashboardState();
}

class _ClientDashboardState extends State<ClientDashboard> {
  final AuthService _authService = AuthService();
  final OrderService _orderService = OrderService();
  
  Map<String, dynamic>? _userData;
  List<Order> _shipments = [];
  bool _isLoading = true;
  int _selectedIndex = 0;

  // صفحات التنقل
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadShipments();
    _startLocationTracking();
  }

  Future<void> _loadUserData() async {
    final result = await _authService.getUserData();
    if (mounted) {
      setState(() {
        _userData = result['user'];
      });
    }
  }

  Future<void> _loadShipments() async {
    setState(() => _isLoading = true);
    try {
      final result = await _orderService.getClientShipments();
      if (result['success'] && mounted) {
        setState(() {
          _shipments = (result['shipments'] as List)
              .map((s) => Order.fromJson(s))
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading shipments: $e');
      setState(() => _isLoading = false);
    }
  }

  // تحديث موقع العميل للسيرفر (لتحديد موقع الاستلام)
  void _startLocationTracking() {
    Timer.periodic(const Duration(minutes: 2), (timer) async {
      try {
        Position position = await Geolocator.getCurrentPosition();
        await _authService.updateLocation(
          latitude: position.latitude,
          longitude: position.longitude,
        );
      } catch (e) {
        print('Location update error: $e');
      }
    });
  }

  void _onItemTapped(int index) {
    if (index == 2) {
      // صفحة الشكاوى
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ComplaintScreen()),
      );
    } else if (index == 3) {
      // صفحة حسابي
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ProfileScreen()),
      );
    } else {
      setState(() => _selectedIndex = index);
    }
  }

  Future<void> _logout() async {
    await _authService.logout();
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('نظام اللوجستيات'),
        backgroundColor: Colors.green.shade700,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {
              // TODO: Show notifications
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: _selectedIndex == 0 ? _buildHomeTab() : _buildShipmentsTab(),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.green.shade700,
        unselectedItemColor: Colors.grey,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'الرئيسية',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.local_shipping),
            label: 'شحناتي',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.report_problem),
            label: 'شكوى',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'حسابي',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateShipmentDialog(),
        backgroundColor: Colors.green.shade700,
        icon: const Icon(Icons.add),
        label: const Text('طلب شحنة'),
      ),
    );
  }

  /// تبويب الرئيسية
  Widget _buildHomeTab() {
    return RefreshIndicator(
      onRefresh: _loadShipments,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ترحيب
            Text(
              'مرحباً، ${_userData?['name'] ?? 'عزيزي'} 👋',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'يمكنك تتبع شحناتك وطلب شحنات جديدة',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),

            // إحصائيات سريعة
            Row(
              children: [
                _buildStatCard(
                  title: 'شحنات نشطة',
                  value: _shipments.where((s) => s.status != 'delivered' && s.status != 'cancelled').length.toString(),
                  icon: Icons.local_shipping,
                  color: Colors.blue,
                ),
                const SizedBox(width: 12),
                _buildStatCard(
                  title: 'تم التسليم',
                  value: _shipments.where((s) => s.status == 'delivered').length.toString(),
                  icon: Icons.check_circle,
                  color: Colors.green,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // آخر الشحنات
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'آخر الشحنات',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => _selectedIndex = 1),
                  child: const Text('عرض الكل'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _shipments.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _shipments.take(3).length,
                        itemBuilder: (context, index) {
                          return _buildShipmentCard(_shipments[index]);
                        },
                      ),
          ],
        ),
      ),
    );
  }

  /// تبويب الشحنات
  Widget _buildShipmentsTab() {
    return RefreshIndicator(
      onRefresh: _loadShipments,
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _shipments.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _shipments.length,
                  itemBuilder: (context, index) {
                    return _buildShipmentCard(_shipments[index]);
                  },
                ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: TextStyle(color: color.withOpacity(0.8)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShipmentCard(Order shipment) {
    final statusColors = {
      'pending': Colors.orange,
      'assigned': Colors.blue,
      'picked_up': Colors.purple,
      'in_transit': Colors.indigo,
      'out_for_delivery': Colors.teal,
      'delivered': Colors.green,
      'cancelled': Colors.red,
    };

    final statusLabels = {
      'pending': 'معلقة',
      'assigned': 'تم التخصيص',
      'picked_up': 'تم الاستلام',
      'in_transit': 'في الطريق',
      'out_for_delivery': 'خارج للتوصيل',
      'delivered': 'تم التسليم',
      'cancelled': 'ملغية',
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showShipmentOptions(shipment),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'رقم: ${shipment.trackingNumber ?? shipment.id}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: (statusColors[shipment.status] ?? Colors.grey).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      statusLabels[shipment.status] ?? shipment.status,
                      style: TextStyle(
                        color: statusColors[shipment.status] ?? Colors.grey,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.location_on, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      shipment.destination ?? 'غير محدد',
                      style: const TextStyle(color: Colors.grey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (shipment.driverName != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.person, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      'السائق: ${shipment.driverName}',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  if (shipment.status != 'delivered' && shipment.status != 'cancelled')
                    _buildActionButton(
                      icon: Icons.map,
                      label: 'تتبع',
                      onTap: () => _trackShipment(shipment),
                    ),
                  _buildActionButton(
                    icon: Icons.report_problem,
                    label: 'شكوى',
                    onTap: () => _submitComplaint(shipment),
                  ),
                  if (shipment.status == 'delivered')
                    _buildActionButton(
                      icon: Icons.qr_code,
                      label: 'استلام',
                      onTap: () => _scanQR(shipment),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: Colors.green.shade700),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text(
            'لا توجد شحنات',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          const Text(
            'اضغط على الزر + لطلب شحنة جديدة',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  void _showShipmentOptions(Order shipment) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'خيارات الشحنة',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.map, color: Colors.blue),
              title: const Text('تتبع الشحنة'),
              onTap: () {
                Navigator.pop(context);
                _trackShipment(shipment);
              },
            ),
            ListTile(
              leading: const Icon(Icons.report_problem, color: Colors.orange),
              title: const Text('تقديم شكوى'),
              onTap: () {
                Navigator.pop(context);
                _submitComplaint(shipment);
              },
            ),
            ListTile(
              leading: const Icon(Icons.info, color: Colors.green),
              title: const Text('تفاصيل الشحنة'),
              onTap: () {
                Navigator.pop(context);
                _showShipmentDetails(shipment);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _trackShipment(Order shipment) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TrackingScreen(shipmentId: int.parse(shipment.id)),
      ),
    );
  }

  void _submitComplaint(Order shipment) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ComplaintScreen(shipmentId: int.parse(shipment.id)),
      ),
    );
  }

  void _scanQR(Order shipment) {
    // TODO: Implement QR scanning for delivery confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('جاري فتح الماسح...')),
    );
  }

  void _showShipmentDetails(Order shipment) {
    // TODO: Navigate to shipment details screen
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تفاصيل الشحنة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('رقم التتبع: ${shipment.trackingNumber ?? shipment.id}'),
            Text('الحالة: ${shipment.status}'),
            Text('الوجهة: ${shipment.destination ?? 'غير محدد'}'),
            if (shipment.driverName != null)
              Text('السائق: ${shipment.driverName}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  void _showCreateShipmentDialog() {
    // TODO: Show create shipment dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('طلب شحنة جديدة'),
        content: const Text('سيتم توجيهك لصفحة طلب الشحنة...'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Navigate to create shipment screen
            },
            child: const Text('متابعة'),
          ),
        ],
      ),
    );
  }
}