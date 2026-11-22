import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_ui/src/shared/widgets/branch_map.dart';
import 'package:latlong2/latlong.dart';

const _north = {
  'branchId': 'north',
  'displayName': 'North Gym',
  'address': '12 Main Road',
  'status': 'active',
  'latitude': 3.20,
  'longitude': 101.70,
};
const _south = {
  'branchId': 'south',
  'displayName': 'South Gym',
  'latitude': 2.71,
  'longitude': 101.96,
};
const _missing = {
  'branchId': 'missing',
  'displayName': 'Missing coordinates',
};

void main() {
  testWidgets('failed tiles preserve controls and retry only on request',
      (tester) async {
    final provider = _FixtureTileProvider();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: BranchMap(tileProviderFactory: () => provider)),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Map tiles unavailable.'), findsOneWidget);
    expect(find.text('Retry map'), findsOneWidget);
    expect(find.byTooltip('Zoom in'), findsOneWidget);
    expect(find.text('© OpenStreetMap contributors'), findsOneWidget);
    final attempts = provider.requests;
    await tester.pump(const Duration(seconds: 2));
    expect(provider.requests, attempts);

    await tester.tap(find.text('Retry map'));
    await tester.pumpAndSettle();
    expect(provider.requests, greaterThan(attempts));
    expect(find.text('Retry map'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('partial success keeps markers, attribution and retry usable',
      (tester) async {
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawColor(Colors.green, ui.BlendMode.src);
    final picture = recorder.endRecording();
    final image = picture.toImageSync(1, 1);
    addTearDown(image.dispose);
    addTearDown(picture.dispose);
    final provider = _FixtureTileProvider(firstImage: image);
    String? chosen;
    Uri? attribution;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: BranchMap(
          branches: const [_north],
          tileProviderFactory: () => provider,
          onBranch: (branch) => chosen = branch['branchId'] as String,
          onOpenAttribution: (uri) => attribution = uri,
        ),
      ),
    ));
    expect(find.text('Loading map…'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('Some map tiles could not load.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('branch-map-marker:north')));
    expect(chosen, 'north');
    await tester.tap(find.text('© OpenStreetMap contributors'));
    expect(attribution, Uri.https('www.openstreetmap.org', '/copyright'));
  });

  testWidgets('selection, fit, resizing and filtering use actual locations',
      (tester) async {
    final provider = _FixtureTileProvider();
    var branches = const [_north, _south, _missing];
    String? selected;
    String? managed;
    var width = 680.0;
    late StateSetter update;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(builder: (context, setState) {
          update = setState;
          return Center(
            child: SizedBox(
              width: width,
              child: BranchMap(
                height: 360,
                branches: branches,
                focusSelected: true,
                selectedId: selected,
                onBranch: (branch) =>
                    update(() => selected = branch['branchId'] as String),
                onManageBranch: (branch) =>
                    managed = branch['branchId'] as String,
                tileProviderFactory: () => provider,
              ),
            ),
          );
        }),
      ),
    ));
    await tester.pumpAndSettle();
    MapCamera camera() => tester
        .widget<FlutterMap>(find.byType(FlutterMap))
        .mapController!
        .camera;
    final markers = find.byType(MarkerLayer);
    expect(tester.widget<MarkerLayer>(markers).markers, hasLength(2));
    final initialZoom = camera().zoom;
    expect(initialZoom, lessThan(15));

    await tester.tap(find.byKey(const ValueKey('branch-map-marker:north')));
    await tester.pumpAndSettle();
    final focused = camera().latLngToScreenOffset(const LatLng(3.20, 101.70));
    expect(focused.dx, closeTo(camera().nonRotatedSize.width / 2, 1));
    expect(focused.dy, lessThan(camera().nonRotatedSize.height / 2));
    expect(find.text('12 Main Road'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
    await tester.tap(find.text('Manage branch'));
    expect(managed, 'north');

    await tester.tap(find.byTooltip('Fit all branches'));
    await tester.pumpAndSettle();
    expect(camera().zoom, closeTo(initialZoom, 0.01));
    update(() => width = 320);
    await tester.pumpAndSettle();
    expect(camera().nonRotatedSize.width, 320);
    expect(camera().visibleBounds.contains(const LatLng(3.20, 101.70)), isTrue);
    expect(camera().visibleBounds.contains(const LatLng(2.71, 101.96)), isTrue);

    update(() => branches = const [_south, _missing]);
    await tester.pumpAndSettle();
    expect(camera().center.latitude, closeTo(2.71, 0.00001));
    expect(camera().center.longitude, closeTo(101.96, 0.00001));
    expect(find.text('Manage branch'), findsNothing);

    update(() => branches = const [_missing]);
    await tester.pumpAndSettle();
    expect(find.byType(FlutterMap), findsNothing);
    expect(find.text('No branches with a map location.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('picker changes only emit actual tap coordinates',
      (tester) async {
    final provider = _FixtureTileProvider();
    LatLng? pending;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: BranchMap(
          onPin: (point) => pending = point,
          tileProviderFactory: () => provider,
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(pending, isNull);
    await tester.tapAt(tester.getCenter(find.byType(FlutterMap)));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(pending?.latitude, closeTo(malaysiaMapCenter.latitude, 0.00001));
    expect(pending?.longitude, closeTo(malaysiaMapCenter.longitude, 0.00001));
  });
}

class _FixtureTileProvider extends TileProvider {
  _FixtureTileProvider({this.firstImage});

  final ui.Image? firstImage;
  int requests = 0;

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      _FixtureImage(requests++ == 0 ? firstImage : null);
}

class _FixtureImage extends ImageProvider<_FixtureImage> {
  const _FixtureImage(this.image);

  final ui.Image? image;

  @override
  Future<_FixtureImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
      _FixtureImage key, ImageDecoderCallback decode) {
    final image = key.image;
    return OneFrameImageStreamCompleter(image == null
        ? Future<ImageInfo>.error(StateError('Fixture tile unavailable'))
        : SynchronousFuture(ImageInfo(image: image.clone())));
  }
}
