import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Hero colors meet AA', () {
    double ratio(Color a, Color b) {
      final x = a.computeLuminance(), y = b.computeLuminance();
      return x > y ? (x + .05) / (y + .05) : (y + .05) / (x + .05);
    }

    for (final c in [
      Colors.white,
      const Color(0xFFE8DDF5),
      const Color(0xFFF5ECFF),
      const Color(0xFFF4B474)
    ]) {
      expect(ratio(c, const Color(0xFF52258F)), greaterThanOrEqualTo(4.5));
    }
    expect(ratio(const Color(0xFF321C49), const Color(0xFFFFF2E5)),
        greaterThanOrEqualTo(4.5));
  });
}
