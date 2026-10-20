import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gainpath_domain/gainpath_domain.dart';

typedef BookingListCallable = Future<Map<String, dynamic>> Function(
    String, Map<String, dynamic>);

/// Read-only Admin transport. App Check is intentionally not a list prerequisite.
class FirebaseBookingListRepository implements BookingListRepository {
  FirebaseBookingListRepository(
      {required this.scope,
      required this.isCurrent,
      String? Function()? currentUid,
      BookingListCallable? call})
      : _uid = currentUid ?? (() => FirebaseAuth.instance.currentUser?.uid),
        _call = call ??
            ((name, input) async => (await FirebaseFunctions.instance
                    .httpsCallable(name)
                    .call<Map<String, dynamic>>(input))
                .data);
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
      BookingCursor? cursor}) async {
    _check();
    if (coachId == null) throw const BookingException('permission-denied');
    try {
      final result = await _call('getBookingListCommand', {
        'schemaVersion': 1,
        'organizationId': scope.organizationId,
        'coachId': coachId,
        if (firstLocalDate != null) 'firstLocalDate': firstLocalDate,
        if (dayCount != null) 'dayCount': dayCount,
        if (cursor != null) 'cursor': cursor.toJson()
      });
      _check();
      return BookingPage.fromJson(result,
          expectedOrganizationId: scope.organizationId,
          expectedCoachId: coachId,
          expectedFirstLocalDate: firstLocalDate);
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
