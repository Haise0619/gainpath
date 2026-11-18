import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

const malaysiaMapCenter = LatLng(3.139, 101.6869);

LatLng? branchMapPoint(Map<String, dynamic> branch) {
  final latitude = branch['latitude'];
  final longitude = branch['longitude'];
  if (latitude is! num ||
      longitude is! num ||
      !latitude.isFinite ||
      !longitude.isFinite ||
      latitude.abs() > 90 ||
      longitude.abs() > 180) {
    return null;
  }
  return LatLng(latitude.toDouble(), longitude.toDouble());
}

double? branchDistanceKm(Map<String, dynamic> branch, LatLng origin) {
  final point = branchMapPoint(branch);
  return point == null
      ? null
      : const Distance().as(LengthUnit.Meter, origin, point) / 1000;
}

class BranchMap extends StatefulWidget {
  const BranchMap(
      {super.key,
      this.branches = const [],
      this.onBranch,
      this.selectedId,
      this.location,
      this.pin,
      this.onPin});

  final List<Map<String, dynamic>> branches;
  final ValueChanged<Map<String, dynamic>>? onBranch;
  final String? selectedId;
  final LatLng? location, pin;
  final ValueChanged<LatLng>? onPin;

  @override
  State<BranchMap> createState() => _BranchMapState();
}

class _BranchMapState extends State<BranchMap> {
  static const _tiles = String.fromEnvironment('GAINPATH_BRANCH_TILE_URL',
      defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png');
  final _controller = MapController();
  final _surface = GlobalKey();
  bool _tileError = false;
  bool _ready = false;

  List<LatLng> get _points => [
        for (final branch in widget.branches)
          if (branchMapPoint(branch) case final LatLng point) point,
        if (widget.location case final LatLng point) point,
        if (widget.pin case final LatLng point) point,
      ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _fit() {
    if (!_ready) return;
    final points = _points.toSet().toList();
    if (points.length > 1) {
      _controller.fitCamera(CameraFit.coordinates(
          coordinates: points, padding: const EdgeInsets.all(45), maxZoom: 16));
    } else {
      _controller.move(
          points.firstOrNull ?? malaysiaMapCenter, points.isEmpty ? 7 : 15);
    }
  }

  @override
  Widget build(BuildContext context) {
    final points = _points;
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      height: 300,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            FlutterMap(
              key: _surface,
              mapController: _controller,
              options: MapOptions(
                initialCenter: points.firstOrNull ?? malaysiaMapCenter,
                initialZoom: points.isEmpty ? 7 : 15,
                minZoom: 3,
                maxZoom: 19,
                interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
                onMapReady: () {
                  _ready = true;
                  _fit();
                },
                onTap: widget.onPin == null
                    ? null
                    : (_, point) => widget.onPin!(point),
              ),
              children: [
                TileLayer(
                  urlTemplate: _tiles,
                  userAgentPackageName: 'com.zyang.gainpath',
                  maxNativeZoom: 19,
                  panBuffer: 0,
                  errorTileCallback: (_, error, stack) {
                    if (mounted && !_tileError) {
                      setState(() => _tileError = true);
                    }
                  },
                ),
                MarkerLayer(markers: [
                  for (final branch in widget.branches)
                    if (branchMapPoint(branch) case final LatLng point)
                      Marker(
                          point: point,
                          width: 46,
                          height: 46,
                          child: IconButton(
                            tooltip:
                                branch['displayName'] as String? ?? 'Branch',
                            color: branch['branchId'] == widget.selectedId
                                ? colors.tertiary
                                : colors.primary,
                            icon: const Icon(Icons.location_on, size: 34),
                            onPressed: () => widget.onBranch?.call(branch),
                          )),
                  if (widget.location case final LatLng point)
                    Marker(
                        point: point,
                        child: Icon(Icons.my_location,
                            color: colors.primary,
                            semanticLabel: 'Your location')),
                  if (widget.pin case final LatLng point)
                    Marker(
                        point: point,
                        width: 48,
                        height: 48,
                        child: GestureDetector(
                          onPanUpdate: (event) {
                            final box =
                                _surface.currentContext?.findRenderObject();
                            if (box is RenderBox) {
                              widget.onPin?.call(_controller.camera
                                  .screenOffsetToLatLng(
                                      box.globalToLocal(event.globalPosition)));
                            }
                          },
                          child: Icon(Icons.location_on,
                              color: colors.tertiary,
                              size: 38,
                              semanticLabel: 'Selected coordinates'),
                        )),
                ]),
                const SimpleAttributionWidget(
                    source: Text('© OpenStreetMap contributors')),
              ],
            ),
            Positioned(
                top: 8,
                right: 8,
                child: Material(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(8),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                        tooltip: 'Zoom in',
                        icon: const Icon(Icons.add),
                        onPressed: () => _zoom(1)),
                    IconButton(
                        tooltip: 'Zoom out',
                        icon: const Icon(Icons.remove),
                        onPressed: () => _zoom(-1)),
                    IconButton(
                        tooltip: 'Fit locations',
                        icon: const Icon(Icons.center_focus_strong),
                        onPressed: _fit),
                  ]),
                )),
            if (_tileError)
              Positioned(
                  left: 8,
                  top: 8,
                  right: 62,
                  child: IgnorePointer(
                    child: Material(
                        color: colors.surface,
                        child: const Padding(
                          padding: EdgeInsets.all(6),
                          child: Text('Some map tiles could not load.'),
                        )),
                  )),
          ],
        ),
      ),
    );
  }

  void _zoom(double delta) {
    if (!_ready) return;
    final camera = _controller.camera;
    _controller.move(
        camera.center, (camera.zoom + delta).clamp(3, 19).toDouble());
  }
}
