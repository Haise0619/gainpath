import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_domain/workout.dart';
import 'package:gainpath_admin_web/infrastructure/firebase/firebase_unified_admin.dart';
import 'package:gainpath_admin_web/infrastructure/firebase/unified_admin_content.dart';
import 'package:gainpath_admin_web/features/workout/domain/admin_workout_program_repository.dart';

class _Canonical implements AdminWorkoutProgramRepository {
  int saves=0;
  @override bool get current=>true;
  @override Future<int> saveDraft(WorkoutProgram program,{required int expectedRevision,required String requestId})async{ saves++;return 1; }
  @override dynamic noSuchMethod(Invocation invocation)=>super.noSuchMethod(invocation);
}
class _CanonicalRoutines implements RoutineTemplateRepository {
  @override List<RoutineBlueprint> get routineTemplates=>const [];
  @override Future<List<RoutineBlueprint>> load()async=>[];
  @override dynamic noSuchMethod(Invocation invocation)=>super.noSuchMethod(invocation);
}
class _CanonicalCatalog implements TutorialRepository {
 @override Future<List<TutorialVideo>> load()async=>[TutorialVideo(id:'canonical-squat',title:'Squat',category:'Lower Body',status:TutorialStatus.active)];
 @override dynamic noSuchMethod(Invocation invocation)=>super.noSuchMethod(invocation);
}
void main(){test('canonical drafts cannot consume read-only FYP Routine references',()async{
  final canonical=_Canonical(),scope=SessionScope(userId:'admin',organizationId:'gainpath');
  final transport=UnifiedAdminTransport(scope:scope,isCurrent:()=>true,currentUid:()=>scope.userId,invoke:(_)async=>{
    'programs':[],'drafts':[],'fypProgramIds':[], 'routines':[
      {'id':'canonical-routine','source':'existing','record':{'title':'Canonical Routine','exercises':[]}},
      {'id':'demo-m13-routine','source':'fyp','record':{'title':'FYP Routine','exercises':[]}}
    ]});
  final repository=UnifiedAdminPrograms(transport,canonical),catalog=await repository.load();
  final template=WorkoutProgram.templates().first.toJson();
  template['days']=(template['days'] as List).map((raw){final day=Map<String,dynamic>.from(raw as Map);if(day['kind']=='workout')day['routineId']='demo-m13-routine';return day;}).toList();
  await expectLater(Future.sync(()=>repository.saveDraft(WorkoutProgram.fromJson(template),expectedRevision:0,requestId:'blocked')),throwsStateError);
  expect(canonical.saves,0);
  expect(catalog.routines.where((r)=>!r.readOnly).map((r)=>r.id),['canonical-routine']);
  expect(catalog.routines,hasLength(2));
});
test('FYP Routine exercise names resolve canonical catalog references through authorized combined reads',()async{
 final scope=SessionScope(userId:'admin',organizationId:'gainpath');
 final transport=UnifiedAdminTransport(scope:scope,isCurrent:()=>true,currentUid:()=>scope.userId,invoke:(data)async{
  final input=data['data'] as Map;final kind=input['kind'];if(kind=='exerciseVideos')throw StateError('Shared exercise IDs must use the existing canonical catalog, not a cross-source identity merge');
  return {'nextCursor':null,'items':kind=='routineBlueprints'?[{'id':'demo-m13-routine','record':{'name':'FYP squat','level':'Beginner','sessionDurationMin':12,'days':[{'dayNumber':1,'exercises':[{'exerciseId':'canonical-squat','sets':3,'reps':8}]}]}}]:input['source']=='all'?[{'id':'canonical-squat','record':{'exerciseName':'Squat'}}]:[]};
 });
 final result=await UnifiedAdminRoutines(transport,_CanonicalRoutines(),_CanonicalCatalog()).load();expect(result.single.readOnly,true);expect(result.single.days.single.exercises.single.exerciseId,'canonical-squat');
});}
