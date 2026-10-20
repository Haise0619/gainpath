import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'published_routine_view.dart';

class PublishedRoutinePage {
  PublishedRoutinePage(List<PublishedRoutine> items, {this.nextCursor})
      : items = List.unmodifiable(items);
  final List<PublishedRoutine> items;
  final String? nextCursor;
}

/// Read-only published organization catalog, not an assignment/session store.
abstract interface class PublishedRoutineCatalogRepository {
  SessionScope get scope;
  Future<PublishedRoutinePage> loadPage({String? afterId});
  Future<PublishedRoutine?> loadById(String id);
}
