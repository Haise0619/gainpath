import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_admin_web/features/analytics/presentation/admin/branch_report_dialog.dart';

void main() {
  testWidgets('historical branch report keeps the selected date range', (tester) async {
    final calls = <Map<String, Object?>>[];
    final start = DateTime.utc(2026, 11, 1);
    final end = DateTime.utc(2026, 11, 18);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: BranchReportDialog(
      range: DateTimeRange(start: start, end: end),
      request: (input) async {
        calls.add(input);
        if (input['action'] == 'list') {
          return {'records': [
            {'branchId': 'old-gym', 'displayName': 'Old gym', 'status': 'inactive'},
          ]};
        }
        return {'branchName': 'Old gym', 'coachingMinor': 12000, 'gymVisits': 2};
      },
    ))));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Old gym (inactive)').last);
    await tester.pumpAndSettle();
    expect(calls.last, {
      'action': 'branchReport', 'branchId': 'old-gym',
      'startAtMillis': start.millisecondsSinceEpoch,
      'endAtMillis': end.millisecondsSinceEpoch,
    });
    expect(find.text('120.00'), findsOneWidget);
  });
}
