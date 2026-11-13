import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show BookingException;
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:url_launcher/url_launcher.dart';
import 'booking_confirmed_screen.dart';

class BookingPaymentScreen extends StatefulWidget {
  const BookingPaymentScreen(
      {super.key,
      required this.repository,
      required this.bookingId,
      required this.isCurrent,
      this.create = false,
      this.usePremiumVoucher = false,
      this.reviewedQuoteToken,
      this.onCancelUnpaidReservation,
      this.now = DateTime.now});
  final BookingPaymentRepository repository;
  final String bookingId;
  final bool Function() isCurrent;
  final bool create;
  final bool usePremiumVoucher;
  final String? reviewedQuoteToken;
  final Future<void> Function()? onCancelUnpaidReservation;
  final DateTime Function() now;
  @override
  State<BookingPaymentScreen> createState() => _BookingPaymentScreenState();
}

class _BookingPaymentScreenState extends State<BookingPaymentScreen>
    with WidgetsBindingObserver {
  BookingPaymentView? _payment;
  bool _busy = false;
  String? _message;
  DateTime? _nextAllowedCheck;
  DateTime? _lastChecked;
  Timer? _retryTimer;
  int _followupsRemaining = 6;
  bool _foreground = true;
  bool _finished = false;
  bool _createRequested = false;
  bool _quoteChanged = false;
  bool _opening = false;
  bool _openedPayment = false;
  final Stopwatch _serverClock = Stopwatch();
  int? _serverAnchor;
  Timer? _countdown;
  int get _nowMillis => _serverAnchor == null
      ? widget.now().millisecondsSinceEpoch
      : _serverAnchor! + _serverClock.elapsedMilliseconds;
  int get _remainingSeconds => _payment == null
      ? 0
      : ((_payment!.holdExpiresAtMillis - _nowMillis) / 1000)
          .ceil()
          .clamp(0, 86400);
  bool get _expired =>
      _payment != null &&
      const ['creating', 'awaiting_payment'].contains(_payment!.status) &&
      _payment!.paymentStatus != 'cleared' &&
      _payment!.refundStatus == null &&
      _remainingSeconds == 0;
  bool get _canCheck =>
      mounted && _foreground && !_finished && widget.isCurrent();

  void _scheduleCheck() {
    _retryTimer?.cancel();
    _retryTimer = null;
    if (!_canCheck || _followupsRemaining <= 0) return;
    final delay = _nextAllowedCheck?.difference(widget.now()) ?? Duration.zero;
    _retryTimer = Timer(delay.isNegative ? Duration.zero : delay, () {
      _retryTimer = null;
      if (!_canCheck) return;
      _followupsRemaining--;
      _load();
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    _load(create: widget.create);
    _countdown = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_canCheck && _payment != null) setState(() {});
    });
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _countdown?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) {
      _retryTimer?.cancel();
      _retryTimer = null;
    } else {
      _followupsRemaining = 6;
      _load();
    }
  }

  Future<void> _load({bool create = false, bool manual = false}) async {
    if (!_canCheck || _busy) return;
    if (manual) _followupsRemaining = 6;
    _createRequested = _createRequested || create;
    final remaining = _nextAllowedCheck?.difference(widget.now());
    if (remaining != null && remaining > Duration.zero) {
      setState(() => _message =
          'Waiting for the next trusted check. We will check again automatically.');
      _scheduleCheck();
      return;
    }
    _retryTimer?.cancel();
    _retryTimer = null;
    final shouldCreate = _createRequested;
    _createRequested = false;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final result = await (shouldCreate
          ? widget.reviewedQuoteToken != null
              ? (widget.repository as ReviewedBookingPaymentRepository)
                  .createReviewed(widget.bookingId,
                      quoteToken: widget.reviewedQuoteToken!,
                      usePremiumVoucher: widget.usePremiumVoucher)
              : widget.usePremiumVoucher
                  ? (widget.repository
                          as PremiumVoucherBookingPaymentRepository)
                      .createWithPremiumVoucher(widget.bookingId)
                  : widget.repository.create(widget.bookingId)
          : widget.repository.get(widget.bookingId));
      if (!mounted || !widget.isCurrent()) return;
      setState(() {
        _payment = result;
        _lastChecked = widget.now();
        if (result.serverNowMillis != null) {
          // Never allow a stale response to extend an existing reservation.
          final previousNow = _serverAnchor == null ? null : _nowMillis;
          _serverAnchor =
              previousNow == null || result.serverNowMillis! > previousNow
                  ? result.serverNowMillis
                  : previousNow;
          _serverClock
            ..reset()
            ..start();
        }
      });
      if (_foreground && result.confirmed && result.refundStatus == null) {
        _finished = true;
        Navigator.pushReplacement(
            context,
            MaterialPageRoute<void>(
                builder: (_) => BookingConfirmedScreen(
                    payment: result, isCurrent: widget.isCurrent)));
      }
    } catch (error) {
      if (mounted && widget.isCurrent()) {
        if (error is BookingException &&
            error.code == 'booking-quote-changed') {
          setState(() => _quoteChanged = true);
          return;
        }
        setState(() => _message =
            'Payment status unavailable. Check again or retry payment for this same booking.');
      }
    } finally {
      _nextAllowedCheck = widget.now().add(const Duration(seconds: 10));
      if (mounted) {
        setState(() => _busy = false);
        _scheduleCheck();
      }
    }
  }

  Future<void> _open() async {
    final value = _payment;
    if (!widget.isCurrent() ||
        _busy ||
        _opening ||
        _expired ||
        _quoteChanged ||
        value?.paymentStatus == 'cleared' ||
        value?.status != 'awaiting_payment' ||
        value?.checkoutUrl == null ||
        !isBillplzSandboxCheckoutUrl(value!.checkoutUrl!)) {
      return;
    }
    setState(() => _opening = true);
    try {
      final opened = await launchUrl(Uri.parse(value.checkoutUrl!),
          mode: LaunchMode.externalApplication);
      if (opened && mounted && widget.isCurrent()) {
        setState(() => _openedPayment = true);
      }
      if (!opened && mounted && widget.isCurrent()) {
        setState(() =>
            _message = 'Could not open Billplz. Try opening payment again.');
      }
    } catch (_) {
      if (mounted && widget.isCurrent()) {
        setState(() =>
            _message = 'Could not open Billplz. Try opening payment again.');
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<void> _cancel() async {
    if (_busy || !widget.isCurrent()) return;
    setState(() => _busy = true);
    try {
      await widget.onCancelUnpaidReservation!();
      if (mounted && widget.isCurrent()) Navigator.pop(context, 'cancelled');
    } catch (_) {
      if (mounted && widget.isCurrent()) {
        setState(() => _message =
            'Could not cancel your reservation. Check its status before trying again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isCurrent()) {
      return const Scaffold(
          body: Center(child: Text('Payments unavailable for this session.')));
    }
    final value = _payment;
    final refund = value?.refundStatus;
    final title = switch (refund) {
      'completed' => 'Refund completed',
      'failed' => 'Refund needs attention',
      'approved' => 'Refund approved · not sent',
      'uncertain' => 'Refund outcome not confirmed',
      'processing' => 'Refund in progress',
      'rejected' => 'Refund request declined',
      _ => _quoteChanged
          ? 'Your booking price changed'
          : _expired
              ? 'Reservation expired'
              : value?.status == 'reconciliation_required'
                  ? 'Payment needs review'
                  : value == null
                      ? 'Preparing your payment'
                      : _openedPayment || value.paymentStatus == 'cleared'
                          ? 'Checking your payment'
                          : 'Your time is reserved',
    };
    final detail = switch (refund) {
      'completed' =>
        'Your payment has been refunded. This booking is not confirmed.',
      'failed' =>
        'The refund could not be completed. Contact the gym for help.',
      'approved' =>
        'The gym approved your refund request. This approval does not mean a refund has been sent. Contact the gym for the next step.',
      'uncertain' =>
        'The provider outcome could not be confirmed. Contact the gym to check the original refund attempt. Do not request another payment or refund for this booking.',
      'processing' =>
        'Your refund is being processed. Contact the gym if you need help.',
      'rejected' =>
        'The gym declined this refund request. Contact the gym for details.',
      _ => value?.status == 'reconciliation_required'
          ? value?.paymentStatus == 'cleared'
              ? 'Payment was received, but your booking is not confirmed. Contact the gym for a payment review.'
              : 'Your booking is not confirmed. Contact the gym before attempting another payment.'
          : _quoteChanged
              ? 'Review the updated total before continuing. No checkout was created.'
              : _expired
                  ? 'This unpaid reservation has ended. Choose another available time. If you already paid, check payment status before booking again.'
                  : _openedPayment || value?.paymentStatus == 'cleared'
                      ? 'We are waiting for payment confirmation. You can safely check again here without paying twice.'
                      : 'Complete payment before your reservation ends to secure your session.',
    };
    return Scaffold(
        appBar: AppBar(title: const Text('Session payment')),
        body: PageBody(children: [
          if (_busy) const LinearProgressIndicator(),
          Panel(
              child: Column(children: [
            const Icon(Icons.lock_outline, color: AppColors.primary, size: 40),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            if (refund == null && !_expired && !_quoteChanged)
              const Text(
                  'Pay securely with Billplz Sandbox. Return here for confirmation.'),
            if (value != null) ...[
              DetailRow('Coach', value.quote.coachName),
              DetailRow('Location', value.quote.branchName),
              const Text(
                  'Checkout time. See My Bookings for any rescheduled time.'),
              DetailRow('Date', value.localDate),
              DetailRow('Time', '${value.startLabel} – ${value.endLabel}'),
              DetailRow('Total', value.quote.formattedAmount),
              DetailRow(
                  'Session length', '${value.quote.durationMinutes} minutes'),
              if (!_expired &&
                  !_quoteChanged &&
                  value.status == 'awaiting_payment' &&
                  value.paymentStatus != 'cleared' &&
                  refund == null)
                Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                        'Time remaining: ${_remainingSeconds ~/ 60}:${(_remainingSeconds % 60).toString().padLeft(2, '0')}',
                        style: Theme.of(context).textTheme.titleLarge)),
              if (value.quote.voucherApplied)
                DetailRow('Premium Coach voucher',
                    '- RM ${(value.quote.discountMinor! / 100).toStringAsFixed(2)}'),
              if (_lastChecked != null)
                Text(
                    'Last checked at ${TimeOfDay.fromDateTime(_lastChecked!).format(context)}.'),
              Text(_followupsRemaining > 0
                  ? 'Checks continue every 10 seconds while this screen is open.'
                  : 'Automatic checks paused. Check again when you are ready.'),
            ],
            Text(detail),
            if (_message != null) Text(_message!),
          ])),
          if (_quoteChanged)
            FilledButton(
                onPressed: () => Navigator.pop(context, 'quote_changed'),
                child: const Text('Return to booking review')),
          if (_expired)
            FilledButton(
                onPressed: () => Navigator.pop(context, 'expired'),
                child: const Text('Choose another time')),
          if (!_expired &&
              !_quoteChanged &&
              refund == null &&
              value?.paymentStatus != 'cleared' &&
              value?.status == 'awaiting_payment' &&
              value?.checkoutUrl != null)
            FilledButton(
                onPressed: _busy || _opening ? null : _open,
                child: const Text('Continue to Payment')),
          OutlinedButton(
              onPressed: _busy ? null : () => _load(manual: true),
              child: const Text('Check payment status')),
          if (!_expired &&
              !_quoteChanged &&
              (value == null ||
                  value.status == 'creating' ||
                  (value.status == 'awaiting_payment' &&
                      value.checkoutUrl == null)))
            TextButton(
                onPressed:
                    _busy ? null : () => _load(create: true, manual: true),
                child: const Text('Retry payment for same booking')),
          if (!_expired &&
              !_quoteChanged &&
              refund == null &&
              value?.paymentStatus != 'cleared' &&
              value?.status == 'awaiting_payment' &&
              widget.onCancelUnpaidReservation != null)
            TextButton(
                onPressed: _busy ? null : _cancel,
                child: const Text('Cancel unpaid reservation')),
          const Text(
              'Need help? Contact your gym with the coach, session time and payment status shown here.'),
        ]));
  }
}
