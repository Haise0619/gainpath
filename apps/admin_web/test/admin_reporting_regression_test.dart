import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:gainpath_admin_web/features/analytics/presentation/admin/admin_dashboard_screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_admin_web/features/analytics/application/admin_reporting_cubit.dart';
import 'package:gainpath_admin_web/features/analytics/application/admin_reporting_gateway.dart';

class Gateway implements AdminReportingGateway {
  Completer<AdminReportingSnapshot> response = Completer();
  AdminReportQuery? query;
  @override
  Future<AdminReportingSnapshot> load(AdminReportQuery query) {
    this.query = query;
    return response.future;
  }
}

void main() {
  test('switching report range must not retain the previous range snapshot',
      () async {
    final gateway = Gateway();
    final cubit = AdminReportingCubit(gateway: gateway);
    final first = AdminReportQuery(
        range: DateTimeRange(
            start: DateTime(2026, 10, 1), end: DateTime(2026, 10, 7)));
    final next = AdminReportQuery(
        range: DateTimeRange(
            start: DateTime(2026, 10, 8), end: DateTime(2026, 10, 14)));
    final loadFirst = cubit.load(first);
    gateway.response.complete(AdminReportingSnapshot(
        query: first, capturedAt: DateTime.now(), activeMembersCount: 12));
    await loadFirst;
    gateway.response = Completer();
    final loadNext = cubit.load(next);
    final staleVisible = cubit.state.snapshot != null &&
        cubit.state.snapshot!.query != cubit.state.query;
    gateway.response.completeError(StateError('simulated network failure'));
    await loadNext;
    final staleAfterFailure = cubit.state.snapshot != null &&
        cubit.state.snapshot!.query != cubit.state.query;
    await cubit.close();
    expect(staleVisible, isFalse,
        reason:
            'The UI must not display old-range values under the new filter.');
    expect(staleAfterFailure, isFalse);
  });

  test('closing report while a load is pending must discard its response',
      () async {
    final gateway = Gateway();
    final cubit = AdminReportingCubit(gateway: gateway);
    final query = cubit.state.query;
    final pending = cubit.load(query);
    await cubit.close();
    gateway.response.complete(AdminReportingSnapshot.unavailable(query: query));
    await expectLater(pending, completes);
  });
  testWidgets(
      'dashboard separates session counts from revenue and exposes loading failure retry',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final gateway = Gateway();
    await tester.pumpWidget(RepositoryProvider<AdminReportingGateway>.value(
        value: gateway,
        child: const MaterialApp(home: AdminDashboardScreen(live: true))));
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    final initial = gateway.query!;
    expect(initial.range.start.hour, 0);
    final now = DateTime.now();
    expect(initial.range.start, DateTime(now.year, now.month, now.day));
    gateway.response.complete(
        AdminReportingSnapshot(query: initial, capturedAt: now, revenueTrend: [
      ReportingPoint(date: now, value: 900, label: 'revenue'),
      ReportingPoint(date: now, value: 1200, label: 'revenue')
    ], hourlySessions: [
      ReportingPoint(date: now, value: 3, label: '09'),
      ReportingPoint(date: now, value: 5, label: '10')
    ]));
    await tester.pumpAndSettle();
    expect(tester.widget<BarChart>(find.byType(BarChart)).values, [3, 5]);
    expect(
        tester.widget<TrendChart>(find.byType(TrendChart)).values, [900, 1200]);
    gateway.response = Completer();
    await tester.tap(find.text('Today'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('This week').last);
    await tester.pump();
    expect(tester.widget<BarChart>(find.byType(BarChart)).values, isEmpty);
    expect(tester.widget<TrendChart>(find.byType(TrendChart)).values, isEmpty);
    gateway.response.completeError(StateError('private provider diagnostic'));
    await tester.pumpAndSettle();
    expect(find.text('Retry reports'), findsOneWidget);
    expect(find.textContaining('private provider diagnostic'), findsNothing);
    gateway.response = Completer();
    await tester.tap(find.text('Retry reports'));
    await tester.pump();
    gateway.response
        .complete(AdminReportingSnapshot.unavailable(query: gateway.query!));
    await tester.pumpAndSettle();
    expect(find.text('Retry reports'), findsNothing);
    expect(tester.widget<BarChart>(find.byType(BarChart)).values, isEmpty);
    expect(tester.widget<TrendChart>(find.byType(TrendChart)).values, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
