import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_domain/membership.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'firebase_unified_admin.dart';
import 'admin_coach_ratings.dart';
import 'firebase_function_transport.dart';
import '../../features/gamification/reward_fulfilment_repository.dart';

Map<String,dynamic> unifiedMap(Object? value) => Map<String,dynamic>.from(value as Map);

class UnifiedAdminMemberDirectory implements AdminMemberDirectoryRepository, MembershipVerificationRepository,RewardFulfilmentRepository {
  UnifiedAdminMemberDirectory(this.transport,this.canonical);
  final UnifiedAdminTransport transport;
  final AdminMemberDirectoryRepository canonical;
  @override
  Future<AdminMemberPage> loadPage({String query='',String status='All',String? afterId}) async {
    final page=await transport.read('directory',{'kind':'members','query':query,'status':status,if(afterId!=null)'afterId':afterId});
    return AdminMemberPage((page['items'] as List).map((raw) {
      final row=unifiedMap(raw), data=unifiedMap(row['record']);
      return AdminMemberRecord(id:row['id'] as String,name:(data['displayName']??data['email']??row['id']) as String,
        email:data['email'] as String? ?? '',status:data['status'] as String,source:row['source'] as String);
    }).toList(),nextCursor:page['nextCursor'] as String?);
  }
  @override
  Future<AdminMemberDetails> loadDetails(String memberId) async {
    final row = await transport.read('member', {'memberId': memberId}),
        data = unifiedMap(row['record']);
    final isReadOnly = row['readOnly'] == true;
    final extra = List<Map<String, String>>.from((row['extra'] as List? ?? [])
        .map((e) => Map<String, String>.from(e as Map)));
    if (!isReadOnly) {
      try {
        final canonicalDetails = await canonical.loadDetails(memberId);
        if (canonicalDetails.extra.isNotEmpty) {
          final existingLabels = extra.map((e) => e['label']).toSet();
          for (final item in canonicalDetails.extra) {
            if (!existingLabels.contains(item['label'])) {
              extra.add(item);
            }
          }
        }
      } catch (_) {}
    }
    return AdminMemberDetails(
        member: AdminMemberRecord(
            id: memberId,
            name: (data['displayName'] ?? data['email'] ?? memberId) as String,
            email: data['email'] as String? ?? '',
            status: data['status'] as String,
            source: row['source'] as String),
        organizationId: transport.scope.organizationId,
        branchIds: List<String>.from(data['branchIds'] as List? ?? []),
        createdAtMillis: data['createdAtMillis'] as int?,
        updatedAtMillis: data['updatedAtMillis'] as int?,
        readOnly: isReadOnly,
        extra: extra);
  }
  @override
  bool get current => transport.isCurrent;
  @override
  Future<MemberMembershipVerification> verifyMembership(String memberId) async {
    final detail=await loadDetails(memberId);
    if(detail.readOnly || canonical is! MembershipVerificationRepository) throw StateError('FYP subscription information is simulation only.');
    return (canonical as MembershipVerificationRepository).verifyMembership(memberId);
  }
  @override
  Future<AdminRewardVoucher> inspect(String id) {
    if(!current||canonical is! RewardFulfilmentRepository)throw StateError('Reward collection unavailable.');
    return (canonical as RewardFulfilmentRepository).inspect(id);
  }
  @override
  Future<AdminRewardVoucher> fulfil(String id) {
    if(!current||canonical is! RewardFulfilmentRepository)throw StateError('Reward collection unavailable.');
    return (canonical as RewardFulfilmentRepository).fulfil(id);
  }
}

class UnifiedAdminCoachDirectory implements CoachProfileAdminRepository {
  UnifiedAdminCoachDirectory(this.transport,this.canonical, {this.readExistingRatings});
  final Future<Map<String, dynamic>> Function(List<String>)? readExistingRatings;
  final UnifiedAdminTransport transport;
  final CoachProfileAdminRepository canonical;
  @override
  SessionScope get scope => canonical.scope;
  @override
  Future<bool> canManageDirectory()=>canonical.canManageDirectory();
  Future<CoachDirectoryPage<T>> _page<T>(String kind,String? after,T Function(String,Map<String,dynamic>) parse) async {
    final page=await transport.read('directory',{'kind':kind,'limit':20,if(after!=null)'afterId':after});
    return CoachDirectoryPage((page['items'] as List).map((e){final r=unifiedMap(e);return parse(r['id'] as String,unifiedMap(r['record']));}).toList(),nextCursor:page['nextCursor'] as String?);
  }
  @override
  Future<CoachDirectoryPage<CoachProfessionalProfile>> loadDraftPage({String? afterId})=>_page('coachProfiles',afterId,CoachProfessionalProfile.fromDocument);
  @override
  Future<CoachDirectoryPage<PublishedCoachProfile>> loadPublicPage({String? afterId}) async {
    final page = await transport.read('directory', {
      'kind': 'coaches', 'limit': 20, if (afterId != null) 'afterId': afterId,
    });
    final rows = (page['items'] as List).map(unifiedMap).toList();
    final rated = <String, PublishedCoachProfile>{};
    for (final source in ['existing', 'fyp']) {
      final profiles = rows.where((row) => row['source'] == source).map((row) =>
          PublishedCoachProfile.fromDocument(row['id'] as String, unifiedMap(row['record']))).toList();
      final hydrated = await loadAdminCoachRatings(profiles, (ids) async {
        if (!transport.isCurrent) throw const CoachRepositoryException('permission-denied');
        final input = <String, dynamic>{'schemaVersion': 1,
          'organizationId': scope.organizationId, 'coachIds': ids};
        final Map<String, dynamic> response;
        if (source == 'fyp') {
          response = Map<String, dynamic>.from(await transport.read('cohort', {
            'operation': 'module/getCoachRatingsCommand', 'input': input,
          }));
        } else {
          response = readExistingRatings != null
              ? await readExistingRatings!(ids)
              : (await firebaseScopedCallable(scope, 'getCoachRatingsCommand')
                  .call<Map<String, dynamic>>(input)).data;
        }
        if (!transport.isCurrent) throw const CoachRepositoryException('permission-denied');
        return response;
      });
      for (final profile in hydrated) { rated[profile.id] = profile; }
    }
    if (!transport.isCurrent) throw const CoachRepositoryException('permission-denied');
    if (rated.length != rows.length) throw const CoachRepositoryException('invalid-response');
    return CoachDirectoryPage(rows.map((row) => rated[row['id']]!).toList(),
        nextCursor: page['nextCursor'] as String?);
  }
  @override
  Future<CoachPublicationReview> loadReview(String coachId) async {
    final r=await transport.read('coach',{'coachId':coachId});
    return CoachPublicationReview(coachId:coachId,draft:r['draft']==null?null:CoachProfessionalProfile.fromDocument(coachId,unifiedMap(r['draft'])),
      publication:r['publication']==null?null:PublishedCoachProfile.fromDocument(coachId,unifiedMap(r['publication'])),branchIds:List<String>.from(r['branchIds'] as List),
      targetMembershipEligible:r['targetMembershipEligible']==true,certificationVerified:r['certificationVerified']==true,approvedCertificationCount:r['approvedCertificationCount'] as int,readOnly:r['readOnly']==true,operationalSummary:List<String>.from(r['operationalSummary'] as List? ?? []));
  }
  @override
  Future<CoachCommandResult> setStatus({required CoachPublicationReview baseline,required CoachDirectoryAction action,required String requestId}) {
    if(baseline.readOnly)throw StateError('Fictional Coach records are read-only in the unified Admin.');
    return canonical.setStatus(baseline:baseline,action:action,requestId:requestId);
  }
}
