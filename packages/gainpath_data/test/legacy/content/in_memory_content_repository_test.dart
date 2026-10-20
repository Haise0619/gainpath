import 'package:test/test.dart';
import 'package:gainpath_data/src/content/in_memory/in_memory_content_repository.dart';
import 'package:gainpath_domain/content.dart';

void main() {
  test('InMemoryContentRepository serves seed data', () {
    final repo = InMemoryContentRepository();
    expect(repo.announcements, isNotEmpty);
  });
  test(
      'mock create, edit, deactivate and stale revision preserve existing entries',
      () async {
    final repo = InMemoryContentRepository();
    final previousIds = repo.announcements.map((a) => a.id).toList();
    final draft = await repo.saveAnnouncement(Announcement(
        id: '',
        title: 'Mock draft',
        body: 'Fixture',
        validFrom: DateTime.now().subtract(const Duration(days: 1)),
        validTo: DateTime.now().add(const Duration(days: 1)),
        status: AnnouncementStatus.draft));
    final published = await repo.saveAnnouncement(draft.copyWith(
        title: 'Published', status: AnnouncementStatus.published));
    expect(published.isActive, isTrue);
    await expectLater(repo.saveAnnouncement(draft.copyWith(body: 'Stale')),
        throwsA(isA<AnnouncementConflict>()));
    final inactive = await repo.saveAnnouncement(
        published.copyWith(status: AnnouncementStatus.inactive));
    expect(inactive.isActive, isFalse);
    expect((await repo.loadAnnouncements()).items.map((a) => a.id),
        containsAll(previousIds));
  });
}
