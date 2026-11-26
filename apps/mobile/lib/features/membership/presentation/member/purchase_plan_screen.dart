import 'dart:async';
import '../../../../presentation/shared/payment_status_heading.dart';
import 'package:flutter/material.dart';
import 'package:gainpath_domain/coaching.dart' show isBookingCheckoutUrl;
import 'package:gainpath_domain/membership.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show BookingException;
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../domain/membership_payment_preview.dart';
import '../../domain/membership_renewal_preview.dart';
import '../shared/membership_data_view.dart';
import '../../application/membership_feature_host.dart';
import '../shared/membership_dashboard_screen.dart';
import 'membership_support_screen.dart';
import 'browse_plans_screen.dart';

class PurchasePlanScreen extends StatelessWidget {
  const PurchasePlanScreen(
      {super.key,
      required this.plan,
      this.connected = false,
      this.repository,
      this.renewalPreview,
      this.upgradeMode,
      this.renewal = false});
  final MembershipPlan plan;
  final bool connected, renewal;
  final MembershipCommerceRepository? repository;
  final MembershipRenewalPreview? renewalPreview;
  final MembershipUpgradeMode? upgradeMode;
  @override
  Widget build(BuildContext context) => repository != null
      ? MembershipRepositoryGuard(
          repository: repository!, child: _body(repository!))
      : MembershipFeatureHost(connected: connected, builder: _body);
  Widget _body(MembershipCommerceRepository repo) => _PurchaseForm(
      repository: repo,
      plan: plan,
      renewal: renewal,
      renewalPreview: renewalPreview,
      upgradeMode: upgradeMode);
}

class _PurchaseForm extends StatefulWidget {
  const _PurchaseForm(
      {required this.repository,
      required this.plan,
      required this.renewal,
      required this.renewalPreview,
      required this.upgradeMode});
  final MembershipCommerceRepository repository;
  final MembershipPlan plan;
  final bool renewal;
  final MembershipRenewalPreview? renewalPreview;
  final MembershipUpgradeMode? upgradeMode;
  @override
  State<_PurchaseForm> createState() => _PurchaseFormState();
}

class _PurchaseFormState extends State<_PurchaseForm> {
  final _promo = TextEditingController();
  late String _requestId =
      'membership-${DateTime.now().microsecondsSinceEpoch}';
  Map<String, dynamic>? _quote;
  String? _message;
  bool _busy = false;
  bool _submitted = false;
  String _quotedCode = '';
  @override
  void initState() {
    super.initState();
    _apply();
  }

  @override
  void dispose() {
    _promo.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    if (_busy || _submitted) return;
    setState(() {
      _busy = true;
      _quote = null;
      _message = null;
    });
    try {
      final code = _promo.text.trim().toUpperCase();
      final q = await widget.repository
          .quote(widget.plan.id, code, upgradeMode: widget.upgradeMode);
      if (q['upgradeExpiresAtMillis'] != null) {
        throw const BookingException('membership-upgrade-unavailable');
      }
      if (widget.upgradeMode != null &&
          (q['upgradeMode'] != widget.upgradeMode!.wireValue ||
              q['quoteId'] is! String ||
              q['amountMinor'] is! int ||
              q['premiumTermAmountMinor'] is! int ||
              q['upgradeChargeMinor'] is! int ||
              q['startsAtMillis'] is! int ||
              q['expiresAtMillis'] is! int)) {
        throw const BookingException('invalid-response');
      }
      if (mounted) {
        setState(() {
          _quote = q;
          _quotedCode = code;
        });
      }
    } catch (error) {
      if (mounted) {
        final code = error is BookingException ? error.code : '';
        setState(() => _message = switch (code) {
              'membership-upgrade-already-scheduled' =>
                'Premium is already scheduled. Return to Membership to review it.',
              'membership-upgrade-unavailable' =>
                'This upgrade is no longer available. Return to Membership to refresh your plan.',
              _ => widget.upgradeMode == null
                  ? 'Price or promo could not be verified. Clear the code or retry.'
                  : 'The upgrade price could not be verified. Try verifying it again.',
            });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pay() async {
    if (_busy || _quote == null) return;
    setState(() {
      _busy = true;
      _submitted = true;
      _message = null;
    });
    try {
      final p = await widget.repository.checkout(
          widget.plan.id, _quotedCode, _requestId,
          renewal: widget.renewal,
          quoteId: _quote!['quoteId'] as String?,
          upgradeMode: widget.upgradeMode);
      if (!mounted || !widget.repository.current) return;
      if (_isExistingOrder(p)) {
        setState(() => _busy = false);
        if (!await _confirmExistingOrder(p)) return;
      }
      if (!mounted || !widget.repository.current) return;
      await Navigator.push(
          context,
          MaterialPageRoute<void>(
              builder: (_) => MembershipPaymentScreen(
                  repository: widget.repository, initial: p)));
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        final code = error is BookingException ? error.code : 'unknown';
        final rejected = const [
          'membership-quote-changed',
          'membership-quote-expired',
          'membership-promo-invalid',
          'membership-unsupported-plan',
          'membership-upgrade-unavailable',
          'membership-upgrade-already-scheduled',
        ].contains(code);
        setState(() {
          if (rejected) {
            _submitted = false;
            _quote = null;
            _requestId = 'membership-${DateTime.now().microsecondsSinceEpoch}';
          }
          _message = switch (code) {
            'membership-quote-expired' => widget.upgradeMode == null
                ? 'The quoted offer has expired. Edit the promo code and verify the current price before paying.'
                : 'The upgrade quote has expired. Verify the current price before paying.',
            'membership-promo-invalid' =>
              'This promo code is unavailable. Edit or remove it, then verify the price.',
            'membership-unsupported-plan' =>
              'This plan is unavailable. Return to the plan comparison to choose an available plan.',
            'membership-quote-changed' =>
              'Review updated price. Verify the price again before continuing.',
            'membership-upgrade-already-scheduled' =>
              'Premium is already scheduled. Return to Membership to review it.',
            'membership-upgrade-unavailable' =>
              'This upgrade is no longer available. Return to Membership to refresh your plan.',
            'unauthenticated' =>
              'Your session has expired. Sign in again and check billing history for your checkout.',
            _ =>
              'Checkout outcome is not confirmed. Recover this same request or check billing history before starting another payment.',
          };
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool _isExistingOrder(Map<String, dynamic> payment) {
    final kind = widget.renewal ? 'MembershipRenewal' : 'MembershipPurchase';
    final quotedAmount = _quote?['amountMinor'];
    return payment['recoveredPendingCheckout'] == true ||
        (payment['planId'] != null && payment['planId'] != widget.plan.id) ||
        (payment['kind'] != null && payment['kind'] != kind) ||
        (payment['amountMinor'] is int &&
            payment['amountMinor'] != quotedAmount) ||
        (payment['promoCode'] ?? '') != _quotedCode ||
        payment['upgradeExpiresAtMillis'] != null ||
        payment['upgradeMode'] != widget.upgradeMode?.wireValue;
  }

  Future<bool> _confirmExistingOrder(Map<String, dynamic> payment) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => MembershipRepositoryGuard(
            repository: widget.repository,
            child: AlertDialog(
              scrollable: true,
              title: const Text('Existing payment found'),
              content: Text(
                  'Open the existing order to verify or continue payment. '
                  'No new order was created.\n\n'
                  '${payment['planName']} · ${membershipMoney(payment['amountMinor'])}\n'
                  '${membershipOrderLabel(payment)}'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Back')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('View existing order')),
              ],
            )),
      ) ??
      false;

  @override
  Widget build(BuildContext context) {
    final preview = widget.renewal ? widget.renewalPreview : null;
    final estimate = preview?.estimatedExpiry(_quote?['durationDays']);
    final upgrade = widget.upgradeMode;
    final stackUpgradeDetails =
        upgrade != null && MediaQuery.textScalerOf(context).scale(14) >= 21;
    Widget detail(String label, String value) => stackUpgradeDetails
        ? Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(label, style: Theme.of(context).textTheme.bodyMedium),
                  Text(value,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ]),
          )
        : DetailRow(label, value);

    return Scaffold(
        appBar: AppBar(
            title: Text(upgrade != null
                ? 'Review Premium upgrade'
                : widget.renewal
                    ? 'Extend your membership'
                    : 'Review order')),
        body: PageBody(children: [
          // 1. Compact Plan Summary Card
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primarySoft.withValues(alpha: 0.35),
                width: 1.5,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x08190F2E),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text(
                      widget.plan.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primaryTint,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        widget.renewal ? '30-day renewal' : '30 days',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  widget.plan.tagline,
                  style:
                      const TextStyle(fontSize: 13, color: AppColors.inkSoft),
                ),
                const SizedBox(height: 8),
                Text(
                  upgrade == MembershipUpgradeMode.immediate
                      ? 'Upgrade your remaining Basic time and add 30 days of Premium.'
                      : upgrade == MembershipUpgradeMode.nextTerm
                          ? 'Keep Basic until it expires. Premium starts at Basic expiry or when payment is confirmed, whichever is later.'
                          : widget.renewal
                              ? 'Renew anytime. Your remaining membership time will be preserved.'
                              : 'One-time membership purchase',
                  style: const TextStyle(fontSize: 12.5, color: AppColors.ink),
                ),
                if (preview != null) ...[
                  const SizedBox(height: 10),
                  const Divider(height: 1, color: AppColors.hairline),
                  const SizedBox(height: 8),
                  Text(
                    '${preview.active ? 'Current membership' : 'Previous membership'}: ${preview.tier.label}',
                    style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${preview.active ? 'Current expiry' : 'Expired'}: ${membershipDate(preview.expiryMillis)}',
                    style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 2. Promo Code Input & Action
          if (upgrade == null) ...[
            TextField(
                controller: _promo,
                enabled: !_busy && !_submitted,
                decoration: InputDecoration(
                  labelText: 'Promo code (optional)',
                  hintText: 'Enter promo code',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                onChanged: (_) => setState(() => _quote = null)),
            const SizedBox(height: 4),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
                onPressed: _busy || _submitted ? null : _apply,
                child: Text(upgrade == null
                    ? 'Verify price / apply code'
                    : 'Verify price')),
          ),
          if (_busy) const LinearProgressIndicator(),
          if (_message != null)
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.dangerTint,
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
              ),
              child: Text(
                _message!,
                style: const TextStyle(color: AppColors.danger, fontSize: 13),
              ),
            ),

          // 3. Compact Order Summary Card with Prominent Total
          if (_quote != null) ...[
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.hairline),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Order Summary',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (upgrade != null) ...[
                    if (upgrade == MembershipUpgradeMode.immediate)
                      detail('Upgrade remaining Basic time',
                          membershipMoney(_quote!['upgradeChargeMinor'])),
                    detail('30-day Premium term',
                        membershipMoney(_quote!['premiumTermAmountMinor'])),
                    detail(
                        upgrade == MembershipUpgradeMode.immediate
                            ? 'Premium starts'
                            : 'Estimated Premium start',
                        upgrade == MembershipUpgradeMode.immediate
                            ? 'When payment is confirmed'
                            : membershipDate(_quote!['startsAtMillis'])),
                    detail('Estimated Premium expiry',
                        membershipDate(_quote!['expiresAtMillis'])),
                  ] else ...[
                    DetailRow(widget.renewal ? 'Additional time' : 'Duration',
                        '${_quote!['durationDays']} days'),
                    if (_quote!['baseAmountMinor'] != null)
                      DetailRow('Original price',
                          membershipMoney(_quote!['baseAmountMinor'])),
                    if (_quotedCode.isNotEmpty)
                      DetailRow('Promo code', _quotedCode),
                    if (_quote!['baseAmountMinor'] is num &&
                        _quote!['amountMinor'] is num)
                      DetailRow(
                          'Discount',
                          membershipMoney((_quote!['baseAmountMinor'] as num) -
                              (_quote!['amountMinor'] as num))),
                  ],
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Divider(color: AppColors.hairline, height: 1),
                  ),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      const Text(
                        'Total',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                      Text(
                        membershipMoney(_quote!['amountMinor']),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryDark,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (estimate != null)
            Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('Estimated new expiry: ${membershipDate(estimate)}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.primaryDark,
                          fontWeight: FontWeight.w700,
                        ))),
          if (widget.renewal)
            const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                    'Your final expiry is calculated when payment clears: any remaining paid time plus this term.',
                    style:
                        TextStyle(fontSize: 12.5, color: AppColors.inkSoft))),
          const Center(
            child: Text(
              'One-time payment. No automatic recurring charges.',
              style: TextStyle(fontSize: 12, color: AppColors.inkSoft),
            ),
          ),
          PaymentEnvironmentDetails(sandbox: widget.repository.sandbox),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
                onPressed: _busy || _quote == null ? null : _pay,
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: Text(
                    _submitted ? 'Recover checkout' : 'Continue to Payment')),
          ),
          const SizedBox(height: 16),
        ]));
  }
}

class MembershipPaymentScreen extends StatefulWidget {
  const MembershipPaymentScreen(
      {super.key,
      required this.repository,
      required this.initial,
      this.openOnStart = false});
  final MembershipCommerceRepository repository;
  final Map<String, dynamic> initial;
  final bool openOnStart;
  @override
  State<MembershipPaymentScreen> createState() =>
      _MembershipPaymentScreenState();
}

class _MembershipPaymentScreenState extends State<MembershipPaymentScreen>
    with WidgetsBindingObserver {
  late Map<String, dynamic> _payment = Map.of(widget.initial);
  bool _busy = false;
  String? _message;
  DateTime? _lastCheck;
  Timer? _timer;
  int _checks = 0;
  bool _foreground = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
    if (widget.openOnStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            widget.repository.current &&
            _payment['fulfilmentStatus'] == 'awaiting_payment') {
          _open();
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _timer?.cancel();
    _foreground = state == AppLifecycleState.resumed;
    if (state == AppLifecycleState.resumed) {
      _checks = 0;
      _check();
    }
  }

  Future<void> _check() async {
    if (_busy || !mounted || !_foreground || !widget.repository.current) return;
    if (_lastCheck != null &&
        DateTime.now().difference(_lastCheck!) < const Duration(seconds: 10)) {
      _schedule();
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    _lastCheck = DateTime.now();
    try {
      final p =
          await widget.repository.payment(_payment['transactionId'] as String);
      if (mounted) setState(() => _payment = p);
    } catch (_) {
      if (mounted) {
        setState(() => _message =
            'Payment status is uncertain. Check again; do not pay twice.');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _schedule();
      }
    }
  }

  void _schedule() {
    _timer?.cancel();
    if (_checks >= 6 ||
        _payment['paymentStatus'] == 'cleared' ||
        !mounted ||
        !_foreground ||
        !widget.repository.current) {
      return;
    }
    _checks++;
    _timer = Timer(const Duration(seconds: 10), _check);
  }

  Future<void> _open() async {
    final value = _payment['checkoutUrl'];
    if (value is! String) return;
    if (!isBookingCheckoutUrl(value)) return;
    final url = Uri.parse(value);
    try {
      final opened = await launchUrl(url, mode: LaunchMode.inAppBrowserView);
      if (!opened && mounted) {
        setState(() => _message =
            'Checkout could not be opened. Retry from this payment record.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _message =
            'Checkout could not be opened. Retry from this payment record.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _payment['fulfilmentStatus'];
    final refundRequested = _payment['refundStatus'] != null;
    return MembershipRepositoryGuard(
        repository: widget.repository,
        child: Scaffold(
            appBar: AppBar(title: const Text('Membership payment')),
            body: PageBody(children: [
              Panel(
                  background: AppColors.primaryTint,
                  child: Column(children: [
                    Text('${_payment['planName']}',
                        style: Theme.of(context).textTheme.headlineMedium),
                    if (_payment['upgradeMode'] != null ||
                        _payment['upgradeExpiresAtMillis'] != null)
                      Text(membershipOrderLabel(_payment)),
                    Text(membershipMoney(_payment['amountMinor'])),
                    const SizedBox(height: 12),
                    PaymentStatusHeading(
                        title: membershipPaymentLabel(_payment),
                        stage: _payment['paymentStatus'] == 'cleared' &&
                                status == 'confirmed'
                            ? PaymentStage.success
                            : const {
                                'expired',
                                'failed',
                                'reconciliation_required'
                              }.contains(status)
                                ? PaymentStage.failure
                                : _busy
                                    ? PaymentStage.loading
                                    : PaymentStage.pending),
                    if (_payment['startsAtMillis'] != null)
                      Text(
                          'Premium starts: ${membershipDate(_payment['startsAtMillis'])}'),
                    if (_payment['expiresAtMillis'] != null)
                      Text(
                          'Paid expiry: ${membershipDate(_payment['expiresAtMillis'])}'),
                    if (_payment['paymentStatus'] == 'pending' &&
                        _payment['upgradeExpiresAtMillis'] != null)
                      Text(
                          'Premium would expire: ${membershipDate(_payment['upgradeExpiresAtMillis'])}'),
                  ])),
              const SizedBox(height: 16),
              ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text('Payment details'),
                  children: [
                    SelectableText('Reference: ${_payment['transactionId']}'),
                    if (_payment['createdAtMillis'] != null)
                      Text(
                          'Created ${membershipDate(_payment['createdAtMillis'])}'),
                    if (_payment['clearedAtMillis'] != null)
                      Text(
                          'Payment cleared ${membershipDate(_payment['clearedAtMillis'])}'),
                    PaymentEnvironmentDetails(
                        sandbox: widget.repository.sandbox),
                  ]),
              const SizedBox(height: 12),
              if (status == 'expired' || status == 'failed')
                const Text(
                    'Checkout closed. You may start a fresh checkout from plans. A late cleared payment will require Admin review.'),
              if (status == 'expired' || status == 'failed')
                FilledButton.tonal(
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                            builder: (_) => BrowsePlansScreen(
                                repository: widget.repository))),
                    child: const Text('Return to plans')),
              if (status == 'reconciliation_required' && !refundRequested)
                const Text(
                    'Our team needs to review this payment. Keep your reference and check this payment again before starting another.'),
              if (_payment['paymentStatus'] != 'cleared' &&
                  !['failed', 'expired'].contains(status))
                const Text(
                    'Pending verification. Closing checkout does not confirm or cancel a bank payment. You can recover this record from billing history.'),
              if (_message != null) Text(_message!),
              if (_busy) const LinearProgressIndicator(),
              if (status == 'awaiting_payment' &&
                  _payment['checkoutUrl'] != null)
                FilledButton(
                    onPressed: _busy ? null : _open,
                    child: const Text('Continue payment')),
              if (_payment['paymentStatus'] == 'cleared' &&
                  status == 'confirmed')
                FilledButton(
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                            builder: (_) => MembershipDashboardScreen(
                                repository: widget.repository))),
                    child: const Text('View membership')),
              if (status == 'reconciliation_required' && !refundRequested)
                FilledButton.tonal(
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                            builder: (_) => MembershipSupportScreen(
                                repository: widget.repository,
                                payment: _payment))),
                    child: const Text('Contact support')),
              if (widget.repository is MembershipPaymentPreview &&
                  _payment['paymentStatus'] != 'cleared')
                FilledButton(
                    onPressed: () async {
                      await (widget.repository as MembershipPaymentPreview)
                          .simulate(_payment['transactionId'] as String);
                      _lastCheck = null;
                      await _check();
                    },
                    child: const Text('Simulate cleared payment (mock only)')),
              TextButton(
                  onPressed: _busy
                      ? null
                      : () {
                          _checks = 0;
                          _check();
                        },
                  child: const Text('Check payment status')),
            ])));
  }
}
