import 'dart:convert';
import 'published_routine_view.dart';

/// Preserve all existing attempts' exact signature; version two signs typed targets.
String routinePlanSignature(PublishedRoutine routine) => jsonEncode([
      routine.id,
      routine.sourceBlueprintId,
      if (routine.schemaVersion == 2) 2,
      for (final e in routine.exercises)
        if (routine.schemaVersion == 1)
          [
            e.exerciseId,
            e.dayNumber,
            e.sets,
            e.reps,
            if (e.restSeconds != 60) e.restSeconds
          ]
        else
          [
            e.entryId,
            e.exerciseId,
            e.executionMode?.name,
            e.dayNumber,
            e.prescription.toJson(),
            e.mediaRevision,
            e.mediaGeneration,
            e.videoUrl
          ],
    ]);
