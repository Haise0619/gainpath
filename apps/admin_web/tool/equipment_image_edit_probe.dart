import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/workout.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:gainpath_admin_web/infrastructure/local/equipment_image_picker.dart';
import 'package:gainpath_admin_web/features/workout/presentation/admin/equipment_catalog_screen.dart';

// Isolated browser regression: real form, file chooser and decoder; saves only
// into this process. No Firebase initialization, credentials or network writes.
void main() {
  final repo = ProbeEquipmentRepository();
  runApp(MultiRepositoryProvider(
      providers: [
        RepositoryProvider<EquipmentRepository>.value(value: repo),
        RepositoryProvider<EquipmentImagePicker>(
            create: (_) => LocalEquipmentImagePicker()),
      ],
      child: MaterialApp(
          theme: AppTheme.build(),
          home: Scaffold(
              body: Column(children: [
            ValueListenableBuilder<int>(
                valueListenable: repo.savedImages,
                builder: (_, count, __) => Text(
                    'LOCAL REGRESSION — saved image replacements: $count — no Firebase writes')),
            const Expanded(child: EquipmentCatalogScreen()),
          ])))));
}

class ProbeEquipmentRepository extends EquipmentRepository {
  final savedImages = ValueNotifier(0);
  GymEquipment entry = GymEquipment(
      id: 'probe',
      name: 'Image replacement regression',
      category: 'Strength',
      description: 'Local fixture only',
      howToUse: [],
      safetyTips: [],
      imageUrl: '',
      muscleGroup: 'Back');
  @override
  bool get isLive => true;
  @override
  List<GymEquipment> get gymEquipment => [entry];
  @override
  Future<EquipmentPage> loadEquipment({String? afterId}) async =>
      EquipmentPage([entry]);
  @override
  Future<GymEquipment> saveEquipment(GymEquipment equipment,
      {EquipmentImage? image}) async {
    entry = equipment;
    if (image != null) savedImages.value++;
    return entry;
  }
}
