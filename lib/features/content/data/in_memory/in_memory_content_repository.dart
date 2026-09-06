import 'package:gainpath/features/content/data/in_memory/content_seed.dart';
import 'package:gainpath/features/content/domain/entities/announcement.dart';
import 'package:gainpath/features/content/domain/repositories/content_repository.dart';

/// Session-scoped in-memory [ContentRepository] backed by [ContentSeed].
class InMemoryContentRepository implements ContentRepository {
  @override
  List<Announcement> get announcements => ContentSeed.announcements;
}
