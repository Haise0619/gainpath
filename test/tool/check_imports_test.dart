import 'dart:io';

import 'package:test/test.dart';

import '../../tool/check_architecture.dart';

void main() {
  late Directory root;
  void write(String path, String content) {
    final file = File('${root.path}/$path');
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(content);
  }

  void owner(String path, String name, {String deps = ''}) {
    write('$path/pubspec.yaml', 'name: $name\ndependencies:\n$deps');
    write('$path/lib/$name.dart', '');
  }

  setUp(() =>
      root = Directory.systemTemp.createTempSync('architecture fixtures '));
  tearDown(() => root.deleteSync(recursive: true));

  test(
      'workspace members resolve beneath roots with or without trailing separators',
      () {
    write('pubspec.yaml', 'name: workspace\nworkspace:\n  - apps/mobile\n');
    owner('apps/mobile', 'gainpath_mobile');
    expect(checkArchitecture(Directory('${root.path}/')), isEmpty);
    expect(checkArchitecture(Directory(root.path)), isEmpty);
  });

  test(
      'features navigate by contracts instead of importing other screens or composition',
      () {
    owner('apps/mobile', 'gainpath_mobile');
    write('apps/mobile/lib/features/identity/presentation/profile.dart',
        "import '../../workout/presentation/screen.dart';\nimport '../../../app/routing/routes.dart';");
    expect(checkArchitecture(root), hasLength(2));
  });

  test('allows public barrels, internal src, and test-only external src', () {
    owner('packages/gainpath_domain', 'gainpath_domain');
    owner('apps/mobile', 'gainpath_mobile');
    write('packages/gainpath_domain/lib/gainpath_domain.dart',
        "export 'src/model.dart';");
    write('packages/gainpath_domain/lib/src/model.dart',
        "import 'package:gainpath_domain/src/other.dart';");
    write('apps/mobile/lib/main.dart',
        "import 'package:gainpath_domain/identity.dart';");
    write('apps/mobile/test/model_test.dart',
        "import 'package:gainpath_domain/src/model.dart';");
    expect(checkArchitecture(root), isEmpty);
  });
  test('checks every conditional export URI', () {
    owner('apps/admin_web', 'gainpath_admin_web');
    write('apps/admin_web/lib/main.dart',
        "export 'stub.dart' if (dart.library.io) 'package:camera/camera.dart' if (dart.library.html) 'package:gainpath_mobile/main.dart';");
    final failures = checkArchitecture(root).join('\n');
    expect(failures, contains('camera'));
    expect(failures, contains('gainpath_mobile'));
  });
  test('ignores comments and strings resembling directives', () {
    owner('packages/gainpath_domain', 'gainpath_domain');
    write('packages/gainpath_domain/lib/example.dart',
        "// import 'package:flutter/material.dart';\n/* export 'package:gainpath_data/data.dart'; */\nconst sample = \"import 'package:gainpath_mobile/main.dart';\";");
    expect(checkArchitecture(root), isEmpty);
  });
  test('rejects external src in imports and exports', () {
    owner('apps/mobile', 'gainpath_mobile');
    write('apps/mobile/lib/main.dart',
        "import 'package:gainpath_domain/src/model.dart';\nexport 'package:collection/src/utils.dart';");
    expect(
        checkArchitecture(root)
            .where((f) => f.contains('external package src')),
        hasLength(2));
  });
  test('normalizes paths before checking a feature importing its own data', () {
    owner('apps/mobile', 'gainpath_mobile');
    write('apps/mobile/lib/features/chat/presentation/view.dart',
        "import '../application/../data/repository.dart';\nexport 'package:gainpath_mobile/features/chat/presentation/../data/seed.dart';");
    expect(
        checkArchitecture(root)
            .where((f) => f.contains('feature imports concrete data')),
        hasLength(2));
  });
  test('rejects relative escapes into another package lib', () {
    owner('packages/gainpath_domain', 'gainpath_domain');
    owner('packages/gainpath_data', 'gainpath_data');
    write('packages/gainpath_domain/lib/main.dart',
        "import '../../gainpath_data/lib/data.dart';");
    expect(checkArchitecture(root).join('\n'),
        contains('relative directive escapes'));
  });
  test('admin detects transitive engine dependencies from manifests', () {
    owner('apps/admin_web', 'gainpath_admin_web',
        deps: '  bridge:\n    path: ../../packages/bridge\n');
    owner('packages/bridge', 'bridge', deps: '  camera: ^0.11.0\n');
    expect(checkArchitecture(root).join('\n'),
        contains('gainpath_admin_web -> bridge -> camera'));
  });
  test('graph follows transitive source-only exports', () {
    owner('apps/admin_web', 'gainpath_admin_web');
    owner('packages/bridge', 'bridge');
    write(
        'apps/admin_web/lib/main.dart', "import 'package:bridge/bridge.dart';");
    write('packages/bridge/lib/bridge.dart',
        "export 'package:gainpath_pose/engine.dart';");
    expect(checkArchitecture(root).join('\n'),
        contains('gainpath_admin_web -> bridge -> gainpath_pose'));
  });
  test('shared packages cannot reach apps through dependency cycles', () {
    owner('packages/one', 'one', deps: '  two: any\n');
    owner('packages/two', 'two', deps: '  one: any\n  gainpath_mobile: any\n');
    expect(checkArchitecture(root).join('\n'),
        contains('one -> two -> gainpath_mobile'));
  });
  test(
      'pure packages reject transitive Flutter but allow test dev dependencies',
      () {
    owner('packages/gainpath_domain', 'gainpath_domain',
        deps:
            '  helper: any\ndev_dependencies:\n  flutter_test:\n    sdk: flutter\n');
    owner('packages/helper', 'helper', deps: '  flutter:\n    sdk: flutter\n');
    expect(checkArchitecture(root).join('\n'),
        contains('gainpath_domain -> helper -> flutter'));
    write('packages/helper/pubspec.yaml', 'name: helper\n');
    expect(checkArchitecture(root), isEmpty);
  });
  test('data rejects Flutter and dart ui', () {
    owner('packages/gainpath_data', 'gainpath_data');
    write('packages/gainpath_data/lib/main.dart',
        "import 'package:flutter/material.dart';\nimport 'dart:ui';");
    final failures = checkArchitecture(root).join('\n');
    expect(failures, contains('flutter'));
    expect(failures, contains('dart:ui'));
  });
  test('checks manifest-only packages and inline dependency maps', () {
    write('packages/gainpath_identity/pubspec.yaml',
        'name: gainpath_identity\ndependencies: {gainpath_data: any}\n');
    expect(checkArchitecture(root).join('\n'),
        contains('identity application depends on data'));
  });
  test('rejects legacy root code and test imports', () {
    write('lib/old.dart', '');
    write('test/old_test.dart', "import 'package:gainpath/main.dart';");
    final failures = checkArchitecture(root);
    expect(failures.where((f) => f.contains('legacy root')), hasLength(2));
  });
  test('reports malformed directives instead of silently passing', () {
    owner('apps/mobile', 'gainpath_mobile');
    write('apps/mobile/lib/main.dart',
        "import 'package:gainpath_data/data.dart'");
    expect(checkArchitecture(root).join('\n'), contains('parse'));
  });
}
