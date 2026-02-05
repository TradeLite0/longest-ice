import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:async';
import '../services/shipment_service.dart';
import 'shipment_details_screen.dart';

/// 📍 شاشة تتبع الشحنة للعميل
class TrackingScreen extends StatefulWidget {
  final String? trackingNumber;

  const TrackingScreen({
    Key? key,
    this.trackingNumber,
  }) : super(key: key);

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  final ShipmentService _shipmentService = ShipmentService();
  final TextEditingController _trackingController = TextEditingController();
  final MapController _mapController = MapController();
  
  Shipment? _shipment;
  List<ShipmentStatus> _timeline = [];
  bool _isLoading = false;
  bool _isSearching = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.trackingNumber != null) {
      _trackingController.text = widget.trackingNumber!;
      _searchShipment();
    }
  }

  @override
  void dispose() {
    _trackingController.dispose();
    super.dispose();
  }

  /// 🔍 البحث عن شحنة
  Future<void> _searchShipment() async {
    final trackingNumber = _trackingController.text.trim();
    if (trackingNumber.isEmpty) {
      setState(() => _errorMessage = 'الرجاء إدخال رقم التتبع');
      return;
    }

    setState(() {
      _isSearching = true;
      _errorMessage = null;
      _shipment = null;
    });

    try {
      // البحث عن الشحنة باستخدام الرقم
      final shipments = await _shipmentService.getShipments();
      final found = shipments.firstWhere(
        (s) => s.trackingNumber == trackingNumber,
        orElse: () => throw Exception('الشحنة غير موجودة'),
      );

      final timeline = await _shipmentService.getShipmentTimeline(found.id);

      setState(() {
        _shipment = found;
        _timeline = timeline;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '❌ لم يتم العثور على الشحنة';
        _isSearching = false;
      });
    }
  }

  /// 📊 الحصول على نسبة التقدم
  double _getProgress() {
    if (_shipment == null) return 0;
    
    final statusProgress = {
      'created': 0.1,
      'pending': 0.2,
      'in_transit': 0.5,
      'out_for_delivery': 0.8,
      'delivered': 1.0,
      'cancelled': 0.0,
    };
    
    return statusProgress[_shipment!.status] ?? 0;
  }

  /// 🎨 لون الحالة
  Color _getStatusColor(String status) {
    final colors = {
      'created': Colors.blue,
      'pending': Colors.orange,
      'in_transit': Colors.purple,
      'out_for_delivery': Colors.indigo,
      'delivered': Colors.green,
      'cancelled': Colors.red,
    };
    return colors[status] ?? Colors.grey;
  }

  /// 📝 نص الحالة
  String _getStatusText(String status) {
    final texts = {
      'created': 'تم الإنشاء',
      'pending': 'في الانتظار',
      'in_transit': 'في الطريق',
      'out_for_delivery': 'جاري التوصيل',
      'delivered': 'تم التسليم',
      'cancelled': 'تم الإلغاء',
    };
    return texts[status] ?? status;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تتبع الشحنة'),
        centerTitle: true,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF667eea), Color(0xFF764ba2)],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // 🔍 شريط البحث
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF667eea), Color(0xFF764ba2)],
              ),
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(30),
              ),
            ),
            child: Column(
              children: [
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
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _trackingController,
                          textDirection: TextDirection.ltr,
                          decoration: InputDecoration(
                            hintText: 'أدخل رقم التتبع',
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            contentPadding: const EdgeInsets.all(20),
                          ),
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.all(4),
                        child: ElevatedButton(
                          onPressed: _isSearching ? null : _searchShipment,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF667eea),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isSearching
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('بحث'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 📋 نتائج البحث
          Expanded(
            child: _isSearching
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? _buildErrorWidget()
                    : _shipment == null
                        ? _buildEmptyWidget()
                        : _buildShipmentResult(),
          ),
        ],
      ),
    );
  }

  /// 📦 عرض نتيجة البحث
  Widget _buildShipmentResult() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // رقم التتبع والحالة
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
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
                            _shipment!.trackingNumber,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(_shipment!.status)
                              .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _getStatusText(_shipment!.status),
                          style: TextStyle(
                            color: _getStatusColor(_shipment!.status),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  // شريط التقدم
                  LinearProgressIndicator(
                    value: _getProgress(),
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation(
                      _getStatusColor(_shipment!.status),
                    ),
                    minHeight: 10,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'نسبة الإنجاز: ${(_getProgress() * 100).toInt()}%',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // معلومات الشحنة
          _buildInfoCard(),
          const SizedBox(height: 16),

          // الخريطة
          if (_shipment!.status != 'pending' && _shipment!.driverId != null)
            _buildMapCard(),
          
          if (_shipment!.status != 'pending' && _shipment!.driverId != null)
            const SizedBox(height: 16),

          // تاريخ الشحنة
          _buildTimelineCard(),
          const SizedBox(height: 16),

          // زر عرض التفاصيل الكاملة
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ShipmentDetailsScreen(
                      shipment: _shipment!,
                      userType: 'client',
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.visibility),
              label: const Text('عرض التفاصيل الكاملة'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF667eea),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 🎴 كارت المعلومات
  Widget _buildInfoCard() {
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
                Icon(Icons.info, color: Color(0xFF667eea)),
                SizedBox(width: 8),
                Text(
                  'معلومات الشحنة',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildInfoRow(
              icon: Icons.person,
              label: 'المرسل',
              value: _shipment!.customerName,
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              icon: Icons.scale,
              label: 'الوزن',
              value: '${_shipment!.weight} كجم',
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              icon: Icons.attach_money,
              label: 'المبلغ',
              value: '${_shipment!.amount.toStringAsFixed(2)} ج.م',
              valueColor: Colors.green,
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              icon: Icons.location_on,
              label: 'من',
              value: _shipment!.pickupAddress,
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              icon: Icons.location_on,
              label: 'إلى',
              value: _shipment!.deliveryAddress,
            ),
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
          const Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.map, color: Color(0xFF667eea)),
                SizedBox(width: 8),
                Text(
                  'موقع السائق',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 200,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(20),
              ),
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  center: LatLng(
                    _shipment!.deliveryLat,
                    _shipment!.deliveryLng,
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
                      Marker(
                        point: LatLng(
                          _shipment!.deliveryLat,
                          _shipment!.deliveryLng,
                        ),
                        width: 50,
                        height: 50,
                        child: const Icon(
                          Icons.location_pin,
                          color: Colors.red,
                          size: 40,
                        ),
                      ),
                      if (_shipment!.status == 'in_transit' ||
                          _shipment!.status == 'out_for_delivery')
                        Marker(
                          point: LatLng(
                            _shipment!.pickupLat,
                            _shipment!.pickupLng,
                          ),
                          width: 50,
                          height: 50,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                            ),
                            child: const Icon(
                              Icons.local_shipping,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 📜 كارت التاريخ
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
                Icon(Icons.history, color: Color(0xFF667eea)),
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
                  'لا يوجد تحديثات بعد',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              )
            else
              ...List.generate(_timeline.length, (index) {
                final status = _timeline[index];
                final isLast = index == _timeline.length - 1;
                
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: _getStatusColor(status.status),
                            shape: BoxShape.circle,
                          ),
                        ),
                        if (!isLast)
                          Container(
                            width: 2,
                            height: 40,
                            color: Colors.grey.shade300,
                          ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getStatusText(status.status),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            status.description,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            _formatDateTime(status.timestamp),
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ],
                );
              }),
          ],
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
  }) {
    return Row(
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
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
        ),
      ],
    );
  }

  /// 📅 تنسيق التاريخ
  String _formatDateTime(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
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
            style: TextStyle(
              color: Colors.red.shade700,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _searchShipment,
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
          Icon(
            Icons.local_shipping,
            size: 100,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 24),
          Text(
            'أدخل رقم التتبع للبحث عن شحنتك',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'يمكنك العثور على رقم التتبع في رسالة التأكيد',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
}
