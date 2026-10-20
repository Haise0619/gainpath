/// Published tutorial media is optional; unsupported media never invalidates
/// otherwise valid workout targets. Query tokens are retained, never displayed.
Uri? tutorialMediaUri(Object? value) {
  if (value is! String) return null;
  final text = value.trim();
  if (text.isEmpty ||
      text.length > 2048 ||
      !RegExp(r'^https://[^/]', caseSensitive: false).hasMatch(text) ||
      RegExp(r'[\x00-\x20\x7f\\#]').hasMatch(text)) {
    return null;
  }
  final uri = Uri.tryParse(text);
  if (uri == null ||
      uri.scheme != 'https' ||
      !RegExp(r'^[a-z0-9.-]+$', caseSensitive: false).hasMatch(uri.host) ||
      uri.port < 1 ||
      uri.port > 65535 ||
      uri.userInfo.isNotEmpty ||
      uri.hasFragment ||
      !uri.path.toLowerCase().endsWith('.mp4')) {
    return null;
  }
  return uri;
}
