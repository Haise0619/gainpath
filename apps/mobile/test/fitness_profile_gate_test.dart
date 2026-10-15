import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_domain/identity.dart' show MemberProfileRepository;
import 'package:gainpath_identity/gainpath_identity.dart';
import 'package:gainpath_mobile/features/identity/presentation/member/fitness_profile_gate.dart';

import 'support/fitness_profile_fake.dart';

void main() {
  const first = AuthSession(
      userId: 'one', email: 'one@example.com', role: AppRole.member);
  const second = AuthSession(
      userId: 'two', email: 'two@example.com', role: AppRole.member);

  testWidgets('ready content edits through the account-owned profile providers',
      (tester) async {
    final profiles = FakeProfileGateway();
    await profiles.repository(first.scope).save(sampleProfile());
    FitnessProfileCubit? cubit;
    await tester.pumpWidget(MaterialApp(
      home: FitnessProfileGate(
        session: first,
        repository: profiles.repository(first.scope),
        readyBuilder: (context, profile) {
          cubit = context.read<FitnessProfileCubit>();
          final member = context.read<MemberProfileRepository>();
          return Scaffold(
            body: Text(
                '${member.memberEmail}: ${member.memberWeight}/${profile.weightKg}'),
          );
        },
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('one@example.com: 65/65'), findsOneWidget);

    profiles.pendingWrite = Completer<void>();
    final save = cubit!.save(cubit!.state.profile!.copyWith(weightKg: 66));
    await tester.pump();
    expect(find.text('one@example.com: 65/65'), findsOneWidget);
    profiles.pendingWrite!.complete();
    await save;
    await tester.pumpAndSettle();
    expect(find.text('one@example.com: 66/66'), findsOneWidget);
    expect((await profiles.repository(first.scope).load())!.weightKg, 66);

    await tester.pumpWidget(const SizedBox());
    expect(cubit!.isClosed, isTrue);
  });

  testWidgets(
      'replacing the account closes its cubit and loads the new profile',
      (tester) async {
    final profiles = FakeProfileGateway();
    await profiles.repository(first.scope).save(sampleProfile());
    await profiles
        .repository(second.scope)
        .save(sampleProfile().copyWith(weightKg: 72));
    final cubits = <FitnessProfileCubit>[];
    Future<void> mount(AuthSession session) async {
      await tester.pumpWidget(MaterialApp(
        home: FitnessProfileGate(
          key: ValueKey(session.scope),
          session: session,
          repository: profiles.repository(session.scope),
          readyBuilder: (context, profile) {
            cubits.add(context.read<FitnessProfileCubit>());
            final member = context.read<MemberProfileRepository>();
            return Scaffold(
                body: Text('${member.memberEmail}: ${profile.weightKg}'));
          },
        ),
      ));
      await tester.pumpAndSettle();
    }

    await mount(first);
    final firstCubit = cubits.last;
    expect(find.text('one@example.com: 65'), findsOneWidget);
    await mount(second);
    expect(firstCubit.isClosed, isTrue);
    expect(find.text('one@example.com: 65'), findsNothing);
    expect(find.text('two@example.com: 72'), findsOneWidget);
    expect(cubits.last.repository.scope, second.scope);

    await tester.pumpWidget(const SizedBox());
    expect(cubits.last.isClosed, isTrue);
  });
}
