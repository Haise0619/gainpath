import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/io_client.dart';
import 'package:gainpath_data/gainpath_data.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_admin_web/app/admin_app.dart';
import 'package:gainpath_admin_web/app/shells/admin_shell.dart';
import 'package:gainpath_admin_web/infrastructure/firebase/firebase_unified_admin.dart';
import 'package:gainpath_admin_web/infrastructure/firebase/unified_admin_directories.dart';
import 'package:gainpath_admin_web/infrastructure/firebase/firebase_admin_reporting_gateway.dart';
import '../../../../test_support/fyp_emulator_gateway.dart';
import '../../../../test_support/fyp_render_support.dart';
import '../../../../test_support/fyp_widget_waits.dart';
import '../../../mobile/test/support/signed_out_firebase.dart';
import '../support/module13_demo_render.dart' show loadDemoRenderFonts;

class _CanonicalMembers implements AdminMemberDirectoryRepository {
 @override
 dynamic noSuchMethod(Invocation invocation)=>super.noSuchMethod(invocation);
}
class _CanonicalCoaches implements CoachProfileAdminRepository {
 _CanonicalCoaches(this.scope);
 @override final SessionScope scope;
 @override Future<bool> canManageDirectory()async=>true;
 @override dynamic noSuchMethod(Invocation invocation)=>super.noSuchMethod(invocation);
}
void main(){
 setUpAll(setUpSignedOutFirebase);setUpAll(loadDemoRenderFonts);setUpAll(()=>GoogleFonts.config.allowRuntimeFetching=false);
 testWidgets('ordinary canonical Admin login renders actual unified emulator services without generation or Send',(tester)async{
  final disposeFonts=await installFypOfflineFonts();addTearDown(disposeFonts);final previous=HttpOverrides.current;HttpOverrides.global=null;
  final client=IOClient(HttpClient()..idleTimeout=Duration.zero..connectionTimeout=const Duration(seconds:5)),gateway=FypEmulatorGateway(client,canonicalAdminOnly:true),auth=FirebaseAuthRepository(gateway);
  addTearDown(()async{await tester.pumpWidget(const SizedBox());client.close();unawaited(auth.dispose());unawaited(gateway.dispose());HttpOverrides.global=previous;});
  tester.view.physicalSize=const Size(1440,1100);tester.view.devicePixelRatio=1;addTearDown(tester.view.reset);
  const key=ValueKey('unified-ordinary-admin');
  UnifiedAdminTransport transport(SessionScope scope,bool Function() current)=>UnifiedAdminTransport(scope:scope,isCurrent:current,currentUid:()=>gateway.current?.userId,invoke:(data)=>gateway.invoke('fypDatasetCommand',data));
  Future<void> capture(String name)async{await tester.pump();await tester.runAsync(()async{final b=tester.renderObject<RenderRepaintBoundary>(find.byKey(key)),image=await b.toImage(),data=await image.toByteData(format:ui.ImageByteFormat.png);final f=File('../../build/unified-admin-20261104/screenshots/emulator-$name.png');await f.parent.create(recursive:true);await f.writeAsBytes(data!.buffer.asUint8List());image.dispose();});}
  await tester.pumpWidget(RepaintBoundary(key:key,child:fypOfflineChartFonts(GainPathAdminWebApp.injected(authRepository:auth,
    datasetTransportFactory:transport,
    memberDirectoryFactory:(scope,current)=>UnifiedAdminMemberDirectory(transport(scope,current),_CanonicalMembers()),
    coachRepositoryFactory:(scope,current)=>UnifiedAdminCoachDirectory(transport(scope,current),_CanonicalCoaches(scope)),
    reportingGatewayFactory:(scope,current)=>FirebaseAdminReportingGateway(scope:scope,isCurrent:current,currentUid:()=>gateway.current?.userId,unified:true,
      invoke:(data)async{final r=await transport(scope,current).read('report',data);debugPrint('[unified-widget] report received unified=${r.containsKey('unified')}');return r;},workoutInvoke:(data)=>transport(scope,current).read('workouts',data))
  ))));
  await tester.pumpAndSettle();await tester.enterText(find.byType(TextField).at(0),'canonical-admin@fixture.invalid');await tester.enterText(find.byType(TextField).at(1),Platform.environment['UNIFIED_EMULATOR_PASSWORD']!);await tester.tap(find.widgetWithText(FilledButton,'Sign in'));
  await waitForFypWidget(tester,find.byType(AdminShell),description:'Canonical Admin shell');expect(gateway.current?.datasetScope,isNull);
  await waitForFypWidget(tester,find.text('MYR 4025.00'),description:'Combined calculated business Dashboard',diagnostics:()=>tester.widgetList<Text>(find.byType(Text)).map((w)=>w.data??'').where((x)=>x.isNotEmpty).take(100).join(' | '));expect(find.text('Dashboard Overview'),findsOneWidget);await waitForFypWidget(tester,find.text('52'),description:'Validated server-backed workout session KPI');await capture('dashboard');
  await tester.tap(find.text('Reports').first);await waitForFypWidget(tester,find.text('Revenue Overview'),description:'Server-backed Reports unified financial section');
  await tester.tap(find.text('Revenue').first);await tester.pump(const Duration(seconds:2));await tester.ensureVisible(find.text('Revenue Overview'));await tester.pump(const Duration(seconds:1));await capture('reports-revenue');
  await tester.tap(find.text('Members').first);await waitForFypWidget(tester,find.text('Demo Learner 01'),description:'Unified Member directory');await capture('members');
  await tester.tap(find.text('Coaches').first);await waitForFypWidget(tester,find.textContaining('Bela'),description:'Unified Coach directory');await capture('coaches');
  await tester.tap(find.text('Recommendations').first);await waitForFypWidget(tester,find.text('Exercise Insights'),description:'Original Insights tab');await waitForFypWidget(tester,find.textContaining('Configuration revision 1'),description:'Actual scoped insights');await capture('insights');
  await tester.tap(find.text('Trainer Matching'));await waitForFypWidget(tester,find.textContaining('Pending: 4'),description:'Preserved Trainer lead queue');final refresh=find.ancestor(of:find.text('Refresh queue'),matching:find.byWidgetPredicate((w)=>w is FilledButton));expect(tester.widget<FilledButton>(refresh).onPressed,isNull);expect(find.widgetWithText(FilledButton,'Send'),findsNothing);await capture('trainer');
  expect(gateway.authSignInRequests,1);expect(gateway.protectedSessionRequests,0);
 });
}
