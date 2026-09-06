import 'dart:io';

/// Feature-boundary rules for `lib/`:
///
/// * `domain/` imports nothing from Flutter (a narrow `show` of value types
///   such as `TimeOfDay`/`IconData` is tolerated), nothing from `app/` or
///   `shared/`, and from other features only their `domain/`.
/// * A feature never imports another feature's `presentation/member|coach|admin`
///   or `application/`. Another feature's `presentation/shared/` and `domain/`
///   are its public surface and may be imported. `data/` may import another
///   feature's `data/`: the in-memory seeds form one shared prototype dataset.
/// * `app/`, `core/` and `shared/` are not checked (composition root and
///   cross-cutting code).
///
/// Returns a list of violations; empty means clean.
List<String> checkImports(Directory lib) {
  final violations = <String>[];
  final featureRe = RegExp(r'features[\\/]([a-z_]+)[\\/](domain|data|application|presentation)[\\/]');
  final importRe = RegExp(r"^import '([^']+)'([^;]*);", multiLine: true);
  final targetRe = RegExp(r'^package:gainpath/features/([a-z_]+)/(domain|data|application|presentation)/(shared/)?');

  final files = lib
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  for (final file in files) {
    final m = featureRe.firstMatch(file.path);
    if (m == null) continue;
    final feature = m.group(1)!;
    final layer = m.group(2)!;
    final rel = file.path.substring(file.path.indexOf('lib'));
    final src = file.readAsStringSync();

    for (final im in importRe.allMatches(src)) {
      final target = im.group(1)!;
      final combinators = im.group(2)!;

      if (layer == 'domain') {
        if (target.startsWith('package:flutter/') && !combinators.contains('show')) {
          violations.add('$rel: domain imports Flutter ($target)');
        }
        if (target.startsWith('package:gainpath/app/') || target.startsWith('package:gainpath/shared/')) {
          violations.add('$rel: domain imports app/shared ($target)');
        }
      }

      final t = targetRe.firstMatch(target);
      if (t == null) continue;
      final targetFeature = t.group(1)!;
      final targetLayer = t.group(2)!;
      final targetShared = t.group(3) != null;
      if (targetFeature == feature) continue;

      if (layer == 'domain' && targetLayer != 'domain') {
        violations.add('$rel: domain imports another feature\'s $targetLayer ($target)');
      } else if (targetLayer == 'presentation' && !targetShared) {
        violations.add('$rel: imports another feature\'s role screens ($target)');
      } else if (targetLayer == 'application' || (targetLayer == 'data' && layer != 'data')) {
        violations.add('$rel: imports another feature\'s $targetLayer ($target)');
      }
    }
  }
  return violations;
}

void main() {
  final violations = checkImports(Directory('lib'));
  if (violations.isNotEmpty) {
    violations.forEach(stderr.writeln);
    exit(1);
  }
  stdout.writeln('imports OK');
}
