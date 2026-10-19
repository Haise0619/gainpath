import 'package:flutter/material.dart';
import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:url_launcher/url_launcher.dart';
import 'booking_confirmed_screen.dart';

class BookingPaymentScreen extends StatefulWidget {
  const BookingPaymentScreen(
      {super.key,
      required this.repository,
      required this.bookingId,
      required this.isCurrent,
      this.create = false});
  final BookingPaymentRepository repository;
  final String bookingId;
  final bool Function() isCurrent;
  final bool create;
  @override
  State<BookingPaymentScreen> createState() => _BookingPaymentScreenState();
}

class _BookingPaymentScreenState extends State<BookingPaymentScreen>
    with WidgetsBindingObserver {
  BookingPaymentView? _payment;
  bool _busy = false;
  String? _message;
  DateTime? _lastCheck;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load(create: widget.create);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load({bool create = false}) async {
    if (_busy ||
        !widget.isCurrent() ||
        (!create &&
            _lastCheck != null &&
            DateTime.now().difference(_lastCheck!) <
                const Duration(seconds: 5))) {
      return;
    }
    _lastCheck = DateTime.now();
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final result = await (create
          ? widget.repository.create(widget.bookingId)
          : widget.repository.get(widget.bookingId));
      if (!mounted || !widget.isCurrent()) return;
      setState(() => _payment = result);
      if (result.confirmed) {
        Navigator.pushReplacement(
            context,
            MaterialPageRoute<void>(
                builder: (_) => BookingConfirmedScreen(payment: result)));
      } else if (create && result.status == 'awaiting_payment') {
        await _open();
      }
    } catch (_) {
      if (mounted && widget.isCurrent()) {
        setState(() => _message =
            'Payment status unavailable. Check again or retry payment for this same booking.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _open() async {
    final value = _payment;
    if (!widget.isCurrent() ||
        value?.status != 'awaiting_payment' ||
        value?.checkoutUrl == null ||
        !isBillplzSandboxCheckoutUrl(value!.checkoutUrl!)) {
      return;
    }
    try {
      final opened = await launchUrl(Uri.parse(value.checkoutUrl!),
          mode: LaunchMode.externalApplication);
      if (!opened && mounted && widget.isCurrent()) {
        setState(() =>
            _message = 'Could not open Billplz. Try opening payment again.');
      }
    } catch (_) {
      if (mounted && widget.isCurrent()) {
        setState(() =>
            _message = 'Could not open Billplz. Try opening payment again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isCurrent()) {
      return const Scaffold(
          body: Center(child: Text('Payments unavailable for this session.')));
    }
    final value = _payment;
    return Scaffold(
        appBar: AppBar(title: const Text('Session payment')),
        body: PageBody(children: [
          if (_busy) const LinearProgressIndicator(),
          Panel(
              child: Column(children: [
            const Icon(Icons.lock_outline, color: AppColors.primary, size: 40),
            const SizedBox(height: 12),
            Text(
                value?.status == 'reconciliation_required'
                    ? 'Payment needs review'
                    : 'Complete payment with Billplz',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            const Text(
                'Billplz sandbox opens in your browser. Return here to check the trusted booking status.'),
            if (value != null) ...[
              DetailRow('Coach', value.quote.coachName),
              DetailRow('Location', value.quote.branchName),
              DetailRow('Date', value.localDate),
              DetailRow('Time', '${value.startLabel} – ${value.endLabel}'),
              DetailRow('Total', value.quote.formattedAmount),
              Text(value.status == 'reconciliation_required'
                  ? 'Your booking is not confirmed. Contact the gym before attempting another payment.'
                  : 'Your booking remains pending until the server verifies payment.'),
            ],
            if (_message != null) Text(_message!),
          ])),
          if (value?.status == 'awaiting_payment' && value?.checkoutUrl != null)
            FilledButton(
                onPressed: _busy ? null : _open,
                child: const Text('Open Billplz sandbox')),
          OutlinedButton(
              onPressed: _busy ? null : () => _load(),
              child: const Text('Check payment status')),
          if (value == null ||
              value.status == 'creating' ||
              (value.status == 'awaiting_payment' && value.checkoutUrl == null))
            TextButton(
                onPressed: _busy ? null : () => _load(create: true),
                child: const Text('Retry payment for same booking')),
        ]));
  }
}
