import 'member_recommendation_repository.dart';

/// A single signed-in host shares Home/history pages and concurrent requests.
/// Actions still resolve on the server. Notifications, consent changes and
/// explicit refresh invalidate all pages; nothing survives an account switch.
class MemberRecommendationPageCache {
  MemberRecommendationPageCache(this.source, this.isCurrent,
      {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;
  final MemberRecommendationPageLoader source;
  final bool Function() isCurrent;
  final DateTime Function() _clock;
  final _pages = <String, (DateTime, MemberRecommendationPage)>{};
  final _pending = <String, Future<MemberRecommendationPage>>{};
  int _generation = 0;

  void invalidate() {
    _generation++;
    _pages.clear();
    _pending.clear();
  }

  Future<MemberRecommendationPage> load(
      {required bool history, String? afterId}) async {
    if (!isCurrent()) {
      invalidate();
      throw const MemberRecommendationUnavailable();
    }
    final key = '$history:${afterId ?? ''}';
    final cached = _pages[key];
    if (cached != null && _clock().difference(cached.$1).inSeconds < 20) {
      return cached.$2;
    }
    final existing = _pending[key];
    if (existing != null) return existing;
    final generation = _generation;
    final request = source(history: history, afterId: afterId);
    _pending[key] = request;
    try {
      final page = await request;
      if (!isCurrent()) throw const MemberRecommendationUnavailable();
      if (generation == _generation) _pages[key] = (_clock(), page);
      return page;
    } finally {
      if (identical(_pending[key], request)) _pending.remove(key);
    }
  }
}
