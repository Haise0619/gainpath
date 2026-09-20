import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_data/gainpath_data.dart';
import 'package:gainpath_identity/gainpath_identity.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show AppRole;
import 'package:gainpath_mobile/app/routing/workout_route.dart';
import 'package:gainpath_mobile/features/workout/data/workout_session_repository.dart';

void main() {
  testWidgets('workout route saves into the authenticated account store',
      (tester) async {
    late AuthBloc auth;
    await tester.runAsync(() async {
      auth = AuthBloc(repository: InMemoryAuthRepository());
      await Future<void>.delayed(Duration.zero);
      auth.add(const RoleSelected(AppRole.member));
      auth.add(const LoginSubmitted(
          email: 'member@example.com', password: 'password123'));
      await auth.stream
          .firstWhere((state) => state.status == AuthStatus.signedIn)
          .timeout(const Duration(seconds: 5));
    });
    final store = InMemoryWorkoutSessionStore(scope: auth.state.session!.scope);
    await tester.pumpWidget(BlocProvider.value(
        value: auth,
        child: MaterialApp(
          home: WorkoutRoute(storeFactory: (_) async => store),
        )));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Guided workout'), findsOneWidget);
    await tester.tap(find.text('Finish and save locally'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final records = await store.read();
    expect(records.single.summary.scope, auth.state.session!.scope);
    expect(records.single.status, WorkoutSyncStatus.pending);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() => auth.close());
  });
}
