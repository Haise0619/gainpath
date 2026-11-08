import 'package:gainpath_domain/identity.dart';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_mobile/features/identity/presentation/coach/coach_account_screen.dart';
import 'package:gainpath_mobile/features/identity/presentation/coach/coach_public_profile_preview.dart';
import 'support/coach_account_gateway_fake.dart';
import 'coach_profile_state_test.dart' show ProfileFake;
import 'coach_shared_account_test.dart' show draft, frame;

class SlowPhotoAccount extends CoachAccountGatewayFake {
  final photo = Completer<Uint8List?>();
  int reads = 0;
  @override
  Future<Uint8List?> loadProfilePhoto(String? path) {
    reads++;
    return photo.future;
  }
}

class PublishedPhotoProfile extends ProfileFake {
  @override
  Future<PublishedCoachProfile?> loadOwnPublication() async =>
      PublishedCoachProfile(
          id: 'coach',
          fields: CoachProfessionalFields(
              displayName: 'Published Coach',
              specialty: 'Strength',
              bio: 'Published bio',
              specializationTags: ['Strength'],
              yearsExperience: 2,
              photoPath: 'orgs/o/coachProfilePhotos/coach/${'b' * 32}'),
          revision: 1,
          sourceRevision: 1,
          status: 'published',
          branchIds: ['main'],
          createdAtMillis: 1,
          updatedAtMillis: 1,
          publishedAtMillis: 1);
}

class SlowPublishedPhoto extends CoachAccountGatewayFake {
  final published = Completer<Uint8List?>();
  int publicReads = 0;
  @override
  Future<Uint8List?> loadProfilePhoto(String? path) {
    if (path?.endsWith('b' * 32) == true) {
      publicReads++;
      return published.future;
    }
    return Future.value(null);
  }
}

void main() {
  testWidgets(
      'preview opens before slow avatar completes and shows photo progress',
      (t) async {
    final account = SlowPhotoAccount();
    await t.pumpWidget(frame(CoachAccountScreen(
        profileRepository: ProfileFake()
          ..profile =
              draft(path: 'orgs/o/coachProfilePhotos/coach/${'a' * 32}'),
        accountRepository: account)));
    await t.pump();
    await t.pump();
    await t.tap(find.text('Preview public profile'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    expect(find.byType(CoachPublicProfilePreview), findsOneWidget);
    expect(find.byKey(const Key('preview-photo-loading')), findsOneWidget);
    expect(account.reads, 1);
    account.photo.complete(null);
    await t.pumpAndSettle();
    expect(find.byKey(const Key('preview-photo-loading')), findsNothing);
    expect(find.byKey(const Key('preview-photo-fallback')), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets('leaving preview while photo loads never reopens it', (t) async {
    final account = SlowPhotoAccount();
    await t.pumpWidget(frame(CoachAccountScreen(
        profileRepository: ProfileFake()
          ..profile =
              draft(path: 'orgs/o/coachProfilePhotos/coach/${'a' * 32}'),
        accountRepository: account)));
    await t.pump();
    await t.pump();
    await t.tap(find.text('Preview public profile'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    expect(find.byType(CoachPublicProfilePreview), findsOneWidget);
    await t.pageBack();
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    account.photo.complete(null);
    await t.pumpAndSettle();
    expect(find.byType(CoachPublicProfilePreview), findsNothing);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets(
      'slow published photo does not block preview or replace draft avatar',
      (t) async {
    final account = SlowPublishedPhoto();
    await t.pumpWidget(frame(CoachAccountScreen(
        profileRepository: PublishedPhotoProfile()
          ..profile =
              draft(path: 'orgs/o/coachProfilePhotos/coach/${'a' * 32}'),
        accountRepository: account)));
    await t.pump();
    await t.pump();
    await t.tap(find.text('Preview public profile'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    expect(find.byType(CoachPublicProfilePreview), findsOneWidget);
    expect(find.byKey(const Key('preview-photo-loading')), findsOneWidget);
    expect(account.publicReads, 1);
    await t.tap(find.widgetWithText(ChoiceChip, 'Draft version'));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('preview-photo-loading')), findsNothing);
    account.published.complete(null);
    await t.pumpAndSettle();
    expect(
        t
            .widget<CoachPublicProfilePreview>(
                find.byType(CoachPublicProfilePreview))
            .profile
            .fields
            .displayName,
        'Actual Coach');
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });
}
