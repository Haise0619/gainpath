import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_data/gainpath_data.dart';
import 'package:gainpath_identity/gainpath_identity.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_mobile/features/gamification/application/app_check_in_cubit.dart';
import 'package:gainpath_mobile/features/gamification/domain/app_check_in.dart';
import 'package:gainpath_mobile/features/gamification/presentation/member/app_check_in_dashboard.dart';
import 'package:gainpath_mobile/app/routing/member_points_progress_route.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_check_in_test.dart' show snapshotJson;

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  testWidgets('Rewards opens live check-in route with account guard',
      (t) async {
    final auth = AuthBloc(repository: InMemoryAuthRepository());
    final scope = SessionScope(userId: 'member', organizationId: 'gainpath');
    await t.pumpWidget(BlocProvider.value(
        value: auth,
        child: MaterialApp(
            home: AppCheckInDashboard(
                state: AppCheckInState(
                    status: AppCheckInStatus.ready,
                    snapshot: AppCheckInSnapshot.fromJson(
                        snapshotJson(scope), scope)),
                onClaim: () async {},
                onRefresh: () async {}))));
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Rewards & Check-in'));
    await t.pumpAndSettle();
    await t.tap(find.text('Rewards & Check-in'));
    await t.pumpAndSettle();
    expect(find.byType(LivePointsProgress), findsOneWidget);
    expect(find.textContaining('Sign in'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    await t.runAsync(auth.close);
  });
}
