import '../entities/announcement.dart';

/// Content authoring port; the mutable getter is retained for mock compatibility.
/// Firebase readers and authors use the asynchronous page/save operations.
class AnnouncementPage {
  AnnouncementPage(Iterable<Announcement> items, {this.nextCursor})
      : items = List.unmodifiable(items);
  final List<Announcement> items;
  final String? nextCursor;
}

abstract interface class AnnouncementReader {
  Future<AnnouncementPage> loadAnnouncements({String? afterId});
}

class AnnouncementConflict implements Exception {
  const AnnouncementConflict();
}

class AnnouncementSessionChanged implements Exception {
  const AnnouncementSessionChanged();
}

abstract class ContentRepository implements AnnouncementReader {
  List<Announcement> get announcements;
  bool get isLive => false;

  @override
  Future<AnnouncementPage> loadAnnouncements({String? afterId}) async =>
      AnnouncementPage(afterId == null ? announcements : []);

  Future<Announcement> saveAnnouncement(Announcement entry) async {
    entry.validate();
    final index = announcements.indexWhere((item) => item.id == entry.id);
    if (entry.id.isNotEmpty && index < 0) throw const AnnouncementConflict();
    if (index >= 0 && announcements[index].revision != entry.revision) {
      throw const AnnouncementConflict();
    }
    final saved = Announcement(
        id: entry.id.isEmpty
            ? 'an${DateTime.now().microsecondsSinceEpoch}'
            : entry.id,
        title: entry.title.trim(),
        body: entry.body.trim(),
        validFrom: entry.validFrom,
        validTo: entry.validTo,
        status: entry.status,
        revision: entry.revision + 1);
    if (index < 0) {
      announcements.insert(0, saved);
    } else {
      announcements[index] = saved;
    }
    return saved;
  }
}
