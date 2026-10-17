import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_identity/gainpath_identity.dart';
import 'package:gainpath_mobile/features/identity/presentation/member/activity_level_screen.dart';
import 'package:gainpath_mobile/features/identity/presentation/member/experience_level_screen.dart';
import 'support/fitness_profile_fake.dart' show sampleProfile;

class _Repository implements FitnessProfileRepository {
  @override
  final scope = SessionScope(userId: 'member', organizationId: 'org');
  FitnessProfile profile = sampleProfile();
  final pending = Completer<void>();
  int writes = 0;
  @override
  Future<FitnessProfile?> load() async => profile;
  @override
  Future<void> save(FitnessProfile value) async {
    writes++;
    await pending.future;
    profile = value;
  }
}

void main() {
  for (final experience in [true, false]) {
    testWidgets(
        '${experience ? 'experience' : 'activity'} protects unsaved changes and locks one pending save',
        (tester) async {
      final repository = _Repository();
      final cubit = FitnessProfileCubit(repository);
      await cubit.load();
      addTearDown(cubit.close);
      await tester.pumpWidget(MaterialApp(
          home: Builder(
              builder: (context) => Scaffold(
                  body: TextButton(
                      child: const Text('Open editor'),
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => experience
                                  ? ExperienceLevelScreen(
                                      liveProfile: repository.profile,
                                      liveCubit: cubit)
                                  : ActivityLevelScreen(
                                      liveProfile: repository.profile,
                                      liveCubit: cubit))))))));
      await tester.tap(find.text('Open editor'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(experience ? 'Advanced' : 'Very active'));
      await tester.pump();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Discard unsaved changes?'), findsOneWidget);
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(repository.writes, 1);
      expect(
          tester
              .widget<FilledButton>(
                  find.widgetWithText(FilledButton, 'Saving…'))
              .onPressed,
          isNull);
      await tester.pageBack();
      await tester.pump();
      expect(find.text('Discard unsaved changes?'), findsNothing);
      repository.pending.complete();
      await tester.pumpAndSettle();
      expect(find.text('Open editor'), findsOneWidget);
      expect(repository.writes, 1);
      if (experience) {
        expect(repository.profile.experience, TrainingExperience.advanced);
      } else {
        expect(repository.profile.activity, ActivityLevel.veryActive);
      }
    });
  }
}
