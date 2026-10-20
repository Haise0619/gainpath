import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_mobile/features/identity/application/coach_profile_cubit.dart';

CoachProfessionalFields fields(String bio) => CoachProfessionalFields(
    displayName: 'Coach',
    specialty: 'Strength',
    bio: bio,
    specializationTags: ['Strength'],
    yearsExperience: null);

class ProfileFake implements CoachProfileRepository {
  @override
  final scope = SessionScope(userId: 'coach', organizationId: 'o');
  CoachProfessionalProfile? profile;
  Completer<CoachProfessionalProfile?>? pending;
  String? failure;
  final requests = <String>[];
  @override
  Future<CoachProfessionalProfile?> loadOwn() async =>
      pending != null ? pending!.future : profile;
  @override
  Future<PublishedCoachProfile?> loadOwnPublication() async => null;
  @override
  Future<CoachCommandResult> save(
      {required int expectedRevision,
      required CoachProfilePatch patch,
      required String requestId}) async {
    requests.add(requestId);
    if (failure != null) throw CoachRepositoryException(failure!);
    profile = CoachProfessionalProfile(
        id: 'coach',
        fields: CoachProfessionalFields.fromJson(
            {...?profile?.fields.toJson(), ...patch.toJson()}),
        revision: expectedRevision + 1,
        createdAtMillis: 1,
        updatedAtMillis: 2);
    return CoachCommandResult(
        requestId: requestId,
        coachId: 'coach',
        revision: profile!.revision,
        outcome: 'saved');
  }
}

void main() {
  test(
      'save/retry preserves intent ID; conflict disables save until explicit reload',
      () async {
    final repo = ProfileFake();
    final controller =
        CoachProfileCubit(repository: repo, isCurrent: () => true);
    await controller.reload();
    repo.failure = 'unavailable';
    await controller.save(fields('Bio'));
    await controller.save(fields('Bio'));
    expect(repo.requests[0], repo.requests[1]);
    repo.failure = 'aborted';
    await controller.save(fields('Bio'));
    expect(controller.state.conflict, isTrue);
    final count = repo.requests.length;
    await controller.save(fields('Changed'));
    expect(repo.requests.length, count);
    repo.failure = null;
    await controller.reload();
    await controller.save(fields('Fresh'));
    expect(repo.profile!.fields.bio, 'Fresh');
    repo.failure = 'permission-denied';
    await controller.save(fields('Unauthorized'));
    expect(controller.state.status, CoachProfileStatus.unavailable);
    expect(controller.state.profile, isNull);
    await controller.close();
  });
  test('late previous account read cannot restore a profile', () async {
    var current = true;
    final repo = ProfileFake()..pending = Completer();
    final cubit = CoachProfileCubit(repository: repo, isCurrent: () => current);
    final read = cubit.reload();
    current = false;
    cubit.invalidate();
    repo.pending!.complete(CoachProfessionalProfile(
        id: 'coach',
        fields: fields('old'),
        revision: 1,
        createdAtMillis: 1,
        updatedAtMillis: 2));
    await read;
    expect(cubit.state.profile, isNull);
    expect(cubit.state.status, CoachProfileStatus.unavailable);
    await cubit.close();
  });
}
