import 'dart:io';

Directory findGainPathWorkspace() {
  var directory = Directory.current;
  while (!File.fromUri(directory.uri.resolve('apps/mobile/pubspec.yaml'))
      .existsSync()) {
    final parent = directory.parent;
    if (parent.path == directory.path) {
      throw StateError('Run the test from the GainPath workspace.');
    }
    directory = parent;
  }
  return directory;
}
