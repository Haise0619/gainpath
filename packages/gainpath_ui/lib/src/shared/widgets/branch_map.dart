import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../tokens/app_theme.dart';

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

class BranchMap extends StatelessWidget {
  const BranchMap({
    super.key,
    this.branches = const [],
    this.onBranch,
    this.selectedId,
    this.location,
    this.pin,
    this.onPin,
    this.height = 300,
    this.focusSelected = false,
    this.focusRequestId = 0,
    this.onManageBranch,
    this.onOpenAttribution,
    this.tileProviderFactory,
  });

  final List<Map<String, dynamic>> branches;
  final ValueChanged<Map<String, dynamic>>? onBranch;
  final String? selectedId;
  final LatLng? location, pin;
  final ValueChanged<LatLng>? onPin;
  final double height;
  final bool focusSelected;
  final int focusRequestId;
  final ValueChanged<Map<String, dynamic>>? onManageBranch;
  final ValueChanged<Uri>? onOpenAttribution;
  final TileProvider Function()? tileProviderFactory;

  @override
  Widget build(BuildContext context) {
    final hasLocations =
        branches.any((branch) => branchMapPoint(branch) != null);
    return Semantics(
      container: true,
      label: onPin == null ? 'Branch map' : 'Branch location picker',
      child: SizedBox(
        height: height,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child:
              focusSelected && !hasLocations && pin == null && location == null
                  ? const ColoredBox(
                      color: AppColors.surfaceAlt,
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Text('No branches with a map location.',
                              textAlign: TextAlign.center),
                        ),
                      ),
                    )
                  : _BranchMapViewport(map: this),
        ),
      ),
    );
  }
}

class _BranchMapViewport extends StatefulWidget {
  const _BranchMapViewport({required this.map});

  final BranchMap map;

  @override
  State<_BranchMapViewport> createState() => _BranchMapViewportState();
}

enum _TileStatus { loading, partialLoading, ready, partialFailure, failure }

class _BranchMapViewportState extends State<_BranchMapViewport> {
  static const _tiles = String.fromEnvironment('GAINPATH_BRANCH_TILE_URL',
      defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png');
  final _controller = MapController();
  final _surface = GlobalKey();
  final _resetTiles = StreamController<void>.broadcast();
  final _visibleTiles = <Object, TileImage>{};
  _TileStatus _tileStatus = _TileStatus.loading;
  bool _tileStatusScheduled = false;
  bool _cameraUpdateScheduled = false;
  bool _focusOnCameraUpdate = false;
  bool _ready = false;
  bool _fitOnResize = true;
  bool _showPopup = true;

  BranchMap get map => widget.map;

  static Map<Object?, LatLng> _coordinates(BranchMap map) => {
        for (final branch in map.branches)
          if (branchMapPoint(branch) case final LatLng point)
            branch['branchId']: point,
      };

  List<LatLng> get _points => {
        ..._coordinates(map).values,
        if (map.location case final LatLng point) point,
        if (map.pin case final LatLng point) point,
      }.toList();

  Map<String, dynamic>? get _selectedBranch {
    if (map.selectedId == null) return null;
    for (final branch in map.branches) {
      if (branch['branchId'] == map.selectedId &&
          branchMapPoint(branch) != null) {
        return branch;
      }
    }
    return null;
  }

  LatLng? get _focusPoint {
    final branch = _selectedBranch;
    return map.focusSelected && branch != null ? branchMapPoint(branch) : null;
  }

  @override
  void didUpdateWidget(covariant _BranchMapViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (map.focusSelected &&
        (map.selectedId != oldWidget.map.selectedId ||
            map.focusRequestId != oldWidget.map.focusRequestId ||
            !mapEquals(_coordinates(map), _coordinates(oldWidget.map)))) {
      _showPopup = true;
      _scheduleCameraUpdate();
    }
  }

  @override
  void dispose() {
    _resetTiles.close();
    _controller.dispose();
    super.dispose();
  }

  CameraFit _cameraFit(List<LatLng> points) => CameraFit.coordinates(
      coordinates: points, padding: const EdgeInsets.all(45), maxZoom: 16);

  void _scheduleCameraUpdate({bool fitAll = false}) {
    _focusOnCameraUpdate = _focusOnCameraUpdate || !fitAll;
    if (_cameraUpdateScheduled) return;
    _cameraUpdateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cameraUpdateScheduled = false;
      final focus = _focusOnCameraUpdate;
      _focusOnCameraUpdate = false;
      if (!mounted || !_ready) return;
      final selected = focus ? _focusPoint : null;
      if (selected == null) {
        _fit();
      } else {
        _fitOnResize = false;
        final camera = _controller.camera;
        _controller.move(selected, camera.zoom.clamp(15, 19).toDouble(),
            offset: map.onManageBranch == null
                ? Offset.zero
                : Offset(0, -camera.nonRotatedSize.height * .24));
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _fit() {
    if (!_ready) return;
    _fitOnResize = true;
    final points = _points;
    if (points.length > 1) {
      _controller.fitCamera(_cameraFit(points));
    } else {
      _controller.move(
          points.firstOrNull ?? malaysiaMapCenter, points.isEmpty ? 7 : 15);
    }
  }

  void _fitFromControl() {
    if (_showPopup) setState(() => _showPopup = false);
    _fit();
  }

  void _zoom(double delta) {
    if (!_ready) return;
    _fitOnResize = false;
    final camera = _controller.camera;
    _controller.move(
        camera.center, (camera.zoom + delta).clamp(3, 19).toDouble());
  }

  void _trackTile(Object observer, TileImage? tile) {
    if (tile == null) {
      _visibleTiles.remove(observer);
    } else {
      _visibleTiles[observer] = tile;
    }
    _scheduleTileStatus();
  }

  void _scheduleTileStatus() {
    if (!mounted || _tileStatusScheduled) return;
    _tileStatusScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tileStatusScheduled = false;
      if (!mounted) return;
      final tiles = _visibleTiles.values;
      final hasError = tiles.any((tile) => tile.loadError);
      final hasImage =
          tiles.any((tile) => !tile.loadError && tile.imageInfo != null);
      final loading =
          tiles.any((tile) => !tile.loadError && tile.imageInfo == null);
      final status = switch ((hasImage, hasError, loading)) {
        (true, true, _) || (false, true, true) => _TileStatus.partialFailure,
        (true, false, true) => _TileStatus.partialLoading,
        (true, false, false) => _TileStatus.ready,
        (false, true, false) => _TileStatus.failure,
        _ => _TileStatus.loading,
      };
      if (status != _tileStatus) setState(() => _tileStatus = status);
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _retryTiles() {
    setState(() => _tileStatus = _TileStatus.loading);
    _resetTiles.add(null);
  }

  Marker _branchMarker(Map<String, dynamic> branch, LatLng point,
      {required bool selected}) {
    final colors = Theme.of(context).colorScheme;
    return Marker(
      key: ValueKey('branch-map-marker:${branch['branchId']}'),
      point: point,
      width: 46,
      height: 46,
      child: Semantics(
        selected: selected,
        child: IconButton(
          tooltip: branch['displayName'] as String? ?? 'Branch',
          style: IconButton.styleFrom(
            backgroundColor: selected ? colors.primary : colors.surface,
            foregroundColor: selected ? colors.onPrimary : AppColors.inkSoft,
            disabledBackgroundColor: colors.surface,
            disabledForegroundColor: AppColors.inkSoft,
          ),
          icon: const Icon(Icons.location_on, size: 27),
          onPressed: map.onBranch == null ? null : () => map.onBranch!(branch),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final points = _points;
    final focused = _focusPoint;
    final selected = _selectedBranch;
    final colors = Theme.of(context).colorScheme;
    final tileMessage = switch (_tileStatus) {
      _TileStatus.loading => 'Loading map…',
      _TileStatus.partialLoading => 'Loading remaining map tiles…',
      _TileStatus.ready => null,
      _TileStatus.partialFailure => 'Some map tiles could not load.',
      _TileStatus.failure => 'Map tiles unavailable.',
    };
    final retry = _tileStatus == _TileStatus.partialFailure ||
        _tileStatus == _TileStatus.failure;
    return ColoredBox(
      color: colors.surface,
      child: Column(children: [
        _toolbar(tileMessage, retry: retry),
        const Divider(height: 1, thickness: 1, color: AppColors.hairline),
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              FlutterMap(
                key: _surface,
                mapController: _controller,
                options: MapOptions(
                  backgroundColor: AppColors.surfaceAlt,
                  initialCenter:
                      focused ?? points.firstOrNull ?? malaysiaMapCenter,
                  initialZoom: points.isEmpty ? 7 : 15,
                  initialCameraFit: focused == null && points.length > 1
                      ? _cameraFit(points)
                      : null,
                  minZoom: 3,
                  maxZoom: 19,
                  interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
                  onMapReady: () {
                    _ready = true;
                    _fitOnResize = focused == null;
                    if (focused != null && map.onManageBranch != null) {
                      _scheduleCameraUpdate();
                    }
                  },
                  onMapEvent: (event) {
                    if (event is MapEventNonRotatedSizeChange &&
                        map.focusSelected &&
                        _fitOnResize) {
                      _scheduleCameraUpdate(fitAll: true);
                    }
                  },
                  onPositionChanged: (_, hasGesture) {
                    if (hasGesture) _fitOnResize = false;
                  },
                  onTap: map.onPin == null
                      ? null
                      : (_, point) => map.onPin!(point),
                ),
                children: [
                  _BranchTiles(
                    url: _tiles,
                    providerFactory: map.tileProviderFactory,
                    reset: _resetTiles.stream,
                    onTile: _trackTile,
                    onError: _scheduleTileStatus,
                  ),
                  MarkerLayer(markers: [
                    for (final branch in map.branches)
                      if (!identical(branch, selected))
                        if (branchMapPoint(branch) case final LatLng point)
                          _branchMarker(branch, point, selected: false),
                    if (selected != null)
                      _branchMarker(selected, branchMapPoint(selected)!,
                          selected: true),
                    if (map.location case final LatLng point)
                      Marker(
                        point: point,
                        child: Icon(Icons.my_location,
                            color: colors.primary,
                            semanticLabel: 'Your location'),
                      ),
                    if (map.pin case final LatLng point)
                      Marker(
                        point: point,
                        width: 48,
                        height: 48,
                        child: GestureDetector(
                          onPanUpdate: map.onPin == null
                              ? null
                              : (event) {
                                  final box = _surface.currentContext
                                      ?.findRenderObject();
                                  if (box is RenderBox) {
                                    map.onPin!(_controller.camera
                                        .screenOffsetToLatLng(box.globalToLocal(
                                            event.globalPosition)));
                                  }
                                },
                          child: Icon(Icons.location_on,
                              color: colors.primary,
                              size: 38,
                              semanticLabel: 'Selected coordinates'),
                        ),
                      ),
                  ]),
                ],
              ),
              if (_showPopup && selected != null && map.onManageBranch != null)
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 34,
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                          maxWidth: 290, maxHeight: map.height * .47),
                      child: _BranchMapPopup(
                        branch: selected,
                        onManage: () => map.onManageBranch!(selected),
                      ),
                    ),
                  ),
                ),
              Positioned(
                bottom: 0,
                right: 0,
                left: 0,
                child: Align(
                  alignment: Alignment.bottomRight,
                  child: Material(
                    color: colors.surface,
                    borderRadius:
                        const BorderRadius.only(topLeft: Radius.circular(6)),
                    child: InkWell(
                      onTap: map.onOpenAttribution == null
                          ? null
                          : () => map.onOpenAttribution!(
                              Uri.https('www.openstreetmap.org', '/copyright')),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 4),
                        child: Text('© OpenStreetMap contributors',
                            style: Theme.of(context).textTheme.labelSmall),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _toolbar(String? message, {required bool retry}) => LayoutBuilder(
        builder: (context, constraints) {
          final textScale = MediaQuery.textScalerOf(context).scale(13);
          final compact = constraints.maxWidth < 430 || textScale > 18;
          return SizedBox(
            height: (textScale * 2 + 16).clamp(52, 90).toDouble(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(children: [
                Expanded(
                  child: message == null
                      ? const SizedBox.shrink()
                      : Semantics(
                          liveRegion: true,
                          child: Tooltip(
                            message: message,
                            child: Text(message,
                                maxLines: 2, overflow: TextOverflow.ellipsis),
                          ),
                        ),
                ),
                if (retry)
                  if (compact)
                    IconButton(
                      tooltip: 'Retry map',
                      onPressed: _retryTiles,
                      icon: const Icon(Icons.refresh),
                    )
                  else
                    TextButton(
                        onPressed: _retryTiles, child: const Text('Retry map')),
                IconButton(
                    tooltip: 'Zoom in',
                    icon: const Icon(Icons.add),
                    onPressed: () => _zoom(1)),
                IconButton(
                    tooltip: 'Zoom out',
                    icon: const Icon(Icons.remove),
                    onPressed: () => _zoom(-1)),
                IconButton(
                    tooltip: map.focusSelected
                        ? 'Fit all branches'
                        : 'Fit locations',
                    icon: const Icon(Icons.center_focus_strong),
                    onPressed: _fitFromControl),
              ]),
            ),
          );
        },
      );
}

class _BranchMapPopup extends StatelessWidget {
  const _BranchMapPopup({required this.branch, required this.onManage});

  final Map<String, dynamic> branch;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = branch['displayName'] as String? ?? 'Branch';
    final status = switch (branch['status']) {
      'active' => 'Active',
      'inactive' => 'Inactive',
      _ => null,
    };
    return Material(
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.hairline),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontSize: 14, fontWeight: FontWeight.w700)),
            if (branch['address'] case final String address
                when address.isNotEmpty)
              Text(address, style: theme.textTheme.bodySmall),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (status != null)
                  Text(status, style: theme.textTheme.bodySmall),
                TextButton(
                    onPressed: onManage, child: const Text('Manage branch')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BranchTiles extends StatefulWidget {
  const _BranchTiles({
    required this.url,
    required this.providerFactory,
    required this.reset,
    required this.onTile,
    required this.onError,
  });

  final String url;
  final TileProvider Function()? providerFactory;
  final Stream<void> reset;
  final void Function(Object, TileImage?) onTile;
  final VoidCallback onError;

  @override
  State<_BranchTiles> createState() => _BranchTilesState();
}

class _BranchTilesState extends State<_BranchTiles> {
  // Some HTTP failures return an image. Treat the HTTP status as authoritative.
  late final _provider = widget.providerFactory?.call() ??
      NetworkTileProvider(attemptDecodeOfHttpErrorResponses: false);

  @override
  Widget build(BuildContext context) => TileLayer(
        urlTemplate: widget.url,
        userAgentPackageName: 'com.zyang.gainpath',
        tileProvider: _provider,
        maxNativeZoom: 19,
        panBuffer: 0,
        reset: widget.reset,
        evictErrorTileStrategy: EvictErrorTileStrategy.dispose,
        errorTileCallback: (_, error, stack) => widget.onError(),
        tileBuilder: (_, child, tile) =>
            _ObservedMapTile(tile: tile, onTile: widget.onTile, child: child),
      );
}

class _ObservedMapTile extends StatefulWidget {
  const _ObservedMapTile({
    required this.tile,
    required this.onTile,
    required this.child,
  });

  final TileImage tile;
  final void Function(Object, TileImage?) onTile;
  final Widget child;

  @override
  State<_ObservedMapTile> createState() => _ObservedMapTileState();
}

class _ObservedMapTileState extends State<_ObservedMapTile> {
  @override
  void dispose() {
    widget.onTile(this, null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    widget.onTile(this, widget.tile);
    return widget.child;
  }
}
