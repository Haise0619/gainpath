/// Converts legacy ranking boilerplate into exercise context without inferring
/// a form fault. Original source text stays on the immutable detail record.
String recommendationPresentationReason(String source, String? exercise) {
  final technical = RegExp(
      r'\b(mapping|candidates?|eligibility|deterministic|synthetic|mock)\b|\breviewed educational\b',
      caseSensitive: false);
  if (!technical.hasMatch(source)) return source;
  final label = exercise?.trim();
  return label == null || label.isEmpty
      ? 'Guidance for your exercise practice.'
      : 'Guidance for your $label practice.';
}
