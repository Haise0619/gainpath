import 'firebase_booking_repository.dart';
import 'firebase_app_check_readiness.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_domain/coaching.dart';

class FirebaseBookingCommunicationRepository
    implements BookingCommunicationRepository, PairConversationRepository {
  FirebaseBookingCommunicationRepository(
      {required this.scope,
      required this.isCurrent,
      BookingCallable? call,
      FirebaseAppCheckReadiness? readiness,
      String? Function()? currentUid})
      : _readiness = readiness ?? FirebaseAppCheckReadiness.instance,
        transport = BookingTransport(
            scope: scope,
            isCurrent: isCurrent,
            call: call,
            currentUid: currentUid);
  final SessionScope scope;
  final bool Function() isCurrent;
  final BookingTransport transport;
  final FirebaseAppCheckReadiness _readiness;
  Future<SessionConversation> _call(
      String id, Map<String, dynamic> fields) async {
    if (!isCurrent()) throw StateError('Session changed');
    if (!await _readiness.ensureReady(check: transport.check)) {
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

  Future<Map<String, dynamic>> _pair(Map<String, dynamic> fields) async {
    if (!isCurrent()) throw StateError('Session changed');
    if (!await _readiness.ensureReady(check: transport.check)) {
      throw StateError('App Check unavailable');
    }
    final result = await transport.call('bookingCommunicationCommand', {
      'schemaVersion': 2,
      'organizationId': scope.organizationId,
      ...fields,
    });
    if (!isCurrent()) throw StateError('Session changed');
    final data = Map<String, dynamic>.from(result);
    if (data['schemaVersion'] != 2) {
      throw const FormatException('Conversation version unavailable');
    }
    return data;
  }

  PairChatPage _page(Map<String, dynamic> data, {String? expectedPeer}) {
    final member = data['memberId'] as String;
    final coach = data['coachId'] as String;
    if (scope.userId != member && scope.userId != coach) {
      throw const FormatException('Conversation owner mismatch');
    }
    final peerId = scope.userId == member ? coach : member;
    if (expectedPeer != null && peerId != expectedPeer) {
      throw const FormatException('Conversation counterparty mismatch');
    }
    final raw = data['context'];
    final context = raw == null ? null : Map<String, dynamic>.from(raw as Map);
    final messages = (data['messages'] as List).map((raw) {
      final m = Map<String, dynamic>.from(raw as Map);
      if (!['member', 'coach', 'system'].contains(m['senderRole']) ||
          m['id'] is! String ||
          m['sentAtMillis'] is! int ||
          m['text'] is! String) {
        throw const FormatException();
      }
      return PairChatMessage(
          id: m['id'],
          senderRole: m['senderRole'],
          text: m['text'],
          sentAtMillis: m['sentAtMillis'],
          sourceBookingId: m['sourceBookingId'] as String?,
          sourceBookingLabel: m['sourceBookingLabel'] as String?,
          orderKey: m['orderKey'] as String?);
    }).toList(growable: false);
    return PairChatPage(
        conversationId: data['conversationId'] as String,
        peerId: peerId,
        peerName: data['peerName'] as String,
        serverNowMillis: data['serverNowMillis'] as int,
        canSend: data['canSend'] as bool,
        reason: data['reason'] as String,
        messages: messages,
        nextBefore: data['nextBefore'] as String?,
        context: context == null
            ? null
            : PairSessionContext(
                bookingId: context['bookingId'],
                kind: context['kind'],
                startAtMillis: context['startAtMillis'],
                endAtMillis: context['endAtMillis'],
                timeZone: context['timeZone'],
                durationMinutes: context['durationMinutes'],
                followUpUntilMillis: context['followUpUntilMillis'] as int?,
                dateLabel: context['dateLabel'] as String?,
                followUpLabel: context['followUpLabel'] as String?));
  }

  @override
  Future<PairChatPage> loadConversation(
          {String? bookingId,
          String? peerId,
          String? before,
          bool markRead = false}) async =>
      _page(
          await _pair({
            if (bookingId != null) 'bookingId': bookingId,
            if (peerId != null) 'peerId': peerId,
            if (before != null) 'before': before,
            'markRead': markRead
          }),
          expectedPeer: peerId);

  @override
  Future<PairChatPage> sendConversation(
          {required String peerId,
          required String requestId,
          required String text}) async =>
      _page(
          await _pair({
            'peerId': peerId,
            'requestId': requestId,
            'text': text,
            'markRead': true
          }),
          expectedPeer: peerId);

  @override
  Future<PairChatInboxPage> loadInbox({String? cursor}) async {
    final data = await _pair(
        {'action': 'inbox', if (cursor != null) 'inboxCursor': cursor});
    return PairChatInboxPage(
        (data['conversations'] as List).map((raw) {
          final m = Map<String, dynamic>.from(raw as Map);
          return PairChatSummary(
              peerId: m['peerId'] as String,
              name: m['name'] as String,
              unreadCount: m['unreadCount'] as int,
              preview: m['preview'] as String?,
              updatedAtMillis: m['updatedAtMillis'] as int?);
        }).toList(growable: false),
        nextCursor: data['nextInboxCursor'] as String?);
  }
}
