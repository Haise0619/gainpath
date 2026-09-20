import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:gainpath_mobile/main.dart';

void main() {
  setUpAll(() {
    // Tests have no network; keep google_fonts from trying to download.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('app boots into a scaffolded first screen', (tester) async {
    await tester.pumpWidget(const GainPathMobileApp());
    await tester.pump();
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(Scaffold), findsWidgets);
  });
}
