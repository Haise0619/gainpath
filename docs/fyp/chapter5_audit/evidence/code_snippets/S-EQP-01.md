# S-EQP-01 — EquipmentMatcher._scoreQueryAgainstEquipment

Chapter section 5.1.4.7. Source `packages/gainpath_domain/lib/src/workout/recognition/equipment_recognition.dart:182–225`. Related regression `packages/gainpath_domain/test/equipment_matcher_test.dart`.

The deterministic alias and token-overlap scores are distinct from Gemini's model confidence. Surrounding source omitted.

```dart
  double _scoreQueryAgainstEquipment(String query, GymEquipment item) {
    final normQuery = _normalize(query);
    final normName = _normalize(item.name);

    if (normQuery.isEmpty || normName.isEmpty) return 0.0;

    // 1. Exact normalized name match
    if (normQuery == normName) return 1.0;

    // 2. Query contains exact item name or item name contains query
    if (normQuery.contains(normName) || normName.contains(normQuery)) {
      final ratio = normName.length / normQuery.length;
      return 0.85 + (0.10 * (ratio > 1.0 ? 1.0 / ratio : ratio));
    }

    // 3. Check known aliases for this item
    final aliases = _standardAliases[normName] ?? const [];
    for (final alias in aliases) {
      final normAlias = _normalize(alias);
      if (normQuery == normAlias) return 0.95;
      if (normQuery.contains(normAlias) || normAlias.contains(normQuery)) {
        return 0.88;
      }
    }

    // 4. Token overlap
    final queryTokens = normQuery.split(' ').where((t) => t.length > 2).toSet();
    final nameTokens = normName.split(' ').where((t) => t.length > 2).toSet();
    if (queryTokens.isNotEmpty && nameTokens.isNotEmpty) {
      final intersection = queryTokens.intersection(nameTokens);
      if (intersection.isNotEmpty) {
        final jaccard =
            intersection.length / queryTokens.union(nameTokens).length;
        if (jaccard >= 0.5) return 0.70 + (0.15 * jaccard);
      }
    }

    // 5. Category correlation boost if category is mentioned
    final normCat = _normalize(item.category);
    if (normCat.isNotEmpty && normQuery.contains(normCat)) {
      return 0.65;
    }

    return 0.0;
```
