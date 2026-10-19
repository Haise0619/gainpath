import 'firebase_booking_repository.dart';
import 'firebase_app_check_readiness.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_domain/coaching.dart';

class FirebaseBookingCommunicationRepository
    implements BookingCommunicationRepository {
  FirebaseBookingCommunicationRepository(
      {required this.scope, required this.isCurrent, BookingCallable? call})
      : transport =
            BookingTransport(scope: scope, isCurrent: isCurrent, call: call);
  final SessionScope scope;
  final bool Function() isCurrent;
  final BookingTransport transport;
  Future<SessionConversation> _call(
      String id, Map<String, dynamic> fields) async {
    if (!isCurrent()) throw StateError('Session changed');
    if (!await FirebaseAppCheckReadiness.instance
        .ensureReady(check: transport.check)) {
      throw StateError('App Check unavailable');
    }
    final result = await transport.call('bookingCommunicationCommand', {
      'schemaVersion': 1,
      'organizationId': scope.organizationId,
      'bookingId': id,
      ...fields,
    });
    if (!isCurrent()) throw StateError('Session changed');
    final data = Map<String, dynamic>.from(result);
    if (data['schemaVersion'] != 1 || data['bookingId'] != id) {
      throw const FormatException();
    }
    final messages = (data['messages'] as List).map((raw) {
      final m = Map<String, dynamic>.from(raw as Map);
      if (!['member', 'coach'].contains(m['senderRole']) ||
          m['sequence'] is! int ||
          m['sentAtMillis'] is! int ||
          m['text'] is! String) {
        throw const FormatException();
      }
      return SessionMessage(
          sequence: m['sequence'],
          senderRole: m['senderRole'],
          text: m['text'],
          sentAtMillis: m['sentAtMillis']);
    }).toList(growable: false);
    return SessionConversation(messages,
        nextBeforeSequence: data['nextBeforeSequence'] as int?);
  }

  @override
  Future<SessionConversation> load(String bookingId, {int? beforeSequence}) =>
      _call(bookingId,
          {if (beforeSequence != null) 'beforeSequence': beforeSequence});
  @override
  Future<SessionConversation> send(
          String bookingId, String requestId, String text) =>
      _call(bookingId, {'requestId': requestId, 'text': text});
}
