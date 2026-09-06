/// UC-2.6 — Equipment recognition catalogue. [category] deliberately uses
/// the same value space as [Exercise.category] (not a separate taxonomy)
/// so a scanned/browsed piece of equipment can pull real matching
/// exercises straight out of `context.read<WorkoutRepository>().routine` — see
/// `EquipmentDetailScreen`'s "Related exercises" section. Some equipment
/// has no exercise in the current routine sharing its category on
/// purpose (Cable Crossover, Treadmill), so that screen also has to
/// handle the honest "nothing matched" case, not just the happy path.
import 'package:gainpath/features/workout/domain/entities/exercise.dart';

class GymEquipment {
  final String id;

  /// Mutable, along with the rest of the descriptive fields below, so
  /// the admin Equipment Catalog's Edit form can update a machine's
  /// record in place — same "mutate the seed in place" pattern used for
  /// [isActive].
  String name;
  String category;
  String description;
  List<String> howToUse;
  List<String> safetyTips;
  String imageUrl;
  String muscleGroup;

  /// Mutable so admin can unpublish a broken/removed machine without
  /// deleting its record — matches `gymEquipment.isActive` in the data
  /// dictionary. Inactive equipment stays out of the member scanner's
  /// match pool and the browse catalogue.
  bool isActive;

  GymEquipment({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.howToUse,
    required this.safetyTips,
    required this.imageUrl,
    required this.muscleGroup,
    this.isActive = true,
  });
}
