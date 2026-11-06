import 'package:gainpath_domain/workout.dart';
import '../../features/workout/domain/admin_workout_program_repository.dart';
import 'firebase_unified_admin.dart';
import 'unified_admin_directories.dart' show unifiedMap;

class UnifiedAdminPrograms implements AdminWorkoutProgramRepository {
  UnifiedAdminPrograms(this.transport,this.canonical);
  final UnifiedAdminTransport transport;
  final AdminWorkoutProgramRepository canonical;
  final Set<String> _fypIds={};
  final Set<String> _canonicalRoutineIds={};
  @override
  bool get current=>transport.isCurrent&&canonical.current;
  @override
  Future<AdminProgramCatalog> load() async {
    final r=await transport.read('programs',{});
    _fypIds..clear()..addAll(List<String>.from(r['fypProgramIds'] as List));
    _canonicalRoutineIds..clear()..addAll((r['routines'] as List).map(unifiedMap).where((d)=>d['source']=='existing').map((d)=>d['id'] as String));
    return AdminProgramCatalog(programs:(r['programs'] as List).map((e)=>WorkoutProgram.fromJson(unifiedMap(e))).toList(),
      drafts:(r['drafts'] as List).map((e){final d=unifiedMap(e),p=WorkoutProgram.fromJson(unifiedMap(d['program']));return AdminProgramDraft(p,d['revision'] as int,readOnly:_fypIds.contains(p.id));}).toList(),
      routines:(r['routines'] as List).map((e){final d=unifiedMap(e),record=unifiedMap(d['record']);return ProgramRoutineChoice(id:d['id'] as String,title:record['title'] as String,snapshot:record,readOnly:d['source']!='existing');}).toList());
  }
  void _write(String id){if(!current||_fypIds.contains(id)||id.startsWith('demo-m13-'))throw StateError('FYP Programs are read-only in the unified Admin.');}
  @override
  Future<int> saveDraft(WorkoutProgram program,{required int expectedRevision,required String requestId}){_write(program.id);if(program.days.any((day)=>day.routineId!=null&&!_canonicalRoutineIds.contains(day.routineId)))throw StateError('Canonical Programs require a current canonical Routine reference.');return canonical.saveDraft(program,expectedRevision:expectedRevision,requestId:requestId);}
  @override
  Future<AdminProgramDraft> publish(String id,{required int expectedRevision,required String requestId}){_write(id);return canonical.publish(id,expectedRevision:expectedRevision,requestId:requestId);}
}

class UnifiedAdminRoutines implements RoutineTemplateRepository,RoutineArchivingRepository {
  UnifiedAdminRoutines(this.transport,this.canonical,this.catalog);
  final UnifiedAdminTransport transport;
  final RoutineTemplateRepository canonical;
  final TutorialRepository catalog;
  @override
  List<RoutineBlueprint> get routineTemplates=>const [];
  Future<List<Map<String,dynamic>>> _all(String kind) async {final result=<Map<String,dynamic>>[];String? after;
    do{final r=await transport.read('directory',{'kind':kind,'source':'fyp','limit':50,if(after!=null)'afterId':after});result.addAll((r['items'] as List).map(unifiedMap));after=r['nextCursor'] as String?;if(result.length>200)throw StateError('Content scan exceeds limit.');}while(after!=null);return result;
  }
  @override
  Future<List<RoutineBlueprint>> load() async {
    final existing=await canonical.load(),rows=await _all('routineBlueprints'),names={for(final exercise in await catalog.load())exercise.id:exercise.title};
    final ids=existing.map((x)=>x.id).toSet();
    return [...existing,...rows.where((r)=>unifiedMap(r['record'])['archived']!=true).map((r){final d=unifiedMap(r['record']);if(!ids.add(r['id'] as String))throw StateError('Duplicate Routine identity');
      return RoutineBlueprint(id:r['id'] as String,name:d['name'] as String,level:d['level'] as String,assignedMembers:0,sessionDurationMin:d['sessionDurationMin'] as int,readOnly:true,
        days:(d['days'] as List).map((raw){final day=unifiedMap(raw);return RoutineDay(day['dayNumber'] as int,(day['exercises'] as List).map((x){final e=unifiedMap(x),id=e['exerciseId'] as String;if(!names.containsKey(id))throw const FormatException('Missing source exercise');return RoutineExerciseRef(names[id]!,e['sets'] as int,e['reps'] as int,exerciseId:id);}).toList());}).toList());
    })];
  }
  @override
  Future<RoutineBlueprint> save(RoutineBlueprint b){if(b.readOnly||b.id.startsWith('demo-m13-'))throw StateError('FYP Routines are read-only.');return canonical.save(b);}
  @override
  Future<void> publish(String id){if(id.startsWith('demo-m13-'))throw StateError('FYP Routines are read-only.');return canonical.publish(id);}
  @override
  Future<void> archive(RoutineBlueprint b){if(b.readOnly||canonical is! RoutineArchivingRepository)throw StateError('This Routine cannot be archived.');return (canonical as RoutineArchivingRepository).archive(b);}
}
