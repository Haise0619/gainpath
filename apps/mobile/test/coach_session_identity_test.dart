import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_identity/gainpath_identity.dart';
import 'package:gainpath_mobile/navigation/session_host.dart';
import 'coach_directory_flow_test.dart' show DriftingCoachAuth;

void main() {
  testWidgets('value-equal replacement invalidates old Coach scope permanently',
      (tester) async {
    final original = AuthSession(
        userId: 'coach',
        organizationId: 'org',
        email: 'coach@example.test',
        role: AppRole.coach);
    final replacement = AuthSession(
        userId: 'coach',
        organizationId: 'org',
        email: 'coach@example.test',
        role: AppRole.coach);
    expect(original, replacement);
    expect(identical(original, replacement), isFalse);
    final repository = DriftingCoachAuth(original);
    final active = AuthBloc(repository: repository)
      ..add(const AuthRestoreRequested());
    bool Function()? current;
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await tester.pump();
    // Mount only after the initial authoritative restore has completed.
    await tester.pumpWidget(BlocProvider.value(
        value: active,
        child: MaterialApp(
            home: CoachSessionHost(
                session: original,
                builder: (_, check) {
                  current = check;
                  return const Text('Private Coach state');
                }))));
    expect(current!(), isTrue);
    repository.drift(replacement);
    await tester.pump();
    await tester.pump();
    expect(current!(), isFalse);
    expect(find.text('Private Coach state'), findsNothing);
    repository.drift(original);
    await tester.pump();
    await tester.pump();
    expect(current!(), isFalse);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await tester.runAsync(() async {
      await active.close();
      await repository.dispose();
    });
  });
}
