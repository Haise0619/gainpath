import 'package:gainpath_domain/workout.dart';
import 'dart:convert';

String guidedTimedMediaIdentity(
        {required String videoUrl,
        required int mediaRevision,
        required String mediaGeneration}) =>
    jsonEncode([videoUrl, mediaRevision, mediaGeneration]);

enum GuidedTimedPhase {
  loading,
  ready,
  working,
  resting,
  paused,
  interrupted,
  saving,
  completed
}

enum GuidedTimedRestKind { betweenSets, midSet }

/// Camera-free elapsed-time evidence. Enclosing checkpoint owns account/routine identity.
class GuidedTimedProgress {
  GuidedTimedProgress(
      {required this.runId,
      required this.entryId,
      required this.entryIndex,
      required this.exerciseId,
      required this.prescription,
      required this.mediaIdentity,
      required this.updatedAt,
      this.startedAt,
      this.endedAt,
      this.phase = GuidedTimedPhase.ready,
      this.phaseBeforePause = GuidedTimedPhase.ready,
      this.restKind = GuidedTimedRestKind.betweenSets,
      List<int> completedSetActiveMicroseconds = const [],
      this.currentSetActiveMicroseconds = 0,
      this.remainingRestMicroseconds = 0})
      : completedSetActiveMicroseconds =
            List.unmodifiable(completedSetActiveMicroseconds) {
    validate();
  }
  final String runId, entryId, exerciseId, mediaIdentity;
  final int entryIndex;
  final TimedPrescription prescription;
  final DateTime updatedAt;
  final DateTime? startedAt, endedAt;
  final GuidedTimedPhase phase, phaseBeforePause;
  final GuidedTimedRestKind restKind;
  final List<int> completedSetActiveMicroseconds;
  final int currentSetActiveMicroseconds, remainingRestMicroseconds;
  int get completedSets => completedSetActiveMicroseconds.length;
  int get targetMicroseconds =>
      prescription.durationSeconds * Duration.microsecondsPerSecond;
  int get totalActiveMicroseconds =>
      completedSets * targetMicroseconds + currentSetActiveMicroseconds;
  bool get completed => completedSets == prescription.sets;
  void validate() {
    prescription.validate();
    if ([runId, entryId, exerciseId, mediaIdentity]
            .any((s) => s.isEmpty || s.length > 4096) ||
        entryIndex < 0 ||
        entryIndex >= 50 ||
        prescription.sets < 1 ||
        prescription.sets > 50 ||
        prescription.durationSeconds < 1 ||
        prescription.durationSeconds > 3600 ||
        prescription.restSeconds < 0 ||
        prescription.restSeconds > 600 ||
        completedSets > prescription.sets ||
        completedSetActiveMicroseconds.any((v) => v != targetMicroseconds) ||
        currentSetActiveMicroseconds < 0 ||
        currentSetActiveMicroseconds >= targetMicroseconds ||
        remainingRestMicroseconds < 0 ||
        remainingRestMicroseconds > prescription.restSeconds * 1000000 ||
        (totalActiveMicroseconds > 0 &&
            (startedAt == null ||
                totalActiveMicroseconds >
                    updatedAt.difference(startedAt!).inMicroseconds)) ||
        (completed && endedAt == null) ||
        (completed && currentSetActiveMicroseconds != 0) ||
        (phase == GuidedTimedPhase.completed && !completed) ||
        !updatedAt.isUtc ||
        (startedAt != null &&
            (!startedAt!.isUtc || startedAt!.isAfter(updatedAt))) ||
        (endedAt != null &&
            (!completed ||
                !endedAt!.isUtc ||
                endedAt!.isAfter(updatedAt) ||
                (startedAt != null && endedAt!.isBefore(startedAt!))))) {
      throw const FormatException('Invalid guided timed progress');
    }
  }

  GuidedTimedProgress copyWith(
          {GuidedTimedPhase? phase,
          GuidedTimedPhase? phaseBeforePause,
          GuidedTimedRestKind? restKind,
          List<int>? completedSetActiveMicroseconds,
          int? currentSetActiveMicroseconds,
          int? remainingRestMicroseconds,
          DateTime? startedAt,
          DateTime? updatedAt,
          DateTime? endedAt}) =>
      GuidedTimedProgress(
          runId: runId,
          entryId: entryId,
          entryIndex: entryIndex,
          exerciseId: exerciseId,
          prescription: prescription,
          mediaIdentity: mediaIdentity,
          phase: phase ?? this.phase,
          phaseBeforePause: phaseBeforePause ?? this.phaseBeforePause,
          restKind: restKind ?? this.restKind,
          completedSetActiveMicroseconds: completedSetActiveMicroseconds ??
              this.completedSetActiveMicroseconds,
          currentSetActiveMicroseconds:
              currentSetActiveMicroseconds ?? this.currentSetActiveMicroseconds,
          remainingRestMicroseconds:
              remainingRestMicroseconds ?? this.remainingRestMicroseconds,
          startedAt: startedAt ?? this.startedAt,
          updatedAt: updatedAt ?? this.updatedAt,
          endedAt: endedAt ?? this.endedAt);
  Map<String, dynamic> toJson() => {
        'runId': runId,
        'entryId': entryId,
        'entryIndex': entryIndex,
        'exerciseId': exerciseId,
        'prescription': prescription.toJson(),
        'mediaIdentity': mediaIdentity,
        'completionProvenance': 'timerElapsed',
        'updatedAt': updatedAt.toIso8601String(),
        if (startedAt != null) 'startedAt': startedAt!.toIso8601String(),
        if (endedAt != null) 'endedAt': endedAt!.toIso8601String(),
        'phase': phase.name,
        'phaseBeforePause': phaseBeforePause.name,
        'restKind': restKind.name,
        'completedSetActiveMicroseconds': completedSetActiveMicroseconds,
        'currentSetActiveMicroseconds': currentSetActiveMicroseconds,
        'remainingRestMicroseconds': remainingRestMicroseconds
      };
  factory GuidedTimedProgress.fromJson(Map<String, dynamic> json) {
    const keys = {
      'runId',
      'entryId',
      'entryIndex',
      'exerciseId',
      'prescription',
      'mediaIdentity',
      'completionProvenance',
      'updatedAt',
      'startedAt',
      'endedAt',
      'phase',
      'phaseBeforePause',
      'restKind',
      'completedSetActiveMicroseconds',
      'currentSetActiveMicroseconds',
      'remainingRestMicroseconds'
    };
    try {
      if (json.keys.any((k) => !keys.contains(k)) ||
          json['completionProvenance'] != 'timerElapsed') {
        throw const FormatException();
      }
      final p = Map<String, dynamic>.from(json['prescription'] as Map);
      if (p.keys.any((k) =>
          !const {'sets', 'durationSeconds', 'restSeconds'}.contains(k))) {
        throw const FormatException();
      }
      final target = ExercisePrescription.fromJson(p);
      if (target is! TimedPrescription) throw const FormatException();
      return GuidedTimedProgress(
          runId: json['runId'] as String,
          entryId: json['entryId'] as String,
          entryIndex: json['entryIndex'] as int,
          exerciseId: json['exerciseId'] as String,
          prescription: target,
          mediaIdentity: json['mediaIdentity'] as String,
          updatedAt: DateTime.parse(json['updatedAt'] as String),
          startedAt: json['startedAt'] == null
              ? null
              : DateTime.parse(json['startedAt'] as String),
          endedAt: json['endedAt'] == null
              ? null
              : DateTime.parse(json['endedAt'] as String),
          phase: GuidedTimedPhase.values.byName(json['phase'] as String),
          phaseBeforePause: GuidedTimedPhase.values
              .byName(json['phaseBeforePause'] as String),
          restKind:
              GuidedTimedRestKind.values.byName(json['restKind'] as String),
          completedSetActiveMicroseconds:
              (json['completedSetActiveMicroseconds'] as List).cast<int>(),
          currentSetActiveMicroseconds:
              json['currentSetActiveMicroseconds'] as int,
          remainingRestMicroseconds: json['remainingRestMicroseconds'] as int);
    } catch (_) {
      throw const FormatException('Invalid guided timed progress');
    }
  }
}
