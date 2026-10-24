import '../entities/gym_equipment.dart';
import '../entities/equipment_image.dart';
import '../entities/equipment_video.dart';

/// Data access contract for the workout feature. Implemented in-memory for the
/// prototype; a Firebase implementation will sit behind the same interface.
class EquipmentPage {
  EquipmentPage(Iterable<GymEquipment> items, {this.nextCursor})
      : items = List.unmodifiable(items);
  final List<GymEquipment> items;
  final String? nextCursor;
}

abstract interface class EquipmentReader {
  Future<EquipmentPage> loadEquipment({String? afterId});
}

class EquipmentConflict implements Exception {
  const EquipmentConflict();
}

class EquipmentSessionChanged implements Exception {
  const EquipmentSessionChanged();
}

abstract class EquipmentRepository implements EquipmentReader {
  List<GymEquipment> get gymEquipment;
  bool get isLive => false;
  @override
  Future<EquipmentPage> loadEquipment({String? afterId}) async =>
      EquipmentPage(afterId == null ? gymEquipment : []);
  Future<GymEquipment> saveEquipment(GymEquipment equipment,
      {EquipmentImage? image,
      EquipmentVideo? video,
      void Function(double)? onVideoProgress}) async {
    if (image != null || video != null) {
      throw UnsupportedError('Image upload requires Firebase mode.');
    }
    equipment.validate();
    final index = gymEquipment.indexWhere((e) => e.id == equipment.id);
    if (equipment.id.isNotEmpty &&
        (index < 0 || gymEquipment[index].revision != equipment.revision)) {
      throw const EquipmentConflict();
    }
    final saved = GymEquipment(
        id: equipment.id.isEmpty
            ? 'eq${DateTime.now().microsecondsSinceEpoch}'
            : equipment.id,
        name: equipment.name.trim(),
        category: equipment.category.trim(),
        muscleGroup: equipment.muscleGroup.trim(),
        description: equipment.description.trim(),
        imageUrl: equipment.imageUrl.trim(),
        tutorialVideoUrl: equipment.tutorialVideoUrl,
        howToUse: equipment.howToUse.map((s) => s.trim()).toList(),
        safetyTips: equipment.safetyTips.map((s) => s.trim()).toList(),
        isActive: equipment.isActive,
        revision: equipment.revision + 1);
    if (index < 0) {
      gymEquipment.add(saved);
    } else {
      gymEquipment[index] = saved;
    }
    return saved;
  }
}
