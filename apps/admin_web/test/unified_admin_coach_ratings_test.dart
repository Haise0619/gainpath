import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_admin_web/infrastructure/firebase/firebase_unified_admin.dart';
import 'package:gainpath_admin_web/infrastructure/firebase/unified_admin_directories.dart';
import 'coach_directory_publication_flow_test.dart' show AdminFake;

void main() {
 test('ordinary unified Admin hydrates canonical and cohort ratings separately', () async {
  final scope=SessionScope(userId:'admin',organizationId:'gainpath');
  final canonical=AdminFake(scope)..seed();
  Map<String,Object?> row(String id,String source)=>{'id':id,'source':source,'record':{
   ...canonical.fields.toJson(),'schemaVersion':1,'revision':1,'sourceRevision':1,'status':'published','branchIds':['main'],'createdAtMillis':1,'updatedAtMillis':1,'publishedAtMillis':1,
  }};
  final transport=UnifiedAdminTransport(scope:scope,isCurrent:()=>true,currentUid:()=>'admin',invoke:(data) async {
   if(data['operation']=='admin.unified.directory') return {'items':[row('jackson','existing'),row('demo','fyp')],'nextCursor':'next'};
   expect(data['operation'],'admin.unified.cohort');
   final input=data['data'] as Map;
   expect(input['operation'],'module/getCoachRatingsCommand');
   expect((input['input'] as Map)['coachIds'],['demo']);
   return {'schemaVersion':1,'records':[{'coachId':'demo','averageRating':null,'reviewCount':0}]};
  });
  final repo=UnifiedAdminCoachDirectory(transport,canonical,readExistingRatings:(ids) async {
   expect(ids,['jackson']);
   return {'schemaVersion':1,'records':[{'coachId':'jackson','averageRating':4.0,'reviewCount':1}]};
  });
  final page=await repo.loadPublicPage();
  expect(page.items.first.averageRating,4.0);
  expect(page.items.first.reviewCount,1);
  expect(page.items.last.averageRating,isNull);
  expect(page.items.last.reviewCount,0);
  expect(page.nextCursor,'next');
 });
}
