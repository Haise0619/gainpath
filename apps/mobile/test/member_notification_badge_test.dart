import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_domain/content.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show AppRole, AuthSession;
import 'package:gainpath_mobile/app/notifications/member_notification_badge.dart';
import 'package:gainpath_mobile/infrastructure/local/member_announcement_read_store.dart';

class _Announcements implements AnnouncementReader {
  _Announcements(this.load);
  final Future<AnnouncementPage> Function(String?) load;

  @override
  Future<AnnouncementPage> loadAnnouncements({String? afterId}) =>
      load(afterId);
}

class _Inbox implements Module9Repository {
  bool read = false;

  @override
  Future<NoticePage> loadInbox({String? afterId}) async => NoticePage([
        MemberNotice(
            id: 'booking-update',
            title: 'New time',
            message: '',
            read: read,
            createdAt: DateTime(2026, 11, 23)),
      ], null);

  @override
  Stream<void> watchInbox() => const Stream.empty();

  @override
  Future<void> markRead(String id) async => read = true;

  @override
  Future<CoachSharing> loadSharing() => throw UnimplementedError();

  @override
  Future<CoachSharing> saveSharing(bool enabled, int expectedRevision) =>
      throw UnimplementedError();

  @override
  Future<CoachReport> loadPerformance() => throw UnimplementedError();
}

void main() {
  final now = DateTime.utc(2026, 11, 23);
  Announcement notice(int revision) => Announcement(
        id: 'gym-closure',
        title: 'Gym closure',
        body: 'Closed today',
        validFrom: now.subtract(const Duration(hours: 1)),
        validTo: now.add(const Duration(days: 1)),
        revision: revision,
      );

  test(
      'finds a later-page announcement, retains seen state, and flags an updated revision',
      () async {
    var entry = notice(1);
    var saved = <String, int>{};
    final reader = _Announcements((cursor) async => cursor == null
        ? AnnouncementPage([], nextCursor: 'older')
        : AnnouncementPage([entry]));
    MemberNotificationBadge badge() => MemberNotificationBadge(
          announcements: reader,
          isCurrent: () => true,
          clock: () => now,
          loadSeen: () async => saved,
          saveSeen: (value) async {
            saved = value;
          },
        );
    final first = badge();
    addTearDown(first.dispose);
    await first.refreshAnnouncements();
    expect(first.value, 1);
    await first.markAnnouncementRead(entry);
    expect(first.value, 0);
    final reopened = badge();
    addTearDown(reopened.dispose);
    await reopened.refreshAnnouncements();
    expect(reopened.value, 0);
    entry = notice(2);
    await reopened.refreshAnnouncements();
    expect(reopened.value, 1);
  });

  test('uses the existing server read state for personal notifications',
      () async {
    final inbox = _Inbox();
    final badge = MemberNotificationBadge(
        inbox: inbox,
        isCurrent: () => true,
        loadSeen: () async => {},
        saveSeen: (_) async {});
    addTearDown(badge.dispose);
    await badge.refreshInbox();
    expect(badge.value, 1);
    await inbox.markRead('booking-update');
    await badge.refreshInbox();
    expect(badge.value, 0);
  });

  test('counts unique announcements and personal notices across pages', () async {
    final entry = notice(1);
    final other = Announcement(
      id: 'new-gym-hours',
      title: 'New gym hours',
      body: 'Check the updated schedule',
      validFrom: entry.validFrom,
      validTo: entry.validTo,
    );
    final inbox = _Inbox();
    final badge = MemberNotificationBadge(
      announcements: _Announcements((cursor) async => cursor == null
          ? AnnouncementPage([entry], nextCursor: 'next')
          : AnnouncementPage([entry, other])),
      inbox: inbox,
      isCurrent: () => true,
      clock: () => now,
      loadSeen: () async => {},
      saveSeen: (_) async {},
    );
    addTearDown(badge.dispose);
    await badge.refreshAnnouncements();
    await badge.refreshInbox();
    expect(badge.value, 3);
    await badge.markAnnouncementRead(other);
    expect(badge.value, 2);
    await inbox.markRead('booking-update');
    await badge.refreshInbox();
    expect(badge.value, 1);
    await badge.markAnnouncementRead(entry);
    expect(badge.value, 0);
  });

  test('the device store keeps receipts separate for each account', () async {
    final directory =
        await Directory.systemTemp.createTemp('announcement-test-');
    addTearDown(() => directory.delete(recursive: true));
    MemberAnnouncementReadStore store(String userId) =>
        MemberAnnouncementReadStore(
          AuthSession(
            userId: userId,
            organizationId: 'gym',
            email: '$userId@example.test',
            role: AppRole.member,
          ).scope,
          directory: () async => directory,
        );
    await store('member-one').save({'gym-closure:1': 1});
    await store('member-two').save({'gym-closure:2': 2});
    await store('member-one').save({'gym-closure:1': 3});
    expect(await store('member-one').read(), {'gym-closure:1': 3});
    expect(await store('member-two').read(), {'gym-closure:2': 2});
  });

  test('discards a late result and writes nothing when the account changes',
      () async {
    var current = true;
    var writes = 0;
    final entered = Completer<void>();
    final response = Completer<AnnouncementPage>();
    final badge = MemberNotificationBadge(
      announcements: _Announcements((_) {
        entered.complete();
        return response.future;
      }),
      isCurrent: () => current,
      clock: () => now,
      loadSeen: () async => {},
      saveSeen: (_) async {
        writes++;
      },
    );
    addTearDown(badge.dispose);
    final pending = badge.refreshAnnouncements();
    await entered.future;
    current = false;
    badge.clear();
    response.complete(AnnouncementPage([notice(1)]));
    await pending;
    await badge.markAnnouncementRead(notice(1));
    expect(badge.value, 0);
    expect(writes, 0);
  });
}
