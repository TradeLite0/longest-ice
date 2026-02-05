import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:async';
import '../services/order_service.dart';
import '../models/order_model.dart';

/// شاشة تتبع الشحنة للعميل - مع خريطة موقع السائق
class TrackingScreen extends StatefulWidget {
  final int shipmentId;

  const TrackingScreen({Key? key, required this.shipmentId}) : super(key: key);

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  Order? _shipment;
  bool _isLoading = true;
  Timer? _refreshTimer;
  
  // خريطة
  final MapController _mapController = MapController();
  LatLng? _driverLocation;
  LatLng? _pickupLocation;
  LatLng? _destinationLocation;

  // خطوات التتبع
  final List<Map<String, dynamic>> _trackingSteps = [
    {'status': 'pending', 'label': 'تم استلام الطلب', 'icon': Icons.receipt},
    {'status': 'assigned', 'label': 'تم تعيين سائق', 'icon': Icons.person_add},
    {'status': 'picked_up', 'label': 'تم استلام الشحنة', 'icon': Icons.inventory},
    {'status': 'in_transit', 'label': 'في الطريق', 'icon': Icons.local_shipping},
    {'status': 'out_for_delivery', 'label': 'خارج للتوصيل', 'icon': Icons.delivery_dining},
    {'status': 'delivered', 'label': 'تم التسليم', 'icon': Icons.check_circle},
  ];

  @override
  void initState() {
    super.initState();
    _loadShipment();
    // تحديث كل 30 ثانية
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _loadShipment();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _loadShipment() async {
    try {
      final orderService = OrderService();
      final result = await orderService.getShipmentDetails(widget.shipmentId);
      
      if (result['success'] && mounted) {
        setState(() {
          _shipment = Order.fromJson(result['shipment']);
          _isLoading = false;
          
          // تحديث مواقع الخريطة
          if (_shipment?.driverLat != null && _shipment?.driverLng != null) {
            _driverLocation = LatLng(_shipment!.driverLat!, _shipment!.driverLng!);
          }
          if (_shipment?.pickupLat != null && _shipment?.pickupLng != null) {
            _pickupLocation = LatLng(_shipment!.pickupLat!, _shipment!.pickupLng!);
          }
        });
      }
    } catch (e) {
      print('Error loading shipment: $e');
    }
  }

  int _getCurrentStepIndex() {
    if (_shipment == null) return 0;
    final index = _trackingSteps.indexWhere((step) => step['status'] == _shipment!.status);
    return index == -1 ? 0 : index;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تتبع الشحنة'),
        backgroundColor: Colors.green.shade700,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadShipment,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _shipment == null
              ? const Center(child: Text('الشحنة غير موجودة'))
              : Column(
                  children: [
                    // رقم التتبع
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      color: Colors.green.shade50,
                      child: Column(
                        children: [
                          const Text(
                            'رقم التتبع',
                            style: TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            _shipment!.trackingNumber,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // الخريطة
                    Expanded(
                      flex: 2,
                      child: FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          center: _driverLocation ?? _pickupLocation ?? const LatLng(30.0444, 31.2357),
                          zoom: 13,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.example.logistics_app',
                          ),
                          // موقع الاستلام
                          if (_pickupLocation != null)
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: _pickupLocation!,
                                  width: 50,
                                  height: 50,
                                  child: const Icon(
                                    Icons.location_on,
                                    color: Colors.blue,
                                    size: 40,
                                  ),
                                ),
                              ],
                            ),
                          // موقع السائق
                          if (_driverLocation != null)
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: _driverLocation!,
                                  width: 60,
                                  height: 60,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.green,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 3),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.green.withOpacity(0.5),
                                          blurRadius: 10,
                                          spreadRadius: 5,
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.local_shipping,
                                      color: Colors.white,
                                      size: 30,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    
                    // معلومات السائق
                    if (_shipment?.driverName != null)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const CircleAvatar(
                              radius: 30,
                              child: Icon(Icons.person, size: 30),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'السائق',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                  Text(
                                    _shipment!.driverName!,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (_shipment?.driverPhone != null)
                                    Text(_shipment!.driverPhone!),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.phone, color: Colors.green),
                              onPressed: () {
                                // اتصال بالسائق
                              },
                            ),
                          ],
                        ),
                      ),
                    
                    // خطوات التتبع
                    Container(
                      height: 120,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        reverse: true,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _trackingSteps.length,
                        itemBuilder: (context, index) {
                          final step = _trackingSteps[index];
                          final currentStep = _getCurrentStepIndex();
                          final isCompleted = index <= currentStep;
                          final isCurrent = index == currentStep;
                          
                          return Container(
                            width: 100,
                            margin: const EdgeInsets.symmetric(horizontal: 5),
                            child: Column(
                              children: [
                                Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isCompleted ? Colors.green : Colors.grey.shade300,
                                    border: isCurrent
                                        ? Border.all(color: Colors.green, width: 3)
                                        : null,
                                  ),
                                  child: Icon(
                                    step['icon'],
                                    color: isCompleted ? Colors.white : Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  step['label'],
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isCompleted ? Colors.black : Colors.grey,
                                    fontWeight: isCurrent ? FontWeight.bold : null,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}