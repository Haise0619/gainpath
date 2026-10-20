import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import '../../features/workout/domain/published_routine_catalog_repository.dart';
import '../../features/workout/domain/published_routine_view.dart';

typedef PublishedRoutineCatalogFactory = PublishedRoutineCatalogRepository
    Function(SessionScope scope, SessionScope? Function() activeScope);

/// Retains the existing single-loader injection contract. Firebase production
/// composition uses the paged repository; this is not a mock Firebase fallback.
class SinglePublishedRoutineCatalog
    implements PublishedRoutineCatalogRepository {
  SinglePublishedRoutineCatalog({required this.scope, required this.loader});
  @override
  final SessionScope scope;
  final Future<PublishedRoutine?> Function() loader;
  @override
  Future<PublishedRoutinePage> loadPage({String? afterId}) async {
    if (afterId != null) return PublishedRoutinePage([]);
    final routine = await loader();
    return PublishedRoutinePage(routine == null ? [] : [routine]);
  }

  @override
  Future<PublishedRoutine?> loadById(String id) async {
    final routine = await loader();
    return routine?.id == id ? routine : null;
  }
}
