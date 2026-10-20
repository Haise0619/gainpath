/// Immutable copies and deep comparison for bounded private Member documents.
/// Opaque SDK scalars (such as Firestore Timestamp) retain their value equality.
Map<String, Object?>? freezeMemberDocument(Map<String, Object?>? document) =>
    document == null
        ? null
        : Map<String, Object?>.unmodifiable({
            for (final entry in document.entries)
              entry.key: _freeze(entry.value),
          });

Object? _freeze(Object? value) {
  if (value is Map) {
    return Map<Object?, Object?>.unmodifiable({
      for (final entry in value.entries) entry.key: _freeze(entry.value),
    });
  }
  if (value is List) return List<Object?>.unmodifiable(value.map(_freeze));
  return value;
}

bool sameMemberDocumentValue(Object? left, Object? right) {
  if (left is Map && right is Map) {
    return left.length == right.length &&
        left.keys.every((key) =>
            right.containsKey(key) &&
            sameMemberDocumentValue(left[key], right[key]));
  }
  if (left is List && right is List) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (!sameMemberDocumentValue(left[index], right[index])) return false;
    }
    return true;
  }
  return left == right;
}
