import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/shipment_service.dart';
import '../services/user_service.dart';
import 'driver_location_screen.dart';

class ShipmentDetailsScreen extends StatefulWidget {
  final Shipment shipment;
  final String? userType; // 'client', 'driver', 'admin'

  const ShipmentDetailsScreen({
    Key? key,
    required this.shipment,
    this.userType = 'client',
  }) : super(key: key);

  @override
  State<ShipmentDetailsScreen> createState() => _ShipmentDetailsScreenState();
}

class _ShipmentDetailsScreenState extends State<ShipmentDetailsScreen> {
  final ShipmentService _shipmentService = ShipmentService();
  final UserService _userService = UserService();
  
  late Shipment _shipment;
  List<ShipmentStatus> _timeline = [];
  bool _isLoading = true;
  bool _isUpdating = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _shipment = widget.shipment;
    _loadTimeline();
  }

  /// 📜 تحميل تاريخ الحالات
  Future<void> _loadTimeline() async {
    setState(() => _isLoading = true);
    
    try {
      final timeline = await _shipmentService.getShipmentTimeline(_shipment.id);
      setState(() {
        _timeline = timeline;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'خطأ في تحميل التاريخ';
        _isLoading = false;
      });
    }
  }

  /// 📞 الاتصال
  Future<void> _makeCall(String phone) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phone);
    try {
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      }
    } catch (e) {
      _showSnackBar('لا يمكن الاتصال', Colors.red);
    }
  }

  /// 🗺️ فتح في خرائط Google
  Future<void> _openGoogleMaps(double lat, double lng) async {
    final url = 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng';
    final Uri uri = Uri.parse(url);
    
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      _showSnackBar('لا يمكن فتح الخرائط', Colors.red);
    }
  }

  /// ✅ تحديث حالة الشحنة
  Future<void> _updateStatus(String newStatus) async {
    setState(() => _isUpdating = true);
    
    final result = await _shipmentService.updateShipmentStatus(
      shipmentId: _shipment.id,
      status: newStatus,
    );

    setState(() => _isUpdating = false);

    if (result['success']) {
      setState(() {
        _shipment = _shipment.copyWith(status: newStatus);
      });
      _showSnackBar(result['message'], Colors.green);
      _loadTimeline();
    } else {
      _showSnackBar(result['message'], Colors.red);
    }
  }

  /// 🚚 تعيين سائق
  Future<void> _assignDriver() async {
    // في الواقع هنا يفتح شاشة اختيار سائق
    // للاختبار نستخدم سائق افتراضي
    setState(() => _isUpdating = true);
    
    final result = await _shipmentService.assignDriver(
      shipmentId: _shipment.id,
      driverId: 'driver_1',
    );

    setState(() => _isUpdating = false);

    if (result['success']) {
      _showSnackBar(result['message'], Colors.green);
    } else {
      _showSnackBar(result['message'], Colors.red);
    }
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

  /// 📋 عرض dialog تأكيد
  Future<bool> _showConfirmDialog(String title, String message) async {
    final result = await showDialog<bool>(
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
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل الشحنة'),
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
            onPressed: _loadTimeline,
            tooltip: 'تحديث',
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
                  // 📦 معلومات الشحنة الأساسية
                  _buildShipmentInfoCard(),
                  const SizedBox(height: 16),

                  // 🗺️ الخريطة
                  _buildMapCard(),
                  const SizedBox(height: 16),

                  // 👤 معلومات العميل
                  _buildCustomerCard(),
                  const SizedBox(height: 16),

                  // 🚚 معلومات السائق
                  if (_shipment.driverId != null)
                    _buildDriverCard()
                  else if (widget.userType == 'admin')
                    _buildAssignDriverCard(),
                  const SizedBox(height: 16),

                  // 📜 تاريخ الحالات (تايم لاين)
                  _buildTimelineCard(),
                  const SizedBox(height: 24),

                  // 🎮 أزرار الإجراءات
                  if (_shipment.status != 'delivered' && 
                      _shipment.status != 'cancelled')
                    _buildActionButtons(),
                ],
              ),
            ),
    );
  }

  /// 📦 كارت معلومات الشحنة
  Widget _buildShipmentInfoCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'رقم التتبع',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _shipment.trackingNumber,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusBadge(_shipment.status),
              ],
            ),
            const Divider(height: 32),
            
            // الوصف
            if (_shipment.description != null) ...[
              _buildInfoRow(
                icon: Icons.description,
                label: 'الوصف',
                value: _shipment.description!,
              ),
              const SizedBox(height: 12),
            ],
            
            // الوزن
            _buildInfoRow(
              icon: Icons.scale,
              label: 'الوزن',
              value: '${_shipment.weight} كجم',
            ),
            const SizedBox(height: 12),
            
            // المبلغ
            _buildInfoRow(
              icon: Icons.attach_money,
              label: 'المبلغ',
              value: '${_shipment.amount.toStringAsFixed(2)} ج.م',
              valueColor: Colors.green,
            ),
            const SizedBox(height: 12),
            
            // تاريخ الإنشاء
            _buildInfoRow(
              icon: Icons.calendar_today,
              label: 'تاريخ الإنشاء',
              value: _formatDate(_shipment.createdAt),
            ),
            
            if (_shipment.estimatedDeliveryDate != null) ...[
              const SizedBox(height: 12),
              _buildInfoRow(
                icon: Icons.schedule,
                label: 'موعد التسليم المتوقع',
                value: _formatDate(_shipment.estimatedDeliveryDate!),
                valueColor: Colors.blue,
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 🗺️ كارت الخريطة
  Widget _buildMapCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // عنوان الكارت
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.map, color: Color(0xFF667eea)),
                const SizedBox(width: 8),
                const Text(
                  'مواقع الشحنة',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          
          // الخريطة
          SizedBox(
            height: 250,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(20),
              ),
              child: FlutterMap(
                options: MapOptions(
                  center: LatLng(
                    (_shipment.pickupLat + _shipment.deliveryLat) / 2,
                    (_shipment.pickupLng + _shipment.deliveryLng) / 2,
                  ),
                  zoom: 12,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.logistics.app',
                  ),
                  MarkerLayer(
                    markers: [
                      // 📍 موقع الاستلام
                      Marker(
                        point: LatLng(
                          _shipment.pickupLat,
                          _shipment.pickupLng,
                        ),
                        width: 80,
                        height: 80,
                        child: const Column(
                          children: [
                            Icon(
                              Icons.location_pin,
                              color: Colors.green,
                              size: 40,
                            ),
                            Text(
                              'الاستلام',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // 📍 موقع التسليم
                      Marker(
                        point: LatLng(
                          _shipment.deliveryLat,
                          _shipment.deliveryLng,
                        ),
                        width: 80,
                        height: 80,
                        child: const Column(
                          children: [
                            Icon(
                              Icons.location_pin,
                              color: Colors.red,
                              size: 40,
                            ),
                            Text(
                              'التسليم',
                              style: TextStyle(
                                fontSize: 10,
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
          ),
          
          // أزرار التنقل
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _openGoogleMaps(
                      _shipment.pickupLat,
                      _shipment.pickupLng,
                    ),
                    icon: const Icon(Icons.navigation),
                    label: const Text('التوجه للاستلام'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _openGoogleMaps(
                      _shipment.deliveryLat,
                      _shipment.deliveryLng,
                    ),
                    icon: const Icon(Icons.navigation),
                    label: const Text('التوجه للتسليم'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 👤 كارت العميل
  Widget _buildCustomerCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFF667eea).withOpacity(0.1),
                  child: const Icon(Icons.person, color: Color(0xFF667eea)),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'معلومات العميل',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildInfoRow(
              icon: Icons.person_outline,
              label: 'الاسم',
              value: _shipment.customerName,
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              icon: Icons.phone,
              label: 'رقم الموبايل',
              value: _shipment.customerPhone,
              onTap: () => _makeCall(_shipment.customerPhone),
              actionIcon: Icons.call,
              actionColor: Colors.green,
            ),
            if (_shipment.customerEmail != null) ...[
              const SizedBox(height: 12),
              _buildInfoRow(
                icon: Icons.email,
                label: 'البريد الإلكتروني',
                value: _shipment.customerEmail!,
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 🚚 كارت السائق
  Widget _buildDriverCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.orange.withOpacity(0.1),
                  child: const Icon(Icons.local_shipping, color: Colors.orange),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'معلومات السائق',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildInfoRow(
              icon: Icons.person,
              label: 'الاسم',
              value: _shipment.driverName ?? 'غير معروف',
            ),
            if (_shipment.driverPhone != null) ...[
              const SizedBox(height: 12),
              _buildInfoRow(
                icon: Icons.phone,
                label: 'رقم الموبايل',
                value: _shipment.driverPhone!,
                onTap: () => _makeCall(_shipment.driverPhone!),
                actionIcon: Icons.call,
                actionColor: Colors.green,
              ),
            ],
            const SizedBox(height: 16),
            
            // أزرار تتبع السائق
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DriverLocationScreen(
                            driverId: _shipment.driverId!,
                            driverName: _shipment.driverName ?? 'السائق',
                            driverPhone: _shipment.driverPhone,
                            vehiclePlate: _shipment.driverId == 'd1' 
                                ? 'أ ب ج 1234' 
                                : null,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.location_on),
                    label: const Text('تتبع السائق'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF667eea),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 🚚 كارت تعيين سائق (للأدمن)
  Widget _buildAssignDriverCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.orange.shade700),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'لم يتم تعيين سائق',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isUpdating ? null : _assignDriver,
                icon: _isUpdating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.person_add),
                label: Text(_isUpdating ? 'جاري التعيين...' : 'تعيين سائق'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 📜 كارت تاريخ الحالات
  Widget _buildTimelineCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.timeline, color: Color(0xFF667eea)),
                SizedBox(width: 8),
                Text(
                  'تاريخ الشحنة',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (_timeline.isEmpty)
              Center(
                child: Text(
                  'لا يوجد تاريخ متاح',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              )
            else
              ...List.generate(_timeline.length, (index) {
                final status = _timeline[index];
                final isLast = index == _timeline.length - 1;
                
                return _buildTimelineItem(
                  status: status,
                  isLast: isLast,
                );
              }),
          ],
        ),
      ),
    );
  }

  /// 📍 عنصر التايم لاين
  Widget _buildTimelineItem({
    required ShipmentStatus status,
    required bool isLast,
  }) {
    final statusColors = {
      'created': Colors.blue,
      'pending': Colors.orange,
      'in_transit': Colors.purple,
      'out_for_delivery': Colors.indigo,
      'delivered': Colors.green,
      'cancelled': Colors.red,
    };

    final statusText = {
      'created': 'تم الإنشاء',
      'pending': 'في الانتظار',
      'in_transit': 'في الطريق',
      'out_for_delivery': 'جاري التوصيل',
      'delivered': 'تم التسليم',
      'cancelled': 'تم الإلغاء',
    };

    final color = statusColors[status.status] ?? Colors.grey;
    final text = statusText[status.status] ?? status.status;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // الخط والنقطة
          Column(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.4),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: Colors.grey.shade300,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          
          // المحتوى
          Expanded(
            child: Container(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    text,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: color,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    status.description,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDateTime(status.timestamp),
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 12,
                    ),
                  ),
                  if (status.location != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.location_on, 
                            size: 14, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(
                          status.location!,
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 🎮 أزرار الإجراءات
  Widget _buildActionButtons() {
    final isDriver = widget.userType == 'driver';
    final isAdmin = widget.userType == 'admin';
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'إجراءات الشحنة',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        
        // أزرار السائق
        if (isDriver) ...[
          if (_shipment.status == 'pending') ...[
            _buildActionButton(
              label: 'بدء التوصيل',
              icon: Icons.play_circle,
              color: Colors.blue,
              onPressed: () => _updateStatus('in_transit'),
            ),
            const SizedBox(height: 12),
          ],
          if (_shipment.status == 'in_transit') ...[
            _buildActionButton(
              label: 'في طريقي للعميل',
              icon: Icons.local_shipping,
              color: Colors.indigo,
              onPressed: () => _updateStatus('out_for_delivery'),
            ),
            const SizedBox(height: 12),
          ],
          if (_shipment.status == 'out_for_delivery') ...[
            _buildActionButton(
              label: 'تم التسليم',
              icon: Icons.check_circle,
              color: Colors.green,
              onPressed: () => _updateStatus('delivered'),
            ),
            const SizedBox(height: 12),
          ],
        ],
        
        // أزرار الأدمن
        if (isAdmin) ...[
          if (_shipment.status == 'pending') ...[
            _buildActionButton(
              label: 'إلغاء الشحنة',
              icon: Icons.cancel,
              color: Colors.red,
              onPressed: () => _updateStatus('cancelled'),
            ),
          ],
        ],
        
        // زر المسار للجميع
        _buildActionButton(
          label: 'فتح المسار في الخرائط',
          icon: Icons.map,
          color: const Color(0xFF667eea),
          onPressed: () => _openGoogleMaps(
            _shipment.deliveryLat,
            _shipment.deliveryLng,
          ),
        ),
      ],
    );
  }

  /// 🔘 زر إجراء
  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: double.infinity,
      height: 56,
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
          onTap: _isUpdating ? null : onPressed,
          child: Center(
            child: _isUpdating
                ? const CircularProgressIndicator(color: Colors.white)
                : Row(
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
      ),
    );
  }

  /// 📋 صف معلومات
  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
    VoidCallback? onTap,
    IconData? actionIcon,
    Color? actionColor,
  }) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: Colors.grey.shade600, size: 20),
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
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: valueColor,
              ),
            ),
          ),
          if (actionIcon != null)
            Icon(actionIcon, color: actionColor, size: 24),
        ],
      ),
    );
  }

  /// 🏷️ شارة الحالة
  Widget _buildStatusBadge(String status) {
    final statusConfig = {
      'created': {'text': 'تم الإنشاء', 'color': Colors.blue},
      'pending': {'text': 'في الانتظار', 'color': Colors.orange},
      'in_transit': {'text': 'في الطريق', 'color': Colors.purple},
      'out_for_delivery': {'text': 'جاري التوصيل', 'color': Colors.indigo},
      'delivered': {'text': 'تم التسليم', 'color': Colors.green},
      'cancelled': {'text': 'ملغى', 'color': Colors.red},
    };

    final config = statusConfig[status] ?? 
        {'text': 'غير معروف', 'color': Colors.grey};

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: (config['color'] as Color).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        config['text'] as String,
        style: TextStyle(
          color: config['color'] as Color,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  /// 📅 تنسيق التاريخ
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  /// 📅 تنسيق التاريخ والوقت
  String _formatDateTime(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
