import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_domain/identity.dart';

/// No pending Coach reviews in composition and responsive layout tests.
class EmptyCoachDirectoryRepository extends Fake
    implements CoachProfileAdminRepository {
  EmptyCoachDirectoryRepository(this.scope);

  @override
  final SessionScope scope;

  @override
  Future<bool> canManageDirectory() async => true;

  @override
  Future<CoachDirectoryPage<CoachProfessionalProfile>> loadDraftPage(
          {String? afterId}) async =>
      CoachDirectoryPage(const []);

  @override
  Future<CoachDirectoryPage<PublishedCoachProfile>> loadPublicPage(
          {String? afterId}) async =>
      CoachDirectoryPage(const []);
}
