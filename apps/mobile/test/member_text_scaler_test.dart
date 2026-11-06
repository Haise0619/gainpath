import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_mobile/app/member_typography_theme.dart';

class _SystemScaler extends TextScaler {
  const _SystemScaler();

  @override
  double scale(double fontSize) => fontSize * (fontSize < 20 ? 1.5 : 1.2);

  @override
  double get textScaleFactor => 1.5;
}

void main() {
  test('member scaling preserves nonlinear system scaling', () {
    final scaler = memberTextScaler(const _SystemScaler());
    expect(scaler.scale(16), closeTo(26.4, 0.001));
    expect(scaler.scale(24), closeTo(31.68, 0.001));
  });
}
