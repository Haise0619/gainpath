import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/check_imports.dart';

void main() {
  test('feature import boundaries hold', () {
    final violations = checkImports(Directory('lib'));
    expect(violations, isEmpty, reason: violations.join('\n'));
  });
}
