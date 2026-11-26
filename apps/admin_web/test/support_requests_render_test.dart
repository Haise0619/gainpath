import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_ui/gainpath_ui.dart';

import '../../../test_support/fyp_render_support.dart';

void main() {
  testWidgets('Render and capture screenshot artifacts for Help & Support Redesign',
      (tester) async {
    final resetFonts = await installFypOfflineFonts();
    addTearDown(resetFonts);

    final buildDir = Directory('../../build/support-redesign')
      ..createSync(recursive: true);
    final brainDir = Directory(
        'C:/Users/Ngzhe/.gemini/antigravity/brain/2e9bce9b-03ec-4533-aa97-83c6a91f9314')
      ..createSync(recursive: true);

    Future<void> capture(GlobalKey key, String name) async {
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1.0);
        final byteData =
            await image.toByteData(format: ui.ImageByteFormat.png);
        final bytes = byteData!.buffer.asUint8List();

        await File('${buildDir.path}/$name').writeAsBytes(bytes);
        await File('${brainDir.path}/$name').writeAsBytes(bytes);
        image.dispose();
      });
    }

    final sampleTickets = [
      {
        'id': 'req-202611-0081',
        'title': 'Coach missed appointment without notice',
        'status': 'Waiting for member',
        'category': 'Coach Booking',
        'memberName': 'Elena Rostova',
        'updatedAtMillis': 1795500000000,
        'createdAtMillis': 1795490000000,
        'unread': true,
        'reference': {'kind': 'Booking', 'id': 'bk-9901'},
      },
      {
        'id': 'req-202611-0082',
        'title': 'Duplicate charge on monthly membership renewal',
        'status': 'Open',
        'category': 'Payment & Refund',
        'memberName': 'Marcus Vance',
        'updatedAtMillis': 1795495000000,
        'createdAtMillis': 1795492000000,
        'unread': false,
        'reference': {'kind': 'Payment', 'id': 'pay-5544'},
      },
      {
        'id': 'req-202611-0083',
        'title': 'Locker access barcode not scanning at Downtown gym',
        'status': 'Resolved',
        'category': 'App Issue',
        'memberName': 'Sophia Chen',
        'updatedAtMillis': 1795480000000,
        'createdAtMillis': 1795470000000,
        'unread': false,
      },
    ];

    final sampleMessages = [
      {
        'role': 'Member',
        'body':
            'Hi, my coach did not arrive for our 10:00 AM personal training session at Downtown Flagship today. I waited 25 minutes. Could you please check what happened and help me reschedule or refund?',
        'createdAtMillis': 1795490000000,
      },
      {
        'role': 'Admin',
        'body':
            'Hello Elena, we sincerely apologize for the inconvenience. We reached out to Coach Rostova and confirmed an unexpected medical emergency. We have credited your account with a full session pass and can also reschedule for tomorrow at 10:00 AM if that suits your schedule. Please let us know your preference.',
        'createdAtMillis': 1795495000000,
      },
    ];

    Future<Map<String, dynamic>> mockCall(
        String action, Map<String, dynamic> input) async {
      if (action == 'list') {
        return {'tickets': sampleTickets, 'nextId': null};
      }
      if (action == 'references') {
        return {
          'references': [
            {'kind': 'Booking', 'id': 'bk-9901', 'label': 'Personal Training with Marcus · 24 Nov'},
            {'kind': 'Payment', 'id': 'pay-5544', 'label': 'MYR 120.00 · Premium Renewal'},
          ]
        };
      }
      if (action == 'detail') {
        return {
          'ticket': sampleTickets[0],
          'messages': sampleMessages,
        };
      }
      return {'id': 'req-202611-0081'};
    }

    // 1. Member Help & Support Home (393 x 852)
    {
      tester.view.resetPhysicalSize();
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;

      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.build(),
          home: SupportRequestsPage(
            key: UniqueKey(),
            call: mockCall,
            admin: false,
          ),
        ),
      ));
      await tester.pumpAndSettle();
      await capture(key, 'member_help_support_home_393.png');
    }

    // 2. Member New Support Request Form (393 x 852)
    {
      tester.view.resetPhysicalSize();
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;

      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.build(),
          home: SupportRequestsPage(
            key: UniqueKey(),
            call: mockCall,
            admin: false,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Tap "Submit a request" to open form
      await tester.tap(find.text('Submit a request'));
      await tester.pumpAndSettle();

      // Pre-fill subject and description for presentation
      await tester.enterText(
          find.byType(TextFormField).at(0), 'Coach missed scheduled training session');
      await tester.enterText(find.byType(TextFormField).at(1),
          'My coach did not arrive at Downtown Flagship today for our 10:00 AM session. Please advise on rescheduling.');
      await tester.pumpAndSettle();

      await capture(key, 'member_new_support_request_393.png');
    }

    // 3. Member Support Thread (393 x 852)
    {
      tester.view.resetPhysicalSize();
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;

      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.build(),
          home: SupportRequestsPage(
            key: UniqueKey(),
            call: mockCall,
            admin: false,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Open first ticket
      await tester.tap(find.text('Coach missed appointment without notice'));
      await tester.pumpAndSettle();

      await capture(key, 'member_support_thread_393.png');
    }

    // 4. Admin Support Queue (1280 x 800)
    {
      tester.view.resetPhysicalSize();
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;

      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.build(),
          home: Scaffold(
            body: SupportRequestsPage(
              key: UniqueKey(),
              call: mockCall,
              admin: true,
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      await capture(key, 'admin_support_queue_1280.png');
    }

    // 5. Admin Support Workspace at 1280 x 800
    {
      tester.view.resetPhysicalSize();
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;

      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.build(),
          home: Scaffold(
            body: SupportRequestsPage(
              key: UniqueKey(),
              call: mockCall,
              admin: true,
              openReference: (kind, id) {},
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Open first ticket
      await tester.tap(find.text('Coach missed appointment without notice'));
      await tester.pumpAndSettle();

      await capture(key, 'admin_support_workspace_1280.png');
    }

    // 6. Admin Support Workspace at 1536 x 900
    {
      tester.view.resetPhysicalSize();
      tester.view.physicalSize = const Size(1536, 900);
      tester.view.devicePixelRatio = 1;

      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.build(),
          home: Scaffold(
            body: SupportRequestsPage(
              key: UniqueKey(),
              call: mockCall,
              admin: true,
              openReference: (kind, id) {},
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Open first ticket
      await tester.tap(find.text('Coach missed appointment without notice'));
      await tester.pumpAndSettle();

      await capture(key, 'admin_support_workspace_1536.png');
    }

    // 7. Admin Support Workspace at 1024 x 768
    {
      tester.view.resetPhysicalSize();
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1;

      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.build(),
          home: Scaffold(
            body: SupportRequestsPage(
              key: UniqueKey(),
              call: mockCall,
              admin: true,
              openReference: (kind, id) {},
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Open first ticket
      await tester.tap(find.text('Coach missed appointment without notice'));
      await tester.pumpAndSettle();

      await capture(key, 'admin_support_workspace_1024.png');
    }
  });
}
