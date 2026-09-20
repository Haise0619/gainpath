import '../entities/announcement.dart';

/// Data access contract for the content feature. Implemented in-memory for the
/// prototype; a Firebase implementation will sit behind the same interface.
abstract class ContentRepository {
  List<Announcement> get announcements;
}
