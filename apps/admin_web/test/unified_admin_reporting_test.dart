import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_admin_web/infrastructure/firebase/firebase_admin_reporting_gateway.dart';
import 'package:gainpath_admin_web/infrastructure/firebase/firebase_admin_workout_report.dart';
import 'package:gainpath_admin_web/features/recommendation/application/recommendation_queue_repository.dart';
import 'firebase_admin_reporting_test.dart' as support;
import 'admin_workout_reporting_test.dart' show workoutResponse;

Map<String,dynamic> unifiedResponse()=>{
 ...support.reportingResponse(),'currentAccounts':{'members':21,'coaches':8},'sourceCounts':{'members':31,'bookings':3,'transactions':4},
 'unified':{'schemaVersion':1,'sourceBreakdown':{'existing':{'members':3,'coaches':1},'fyp':{'members':18,'coaches':7}},'illustrativeRevenueMinor':23900,
  'sampleBusiness':{'provenance':'fyp_business_simulation','currency':'MYR','simulatedRevenueMinor':10000,'membershipRevenueMinor':6000,'coachingRevenueMinor':4000,
   'subscriptions':{'total':18,'active':17,'expired':1,'free':6,'basic':6,'premium':6},'appointments':{'total':24,'completed':16,'cancelled':8},'monthly':[{'month':'2026-10','amountMinor':10000}]}}
};
void main(){
 test('missing Firebase session cannot retain another account snapshot or throw outside the reporting guard',(){final gateway=FirebaseAdminReportingGateway(scope:support.reportingScope,isCurrent:()=>true,currentUid:()=>throw StateError('SDK not initialized'),invoke:(_)async=>throw StateError('must not read'));expect(gateway.canRetainSnapshot,isFalse);});
 test('combined census and sample CSV never relabel simulated amounts as existing provider receipts',(){final s=parseAdminOperationalReport(unifiedResponse(),support.reportingScope,support.reportingQuery);expect(s.activeMembersCount,21);expect(s.totalRevenue!.minorUnits,13900);expect(s.unified!.simulatedMinor,10000);expect(s.unified!.illustrativeMinor,23900);expect(s.unified!.toCsv().first.join(' '),contains('not settled income'));expect(s.operations!.toCsv(s).expand((r)=>r).whereType<String>().join(' '),contains('FYP fictional'));});
 test('rejects inconsistent source-count and illustrative-money claims',(){for(final mutate in [ (Map<String,dynamic> q){(q['unified'] as Map)['illustrativeRevenueMinor']=999;},(Map<String,dynamic> q){((q['unified'] as Map)['sourceBreakdown']['fyp'] as Map)['members']=17;}]){final q=unifiedResponse();mutate(q);expect(()=>parseAdminOperationalReport(q,support.reportingScope,support.reportingQuery),throwsFormatException);}});
 test('mixed workout provenance requires explicit unified composition and remains present in export',(){final raw={...workoutResponse(),'classification':'mixed_descriptive_sources','containsFictional':true,'sourceBreakdown':{'existing':{'sessions':0},'fyp':{'sessions':2}}};expect(()=>parseAdminWorkoutReport(raw,support.reportingScope,support.reportingQuery),throwsFormatException);final r=parseAdminWorkoutReport(raw,support.reportingScope,support.reportingQuery,allowUnified:true);expect(r.mixedSources,true);expect(r.totals.sessions,2);expect(r.toCsv().first.last,contains('mixed_descriptive_sources'));final csv=r.toCsv().expand((r)=>r).whereType<String>().join(' ');expect(csv,contains('FYP simulation'));expect(csv, isNot(contains('Camera sessions')));expect(csv,isNot(contains('Latest backups of current active Member accounts only')));});
 test('read-only recommendation repository refuses refresh before invoking any transport',()async{var requests=0;final r=RpcRecommendationQueueRepository(organizationId:'gainpath',readOnly:true,isCurrent:()=>true,invoke:(_,__)async{requests++;return {};});await expectLater(r.refresh('trainer','must-not-send'),throwsA(isA<RecommendationQueueUnavailable>()));expect(requests,0);});
}
