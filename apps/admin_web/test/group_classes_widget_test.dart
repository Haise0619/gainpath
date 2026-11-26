import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_admin_web/features/group_classes/group_classes_admin.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../../test_support/fyp_render_support.dart';
import '../../../test_support/member_demo_render_fonts.dart';
import 'package:gainpath_admin_web/features/operations_calendar/operations_calendar_data.dart';

final start = DateTime.utc(2026, 11, 28, 2).millisecondsSinceEpoch;
final first = <String, dynamic>{
  'id': 'strength',
  'title': 'Strength Lab',
  'description':
      'A full-body strength class built around simple lifting patterns.',
  'category': 'Strength',
  'branchId': 'main',
  'branchName': 'Main Branch',
  'coachId': 'coach',
  'instructor': 'Alicia Tan',
  'specialty': 'Strength & Conditioning',
  'venue': 'Studio A',
  'startAtMillis': start,
  'endAtMillis': start + 3600000,
  'activeCount': 12,
  'capacity': 16,
  'status': 'Open',
  'state': 'Published',
  'difficulty': 'All levels',
  'eligibility': 'All Members',
  'cancellationCount': 1,
};
final second = <String, dynamic>{
  ...first,
  'id': 'yoga',
  'title': 'Sunday Reset Yoga',
  'category': 'Yoga',
  'branchName': 'West Branch',
  'instructor': 'Marcus Lim',
  'eligibility': 'Premium Only',
  'status': 'Full',
  'activeCount': 16,
};

Future<void> _capture(WidgetTester tester, GlobalKey key, String name) async {
  final target = Platform.environment['GAINPATH_CLASS_SCREENSHOT_DIR'];
  if (target == null) return;
  for (var i = 0; i < 6; i++) {
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 25)));
    await tester.pump();
  }
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      final body = await image.toByteData(format: ui.ImageByteFormat.png);
      final folder = Directory(target)..createSync(recursive: true);
      File('${folder.path}/$name.png')
          .writeAsBytesSync(body!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}

void main() {
  setUpAll(loadDemoRenderFonts);

  testWidgets('class cover previews locally before upload and can retry',
      (tester) async {
    addTearDown(await installFypOfflineFonts());
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final bytes = (await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawPaint(Paint()..color = Colors.purple);
      final picture = recorder.endRecording();
      final image = await picture.toImage(16, 9);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      picture.dispose();
      return data!.buffer.asUint8List();
    }))!;
    final started = Completer<void>();
    final upload = Completer<Map<String, dynamic>>();
    final attempts = <Map<String, dynamic>>[];
    String? savedDraftId;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.build(),
      home: Scaffold(
        body: GroupClassesAdminPage(
          pickCover: () async => XFile.fromData(bytes, name: 'cover.png'),
          call: (action, input) async {
            switch (action) {
              case 'list':
                return {
                  'classes': [first]
                };
              case 'options':
                return {
                  'branches': [
                    {'id': 'main', 'name': 'Main Branch'}
                  ],
                  'coaches': [
                    {'id': 'coach', 'name': 'Alicia Tan', 'specialty': 'Yoga'}
                  ],
                };
              case 'uploadCover':
                attempts.add(input);
                if (attempts.length == 1) {
                  started.complete();
                  return upload.future;
                }
                return {'url': 'https://example.invalid/cover.png'};
              case 'save':
                savedDraftId = input['id'] as String;
                return {};
              case 'publish':
                expect(input['id'], savedDraftId);
                throw FirebaseFunctionsException(
                  code: 'failed-precondition',
                  message:
                      'The coach has no availability at this branch for the full class time.',
                  stackTrace: StackTrace.fromString('private stack trace'),
                );
              default:
                throw StateError('Unexpected action: $action');
            }
          },
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create class').first);
    await tester.pumpAndSettle();
    final selectCover = find.text('Upload Cover Photo');
    await tester.ensureVisible(selectCover);
    await tester.tap(selectCover);
    for (var i = 0; i < 50 && !started.isCompleted; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
    expect(started.isCompleted, isTrue);
    expect(find.text('Uploading cover…'), findsOneWidget);
    expect(
      tester
          .widgetList<GroupClassCover>(find.byType(GroupClassCover))
          .where((cover) => cover.bytes != null),
      hasLength(2),
    );
    upload.completeError(StateError('Upload unavailable'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not upload cover'), findsOneWidget);
    final retry = find.text('Retry upload');
    await tester.ensureVisible(retry);
    await tester.tap(retry);
    await tester.pumpAndSettle();
    expect(find.text('Cover uploaded'), findsOneWidget);
    expect(attempts, hasLength(2));
    expect(attempts.first['uploadId'], attempts.last['uploadId']);
    expect(attempts.last['contentType'], 'image/png');
    expect(find.text('All Members'), findsNothing);
    expect(find.text('Paid Members'), findsWidgets);

    final name = find.widgetWithText(TextFormField, 'Class Name *');
    await tester.ensureVisible(name);
    await tester.enterText(name, 'Yoga class');
    final description = find.widgetWithText(TextFormField, 'Description *');
    await tester.ensureVisible(description);
    await tester.enterText(description, 'Practice basic yoga.');
    await tester.tap(find.text('Next Step'));
    await tester.pumpAndSettle();
    final instructorType = find.byType(SegmentedButton<bool>);
    final coach = find.byType(DropdownButtonFormField<String>).last;
    expect(find.text('Assign Coach *'), findsOneWidget);
    expect(
        tester.getTopLeft(coach).dy - tester.getBottomLeft(instructorType).dy,
        greaterThanOrEqualTo(16));
    await tester.tap(find.text('Next Step'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Publish Class'));
    await tester.pumpAndSettle();
    expect(savedDraftId, isNotNull);
    final publishError = find.text(
        'Draft saved. The coach has no availability at this branch for the full class time.');
    expect(tester.widget<Text>(publishError).style?.color, AppColors.danger);
    expect(find.textContaining('private stack trace'), findsNothing);
    await tester.tap(find.text('Edit schedule'));
    await tester.pumpAndSettle();
    expect(find.text('Assign Coach *'), findsOneWidget);
    int previewTime(String field) => tester
        .widget<GroupClassCard>(find.byType(GroupClassCard).last)
        .row[field] as int;
    final oldStart = previewTime('startAtMillis');
    final startPicker = find.text('Class Start Time (MYT)');
    await tester.ensureVisible(startPicker);
    await tester.tap(startPicker);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Next month'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('15').last);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    final newStart = previewTime('startAtMillis');
    expect(newStart, isNot(oldStart));
    expect(previewTime('endAtMillis') - newStart,
        const Duration(hours: 1).inMilliseconds);
    expect(tester.takeException(), isNull);
  });

  test('group classes use the existing calendar event model and branch filter',
      () async {
    final from =
        DateTime.fromMillisecondsSinceEpoch(start - 3600000, isUtc: true);
    final to = from.add(const Duration(days: 1));
    final repo = FirebaseOperationsCalendarRepository((_) async {
      throw StateError(
          'Existing booking endpoint must not receive the group class type.');
    }, groupClasses: (action, input) async {
      expect(action, 'calendar');
      expect(input['branchId'], 'main');
      expect(input['startAtMillis'], from.millisecondsSinceEpoch);
      return {
        'classes': [first]
      };
    });
    final result = await repo.loadEvents(
        start: from,
        end: to,
        types: {CalendarEventType.groupClass},
        branchId: 'main');
    expect(result.events.single.type, CalendarEventType.groupClass);
    expect(result.events.single.sourceId, 'strength');
    expect(result.events.single.description, contains('12/16 registered'));
  });

  testWidgets('reports calculate rates from marked attendance only',
      (tester) async {
    addTearDown(await installFypOfflineFonts());
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(),
      home: Scaffold(
          body: GroupClassAnalytics(
              call: (_, __) async => {
                    'classes': [
                      {
                        ...first,
                        'status': 'Completed',
                        'attendedCount': 2,
                        'absentCount': 1,
                        'totalRegistrations': 12,
                      }
                    ],
                  })),
    ));
    await tester.pumpAndSettle();
    expect(find.text('66.7%'), findsOneWidget);
    expect(
        find.text('2 attended · 3 attendance records marked'), findsOneWidget);
  });

  testWidgets('member discovers, registers and sees the entry under My Classes',
      (tester) async {
    addTearDown(await installFypOfflineFonts());
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    var registered = false;
    Future<Map<String, dynamic>> call(
        String action, Map<String, dynamic> input) async {
      final row = {...first, 'registration': registered ? 'Registered' : null};
      if (action == 'join') {
        registered = true;
        return {'saved': true};
      }
      if (action == 'detail') {
        return {
          'item': {...row, 'eligible': true},
          'serverNowMillis': start - 86400000
        };
      }
      return {
        'classes': [row, second]
      };
    }

    await tester.pumpWidget(RepaintBoundary(
        key: key,
        child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.build(),
            home: Scaffold(
                appBar: AppBar(title: const Text('Group Classes')),
                body: MemberGroupClassesPage(call: call, onUpgrade: () {})))));
    await tester.pumpAndSettle();
    expect(find.text('Strength Lab'), findsOneWidget);
    await _capture(tester, key, 'member-group-classes');
    await tester.tap(find.text('Strength Lab'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Join Class'));
    await tester.tap(find.text('Join Class'));
    await tester.pumpAndSettle();
    expect(find.textContaining('You’re registered'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('My Classes'));
    await tester.pumpAndSettle();
    expect(find.text('Strength Lab'), findsOneWidget);
    expect(find.text('Sunday Reset Yoga'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('admin opens the participants drawer from the catalogue',
      (tester) async {
    addTearDown(await installFypOfflineFonts());
    tester.view.physicalSize = const Size(1280, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.build(),
          home:
              Scaffold(body: GroupClassesAdminPage(call: (action, input) async {
            if (action == 'detail') {
              return {
                'item': first,
                'participants': [
                  {
                    'name': 'Fixture Member',
                    'memberId': 'member',
                    'status': 'Registered'
                  },
                ]
              };
            }
            return {
              'classes': [first, second]
            };
          })),
        )));
    await tester.pumpAndSettle();
    expect(find.text('Create class'), findsOneWidget);
    await _capture(tester, key, 'admin-group-classes');
    await tester.tap(find.text('Strength Lab'));
    await tester.pumpAndSettle();
    expect(find.text('Class details'), findsOneWidget);
    expect(find.text('Fixture Member'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'published scheduled class saves registration edits without publishing again',
      (tester) async {
    addTearDown(await installFypOfflineFonts());
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final now = DateTime.now().toUtc();
    final classStart = DateTime.utc(now.year, now.month + 1, 15, 2);
    final opens = DateTime.utc(now.year, now.month + 1, 12, 1);
    final newOpens = opens.add(const Duration(days: 1)).millisecondsSinceEpoch;
    final scheduled = {
      ...first,
      'status': 'Scheduled',
      'startAtMillis': classStart.millisecondsSinceEpoch,
      'endAtMillis':
          classStart.add(const Duration(hours: 1)).millisecondsSinceEpoch,
      'openAtMillis': opens.millisecondsSinceEpoch,
      'closeAtMillis':
          classStart.subtract(const Duration(hours: 2)).millisecondsSinceEpoch,
    };
    final writes = <String>[];
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.build(),
      home: Scaffold(body: GroupClassesAdminPage(call: (action, input) async {
        switch (action) {
          case 'list':
            return {
              'classes': [scheduled]
            };
          case 'detail':
            return {'item': scheduled, 'participants': []};
          case 'options':
            return {
              'branches': [
                {'id': 'main', 'name': 'Main Branch'}
              ],
              'coaches': [
                {'id': 'coach', 'name': 'Alicia Tan', 'specialty': 'Yoga'}
              ],
            };
          case 'save':
            writes.add(action);
            expect(input['id'], scheduled['id']);
            expect((input['item'] as Map)['openAtMillis'], newOpens);
            return {};
          case 'publish':
            writes.add(action);
            throw StateError('This class is already published.');
          default:
            throw StateError('Unexpected action: $action');
        }
      })),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Strength Lab'));
    await tester.pumpAndSettle();
    final edit = find.text('Edit class');
    await tester.ensureVisible(edit);
    await tester.tap(edit);
    await tester.pumpAndSettle();
    await tester.tap(find.text('3. Registration'));
    await tester.pumpAndSettle();
    expect(find.text('Publish Class'), findsNothing);
    expect(find.text('Save Draft'), findsNothing);
    final registrationOpens = find.text('Registration Opens');
    await tester.ensureVisible(registrationOpens);
    await tester.tap(registrationOpens);
    await tester.pumpAndSettle();
    await tester.tap(find.text('13').last);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save changes').last);
    await tester.pumpAndSettle();
    expect(writes, ['save']);
    expect(find.text('Create class'), findsOneWidget);
  });
}
