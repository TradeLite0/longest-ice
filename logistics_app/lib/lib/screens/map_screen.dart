import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

class MapScreen extends StatefulWidget {
  final String destination;
  final double? lat;
  final double? lng;

  const MapScreen({
    Key? key,
    required this.destination,
    this.lat,
    this.lng,
  }) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late final MapController _mapController;
  LatLng? _destination;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _initializeLocation();
  }

  void _initializeLocation() {
    // لو فيه إحداثيات، نستخدمها
    if (widget.lat != null && widget.lng != null) {
      _destination = LatLng(widget.lat!, widget.lng!);
    } else {
      // إحداثيات افتراضية (القاهرة)
      _destination = const LatLng(30.0444, 31.2357);
    }
    setState(() => _isLoading = false);
  }

  // 🗺️ فتح Google Maps للتنقل
  Future<void> _openGoogleMaps() async {
    if (_destination == null) return;
    
    final url = 'https://www.google.com/maps/dir/?api=1&destination='
        '${_destination!.latitude},${_destination!.longitude}';
    
    final Uri uri = Uri.parse(url);
    
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ لا يمكن فتح الخرائط'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الموقع على الخريطة'),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF667eea), Color(0xFF764ba2)],
            ),
          ),
        ),
        actions: [
          // 🗺️ فتح في Google Maps
          IconButton(
            icon: const Icon(Icons.navigation),
            onPressed: _openGoogleMaps,
            tooltip: 'فتح في خرائط Google',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 📝 معلومات العنوان
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.white,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.location_on, color: Colors.red),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.destination,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_destination != null)
                        Text(
                          '📍 الإحداثيات: ${_destination!.latitude.toStringAsFixed(4)}, ${_destination!.longitude.toStringAsFixed(4)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                    ],
                  ),
                ),
                
                // 🗺️ الخريطة
                Expanded(
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      center: _destination,
                      zoom: 15,
                      minZoom: 5,
                      maxZoom: 18,
                    ),
                    children: [
                      // 🌍 طبقة OpenStreetMap (مجانية)
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.logistics.app',
                      ),
                      
                      // 📍 علامة الموقع
                      MarkerLayer(
                        markers: [
                          if (_destination != null)
                            Marker(
                              point: _destination!,
                              width: 80,
                              height: 80,
                              child: const Icon(
                                Icons.location_pin,
                                color: Colors.red,
                                size: 50,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // 🎮 أزرار التحكم
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // 🔍 تكبير
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            final currentZoom = _mapController.zoom;
                            _mapController.move(
                              _mapController.center,
                              currentZoom + 1,
                            );
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('تكبير'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF667eea),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      
                      // 🔍 تصغير
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            final currentZoom = _mapController.zoom;
                            _mapController.move(
                              _mapController.center,
                              currentZoom - 1,
                            );
                          },
                          icon: const Icon(Icons.remove),
                          label: const Text('تصغير'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF667eea),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      
                      // 🗺️ التنقل
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _openGoogleMaps,
                          icon: const Icon(Icons.navigation),
                          label: const Text('تنقل'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
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
}
