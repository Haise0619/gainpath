import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_ui/gainpath_ui.dart';

void main() {
  testWidgets('shared panel renders and forwards taps without app services',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Panel(
      onTap: () => taps++,
      child: const Text('Shared primitive'),
    ))));
    await tester.tap(find.text('Shared primitive'));
    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });
}
