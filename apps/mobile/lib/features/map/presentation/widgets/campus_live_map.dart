import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as geo;

import '../../../../app/theme.dart';
import '../../../../core/hunt/hunt_service.dart';
import '../../../../core/location/lat_lng.dart' as app;

/// Geographic map for the real campus build. The illustrated route is still
/// used in demo mode, but cannot represent a professor anywhere on campus.
class CampusLiveMap extends StatefulWidget {
  const CampusLiveMap({super.key, this.playerPosition, this.hunts = const []});

  final app.LatLng? playerPosition;
  final List<HuntSession> hunts;

  static const center = geo.LatLng(-0.1969, -78.4362);
  static const tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  @override
  State<CampusLiveMap> createState() => _CampusLiveMapState();
}

class _CampusLiveMapState extends State<CampusLiveMap> {
  final MapController _controller = MapController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _centerOn(geo.LatLng point, {double zoom = 17.5}) {
    _controller.move(point, zoom);
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().toUtc();
    final visibleHunts = widget.hunts
        .where((hunt) => hunt.hasFreshLocationAt(now))
        .toList(growable: false);
    final player = widget.playerPosition;
    final professorPoint = visibleHunts.isEmpty
        ? null
        : geo.LatLng(
            visibleHunts.first.position!.latitude,
            visibleHunts.first.position!.longitude,
          );

    return Semantics(
      label: 'Mapa geográfico del campus USFQ',
      container: true,
      child: Stack(
        children: [
          FlutterMap(
            mapController: _controller,
            options: const MapOptions(
              initialCenter: CampusLiveMap.center,
              initialZoom: 16.5,
              minZoom: 15,
              maxZoom: 19,
              backgroundColor: Color(0xFFD9E8DA),
            ),
            children: [
              TileLayer(
                urlTemplate: CampusLiveMap.tileUrl,
                userAgentPackageName: 'edu.profesorgo.profesor_go',
              ),
              CircleLayer(
                circles: [
                  for (final hunt in visibleHunts)
                    CircleMarker(
                      point: geo.LatLng(
                        hunt.position!.latitude,
                        hunt.position!.longitude,
                      ),
                      radius: math.max(hunt.accuracyMeters ?? 20, 15),
                      useRadiusInMeter: true,
                      color: AppColors.accent.withValues(alpha: 0.22),
                      borderColor: AppColors.accent,
                      borderStrokeWidth: 2,
                    ),
                ],
              ),
              MarkerLayer(
                markers: [
                  if (player != null)
                    Marker(
                      key: const Key('live-map-player'),
                      point: geo.LatLng(player.latitude, player.longitude),
                      width: 44,
                      height: 44,
                      child: const _PlayerMarker(),
                    ),
                  for (final hunt in visibleHunts)
                    Marker(
                      key: Key('live-map-professor-${hunt.professorId}'),
                      point: geo.LatLng(
                        hunt.position!.latitude,
                        hunt.position!.longitude,
                      ),
                      width: 120,
                      height: 64,
                      child: _ProfessorMarker(name: hunt.professorName),
                    ),
                ],
              ),
            ],
          ),
          Positioned(
            top: 158,
            right: 8,
            child: Column(
              children: [
                if (professorPoint != null)
                  _MapAction(
                    icon: Icons.person_pin_circle,
                    label: 'Centrar en el profesor',
                    onTap: () => _centerOn(professorPoint),
                  ),
                if (player != null) ...[
                  const SizedBox(height: 8),
                  _MapAction(
                    icon: Icons.my_location,
                    label: 'Centrar en mi ubicación',
                    onTap: () => _centerOn(
                      geo.LatLng(player.latitude, player.longitude),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Positioned(
            top: 265,
            right: 4,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(3),
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text(
                  '© OpenStreetMap contributors',
                  style: TextStyle(color: Colors.black87, fontSize: 10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerMarker extends StatelessWidget {
  const _PlayerMarker();

  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(
      color: AppColors.accentAlt,
      shape: BoxShape.circle,
      boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 5)],
    ),
    child: Icon(Icons.person, color: Colors.white, size: 27),
  );
}

class _ProfessorMarker extends StatelessWidget {
  const _ProfessorMarker({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.accent,
          border: Border.all(color: AppColors.background, width: 2),
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 5)],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.background,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      const Icon(Icons.location_on, color: AppColors.accent, size: 25),
    ],
  );
}

class _MapAction extends StatelessWidget {
  const _MapAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.background.withValues(alpha: 0.9),
    borderRadius: BorderRadius.circular(10),
    child: IconButton(
      tooltip: label,
      onPressed: onTap,
      icon: Icon(icon, color: AppColors.accentAlt),
    ),
  );
}
