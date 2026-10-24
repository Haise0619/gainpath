import 'dart:async';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/workout.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/equipment_scanner_screen.dart';
import 'package:gainpath_mobile/features/workout/presentation/shared/equipment_detail_screen.dart';

class FakeEquipmentReader implements EquipmentReader {
  FakeEquipmentReader(this.items);
  final List<GymEquipment> items;

  @override
  Future<EquipmentPage> loadEquipment({String? afterId}) async {
    return EquipmentPage(items);
  }
}

class StaticEquipmentVisionClassifier implements EquipmentVisionClassifier {
  StaticEquipmentVisionClassifier(this.result);
  final EquipmentRecognitionResult result;
  int calls = 0;
  List<int>? captured;

  @override
  Future<EquipmentRecognitionResult> identifyEquipment(
    List<int> imageBytes, {
    String mimeType = 'image/jpeg',
  }) async {
    calls++;
    captured = imageBytes;
    return result;
  }
}

class FailingEquipmentVisionClassifier implements EquipmentVisionClassifier {
  @override
  Future<EquipmentRecognitionResult> identifyEquipment(
    List<int> imageBytes, {
    String mimeType = 'image/jpeg',
  }) async {
    throw Exception('Simulated network timeout');
  }
}

void main() {
  late TestCameraPlatform camera;
  late CameraPlatform original;
  setUp(() {
    original = CameraPlatform.instance;
    camera = TestCameraPlatform();
    CameraPlatform.instance = camera;
  });
  tearDown(() {
    CameraPlatform.instance = original;
  });
  final testEquipment = [
    GymEquipment(
      id: 'eq1',
      name: 'Squat Rack',
      category: 'Compound Lower-Body',
      description: 'A fixed barbell rack with adjustable safety arms.',
      howToUse: ['Set J-hooks to shoulder height.', 'Step under the bar.'],
      safetyTips: ['Set safety arms before lifting.'],
      imageUrl: '',
      muscleGroup: 'Quads · Glutes',
      isActive: true,
    ),
    GymEquipment(
      id: 'eq2',
      name: 'Adjustable Bench',
      category: 'Isolation Upper-Body',
      description: 'A flat-to-incline bench for dumbbell work.',
      howToUse: ['Set bench incline.'],
      safetyTips: ['Check incline pin.'],
      imageUrl: '',
      muscleGroup: 'Chest · Shoulders',
      isActive: true,
    ),
  ];

  Widget buildTestApp({
    required EquipmentVisionClassifier classifier,
    VoidCallback? onBrowse,
  }) {
    return MaterialApp(
      home: EquipmentScannerScreen(
        connected: true,
        enableCamera: true, // Real controller; fake only the native platform.
        reader: FakeEquipmentReader(testEquipment),
        classifier: classifier,
        onBrowse: onBrowse,
      ),
    );
  }

  for (final failure in [
    'permission',
    'missing',
    'initialize',
    'capture',
    'empty'
  ]) {
    testWidgets(
        'camera $failure failure never calls classifier; retry recovers',
        (tester) async {
      camera.denyPermission = failure == 'permission';
      camera.noCameras = failure == 'missing';
      camera.failCapture = failure == 'capture';
      camera.failInitialization = failure == 'initialize';
      camera.emptyCapture = failure == 'empty';
      final classifier = StaticEquipmentVisionClassifier(
          const EquipmentRecognitionResult(
              detectedEquipment: 'Squat Rack', confidence: 0.99));
      var browsed = false;
      await tester.pumpWidget(
          buildTestApp(classifier: classifier, onBrowse: () => browsed = true));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byIcon(Icons.camera_alt_rounded));
      await tester.pump();
      expect(find.text('Camera unavailable'), findsOneWidget);
      expect(classifier.calls, 0);
      await tester.tap(find.text('Browse catalogue'));
      expect(browsed, isTrue);
      camera.denyPermission = false;
      camera.noCameras = false;
      camera.failCapture = false;
      camera.failInitialization = false;
      camera.emptyCapture = false;
      await tester.tap(find.text('Retry'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(CameraPreview), findsOneWidget);
      expect(classifier.calls, 0);
      await tester.tap(find.byIcon(Icons.camera_alt_rounded));
      await tester.pump(const Duration(milliseconds: 100));
      expect(classifier.captured, [255, 216, 255, 42]);
      expect(find.text('Confirm equipment'), findsOneWidget);
      expect(find.byType(EquipmentDetailScreen), findsNothing);
    });
  }

  for (final mode in ['complete', 'failure', 'loop']) {
    testWidgets('catalog pagination $mode', (tester) async {
      final reader = PagedEquipmentReader(testEquipment,
          failLater: mode == 'failure', loop: mode == 'loop');
      await tester.pumpWidget(MaterialApp(
          home: EquipmentScannerScreen(
        connected: true,
        reader: reader,
        classifier: StaticEquipmentVisionClassifier(
            const EquipmentRecognitionResult(
                detectedEquipment: 'Squat Rack', confidence: 0.99)),
      )));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byIcon(Icons.camera_alt_rounded));
      await tester.pump(const Duration(milliseconds: 100));
      expect(reader.cursors, [null, 'page2']);
      expect(find.byType(EquipmentDetailScreen), findsNothing);
      expect(
          find.text(mode == 'complete'
              ? 'Confirm equipment'
              : 'Scanning unavailable'),
          findsOneWidget);
    });
  }

  testWidgets('uncertain exact prediction cannot open details', (tester) async {
    await tester.pumpWidget(buildTestApp(
        classifier: StaticEquipmentVisionClassifier(
            const EquipmentRecognitionResult(
                detectedEquipment: 'Squat Rack', confidence: 0.79))));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byIcon(Icons.camera_alt_rounded));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text("Couldn't recognise this equipment"), findsOneWidget);
    expect(find.byType(EquipmentDetailScreen), findsNothing);
  });

  testWidgets('large candidate list scrolls without overflowing the scanner',
      (tester) async {
    final items = List.generate(
        30,
        (i) => GymEquipment(
            id: 'b$i',
            name: 'Bench $i',
            category: 'Bench',
            description: '',
            howToUse: [],
            safetyTips: [],
            imageUrl: '',
            muscleGroup: '',
            isActive: true));
    await tester.pumpWidget(MaterialApp(
        home: EquipmentScannerScreen(
      connected: true,
      reader: FakeEquipmentReader(items),
      classifier: StaticEquipmentVisionClassifier(
          const EquipmentRecognitionResult(
              detectedEquipment: 'Bench', confidence: 0.99)),
    )));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byIcon(Icons.camera_alt_rounded));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
    await tester.drag(
        find.byType(SingleChildScrollView), const Offset(0, -1800));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.ensureVisible(find.text('Bench 29'));
    await tester.tap(find.text('Bench 29'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(EquipmentDetailScreen), findsOneWidget);
  });

  testWidgets('renders scanner UI elements properly', (tester) async {
    await tester.pumpWidget(
      buildTestApp(
        classifier: StaticEquipmentVisionClassifier(
          const EquipmentRecognitionResult(
            detectedEquipment: 'Squat Rack',
            confidence: 0.95,
          ),
        ),
      ),
    );

    expect(find.text('Scan equipment'), findsOneWidget);
    expect(find.text('Point your camera at gym equipment'), findsOneWidget);
    expect(find.byIcon(Icons.grid_view_rounded), findsOneWidget);
    expect(find.byIcon(Icons.camera_alt_rounded), findsOneWidget);
  });

  testWidgets('browse icon triggers onBrowse callback', (tester) async {
    var browseClicked = false;
    await tester.pumpWidget(
      buildTestApp(
        classifier: StaticEquipmentVisionClassifier(
          const EquipmentRecognitionResult(
            detectedEquipment: 'Squat Rack',
            confidence: 0.95,
          ),
        ),
        onBrowse: () => browseClicked = true,
      ),
    );

    await tester.tap(find.byIcon(Icons.grid_view_rounded));
    await tester.pump();

    expect(browseClicked, isTrue);
  });

  testWidgets('successful scan opens EquipmentDetailScreen with real details',
      (tester) async {
    await tester.pumpWidget(
      buildTestApp(
        classifier: StaticEquipmentVisionClassifier(
          const EquipmentRecognitionResult(
            detectedEquipment: 'Squat Rack',
            aliases: ['Power Rack'],
            confidence: 0.98,
            isGymEquipment: true,
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 100));
    // Tap shutter button
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byIcon(Icons.camera_alt_rounded));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(EquipmentDetailScreen), findsNothing);
    await tester.tap(find.text('Confirm equipment'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Should navigate to EquipmentDetailScreen
    expect(find.byType(EquipmentDetailScreen), findsOneWidget);
    expect(find.text('Squat Rack'), findsWidgets);
  });

  testWidgets('unrecognized item shows no-match card with browse button',
      (tester) async {
    await tester.pumpWidget(
      buildTestApp(
        classifier: StaticEquipmentVisionClassifier(
          const EquipmentRecognitionResult(
            detectedEquipment: 'Water Bottle',
            confidence: 0.8,
            isGymEquipment: false,
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byIcon(Icons.camera_alt_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text("Couldn't recognise this equipment"), findsOneWidget);
    expect(find.text('Browse all equipment'), findsOneWidget);
  });

  testWidgets('multiple matches show disambiguation options', (tester) async {
    final multipleEquipment = [
      GymEquipment(
        id: 'b1',
        name: 'Flat Bench',
        category: 'Isolation',
        description: 'Flat bench',
        howToUse: ['Lie down'],
        safetyTips: ['Feet flat'],
        imageUrl: '',
        muscleGroup: 'Chest',
        isActive: true,
      ),
      GymEquipment(
        id: 'b2',
        name: 'Incline Bench',
        category: 'Isolation',
        description: 'Incline bench',
        howToUse: ['Lie down'],
        safetyTips: ['Feet flat'],
        imageUrl: '',
        muscleGroup: 'Chest',
        isActive: true,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: EquipmentScannerScreen(
          connected: true,
          enableCamera: true,
          reader: FakeEquipmentReader(multipleEquipment),
          classifier: StaticEquipmentVisionClassifier(
            const EquipmentRecognitionResult(
              detectedEquipment: 'Bench',
              confidence: 0.80,
              isGymEquipment: true,
            ),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byIcon(Icons.camera_alt_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Confirm equipment'), findsOneWidget);
    expect(find.text('Flat Bench'), findsOneWidget);
    expect(find.text('Incline Bench'), findsOneWidget);

    // Tapping Flat Bench opens its detail screen
    await tester.tap(find.text('Flat Bench'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(EquipmentDetailScreen), findsOneWidget);
    expect(find.text('Flat Bench'), findsWidgets);
  });

  testWidgets('classifier error shows error card with retry and browse',
      (tester) async {
    await tester.pumpWidget(
      buildTestApp(classifier: FailingEquipmentVisionClassifier()),
    );

    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byIcon(Icons.camera_alt_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Scanning unavailable'), findsOneWidget);
    expect(find.text('Browse catalogue'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('mock mode runs scan and navigates using repository',
      (tester) async {
    final mockRepo = testEquipment;

    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<EquipmentRepository>(
            create: (_) => _FakeEquipmentRepo(mockRepo),
          ),
          RepositoryProvider<WorkoutRepository>(
            create: (_) => _FakeWorkoutRepo(),
          ),
        ],
        child: MaterialApp(
          home: EquipmentScannerScreen(
            connected: false,
            enableCamera: true,
            classifier: StaticEquipmentVisionClassifier(
              const EquipmentRecognitionResult(
                detectedEquipment: 'Adjustable Bench',
                confidence: 0.95,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byIcon(Icons.camera_alt_rounded));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(EquipmentDetailScreen), findsNothing);
    await tester.tap(find.text('Confirm equipment'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(EquipmentDetailScreen), findsOneWidget);
    expect(find.text('Adjustable Bench'), findsWidgets);
  });
}

class _FakeWorkoutRepo implements WorkoutRepository {
  @override
  List<Exercise> get routine => [];
  @override
  List<WorkoutRecord> get history => [];
  @override
  List<String> get voiceCues => [];
  @override
  int get heightCm => 175;
}

class _FakeEquipmentRepo implements EquipmentRepository {
  _FakeEquipmentRepo(this.gymEquipment);
  @override
  final List<GymEquipment> gymEquipment;
  @override
  bool get isLive => false;
  @override
  Future<EquipmentPage> loadEquipment({String? afterId}) async =>
      EquipmentPage(gymEquipment);
  @override
  Future<GymEquipment> saveEquipment(GymEquipment equipment,
          {EquipmentImage? image,
          EquipmentVideo? video,
          void Function(double)? onVideoProgress}) async =>
      equipment;
}

class TestCameraPlatform extends CameraPlatform {
  bool denyPermission = false;
  bool failCapture = false;
  bool noCameras = false;
  bool failInitialization = false;
  bool emptyCapture = false;
  int disposed = 0;
  @override
  Future<List<CameraDescription>> availableCameras() async => noCameras
      ? []
      : [
          const CameraDescription(
              name: 'back',
              lensDirection: CameraLensDirection.back,
              sensorOrientation: 90),
        ];
  @override
  Future<int> createCamera(
      CameraDescription description, ResolutionPreset? preset,
      {bool enableAudio = false}) async {
    if (denyPermission) {
      throw CameraException('CameraAccessDenied', 'Permission denied');
    }
    return 1;
  }

  @override
  Stream<DeviceOrientationChangedEvent> onDeviceOrientationChanged() =>
      const Stream.empty();
  @override
  Stream<CameraInitializedEvent> onCameraInitialized(int id) =>
      Stream.value(CameraInitializedEvent(
          id, 640, 480, ExposureMode.auto, false, FocusMode.auto, false));
  @override
  Stream<CameraErrorEvent> onCameraError(int id) => Stream.multi((_) {});
  @override
  Future<void> initializeCamera(int id,
      {ImageFormatGroup imageFormatGroup = ImageFormatGroup.unknown}) async {
    if (failInitialization) {
      throw CameraException('initialize-failed', 'Initialization failed');
    }
  }

  @override
  Widget buildPreview(int id) => const ColoredBox(color: Colors.black);
  @override
  Future<XFile> takePicture(int id) async {
    if (failCapture) throw CameraException('capture-failed', 'Capture failed');
    return XFile.fromData(
        Uint8List.fromList(emptyCapture ? [] : [255, 216, 255, 42]),
        mimeType: 'image/jpeg');
  }

  @override
  Future<void> dispose(int id) async {
    disposed++;
  }
}

class PagedEquipmentReader implements EquipmentReader {
  PagedEquipmentReader(this.items, {this.failLater = false, this.loop = false});
  final List<GymEquipment> items;
  final bool failLater;
  final bool loop;
  final List<String?> cursors = [];
  @override
  Future<EquipmentPage> loadEquipment({String? afterId}) async {
    cursors.add(afterId);
    if (afterId == null) {
      return EquipmentPage(
          List.generate(
              20,
              (i) => GymEquipment(
                    id: 'first-$i',
                    name: 'Unrelated Equipment $i',
                    category: 'Other',
                    description: '',
                    howToUse: [],
                    safetyTips: [],
                    imageUrl: '',
                    muscleGroup: '',
                    isActive: true,
                  )),
          nextCursor: 'page2');
    }
    if (failLater) throw const EquipmentSessionChanged();
    return EquipmentPage(items, nextCursor: loop ? 'page2' : null);
  }
}
