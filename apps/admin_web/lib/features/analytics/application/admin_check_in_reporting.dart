import 'admin_observed_activity.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'admin_reporting_gateway.dart';
import 'admin_engagement_extension.dart';

abstract interface class AdminCheckInReportingGateway {
  Future<AdminCheckInReport> loadCheckIns(AdminReportQuery query);
}

class AdminCheckInReportException implements Exception {
  const AdminCheckInReportException(this.message);
  final String message;
}

class CheckInReportPeriod {
  const CheckInReportPeriod(
      {required this.date,
      required this.claims,
      required this.claimingMembers,
      required this.pointsAwarded});
  final String date;
  final int claims, claimingMembers, pointsAwarded;
}

class AdminCheckInReport {
  AdminCheckInReport(
      {required this.query,
      required this.scanStartedAt,
      required this.capturedAt,
      required this.asOfDate,
      required this.claims,
      required this.claimingMembers,
      required this.pointsAwarded,
      this.extensions,
      this.observations,
      required Map<String, int> coverage,
      required List<CheckInReportPeriod> daily,
      required List<CheckInReportPeriod> weekly,
      required Map<String, int> currentStreaks,
      required Map<String, int> longestStreaks})
      : coverage = Map.unmodifiable(coverage),
        daily = List.unmodifiable(daily),
        weekly = List.unmodifiable(weekly),
        currentStreaks = Map.unmodifiable(currentStreaks),
        longestStreaks = Map.unmodifiable(longestStreaks);
  static const policyVersion = 'app-check-in-v1', pointsPerClaim = 50;
  static const streakLabels = {
    'zero': '0 days',
    'oneTwo': '1–2 days',
    'threeSix': '3–6 days',
    'sevenPlus': '7+ days'
  };
  final AdminObservedActivity? observations;
  final AdminEngagementExtension? extensions;
  final AdminReportQuery query;
  final DateTime scanStartedAt, capturedAt;
  final String asOfDate;
  final int claims, claimingMembers, pointsAwarded;
  final Map<String, int> coverage, currentStreaks, longestStreaks;
  final List<CheckInReportPeriod> daily, weekly;
  List<List<Object?>> toCsv() => [
        [
          extensions == null
              ? 'GainPath app check-in analytics'
              : 'GainPath gamification engagement analytics',
          policyVersion
        ],
        ['Timezone', 'Asia/Kuala_Lumpur UTC+08:00'],
        ['Start inclusive UTC', query.range.start.toUtc().toIso8601String()],
        ['End exclusive UTC', query.range.end.toUtc().toIso8601String()],
        ['Source scan started UTC', scanStartedAt.toIso8601String()],
        ['Captured UTC', capturedAt.toIso8601String()],
        [
          'Basis',
          'Server-confirmed app check-in receipts for current canonical active Members. Not gym attendance, games, wallet balances or redemption.'
        ],
        ['Policy points per claim', pointsPerClaim],
        ['Claims in selected range', claims],
        ['Unique claiming Members in selected range', claimingMembers],
        ['Points awarded in selected range', pointsAwarded],
        ['Current cohort', 'Count'],
        for (final e in coverage.entries) [e.key, e.value],
        [],
        ['Malaysia day', 'Claims', 'Unique claiming Members', 'Points awarded'],
        for (final d in daily)
          [d.date, d.claims, d.claimingMembers, d.pointsAwarded],
        [],
        [
          'Malaysia week starting Monday (selected dates only)',
          'Claims',
          'Distinct claiming Members',
          'Points awarded'
        ],
        for (final w in weekly)
          [w.date, w.claims, w.claimingMembers, w.pointsAwarded],
        [],
        [
          'Streak scope',
          'Current as of',
          asOfDate,
          'All-time history of current active Members; unaffected by selected dates'
        ],
        ['Streak length', 'Current Members', 'Longest-ever Members'],
        for (final e in streakLabels.entries)
          [e.value, currentStreaks[e.key], longestStreaks[e.key]],
        [
          'Read consistency',
          'Complete bounded reads over a disclosed interval, not one atomic organization snapshot.'
        ],
        if (extensions != null) ...extensions!.engagementCsv(),
      ];
}

class AdminCheckInReportingState {
  const AdminCheckInReportingState(
      {required this.query, this.report, this.loading = false, this.error});
  final AdminReportQuery query;
  final AdminCheckInReport? report;
  final bool loading;
  final String? error;
}

class AdminCheckInReportingCubit extends Cubit<AdminCheckInReportingState> {
  AdminCheckInReportingCubit(
      {required this.gateway, required AdminReportQuery query})
      : super(AdminCheckInReportingState(query: query));
  final AdminCheckInReportingGateway gateway;
  int _generation = 0;
  Future<void> load([AdminReportQuery? target]) async {
    if (isClosed) return;
    final query = target ?? state.query, generation = ++_generation;
    final retained = query == state.query &&
            (gateway is! AdminReportingSessionGuard ||
                (gateway as AdminReportingSessionGuard).canRetainSnapshot)
        ? state.report
        : null;
    emit(AdminCheckInReportingState(
        query: query, report: retained, loading: true));
    try {
      final report = await gateway.loadCheckIns(query);
      if (isClosed || generation != _generation) return;
      if (gateway is AdminReportingSessionGuard &&
          !(gateway as AdminReportingSessionGuard).canRetainSnapshot) {
        throw StateError('Reporting account changed');
      }
      if (report.query != query) {
        throw const FormatException('Check-in report query mismatch');
      }
      emit(AdminCheckInReportingState(query: query, report: report));
    } catch (e) {
      if (isClosed || generation != _generation) return;
      emit(AdminCheckInReportingState(
          query: query,
          report: (e is AdminReportingException && e.invalidatesSnapshot) ||
                  e is StateError ||
                  e is FormatException ||
                  (gateway is AdminReportingSessionGuard &&
                      !(gateway as AdminReportingSessionGuard)
                          .canRetainSnapshot)
              ? null
              : retained,
          error: e is AdminReportingException
              ? e.message
              : e is AdminCheckInReportException
                  ? e.message
                  : 'Could not load check-in analytics. Check your connection and retry.'));
    }
  }

  @override
  Future<void> close() {
    _generation++;
    return super.close();
  }
}
