import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_mobile/features/recommendation/application/member_recommendation_page_cache.dart';
import 'package:gainpath_mobile/features/recommendation/application/member_recommendation_repository.dart';

void main() {
  test('coalesces pages, shares Home cache, expires and separates history',
      () async {
    var now = DateTime.utc(2026), calls = 0;
    final cache = MemberRecommendationPageCache((
        {required bool history, String? afterId}) async {
      calls++;
      return const MemberRecommendationPage(records: []);
    }, () => true, clock: () => now);
    await Future.wait([cache.load(history: false), cache.load(history: false)]);
    await cache.load(history: false);
    expect(calls, 1);
    await cache.load(history: true);
    await cache.load(history: true, afterId: 'next');
    expect(calls, 3);
    now = now.add(const Duration(seconds: 21));
    await cache.load(history: false);
    expect(calls, 4);
    cache.invalidate();
    await cache.load(history: false);
    expect(calls, 5);
  });

  test(
      'invalidation cannot restore an old in-flight page; account loss fails closed',
      () async {
    var current = true, calls = 0;
    final pending = Completer<MemberRecommendationPage>();
    final cache = MemberRecommendationPageCache((
        {required bool history, String? afterId}) {
      calls++;
      return calls == 1
          ? pending.future
          : Future.value(const MemberRecommendationPage(records: []));
    }, () => current);
    final first = cache.load(history: false);
    cache.invalidate();
    pending.complete(const MemberRecommendationPage(records: []));
    await first;
    await cache.load(history: false);
    expect(calls, 2);
    current = false;
    await expectLater(cache.load(history: false),
        throwsA(isA<MemberRecommendationUnavailable>()));
  });
}
