import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gainpath_domain/membership.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../domain/membership_payment_preview.dart';
import '../shared/membership_data_view.dart';
import '../../application/membership_feature_host.dart';

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
  late final String _requestId =
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
    } catch (_) {
      if (mounted) {
        setState(() => _message =
            'Checkout outcome is not confirmed. Retry this same request or check billing history before starting another payment.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
          title:
              Text(widget.renewal ? 'Confirm renewal' : 'Confirm your plan')),
      body: PageBody(children: [
        Panel(
            background: AppColors.primaryTint,
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.plan.name,
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(widget.plan.tagline),
              ...widget.plan.perks.map((b) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.check_circle_outline),
                  title: Text(b))),
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
            DetailRow('Period', '${_quote!['durationDays']} days'),
            DetailRow('Total', membershipMoney(_quote!['amountMinor']))
          ])),
        const SizedBox(height: 16),
        Text(widget.repository.sandbox
            ? 'Billplz Sandbox test checkout. No recurring billing. Membership activates only after server verification.'
            : 'Mock preview. Payment is simulated.'),
        const SizedBox(height: 16),
        FilledButton(
            onPressed: _busy || _quote == null ? null : _pay,
            child: Text(_submitted
                ? 'Recover checkout'
                : 'Continue to secure checkout')),
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
    return MembershipRepositoryGuard(
        repository: widget.repository,
        child: Scaffold(
            appBar: AppBar(title: const Text('Membership payment')),
            body: PageBody(children: [
              Panel(
                  background: AppColors.primaryTint,
                  child: Column(children: [
                    Text('${_payment['planName']}',
                        style: Theme.of(context).textTheme.headlineSmall),
                    Text(membershipMoney(_payment['amountMinor'])),
                    const SizedBox(height: 12),
                    Text(membershipPaymentLabel(_payment)),
                    if (_payment['expiresAtMillis'] != null)
                      Text(
                          'Paid expiry: ${membershipDate(_payment['expiresAtMillis'])}'),
                  ])),
              const SizedBox(height: 16),
              Text('Reference: ${_payment['transactionId']}'),
              const SizedBox(height: 12),
              if (status == 'expired' || status == 'failed')
                const Text(
                    'Checkout closed. You may start a fresh checkout from plans. A late cleared payment will require Admin review.'),
              if (status == 'reconciliation_required')
                const Text(
                    'Admin review required. Do not make another payment for this checkout.'),
              if (_payment['paymentStatus'] != 'cleared')
                const Text(
                    'Pending verification. Closing checkout does not confirm or cancel a bank payment. You can recover this record from billing history.'),
              if (_message != null) Text(_message!),
              if (_busy) const LinearProgressIndicator(),
              if (status == 'awaiting_payment' &&
                  _payment['checkoutUrl'] != null)
                FilledButton(
                    onPressed: _busy ? null : _open,
                    child: const Text('Open Billplz Sandbox')),
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
                  child: const Text('Check trusted payment status')),
            ])));
  }
}
