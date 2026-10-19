import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gainpath_domain/gainpath_domain.dart';

typedef PaymentReviewCall = Future<Map<String, dynamic>> Function(
    String, Map<String, dynamic>);

class PaymentReviewException implements Exception {
  const PaymentReviewException(this.code);
  final String code;
  @override
  String toString() {
    switch (code) {
      case 'permission-denied':
        return 'This Admin session is no longer authorized. Sign in again.';
      case 'failed-precondition':
        return 'Payment review state changed or order ID required. Refresh the record before retrying.';
      case 'invalid-argument':
        return 'Invalid payment review request. Check the entered details and retry.';
      default:
        return 'Payment review could not be completed ($code). Refresh the record before retrying.';
    }
  }
}

class PaymentReviewRecord {
  PaymentReviewRecord(Map<String, dynamic> data)
      : data = Map.unmodifiable(data) {
    for (final key in [
      'bookingId',
      'memberId',
      'paymentStatus',
      'fulfilmentStatus'
    ]) {
      if (data[key] is! String || (data[key] as String).isEmpty) {
        throw const FormatException('Invalid payment');
      }
    }
    if (data['amountMinor'] is! int ||
        (data['amountMinor'] as int) <= 0 ||
        data['currency'] != 'MYR') {
      throw const FormatException('Invalid amount');
    }
    if (!['pending', 'cleared'].contains(data['paymentStatus']) ||
        ![
          'creating',
          'awaiting_payment',
          'confirmed',
          'reconciliation_required'
        ].contains(data['fulfilmentStatus']) ||
        (data['refundStatus'] != null &&
            ![
              'approved',
              'rejected',
              'processing',
              'uncertain',
              'completed',
              'failed'
            ].contains(data['refundStatus']))) {
      throw const FormatException('Invalid payment state');
    }
  }
  final Map<String, dynamic> data;
  String text(String key) => data[key]?.toString() ?? '';
  String get id => text('bookingId');
  int get amountMinor => data['amountMinor'] as int;
  String get amount => 'RM ${(amountMinor / 100).toStringAsFixed(2)}';
  bool get needsReview =>
      text('fulfilmentStatus') == 'reconciliation_required' &&
      text('refundStatus') != 'completed';
  bool get canDecide =>
      needsReview &&
      text('paymentStatus') == 'cleared' &&
      (text('refundStatus').isEmpty ||
          ['rejected', 'approved'].contains(text('refundStatus')));
}

class PaymentReviewPage {
  const PaymentReviewPage(this.records, {this.nextAfterId});
  final List<PaymentReviewRecord> records;
  final String? nextAfterId;
}

class PaymentReviewDetail {
  const PaymentReviewDetail(this.payment,
      {this.events = const [], this.refundExecutionAvailable = false});
  final PaymentReviewRecord payment;
  final List<Map<String, dynamic>> events;
  final bool refundExecutionAvailable;
  factory PaymentReviewDetail.fromJson(Map<String, dynamic> json,
      {required String expectedBookingId}) {
    if ((json['payment'] as Map)['bookingId'] != expectedBookingId) {
      throw const FormatException('Payment booking mismatch');
    }
    return PaymentReviewDetail(
        PaymentReviewRecord(Map<String, dynamic>.from(json['payment'] as Map)),
        events: (json['events'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList(),
        refundExecutionAvailable: json['refundExecutionAvailable'] == true);
  }
}

abstract class PaymentReviewRepository {
  Future<PaymentReviewPage> load({String? afterId});
  Future<PaymentReviewDetail> detail(String bookingId);
  Future<PaymentReviewDetail> manage(String bookingId, String action,
      {required String requestId,
      String? reason,
      String? billId,
      String? refundOrderId});
}

class FirebasePaymentReviewRepository implements PaymentReviewRepository {
  FirebasePaymentReviewRepository(
      {required this.session,
      required this.isCurrent,
      String? Function()? currentUid,
      PaymentReviewCall? call})
      : _uid = currentUid ?? (() => FirebaseAuth.instance.currentUser?.uid),
        _call = call ??
            ((name, data) async => (await FirebaseFunctions.instance
                    .httpsCallable(name)
                    .call<Map<String, dynamic>>(data))
                .data);
  final AuthSession session;
  final bool Function() isCurrent;
  final String? Function() _uid;
  final PaymentReviewCall _call;
  void _check() {
    if (!isCurrent() ||
        _uid() != session.userId ||
        session.role != AppRole.admin ||
        session.needsVerification) {
      throw const PaymentReviewException('permission-denied');
    }
  }

  Future<Map<String, dynamic>> _request(
      String name, Map<String, dynamic> input) async {
    _check();
    try {
      final response = await _call(name, {
        'schemaVersion': 1,
        'organizationId': session.organizationId,
        ...input
      });
      _check();
      if (response['schemaVersion'] != 1) {
        throw const PaymentReviewException('unsupported-response');
      }
      return response;
    } on FirebaseFunctionsException catch (e) {
      _check();
      throw PaymentReviewException(e.code);
    } catch (_) {
      _check();
      rethrow;
    }
  }

  @override
  Future<PaymentReviewPage> load({String? afterId}) async {
    final json = await _request('listAdminBookingPaymentsCommand',
        {if (afterId != null) 'afterId': afterId});
    return PaymentReviewPage(
        (json['records'] as List)
            .map(
                (e) => PaymentReviewRecord(Map<String, dynamic>.from(e as Map)))
            .toList(),
        nextAfterId: json['nextAfterId'] as String?);
  }

  @override
  Future<PaymentReviewDetail> detail(String bookingId) async =>
      PaymentReviewDetail.fromJson(
          await _request(
              'getAdminBookingPaymentCommand', {'bookingId': bookingId}),
          expectedBookingId: bookingId);
  @override
  Future<PaymentReviewDetail> manage(String bookingId, String action,
          {required String requestId,
          String? reason,
          String? billId,
          String? refundOrderId}) async =>
      PaymentReviewDetail.fromJson(
          await _request('manageAdminBookingPaymentCommand', {
            'bookingId': bookingId,
            'action': action,
            'requestId': requestId,
            if (reason != null) 'reason': reason,
            if (billId != null) 'billId': billId,
            if (refundOrderId != null) 'refundOrderId': refundOrderId,
          }),
          expectedBookingId: bookingId);
}

/// Neutral repository for the unconnected console. Never invents payment data.
class EmptyPaymentReviewRepository implements PaymentReviewRepository {
  @override
  Future<PaymentReviewPage> load({String? afterId}) async =>
      const PaymentReviewPage([]);
  @override
  Future<PaymentReviewDetail> detail(String bookingId) async =>
      throw const PaymentReviewException('not-connected');
  @override
  Future<PaymentReviewDetail> manage(String bookingId, String action,
          {required String requestId,
          String? reason,
          String? billId,
          String? refundOrderId}) async =>
      throw const PaymentReviewException('not-connected');
}
