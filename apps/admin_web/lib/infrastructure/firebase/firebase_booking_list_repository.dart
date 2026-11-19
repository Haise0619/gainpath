import 'package:firebase_auth/firebase_auth.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'firebase_function_transport.dart';
import 'firebase_unified_admin.dart';

typedef BookingListCallable = Future<Map<String, dynamic>> Function(
    String, Map<String, dynamic>);

/// Read-only Admin transport. Regional reads require configured App Check.
class FirebaseBookingListRepository
    implements BookingListRepository, BranchBookingListRepository {
  FirebaseBookingListRepository(
      {required this.scope,
      required this.isCurrent,
      bool unifiedReads=false,
      String? Function()? currentUid,
      BookingListCallable? call})
      : _uid = currentUid ?? (() => FirebaseAuth.instance.currentUser?.uid),
        _call = call ?? ((name, input) async => unifiedReads&&scope.datasetScope==null&&input['coachId'] is String&&(input['coachId'] as String).startsWith('demo-m13-coach-')
          ? Map<String,dynamic>.from(await UnifiedAdminTransport(scope:scope,isCurrent:isCurrent).read('cohort',{'operation':'module/$name','input':input}))
          : (await firebaseScopedCallable(scope, name).call<Map<String, dynamic>>(input)).data);

  @override
  final SessionScope scope;
  final bool Function() isCurrent;
  final String? Function() _uid;
  final BookingListCallable _call;
  void _check() {
    if (!isCurrent() || _uid() != scope.userId) {
      throw const BookingException('permission-denied');
    }
  }

  @override
  Future<BookingPage> load(
      {String? coachId,
      String? firstLocalDate,
      int? dayCount,
      BookingCursor? cursor}) =>
      _load(coachId: coachId, firstLocalDate: firstLocalDate, dayCount: dayCount, cursor: cursor);

  @override
  Future<BookingPage> loadBranch(String branchId,
          {String? firstLocalDate, BookingCursor? cursor}) =>
      _load(branchId: branchId, firstLocalDate: firstLocalDate, cursor: cursor);

  Future<BookingPage> _load({String? coachId, String? branchId,
      String? firstLocalDate, int? dayCount, BookingCursor? cursor}) async {
    _check();
    if (coachId == null && branchId == null) throw const BookingException('permission-denied');
    try {
      final result = await _call('getBookingListCommand', {
        'schemaVersion': 1,
        'organizationId': scope.organizationId,
        if (coachId != null) 'coachId': coachId,
        if (branchId != null) 'branchId': branchId,
        'includeSelectedPaymentMethod': true,
        if (firstLocalDate != null) 'firstLocalDate': firstLocalDate,
        if (dayCount != null) 'dayCount': dayCount,
        if (cursor != null) 'cursor': cursor.toJson()
      });
      _check();
      final page = BookingPage.fromJson(result,
          expectedOrganizationId: scope.organizationId,
          expectedCoachId: coachId,
          expectedFirstLocalDate: firstLocalDate);
      if (branchId != null && page.records.any((row) => row.branchId != branchId)) {
        throw const FormatException('Unexpected booking branch');
      }
      return page;
    } on FirebaseException catch (error) {
      _check();
      throw BookingException(error.code);
    } on FormatException {
      _check();
      throw const BookingException('failed-precondition');
    } on BookingException {
      _check();
      rethrow;
    } catch (_) {
      _check();
      throw const BookingException('unknown');
    }
  }
}
