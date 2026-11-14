import 'package:firebase_auth/firebase_auth.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import '../../features/recommendation/application/member_recommendation_repository.dart';
import '../../features/recommendation/application/recommendation_consent_repository.dart';
import 'firebase_app_check_readiness.dart';
import 'firebase_function_transport.dart';

typedef RecommendationCallable = Future<Object?> Function(
    Map<String, Object?> envelope);

/// Client visibility and server admission are independent gates. No dataset fallback.
class FirebaseMemberRecommendations {
  FirebaseMemberRecommendations(
      {required this.scope,
      required bool Function() isCurrent,
      this.enabled =
          const bool.fromEnvironment('GAINPATH_RECOMMENDATIONS_ENABLED'),
      String? Function()? currentUid,
      RecommendationCallable? invoke,
      FirebaseAppCheckReadiness? readiness})
      : _current = isCurrent,
        _uid = currentUid ?? (() => FirebaseAuth.instance.currentUser?.uid),
        _invoke = invoke ??
            ((envelope) async =>
                (await firebaseScopedCallable(scope, 'module13MemberCommand')
                        .call<Object?>(envelope))
                    .data),
        _readiness = readiness ?? FirebaseAppCheckReadiness.instance {
    recommendation = enabled
        ? RpcMemberRecommendationRepository(
            scope: scope,
            isCurrent: _isCurrent,
            fixtureOnly: false,
            invoke: (data) async {
              final result =
                  _map(await call('member.recommendation.command', data));
              if (result['mode'] != 'accepted_workout') {
                throw const FormatException('Invalid recommendation source');
              }
              return result;
            })
        : UnavailableMemberRecommendationRepository(scope);
    consent = RpcRecommendationConsentRepository(
        scope: scope,
        isCurrent: _isCurrent,
        read: (data) async {
          final result = await call('member.consent.get', data);
          return result == null ? null : _map(result);
        },
        command: (data) async => _map(await call('member.consent.set', data)));
  }

  final SessionScope scope;
  final bool enabled;
  final bool Function() _current;
  final String? Function() _uid;
  final RecommendationCallable _invoke;
  final FirebaseAppCheckReadiness _readiness;
  late final MemberRecommendationRepository recommendation;
  late final RecommendationConsentRepository consent;

  bool _isCurrent() => _current() && _uid() == scope.userId;
  void _check() {
    if (!enabled || scope.datasetScope != null || !_isCurrent()) {
      throw const MemberRecommendationUnavailable();
    }
  }

  Future<Object?> call(String operation, Map<String, Object?> data) async {
    _check();
    if (!await _readiness.ensureReady(check: _check)) {
      throw const MemberRecommendationUnavailable();
    }
    _check();
    final response = await _invoke({
      'schemaVersion': 1,
      'operation': operation,
      'data': {...data, 'organizationId': scope.organizationId}
    });
    _check();
    return response;
  }

  Future<MemberRecommendationPage> loadPage(
      {required bool history, String? afterId}) async {
    if (!enabled) {
      return const MemberRecommendationPage(records: [], enabled: false);
    }
    final response = _map(await call('member.recommendation.list', {
      'schemaVersion': 1,
      'history': history,
      'afterId': afterId,
    }));
    if (response['schemaVersion'] != 1 ||
        response['mode'] != 'accepted_workout' ||
        response['organizationId'] != scope.organizationId ||
        response['enabled'] is! bool ||
        response['recommendations'] is! List ||
        (response['recommendations'] as List).length > 25 ||
        response['nextAfterId'] != null && response['nextAfterId'] is! String) {
      throw const FormatException('Invalid recommendation page');
    }
    final records = <MemberRecommendationDetail>[];
    for (final row in response['recommendations'] as List) {
      final data = _map(row);
      if (data['mode'] != 'accepted_workout' ||
          data['recommendationId'] is! String) {
        throw const FormatException('Invalid recommendation scope');
      }
      final detail = MemberRecommendationDetail.parse(
          data, scope.organizationId, data['recommendationId'] as String);
      if (detail.deliveredAt == null ||
          detail.state.name == 'notDelivered' ||
          records.any((r) => r.recommendationId == detail.recommendationId)) {
        throw const FormatException('Invalid delivered recommendation');
      }
      records.add(detail);
    }
    if (response['enabled'] == false && records.isNotEmpty) {
      throw const FormatException('Disabled recommendation data');
    }
    return MemberRecommendationPage(
        records: List.unmodifiable(records),
        nextAfterId: response['nextAfterId'] as String?,
        enabled: response['enabled'] as bool);
  }

  Future<RecommendationConsentNotice?> notice() async {
    if (!enabled) return null;
    final raw = _map(await call('member.consent.notice', {'schemaVersion': 1}));
    if (raw['schemaVersion'] != 1 ||
        raw['organizationId'] != scope.organizationId ||
        raw['demoData'] != false) {
      throw const FormatException('Invalid personalization notice');
    }
    String text(String key) {
      final value = raw[key];
      if (value is! String || value.trim().isEmpty || value.length > 1200) {
        throw const FormatException('Invalid personalization notice');
      }
      return value;
    }

    return RecommendationConsentNotice(
        policyId: text('policyId'),
        noticeVersion: text('noticeVersion'),
        contentVersion: text('contentVersion'),
        historyDescription: text('historyDescription'),
        fictional: false);
  }
}

Map<String, Object?> _map(Object? value) {
  if (value is! Map) {
    throw const FormatException('Invalid recommendation response');
  }
  return Map<String, Object?>.from(value);
}
