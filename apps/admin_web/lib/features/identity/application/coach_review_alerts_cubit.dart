import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/identity.dart';

class CoachReviewAlert {
  const CoachReviewAlert(this.coachId, this.name, this.updatedAtMillis);
  final String coachId, name;
  final int updatedAtMillis;
}

class CoachReviewAlertsState {
  const CoachReviewAlertsState(
      {this.items = const [], this.loading = false, this.error});
  final List<CoachReviewAlert> items;
  final bool loading;
  final String? error;
}

/// Derived from canonical drafts/publications: no duplicate notification store
/// or client publication authority. A pending alert survives reload until review.
class CoachReviewAlertsCubit extends Cubit<CoachReviewAlertsState> {
  CoachReviewAlertsCubit(this.repository)
      : super(const CoachReviewAlertsState());
  final CoachProfileAdminRepository repository;
  bool _busy = false;
  Future<void> refresh() async {
    if (_busy || isClosed) return;
    _busy = true;
    emit(const CoachReviewAlertsState(loading: true));
    try {
      if (!await repository.canManageDirectory()) {
        throw const CoachRepositoryException('permission-denied');
      }
      late final List<CoachProfessionalProfile> drafts;
      late final List<PublishedCoachProfile> publicProfiles;
      // Each cursor chain remains sequential; the two collections are independent.
      await Future.wait<void>([
        _loadPages(repository.loadDraftPage).then((items) => drafts = items),
        _loadPages(repository.loadPublicPage)
            .then((items) => publicProfiles = items),
      ]);
      if (isClosed) return;
      final publications = {for (final item in publicProfiles) item.id: item};
      final alerts = <CoachReviewAlert>[];
      // Deactivation alone must not create a new review request.
      final candidates = drafts
          .where((draft) =>
              (publications[draft.id]?.sourceRevision ?? 0) < draft.revision)
          .toList();
      for (var offset = 0; offset < candidates.length; offset += 4) {
        final reviews = await Future.wait(candidates
            .skip(offset)
            .take(4)
            .map((draft) => repository.loadReview(draft.id)));
        if (isClosed) return;
        for (final review in reviews) {
          final latest = review.draft;
          if (review.targetMembershipEligible &&
              latest != null &&
              (review.publication?.sourceRevision ?? 0) < latest.revision) {
            alerts.add(CoachReviewAlert(
                latest.id, latest.fields.displayName, latest.updatedAtMillis));
          }
        }
      }
      if (!await repository.canManageDirectory()) {
        throw const CoachRepositoryException('permission-denied');
      }
      alerts.sort((a, b) => b.updatedAtMillis.compareTo(a.updatedAtMillis));
      if (!isClosed) {
        emit(CoachReviewAlertsState(items: List.unmodifiable(alerts)));
      }
    } catch (_) {
      if (!isClosed) {
        emit(const CoachReviewAlertsState(
            error: 'Could not check Coach updates. Retry.'));
      }
    } finally {
      _busy = false;
    }
  }

  Future<List<T>> _loadPages<T>(
      Future<CoachDirectoryPage<T>> Function({String? afterId})
          loadPage) async {
    final items = <T>[];
    final seen = <String>{};
    String? cursor;
    do {
      final page = await loadPage(afterId: cursor);
      if (isClosed) return [];
      items.addAll(page.items);
      cursor = page.nextCursor;
      if (cursor != null && !seen.add(cursor)) {
        throw StateError('Repeated Coach directory cursor');
      }
    } while (cursor != null);
    return items;
  }
}
