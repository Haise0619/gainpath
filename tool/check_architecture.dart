import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:yaml/yaml.dart';
import 'package:path/path.dart' as p;

class _Package {
  _Package(this.name, this.directory, this.isApp, this.manifest);
  final String name;
  final Directory directory;
  final bool isApp;
  final Map manifest;
  final Set<String> dependencies = {};
}

String _path(FileSystemEntity entity) => p.normalize(entity.absolute.path).replaceAll('\\', '/');

Iterable<File> _dartFiles(Directory directory) sync* {
  if (!directory.existsSync()) return;
  for (final entity in directory.listSync(followLinks: false)) {
    if (entity is File && entity.path.endsWith('.dart')) yield entity;
    if (entity is Directory &&
        !{
          '.dart_tool',
          'build',
          'node_modules',
          '.git'
        }.contains(entity.uri.pathSegments.where((p) => p.isNotEmpty).last)) {
      yield* _dartFiles(entity);
    }
  }
}

Map _manifest(File file, Set<String> failures) {
  if (!file.existsSync()) return {};
  try {
    final value = loadYaml(file.readAsStringSync());
    if (value is Map) return value;
    failures.add('${_path(file)}: pubspec must be a YAML map');
  } catch (error) {
    failures.add('${_path(file)}: cannot parse pubspec: $error');
  }
  return {};
}

String? _forbidden(_Package owner, String target, Set<String> apps) {
  if (target == 'gainpath' || target == 'gainpath_workspace') {
    return 'legacy root app dependency';
  }
  if (apps.contains(target) && target != owner.name) {
    return 'dependency on another app';
  }
  final pure = {'gainpath_domain', 'gainpath_pose', 'gainpath_data'}
      .contains(owner.name);
  final flutter = target == 'flutter' ||
      target.startsWith('flutter_') ||
      target == 'dart:ui';
  if (pure && flutter) return 'pure Dart dependency violated';
  if ({'gainpath_domain', 'gainpath_pose'}.contains(owner.name) &&
      ({'gainpath_data', 'gainpath_ui', 'gainpath_identity'}.contains(target) ||
          target.startsWith('firebase_') ||
          target == 'cloud_firestore')) {
    return 'pure domain/pose dependency violated';
  }
  if (owner.name == 'gainpath_identity' && target == 'gainpath_data') {
    return 'identity application depends on data';
  }
  if (owner.name == 'gainpath_ui' &&
      {'gainpath_data', 'gainpath_identity', 'gainpath_domain'}
          .contains(target)) {
    return 'visual primitives depend on business code';
  }
  if (owner.name == 'gainpath_admin_web' &&
      (target == 'gainpath_pose' ||
          target == 'camera' ||
          target.startsWith('camera_') ||
          target.startsWith('google_mlkit'))) {
    return 'admin imports mobile engine';
  }
  return null;
}

/// Validates source boundaries and runtime dependency reachability.
///
/// Runtime edges come from current workspace pubspecs and all import/export
/// alternatives. When available, pub's resolved graph supplies external edges.
/// Dev dependencies never become runtime edges. Tests may access another
/// package's src, but may not resurrect the legacy root package.
List<String> checkArchitecture(Directory root) {
  root = root.absolute;
  final failures = <String>{};
  final rootManifest = _manifest(File('${root.path}/pubspec.yaml'), failures);
  if (rootManifest['name'] == 'gainpath') {
    failures.add('${root.path}/pubspec.yaml: legacy root app package');
  }
  final owners = <String, _Package>{};
  final ownerPaths = <String>{};
  void addOwner(Directory directory, bool isApp) {
    if (!ownerPaths.add(_path(directory))) return;
    final file = File('${directory.path}/pubspec.yaml');
    if (!file.existsSync()) return;
    final manifest = _manifest(file, failures);
    final name = manifest['name'];
    if (name is! String || name.isEmpty) {
      failures.add('${_path(file)}: missing package name');
      return;
    }
    if (owners.containsKey(name)) {
      failures.add('${_path(file)}: duplicate workspace package $name');
      return;
    }
    final owner = _Package(name, directory, isApp, manifest);
    final dependencies = manifest['dependencies'];
    if (dependencies is Map) {
      owner.dependencies.addAll(dependencies.keys.whereType<String>());
    } else if (dependencies != null) {
      failures.add('${_path(file)}: dependencies must be a YAML map');
    }
    owners[name] = owner;
  }

  for (final group in ['apps', 'packages']) {
    final directory = Directory('${root.path}/$group');
    if (!directory.existsSync()) continue;
    for (final child
        in directory.listSync(followLinks: false).whereType<Directory>()) {
      addOwner(child, group == 'apps');
    }
  }
  final workspace = rootManifest['workspace'];
  if (workspace is List) {
    for (final member in workspace.whereType<String>()) {
      final directory =
          Directory.fromUri(root.uri.resolve('$member/').normalizePath());
      if (!_path(directory).startsWith('${_path(root)}/')) {
        failures.add('pubspec.yaml: workspace member escapes root ($member)');
        continue;
      }
      addOwner(directory, _path(directory).startsWith('${_path(root)}/apps/'));
    }
  }

  final apps = {
    'gainpath_mobile',
    'gainpath_admin_web',
    ...owners.values.where((p) => p.isApp).map((p) => p.name)
  };
  final graph = <String, Set<String>>{};
  // Use resolved dependencies only for external packages: current workspace
  // source/manifests remain authoritative during a migration before pub get.
  final resolved = File('${root.path}/.dart_tool/package_graph.json');
  if (resolved.existsSync()) {
    try {
      final packages =
          (jsonDecode(resolved.readAsStringSync()) as Map)['packages'] as List;
      for (final entry in packages.whereType<Map>()) {
        final name = entry['name'];
        if (name is String && !owners.containsKey(name)) {
          graph[name] = (entry['dependencies'] as List? ?? [])
              .whereType<String>()
              .toSet();
        }
      }
    } catch (error) {
      failures.add(
          '${_path(resolved)}: cannot parse resolved dependency graph: $error');
    }
  }

  void scan(File file, _Package? owner,
      {required bool isTest, required bool runtime}) {
    final path = _path(file);
    final result = parseString(
        content: file.readAsStringSync(),
        path: path,
        throwIfDiagnostics: false);
    for (final error in result.errors) {
      failures.add(
          '$path:${result.lineInfo.getLocation(error.offset).lineNumber}: parse error: ${error.message}');
    }
    for (final directive in result.unit.directives) {
      final literals = <StringLiteral>[];
      if (directive is UriBasedDirective) literals.add(directive.uri);
      if (directive is ImportDirective) {
        literals.addAll(directive.configurations.map((c) => c.uri));
      }
      if (directive is ExportDirective) {
        literals.addAll(directive.configurations.map((c) => c.uri));
      }
      // A URI-form part-of also must not bypass the package boundary.
      if (directive is PartOfDirective && directive.uri != null) {
        literals.add(directive.uri!);
      }
      for (final literal in literals) {
        final target = literal.stringValue;
        if (target == null) continue;
        final location =
            '$path:${result.lineInfo.getLocation(literal.offset).lineNumber}';
        void reject(String reason) =>
            failures.add('$location: $reason ($target)');
        Uri uri;
        try {
          uri = Uri.parse(target);
        } on FormatException {
          reject('invalid directive URI');
          continue;
        }
        String? package;
        String? targetPath;
        if (uri.scheme == 'package') {
          final decoded = Uri.decodeComponent(uri.path).replaceAll('\\', '/');
          final parts = decoded.split('/');
          package = parts.first;
          final base = Uri.parse('file:///package/');
          final normalized =
              base.resolve(parts.skip(1).join('/')).normalizePath();
          if (parts.length < 2 || !normalized.path.startsWith('/package/')) {
            reject('invalid package URI');
            continue;
          }
          targetPath = normalized.path.substring('/package/'.length);
          if (package == 'gainpath' || package == 'gainpath_workspace') {
            reject('legacy root app dependency');
          }
          if (!isTest &&
              package != owner?.name &&
              targetPath.split('/').first == 'src') {
            reject('external package src access');
          }
        } else if (uri.scheme == 'dart') {
          package = target;
        } else {
          if (uri.hasScheme ||
              uri.hasAuthority ||
              uri.hasQuery ||
              uri.hasFragment) {
            reject('unsupported directive URI');
            continue;
          }
          final normalized = file.absolute.uri
              .resolve(Uri.decodeComponent(target).replaceAll('\\', '/'))
              .normalizePath();
          final boundary = owner == null
              ? root.absolute.uri
              : owner.directory.absolute.uri.resolve(isTest ? '' : 'lib/');
          if (!normalized.toString().startsWith(boundary.toString())) {
            reject('relative directive escapes package');
          } else {
            targetPath = Uri.decodeComponent(
                normalized.toString().substring(boundary.toString().length));
          }
        }
        if (owner != null && runtime) {
          if (package != null && package != owner.name) {
            owner.dependencies.add(package);
          }
          final featureLayer = owner.isApp &&
              RegExp(r'/features/[^/]+/(application|presentation)/')
                  .hasMatch(path);
          if (featureLayer &&
              (package == null || package == owner.name) &&
              targetPath != null) {
            final sourceFeature =
                RegExp(r'/features/([^/]+)/').firstMatch(path)?.group(1);
            final targetFeature =
                RegExp(r'^features/([^/]+)/(application|presentation|data)/')
                    .firstMatch(targetPath);
            if (targetFeature != null &&
                targetFeature.group(1) != sourceFeature) {
              reject(
                  'cross-feature implementation access; use a navigation or domain contract');
            }
            if (targetPath.startsWith('app/')) {
              reject('feature imports application composition');
            }
          }
          if (featureLayer &&
              (package == 'gainpath_data' ||
                  (package == null || package == owner.name) &&
                      targetPath != null &&
                      targetPath.split('/').contains('data'))) {
            reject('feature imports concrete data layer');
          }
        }
      }
    }
  }

  for (final owner in owners.values) {
    for (final folder in ['lib', 'bin', 'test', 'integration_test', 'tool']) {
      final isTest = folder == 'test' || folder == 'integration_test';
      for (final file
          in _dartFiles(Directory('${owner.directory.path}/$folder'))) {
        scan(file, owner,
            isTest: isTest, runtime: folder == 'lib' || folder == 'bin');
      }
    }
    graph[owner.name] = owner.dependencies;
  }
  for (final file in _dartFiles(Directory('${root.path}/lib'))) {
    failures.add('${_path(file)}: legacy root lib source');
  }
  for (final folder in ['android', 'ios', 'web', 'windows', 'linux', 'macos']) {
    if (Directory('${root.path}/$folder').existsSync()) {
      failures.add('${root.path}/$folder: legacy root app runner');
    }
  }
  for (final folder in ['test', 'tool']) {
    for (final file in _dartFiles(Directory('${root.path}/$folder'))) {
      scan(file, null, isTest: folder == 'test', runtime: false);
    }
  }
  for (final owner in owners.values) {
    final queue = <List<String>>[
      [owner.name]
    ];
    final visited = {owner.name};
    for (var index = 0; index < queue.length; index++) {
      final chain = queue[index];
      final dependencies = (graph[chain.last] ?? {}).toList()..sort();
      for (final dependency in dependencies) {
        if (!visited.add(dependency)) continue;
        final next = [...chain, dependency];
        final reason = _forbidden(owner, dependency, apps);
        if (reason != null) {
          failures.add(
              '${_path(owner.directory)}/pubspec.yaml: $reason (${next.join(' -> ')})');
        }
        queue.add(next);
      }
    }
  }
  return failures.toList()..sort();
}

void main(List<String> arguments) {
  if (arguments.length > 1) {
    stderr.writeln(
        'Usage: dart run tool/check_architecture.dart [workspace-root]');
    exitCode = 64;
    return;
  }
  final failures = checkArchitecture(
      arguments.isEmpty ? Directory.current : Directory(arguments.single));
  if (failures.isEmpty) {
    stdout.writeln('Architecture boundaries OK');
  } else {
    failures.forEach(stderr.writeln);
    exitCode = 1;
  }
}
