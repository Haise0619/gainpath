import 'exercise.dart';

/// UC-2.6 — Equipment recognition catalogue. [category] deliberately uses
/// the same value space as [Exercise.category] (not a separate taxonomy)
/// so a scanned/browsed piece of equipment can pull real matching
/// exercises straight out of the workout routine — see
/// `EquipmentDetailScreen`'s "Related exercises" section. Some equipment
/// has no exercise in the current routine sharing its category on
/// purpose (Cable Crossover, Treadmill), so that screen also has to
/// handle the honest "nothing matched" case, not just the happy path.

abstract class EquipmentEditBaseline {}

class GymEquipment {
  final String id;
  final int revision;
  final EquipmentEditBaseline? editBaseline;

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
    this.revision = 0,
    this.editBaseline,
  });

  GymEquipment copyWith({bool? isActive}) => GymEquipment(
      id: id,
      name: name,
      category: category,
      description: description,
      howToUse: List.of(howToUse),
      safetyTips: List.of(safetyTips),
      imageUrl: imageUrl,
      muscleGroup: muscleGroup,
      isActive: isActive ?? this.isActive,
      revision: revision,
      editBaseline: editBaseline);

  void validate() {
    if (name.trim().isEmpty ||
        name.trim().length > 100 ||
        category.trim().isEmpty ||
        category.trim().length > 80 ||
        muscleGroup.trim().isEmpty ||
        muscleGroup.trim().length > 80 ||
        description.trim().isEmpty ||
        description.trim().length > 2000) {
      throw const FormatException(
          'Enter a name (1–100), category and muscle group (1–80), and description (1–2000 characters).');
    }
    final uri = Uri.tryParse(imageUrl.trim());
    if (imageUrl.trim().length > 2048 ||
        (imageUrl.trim().isNotEmpty &&
            (uri == null ||
                !imageUrl.trim().startsWith('https://') ||
                uri.host.isEmpty ||
                uri.userInfo.isNotEmpty ||
                RegExp(r'\s').hasMatch(imageUrl.trim())))) {
      throw const FormatException(
          'Use a valid HTTPS image URL or leave it empty.');
    }
    for (final steps in [howToUse, safetyTips]) {
      if (steps.length > 10 ||
          steps.any((s) => s.trim().isEmpty || s.trim().length > 400)) {
        throw const FormatException(
            'Use at most 10 non-empty steps per list, with up to 400 characters each.');
      }
    }
  }

  static GymEquipment fromDocument(String id, Map<String, dynamic> d,
      {EquipmentEditBaseline? baseline}) {
    if (d['schemaVersion'] != 1 ||
        d['revision'] is! int ||
        d['revision'] < 1 ||
        d['isActive'] is! bool ||
        d['howToUse'] is! List ||
        d['safetyTips'] is! List) {
      throw const FormatException('Equipment data is unavailable.');
    }
    final entry = GymEquipment(
        id: id,
        name: d['name'] as String,
        category: d['category'] as String,
        muscleGroup: d['muscleGroup'] as String,
        description: d['description'] as String,
        imageUrl: d['imageUrl'] as String,
        howToUse: List<String>.from(d['howToUse'] as List),
        safetyTips: List<String>.from(d['safetyTips'] as List),
        isActive: d['isActive'] as bool,
        revision: d['revision'] as int,
        editBaseline: baseline);
    entry.validate();
    return entry;
  }
}
