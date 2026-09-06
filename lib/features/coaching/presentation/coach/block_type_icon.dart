import 'package:flutter/material.dart';
import 'package:gainpath/features/coaching/domain/entities/availability.dart';

/// Presentation-only icon for each [BlockType]; the label lives with the entity.
extension BlockTypeIcon on BlockType {
  IconData get icon => switch (this) {
        BlockType.breakTime => Icons.free_breakfast_rounded,
        BlockType.offDay => Icons.weekend_rounded,
        BlockType.leave => Icons.flight_takeoff_rounded,
      };
}
