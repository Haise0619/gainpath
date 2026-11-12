import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gainpath_domain/membership.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show BookingException;
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../domain/membership_payment_preview.dart';
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
      this.renewal = false});
  final MembershipPlan plan;
  final bool connected, renewal;
  final MembershipCommerceRepository? repository;
  @override
  Widget build(BuildContext context) => repository != null
      ? MembershipRepositoryGuard(
          repository: repository!, child: _body(repository!))
      : MembershipFeatureHost(connected: connected, builder: _body);
  Widget _body(MembershipCommerceRepository repo) =>
      _PurchaseForm(repository: repo, plan: plan, renewal: renewal);
}

class _PurchaseForm extends StatefulWidget {
  const _PurchaseForm(
      {required this.repository, required this.plan, required this.renewal});
  final MembershipCommerceRepository repository;
  final MembershipPlan plan;
  final bool renewal;
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
      final q = await widget.repository.quote(widget.plan.id, code);
      if (mounted) {
        setState(() {
          _quote = q;
          _quotedCode = code;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _message =
            'Price or promo could not be verified. Clear the code or retry.');
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
          renewal: widget.renewal, quoteId: _quote!['quoteId'] as String?);
      if (!mounted) return;
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
          'membership-unsupported-plan'
        ].contains(code);
        setState(() {
          if (rejected) {
            _submitted = false;
            _quote = null;
            _requestId = 'membership-${DateTime.now().microsecondsSinceEpoch}';
          }
          _message = switch (code) {
            'membership-quote-expired' =>
              'The quoted offer has expired. Edit the promo code and verify the current price before paying.',
            'membership-promo-invalid' =>
              'This promo code is unavailable. Edit or remove it, then verify the price.',
            'membership-unsupported-plan' =>
              'This plan is unavailable. Return to the plan comparison to choose an available plan.',
            'membership-quote-changed' =>
              'Review updated price. Verify the price again before continuing.',
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

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
          title:
              Text(widget.renewal ? 'Confirm renewal' : 'Review order')),
      body: PageBody(children: [
        Panel(
            background: AppColors.primaryTint,
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.plan.name,
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(widget.plan.tagline),
              const SizedBox(height: 8),
              Text(widget.renewal
                  ? 'Manual renewal · Remaining paid time is preserved.'
                  : 'One-time membership purchase'),
            ])),
        const SizedBox(height: 18),
        TextField(
            controller: _promo,
            enabled: !_busy && !_submitted,
            decoration:
                const InputDecoration(labelText: 'Promo code (optional)'),
            onChanged: (_) => setState(() => _quote = null)),
        TextButton(
            onPressed: _busy || _submitted ? null : _apply,
            child: const Text('Verify price / apply code')),
        if (_busy) const LinearProgressIndicator(),
        if (_message != null)
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(_message!)),
        if (_quote != null)
          Panel(
              child: Column(children: [
            DetailRow('Duration', '${_quote!['durationDays']} days'),
            if (_quote!['baseAmountMinor'] != null)
              DetailRow('Original price',
                  membershipMoney(_quote!['baseAmountMinor'])),
            if (_quotedCode.isNotEmpty) DetailRow('Promo code', _quotedCode),
            if (_quote!['baseAmountMinor'] is num &&
                _quote!['amountMinor'] is num)
              DetailRow(
                  'Discount',
                  membershipMoney((_quote!['baseAmountMinor'] as num) -
                      (_quote!['amountMinor'] as num))),
            const Divider(),
            DetailRow('Total', membershipMoney(_quote!['amountMinor'])),
          ])),
        const SizedBox(height: 16),
        if (widget.renewal)
          const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                  'Your final expiry is calculated when payment clears: any remaining paid time plus this term.')),
        const Text('One-time payment. Membership activates after payment verification.'),
        PaymentEnvironmentDetails(sandbox: widget.repository.sandbox),
        const SizedBox(height: 16),
        FilledButton(
            onPressed: _busy || _quote == null ? null : _pay,
            child:
                Text(_submitted ? 'Recover checkout' : 'Continue to Payment')),
      ]));
}

class MembershipPaymentScreen extends StatefulWidget {
  const MembershipPaymentScreen(
      {super.key, required this.repository, required this.initial});
  final MembershipCommerceRepository repository;
  final Map<String, dynamic> initial;
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
    final url = Uri.tryParse(value);
    if (url == null ||
        url.scheme != 'https' ||
        !['www.billplz-sandbox.com', 'billplz-sandbox.com']
            .contains(url.host) ||
        url.userInfo.isNotEmpty ||
        (url.hasPort && url.port != 443)) {
      return;
    }
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
                    Text(membershipMoney(_payment['amountMinor'])),
                    const SizedBox(height: 12),
                    Text(membershipPaymentLabel(_payment)),
                    if (_payment['expiresAtMillis'] != null)
                      Text(
                          'Paid expiry: ${membershipDate(_payment['expiresAtMillis'])}'),
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
                    PaymentEnvironmentDetails(sandbox: widget.repository.sandbox),
                  ]),
              const SizedBox(height: 12),
              if (status == 'expired' || status == 'failed')
                const Text(
                    'Checkout closed. You may start a fresh checkout from plans. A late cleared payment will require Admin review.'),
              if (status == 'expired' || status == 'failed')
                FilledButton.tonal(
                    onPressed: () => Navigator.push(context, MaterialPageRoute<void>(
                        builder: (_) => BrowsePlansScreen(repository: widget.repository))),
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
