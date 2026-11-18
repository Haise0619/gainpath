import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_ui/gainpath_ui.dart';

void main() {
  testWidgets(
      'nearby sorts branches without sending location to the repository',
      (tester) async {
    final calls = <Map<String, Object?>>[];
    await tester.pumpWidget(MaterialApp(
        home: BranchDirectoryPage(
      request: (input) async {
        calls.add(input);
        return {
          'records': [
            {'branchId': 'missing', 'displayName': 'Missing coordinates'},
            {
              'branchId': 'far',
              'displayName': 'Far gym',
              'latitude': 5,
              'longitude': 102
            },
            {
              'branchId': 'near',
              'displayName': 'Near gym',
              'latitude': 3.14,
              'longitude': 101.68
            },
          ]
        };
      },
      locate: () async => (latitude: 3.14, longitude: 101.68),
      openDirections: (_) async => true,
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use my location'));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('Near gym')).dy,
        lessThan(tester.getTopLeft(find.text('Far gym')).dy));
    expect(find.text('0.0 km away'), findsOneWidget);
    expect(calls, [
      {'action': 'list'}
    ]);
  });

  testWidgets('location denial preserves the branch and address directions',
      (tester) async {
    Uri? opened;
    await tester.pumpWidget(MaterialApp(
        home: BranchDirectoryPage(
      request: (_) async => {
        'records': [
          {
            'branchId': 'old',
            'displayName': 'Old gym',
            'address': '12 Main Road'
          },
        ]
      },
      locate: () async => throw StateError('Location access is off.'),
      openDirections: (uri) async {
        opened = uri;
        return true;
      },
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use my location'));
    await tester.pumpAndSettle();
    expect(find.text('Location access is off.'), findsOneWidget);
    await tester.tap(find.text('Old gym'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Get directions'));
    await tester.pumpAndSettle();
    expect(opened?.queryParameters['destination'], '12 Main Road');
    expect(opened?.queryParameters.containsKey('origin'), isFalse);
  });
}
