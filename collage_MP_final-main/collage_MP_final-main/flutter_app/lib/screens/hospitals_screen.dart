import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api_client.dart';

class HospitalsScreen extends ConsumerStatefulWidget {
  const HospitalsScreen({super.key});

  @override
  ConsumerState<HospitalsScreen> createState() => _HospitalsScreenState();
}

class _HospitalsScreenState extends ConsumerState<HospitalsScreen> {
  LatLng center = const LatLng(28.6139, 77.2090);
  List<dynamic> hospitals = [];
  int radius = 5000;
  bool clinics = false;
  String filter = '';
  int? selectedIndex;
  final map = MapController();

  @override
  void initState() {
    super.initState();
    permissionAndLoad();
  }

  Future<void> permissionAndLoad() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse) {
      final position = await Geolocator.getCurrentPosition();
      setState(() {
        center = LatLng(position.latitude, position.longitude);
      });
    }
    await load();
  }

  Future<void> load() async {
    final response = await ref.read(apiProvider).get(
      '/hospitals/nearby',
      queryParameters: {
        'lat': center.latitude,
        'lon': center.longitude,
        'radius_m': radius,
        'limit': 30,
        'include_clinics': clinics,
      },
    );
    if (!mounted) return;
    setState(() {
      hospitals = response.data['hospitals'] as List<dynamic>;
      selectedIndex = null;
    });
  }

  void selectHospital(int index) {
    setState(() => selectedIndex = index);
    final hospital = visibleHospitals[index];
    map.move(LatLng(hospital['lat'], hospital['lon']), 14);
  }

  List<dynamic> get visibleHospitals => hospitals
      .where((hospital) => (hospital['name'] as String? ?? 'Unnamed hospital')
          .toLowerCase()
          .contains(filter.toLowerCase()))
      .toList();

  Future<void> openDirections(dynamic hospital) async {
    final uri = Uri.parse(hospital['directions_url'] as String);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final visible = visibleHospitals;
    return Scaffold(
      appBar: AppBar(title: const Text('Nearby Hospitals')),
      body: Stack(
        children: [
          FlutterMap(
            mapController: map,
            options: MapOptions(initialCenter: center, initialZoom: 13),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'aqi_public_health_monitor',
              ),
              const RichAttributionWidget(
                attributions: [
                  TextSourceAttribution('OpenStreetMap contributors'),
                ],
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: center,
                    width: 32,
                    height: 32,
                    child: const Icon(Icons.my_location, color: Colors.blue),
                  ),
                  ...visible.asMap().entries.map((entry) {
                    final hospital = entry.value;
                    final point = LatLng(
                        hospital['lat'] as double, hospital['lon'] as double);
                    return Marker(
                      point: point,
                      width: 38,
                      height: 38,
                      child: IconButton(
                        onPressed: () => selectHospital(entry.key),
                        icon: Icon(
                          Icons.local_hospital,
                          color: selectedIndex == entry.key
                              ? Theme.of(context).colorScheme.error
                              : Theme.of(context).colorScheme.primary,
                        ),
                        tooltip: hospital['name'] as String?,
                      ),
                    );
                  }),
                ],
              ),
            ],
          ),
          DraggableScrollableSheet(
            initialChildSize: 0.36,
            minChildSize: 0.18,
            maxChildSize: 0.72,
            builder: (context, scrollController) => Material(
              elevation: 4,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: TextField(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Filter by name',
                      ),
                      onChanged: (value) => setState(() => filter = value),
                    ),
                  ),
                  Expanded(
                    child: visible.isEmpty
                        ? const Center(
                            child: Text('No hospitals found in this area.'))
                        : ListView.builder(
                            controller: scrollController,
                            itemCount: visible.length,
                            itemBuilder: (context, index) {
                              final hospital = visible[index];
                              return ListTile(
                                selected: selectedIndex == index,
                                title: Text(hospital['name'] as String),
                                subtitle: Text(
                                    '${hospital['distance_km']} km · ${hospital['address'] ?? ''}'),
                                trailing: TextButton(
                                  onPressed: () => openDirections(hospital),
                                  child: const Text('Directions'),
                                ),
                                onTap: () => selectHospital(index),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
