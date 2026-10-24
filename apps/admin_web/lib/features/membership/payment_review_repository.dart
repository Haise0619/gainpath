import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_data/gainpath_data.dart' show InFlightRead;
import '../../infrastructure/firebase/firebase_function_transport.dart';

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
          'expired',
          'failed',
          'confirmed',
          'reconciliation_required'
        ].contains(data['fulfilmentStatus']) ||
        (data['refundStatus'] != null &&
            ![
              'pending_review',
              'approved',
              'rejected',
              'processing',
              'uncertain',
              'completed',
              'failed'
            ].contains(data['refundStatus']))) {
      throw const FormatException('Invalid payment state');
    }
    if (data.containsKey('premiumVoucher') ||
        data.containsKey('grossAmountMinor') ||
        data.containsKey('discountMinor')) {
      final voucher = data['premiumVoucher'];
      final gross = data['grossAmountMinor'], discount = data['discountMinor'];
      if (isMembership ||
          voucher is! Map ||
          voucher['schemaVersion'] != 1 ||
          voucher['memberId'] != data['memberId'] ||
          voucher['amountMinor'] != amountMinor ||
          voucher['grossAmountMinor'] != gross ||
          voucher['discountMinor'] != discount ||
          gross is! int ||
          gross <= 0 ||
          gross > 100000000 ||
          discount is! int ||
          discount <= 0 ||
          discount > 1500 ||
          gross - discount != amountMinor ||
          voucher['fundingSource'] != 'gym' ||
          voucher['coachCommissionBasis'] != 'gross_fee' ||
          voucher['commissionPolicyVersion'] != 'sandbox-coach-80-v1' ||
          ['voucherId', 'policyVersion', 'financeApprovalId'].any((key) =>
              voucher[key] is! String || (voucher[key] as String).isEmpty)) {
        throw const FormatException('Invalid voucher finance snapshot');
      }
    }
  }
  final Map<String, dynamic> data;
  String text(String key) => data[key]?.toString() ?? '';
  String get id => text('bookingId');
  bool get isMembership =>
      ['MembershipPurchase', 'MembershipRenewal'].contains(text('kind'));
  String get schedule => text('localDate').isEmpty
      ? 'Original checkout schedule unavailable'
      : '${text('localDate')} · ${text('startLabel')} – ${text('endLabel')}';
  String get sessionSchedule => text('sessionLocalDate').isEmpty
      ? schedule
      : '${text('sessionLocalDate')} · ${text('sessionStartLabel')} – ${text('sessionEndLabel')} (${text('sessionTimeZone')})';
  String get refundExplanation => switch (text('refundStatus')) {
        'pending_review' =>
          'Member requested a refund. Review the reason and notes. No transfer has been sent.',
        'approved' when isMembership =>
          'Refund approved for review. No money has been returned. Membership refund execution awaits provider resolution and an entitlement reversal policy.',
        'approved' =>
          'Approved for refund. No Payment Order has been sent yet. Execute sandbox refund creates a test order using dummy bank details; it does not refund real money.',
        'uncertain' =>
          'Provider outcome not confirmed. Do not execute again. Check the original Payment Order in Billplz Sandbox using the refund reference. If an order exists, use Recover Payment Order to attach its ID and verify its status. If no order is found, an authorized provider review is required; this screen cannot safely resend it.',
        'processing' =>
          'A Sandbox Payment Order was submitted. Check refund status to verify the existing order; do not create another one.',
        'completed' =>
          'Sandbox provider confirmed completion. This is a test refund; no real money was returned.',
        'failed' =>
          'The Sandbox Payment Order did not complete. Review the provider record before taking further action.',
        'rejected' =>
          'Admin declined this refund request. No refund was sent by this decision.',
        _ => needsReview
            ? 'Payment received; Admin review is required. Approval records a decision and does not send a refund.'
            : 'No refund request is currently awaiting a decision.',
      };
  int get amountMinor => data['amountMinor'] as int;
  bool get hasPremiumVoucher => data['premiumVoucher'] is Map;
  String get originalAmount =>
      'RM ${((data['grossAmountMinor'] as int) / 100).toStringAsFixed(2)}';
  String get voucherDiscount =>
      'RM ${((data['discountMinor'] as int) / 100).toStringAsFixed(2)}';
  String get voucherFinanceReference {
    final voucher = data['premiumVoucher'] as Map;
    return 'Gym-funded · Coach commission on original fee · ${voucher['commissionPolicyVersion']} · Approval ${voucher['financeApprovalId']}';
  }

  String get amount => 'RM ${(amountMinor / 100).toStringAsFixed(2)}';
  bool get needsReview =>
      text('fulfilmentStatus') == 'reconciliation_required' &&
      text('refundStatus') != 'completed';
  bool get canDecide =>
      needsReview &&
      text('paymentStatus') == 'cleared' &&
      (text('refundStatus').isEmpty ||
          ['pending_review', 'rejected', 'approved']
              .contains(text('refundStatus')));
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
            ((name, data) async =>
                (await firebaseCallable(name).call<Map<String, dynamic>>(data))
                    .data);
  final AuthSession session;
  final bool Function() isCurrent;
  final String? Function() _uid;
  final PaymentReviewCall _call;
  final _pages = InFlightRead<PaymentReviewPage>();
  final _details = InFlightRead<PaymentReviewDetail>();
  int _readEpoch = 0;
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
    _check();
    final result = await _pages
        .run('$_readEpoch:${afterId == null ? 'first' : 'after:$afterId'}',
            () async {
      final json = await _request('listAdminBookingPaymentsCommand',
          {if (afterId != null) 'afterId': afterId});
      return PaymentReviewPage(
          (json['records'] as List)
              .map((e) =>
                  PaymentReviewRecord(Map<String, dynamic>.from(e as Map)))
              .toList(),
          nextAfterId: json['nextAfterId'] as String?);
    });
    _check();
    return result;
  }

  @override
  Future<PaymentReviewDetail> detail(String bookingId) async {
    _check();
    final result = await _details.run(
        '$_readEpoch:$bookingId',
        () async => PaymentReviewDetail.fromJson(
            await _request(
                'getAdminBookingPaymentCommand', {'bookingId': bookingId}),
            expectedBookingId: bookingId));
    _check();
    return result;
  }

  @override
  Future<PaymentReviewDetail> manage(String bookingId, String action,
      {required String requestId,
      String? reason,
      String? billId,
      String? refundOrderId}) async {
    // Neither commands nor completed financial reads are cached. Reads started
    // during/after a command cannot join work from before that boundary, even
    // when a provider outcome is uncertain or the command fails.
    _readEpoch++;
    try {
      return PaymentReviewDetail.fromJson(
          await _request('manageAdminBookingPaymentCommand', {
            'bookingId': bookingId,
            'action': action,
            'requestId': requestId,
            if (reason != null) 'reason': reason,
            if (billId != null) 'billId': billId,
            if (refundOrderId != null) 'refundOrderId': refundOrderId,
          }),
          expectedBookingId: bookingId);
    } finally {
      _readEpoch++;
    }
  }
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
