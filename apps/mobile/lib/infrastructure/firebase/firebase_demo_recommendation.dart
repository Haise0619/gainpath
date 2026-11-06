import 'firebase_demo_emulator_transport.dart';
import 'dart:convert';
import 'package:gainpath_domain/analytics.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:gainpath_data/gainpath_data.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_domain/identity.dart';
import '../../features/recommendation/application/member_recommendation_repository.dart';
import '../../features/recommendation/application/recommendation_consent_repository.dart';
import '../../features/workout/domain/published_routine_catalog_repository.dart';
import '../../features/workout/domain/published_routine_view.dart';
import '../../features/workout/domain/workout_contracts.dart'
    show WorkoutSessionSummary;
import 'firebase_module9_repository.dart' show parseMemberNotice;

Module13DemoTransport createFirebaseDemoMemberTransport(
    {required AuthSession session,
    required bool Function() isCurrent,
    required FirebaseAuth auth,
    required FirebaseFirestore firestore,
    required FirebaseFunctions functions,
    required bool emulator,
    Future<bool> Function()? appCheckReady}) {
  final binding = Module13DemoBinding(
      projectId: firestore.app.options.projectId,
      databaseId: firestore.databaseId,
      emulator: emulator);
  if (!binding.isValid ||
      session.role != AppRole.member ||
      firestore.app.name != auth.app.name ||
      auth.app.name != functions.app.name) {
    throw const Module13DemoUnavailable();
  }
  return Module13DemoTransport(
      scope: session.scope,
      role: session.role,
      isCurrent: isCurrent,
      currentUid: () => auth.currentUser?.uid,
      emailVerified: () => auth.currentUser?.emailVerified == true,
      appCheckReady: appCheckReady ??
          () async =>
              emulator ||
              (await FirebaseAppCheck.instanceFor(app: auth.app).getToken())
                      ?.isNotEmpty ==
                  true,
      invoke: emulator
          ? demoEmulatorInvoke(auth)
          : (name, request) async => (await functions
                  .httpsCallable(name,
                      options: HttpsCallableOptions(
                          timeout: const Duration(seconds: 60)))
                  .call<Object?>(request))
              .data);
}

class FirebaseDemoMemberRepositories {
  FirebaseDemoMemberRepositories(this.transport) {
    recommendation = RpcMemberRecommendationRepository(
        scope: transport.scope,
        isCurrent: () => transport.isCurrent,
        invoke: (data) => transport.map('member.recommendation.command', data));
    consent = RpcRecommendationConsentRepository(
        scope: transport.scope,
        isCurrent: () => transport.isCurrent,
        read: (data) async {
          final raw = await transport.call('member.consent.get', data);
          if (raw == null) {
            return null;
          }
          if (raw is! Map) {
            throw const RecommendationConsentUnavailable();
          }
          return Map<String, Object?>.from(raw);
        },
        command: (data) => transport.map('member.consent.set', data));
    inbox = FirebaseDemoInboxRepository(transport);
    directory = FirebaseDemoCoachDirectory(transport);
    catalog = FirebaseDemoTutorialCatalog(transport);
  }
  final ScopedCommandTransport transport;
  late final MemberRecommendationRepository recommendation;
  late final RecommendationConsentRepository consent;
  late final Module9Repository inbox;
  late final CoachDirectoryRepository directory;
  late final PublishedRoutineCatalogRepository catalog;
  Map<String, Object?> get _scope =>
      {'schemaVersion': 1, 'organizationId': transport.scope.organizationId};
  Future<Map<String, Object?>> access() =>
      transport.map('session.access', _scope);
  Future<RecommendationConsentNotice> notice() async {
    final raw = await transport.map('member.consent.notice', _scope);
    const keys = {
      'schemaVersion',
      'organizationId',
      'policyId',
      'noticeVersion',
      'contentVersion',
      'historyDescription',
      'demoData'
    };
    if (raw.length != keys.length ||
        !raw.keys.toSet().containsAll(keys) ||
        raw['schemaVersion'] != 1 ||
        raw['organizationId'] != transport.scope.organizationId ||
        raw['demoData'] != true) {
      throw const FormatException('Unrecognized reviewed demo notice.');
    }
    String text(String key, int max) {
      final value = raw[key];
      if (value is! String ||
          value.trim().isEmpty ||
          value.length > max ||
          RegExp(r'[\x00-\x1f\x7f]').hasMatch(value)) {
        throw const FormatException('Invalid notice.');
      }
      return value;
    }

    String id(String key) {
      final value = text(key, 128);
      if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(value)) {
        throw const FormatException('Invalid notice version.');
      }
      return value;
    }

    return RecommendationConsentNotice(
        policyId: id('policyId'),
        noticeVersion: id('noticeVersion'),
        contentVersion: id('contentVersion'),
        historyDescription: text('historyDescription', 1200));
  }

  Future<Map<String, Object?>> workoutHistory(
          {String? afterKey, required bool backupConsented}) =>
      transport.map('member.workoutHistory', {
        ..._scope,
        'afterKey': afterKey,
        'backupConsented': backupConsented
      });

  /// Read-only projection of owned validated backups into the existing timeline.
  /// Unknown upload status never implies an accepted physical capture or points.
  Future<MemberLocalProgress> loadWorkoutProgress() async {
    final records = <LocalWorkoutProgressRecord>[], seen = <String, String>{};
    String? cursor;
    for (var page = 0; page < 40; page++) {
      final response =
          await workoutHistory(afterKey: cursor, backupConsented: true);
      if (response['schemaVersion'] != 1 ||
          response['records'] is! List ||
          (response['records'] as List).length > 3) {
        throw const FormatException('Invalid owned history page.');
      }
      for (final value in response['records'] as List) {
        if (value is! Map ||
            value['kind'] != 'session' ||
            value['payload'] is! Map) {
          throw const FormatException('Unsupported demo history record.');
        }
        final summary = WorkoutSessionSummary.fromJson(
            Map<String, Object?>.from(value['payload'] as Map));
        if (summary.scope != transport.scope || summary.poseMetrics == null) {
          throw const FormatException('Invalid history ownership.');
        }
        final serialized = jsonEncode(summary.toJson()),
            prior = seen[summary.sessionId];
        if (prior != null) {
          if (prior != serialized) {
            throw const FormatException('Conflicting session revisions.');
          }
          continue;
        }
        seen[summary.sessionId] = serialized;
        final metrics = summary.poseMetrics!;
        records.add(LocalWorkoutProgressRecord(
            scope: transport.scope,
            sessionId: summary.sessionId,
            exerciseId: summary.exerciseId,
            startedAt: summary.startedAt,
            endedAt: summary.endedAt,
            repetitions: summary.repetitions,
            partialRepetitions: summary.partialRepetitions,
            trackedDurationMicros: summary.trackedDurationMicros,
            rejectedDurationMicros: summary.rejectedDurationMicros,
            formScorePercent: summary.formScorePercent,
            scoringVersion: metrics.scoringVersion,
            detectorId: metrics.detectorId,
            detectorVersion: metrics.detectorVersion,
            cameraView: metrics.cameraView,
            status: LocalWorkoutRecordStatus.unknown));
      }
      final next = response['nextCursor'];
      if (next == null) {
        return calculateLocalMemberProgress(
            scope: transport.scope,
            records: records,
            asOf: DateTime.now().toUtc());
      }
      if (next is! String ||
          next == cursor ||
          !RegExp(r'^(routines|(?:session|routine)-[A-Za-z0-9_-]{1,128})$')
              .hasMatch(next)) {
        throw const FormatException('Invalid history cursor.');
      }
      cursor = next;
    }
    throw const Module13DemoUnavailable();
  }
}

class FirebaseDemoInboxRepository implements Module9Repository {
  FirebaseDemoInboxRepository(this.transport);
  final ScopedCommandTransport transport;
  @override
  Stream<void> watchInbox() => const Stream.empty();
  @override
  Future<NoticePage> loadInbox({String? afterId}) async {
    final raw = await transport.map('member.inbox', {
      'schemaVersion': 1,
      'organizationId': transport.scope.organizationId,
      if (afterId != null) 'afterId': afterId
    });
    if (raw['schemaVersion'] != 1 ||
        raw['records'] is! List ||
        (raw['records'] as List).length > 30 ||
        raw['nextAfterId'] != null && raw['nextAfterId'] is! String) {
      throw const FormatException('Invalid owned inbox.');
    }
    return NoticePage(
        (raw['records'] as List)
            .map((r) => parseMemberNotice(r, transport.scope.organizationId))
            .toList(),
        raw['nextAfterId'] as String?);
  }

  @override
  Future<void> markRead(String id) async {
    if (transport.scope.datasetScope == null) {
      throw const Module13DemoUnavailable();
    }
    final result = await transport.map('module/module9MemberCommandCallable', {
      'schemaVersion': 1,
      'organizationId': transport.scope.organizationId,
      'action': 'readNotification',
      'notificationId': id,
    });
    if (result['schemaVersion'] != 1) {
      throw const FormatException('Invalid notification acknowledgement.');
    }
  }
  @override
  Future<CoachSharing> loadSharing() =>
      Future.error(const Module13DemoUnavailable());
  @override
  Future<CoachSharing> saveSharing(bool enabled, int expectedRevision) =>
      Future.error(const Module13DemoUnavailable());
  @override
  Future<CoachReport> loadPerformance() =>
      Future.error(const Module13DemoUnavailable());
}

class FirebaseDemoCoachDirectory implements CoachDirectoryRepository {
  FirebaseDemoCoachDirectory(this.transport);
  final ScopedCommandTransport transport;
  @override
  SessionScope get scope => transport.scope;
  @override
  Future<PublishedCoachProfile?> loadPublished(String id) async {
    final raw = await transport.map('member.coach', {
      'schemaVersion': 1,
      'organizationId': scope.organizationId,
      'coachId': id
    });
    return PublishedCoachProfile.fromDocument(
        id, Map<String, dynamic>.from(raw));
  }

  @override
  Future<CoachDirectoryPage<PublishedCoachProfile>> loadPage(
          {String? afterId}) =>
      Future.error(const Module13DemoUnavailable());
}

class FirebaseDemoTutorialCatalog implements PublishedRoutineCatalogRepository {
  FirebaseDemoTutorialCatalog(this.transport);
  final ScopedCommandTransport transport;
  @override
  SessionScope get scope => transport.scope;
  @override
  Future<PublishedRoutine?> loadById(String id) async =>
      PublishedRoutine.fromDocument(
          id,
          Map<String, dynamic>.from(await transport.map('member.routine', {
            'schemaVersion': 1,
            'organizationId': scope.organizationId,
            'routineId': id
          })));
  @override
  Future<PublishedRoutinePage> loadPage({String? afterId}) =>
      Future.error(const Module13DemoUnavailable());
}
