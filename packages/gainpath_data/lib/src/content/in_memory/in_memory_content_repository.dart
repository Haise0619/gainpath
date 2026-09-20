import '../../fakes/mock_data_session.dart';
import 'content_seed.dart';
import 'package:gainpath_domain/content.dart';

/// Session-scoped in-memory [ContentRepository] backed by [ContentSeed].
class InMemoryContentRepository implements ContentRepository {
  InMemoryContentRepository({MockDataSession? session})
      : _seed = (session ?? MockDataSession()).content;

  final ContentSeed _seed;

  @override
  List<Announcement> get announcements => _seed.announcements;
}
