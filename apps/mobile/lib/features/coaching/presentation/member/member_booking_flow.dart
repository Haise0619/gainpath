import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/coaching.dart'
    show
        BookingPaymentRepository,
        BookingPaymentQuote,
        PremiumVoucherBookingPaymentRepository,
        ReviewedBookingPaymentRepository;
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_domain/chatbot.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../application/live_booking_cubit.dart';
import '../../application/booking_date_availability.dart';
import 'booking_payment_screen.dart';

/// New purchases only. Existing appointments use the separate management flow.
class MemberBookingFlow extends StatefulWidget {
  const MemberBookingFlow(
      {super.key,
      required this.options,
      required this.writer,
      required this.coachId,
      required this.isCurrent,
      required this.onOpenBookings,
      this.payments,
      this.cancellation,
      this.suggestion});
  final MemberBookingOptionsRepository options;
  final BookingRepository writer;
  final BookingPaymentRepository? payments;
  final BookingCancellationRepository? cancellation;
  final BookingSuggestionAttachment? suggestion;
  final String coachId;
  final bool Function() isCurrent;
  final VoidCallback onOpenBookings;
  @override
  State<MemberBookingFlow> createState() => _MemberBookingFlowState();
}

class _MemberBookingFlowState extends State<MemberBookingFlow>
    with WidgetsBindingObserver {
  late final controller = LiveBookingCubit(
      options: widget.options,
      writer: widget.writer,
      coachId: widget.coachId,
      isCurrent: widget.isCurrent);
  late final dates = BookingDateAvailability(
      repository: widget.options,
      coachId: widget.coachId,
      isCurrent: () => widget.isCurrent());
  BookingPaymentQuote? _quote;
  String? _quoteBranch, _message;
  bool _quoteBusy = false, _reviewing = false, _voucher = false;
  bool _priceChanged = false,
      _priceAccepted = false,
      _opening = false,
      _closed = false;
  int _generation = 0;
  bool _interacted = false;
  final _scroll = ScrollController();
  String? _cancelRequestId;
  bool get _current => mounted && widget.isCurrent();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    dates.addListener(_datesChanged);
    unawaited(_initial());
  }

  @override
  void dispose() {
    _generation++;
    WidgetsBinding.instance.removeObserver(this);
    dates.removeListener(_datesChanged);
    dates.dispose();
    _scroll.dispose();
    controller.close();
    super.dispose();
  }

  void _datesChanged() {
    if (_current) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _current &&
        !_opening &&
        !_reviewing &&
        !controller.state.busy &&
        controller.state.intent == null &&
        controller.state.hold == null &&
        !controller.state.uncertain) {
      unawaited(_refresh(autoSelect: true));
    }
  }

  Future<void> _initial() async {
    final suggestion = widget.suggestion;
    await _refresh(
        localDate: suggestion?.expired == false ? suggestion!.localDate : null,
        autoSelect: true);
    if (!_current || suggestion == null || _interacted) return;
    final match = controller.state.options?.options
        .where((o) =>
            o.startAtMillis == suggestion.startAtMillis &&
            o.branchId == suggestion.branchId)
        .firstOrNull;
    if (!suggestion.expired &&
        suggestion.durationMinutes == 60 &&
        suggestion.coachId == widget.coachId &&
        match != null) {
      await _select(match);
    } else {
      setState(() => _message =
          'That suggestion is no longer available. Choose a current 60-minute session.');
    }
  }

  Future<void> _refresh({String? localDate, bool autoSelect = false}) async {
    if (_opening ||
        controller.state.uncertain ||
        controller.state.hold != null) {
      return;
    }
    ++_generation;
    setState(() {
      _quote = null;
      _quoteBranch = null;
      _quoteBusy = false;
      _voucher = false;
      _message = null;
      _reviewing = false;
    });
    await controller.refresh(localDate: localDate, durationMinutes: 60);
    if (!_current) return;
    if (controller.state.options?.durationMinutes != 60) return;
    await _loadQuote();
    if (!_current) return;
    final reference = controller.state.options;
    if (reference == null) return;
    await dates.loadPage(reference, refresh: true);
    if (_current &&
        autoSelect &&
        controller.state.intent == null &&
        controller.state.options?.localDate == reference.localDate &&
        reference.options.isEmpty &&
        dates.firstAvailable != null) {
      await _applyDate(dates.firstAvailable!);
    }
  }

  Future<void> _applyDate(BookingOptionsContext value) async {
    if (!_current ||
        _opening ||
        controller.state.busy ||
        controller.state.uncertain ||
        controller.state.hold != null) {
      return;
    }
    ++_generation;
    setState(() {
      _quote = null;
      _quoteBranch = null;
      _quoteBusy = false;
      _voucher = false;
      _message = null;
      _reviewing = false;
    });
    controller.useAvailability(value);
    await _loadQuote();
  }

  Future<void> _changeDatePage(int page) async {
    final reference = controller.state.options;
    if (reference == null ||
        dates.loading ||
        _quoteBusy ||
        _opening ||
        controller.state.hold != null ||
        controller.state.uncertain) {
      return;
    }
    _interacted = true;
    final interaction = _generation;
    await dates.loadPage(reference, targetPage: page);
    if (!_current || interaction != _generation) return;
    final choice = dates.firstAvailable ?? dates.value(dates.days.first);
    if (choice != null) await _applyDate(choice);
  }

  Future<void> _chooseCalendarDate(String day) async {
    _interacted = true;
    if (dates.state(day) == BookingDateState.failed) await dates.retry(day);
    if (!_current || dates.state(day) != BookingDateState.available) return;
    final value = dates.value(day);
    if (value != null) await _applyDate(value);
  }

  Future<void> _select(BookingOption option) async {
    if (_opening || controller.state.options?.durationMinutes != 60) return;
    _interacted = true;
    controller.select(option);
    setState(() {
      _voucher = false;
      _priceChanged = false;
      _priceAccepted = false;
      _message = null;
    });
    await _loadQuote();
  }

  Future<BookingPaymentQuote?> _loadQuote() async {
    final repo = widget.payments, state = controller.state;
    final branch = state.intent?.branchId.value ??
        state.options?.permittedBranchIds.firstOrNull;
    if (repo == null || branch == null || !_current) return null;
    final generation = ++_generation;
    setState(() {
      _quoteBusy = true;
      _message = null;
    });
    try {
      final quote = repo is PremiumVoucherBookingPaymentRepository
          ? await (repo as PremiumVoucherBookingPaymentRepository)
              .loadVoucherQuote(
                  coachId: widget.coachId,
                  branchId: branch,
                  durationMinutes: 60,
                  usePremiumVoucher: _voucher)
          : await repo.loadQuote(
              coachId: widget.coachId, branchId: branch, durationMinutes: 60);
      if (!_current || generation != _generation) return null;
      if (quote.durationMinutes != 60 || (_voucher && !quote.voucherApplied)) {
        throw const FormatException('Invalid quote');
      }
      setState(() {
        _quote = quote;
        _quoteBranch = branch;
      });
      return quote;
    } catch (_) {
      if (_current && generation == _generation && _voucher) {
        _voucher = false;
        final standard = await _loadQuote();
        if (_current && standard != null) {
          setState(() {
            _priceChanged = true;
            _priceAccepted = false;
            _message =
                'The voucher could not be applied. Review and accept the standard session price to continue.';
          });
        }
        return standard;
      }
      if (_current && generation == _generation) {
        setState(() {
          _quote = null;
          _message = 'We could not confirm the price. Please try again.';
        });
      }
      return null;
    } finally {
      if (_current && generation == _generation) {
        setState(() => _quoteBusy = false);
      }
    }
  }

  Future<void> _review() async {
    if (controller.state.intent == null || _quoteBusy) return;
    _interacted = true;
    final old = _quote;
    final quote = await _loadQuote();
    if (!_current || (widget.payments != null && quote == null)) return;
    setState(() {
      _reviewing = true;
      _priceChanged = old != null &&
          quote != null &&
          (old.amountMinor != quote.amountMinor ||
              old.grossAmountMinor != quote.grossAmountMinor ||
              old.discountMinor != quote.discountMinor);
      _priceAccepted = !_priceChanged;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  Future<void> _cancelHold() async {
    final repo = widget.cancellation, hold = controller.state.hold;
    if (repo == null || hold == null || !_current) {
      throw StateError('Reservation unavailable');
    }
    _cancelRequestId ??= 'member-close-${hold.bookingId}';
    final result = await repo.cancelHold(CancelBookingHoldRequest(
        organizationId: widget.options.scope.organizationId,
        bookingId: hold.bookingId,
        requestId: _cancelRequestId!));
    if (!_current || result.bookingId != hold.bookingId) {
      throw StateError('Account changed');
    }
    _closed = true;
  }

  Future<void> _reserve() async {
    if (_opening || _quoteBusy || !_current) return;
    if (_priceChanged && !_priceAccepted) {
      setState(() => _priceAccepted = true);
      return;
    }
    if (widget.payments is ReviewedBookingPaymentRepository &&
        _quote?.quoteToken == null) {
      setState(() => _message = 'Please refresh the price before continuing.');
      return;
    }
    setState(() {
      _opening = true;
      _message = null;
    });
    try {
      await controller.submit();
      if (!_current) return;
      final hold = controller.state.hold;
      if (hold == null) {
        if (controller.state.intent == null) setState(() => _reviewing = false);
        return;
      }
      if (widget.payments == null) {
        return; // Explicit injected hold-only composition.
      }
      final outcome = await Navigator.push<String>(
          context,
          MaterialPageRoute<String>(
              builder: (_) => BookingPaymentScreen(
                  repository: widget.payments!,
                  bookingId: hold.bookingId,
                  isCurrent: widget.isCurrent,
                  create: true,
                  reviewedQuoteToken: _quote?.quoteToken,
                  usePremiumVoucher: _voucher && _quote!.voucherApplied,
                  onCancelUnpaidReservation:
                      widget.cancellation == null ? null : _cancelHold)));
      if (!_current) return;
      if (outcome == 'quote_changed') {
        await _loadQuote();
        if (_current) {
          setState(() {
            _reviewing = true;
            _priceChanged = true;
            _priceAccepted = false;
          });
        }
        if (_scroll.hasClients) _scroll.jumpTo(0);
      } else if (outcome == 'expired' && widget.cancellation != null) {
        // A local timer is not proof of no payment: close/reconcile via server first.
        await _cancelHold();
      }
      if (_closed && _current) {
        controller.clearClosedHold();
        _closed = false;
        _cancelRequestId = null;
        _opening = false;
        await _refresh();
      }
    } catch (_) {
      if (_current) {
        setState(() => _message =
            'We could not confirm the reservation status. Check My bookings before choosing another time.');
      }
    } finally {
      if (_current) setState(() => _opening = false);
    }
  }

  Future<void> _nextAvailable() async {
    final options = controller.state.options;
    if (options == null || controller.state.busy || _quoteBusy) return;
    final generation = ++_generation;
    setState(() {
      _quoteBusy = true;
      _message = 'Checking the next available dates…';
    });
    try {
      var date = DateTime.parse(options.localDate).add(const Duration(days: 1));
      final last = DateTime.parse(options.throughLocalDate);
      while (!date.isAfter(last) && _current && generation == _generation) {
        final day = date.toIso8601String().substring(0, 10);
        final result = await widget.options
            .load(coachId: widget.coachId, localDate: day, durationMinutes: 60);
        if (!_current || generation != _generation) return;
        if (result.options.isNotEmpty) {
          _quoteBusy = false;
          await _refresh(localDate: day);
          return;
        }
        date = date.add(const Duration(days: 1));
      }
      if (_current && generation == _generation) {
        setState(() => _message =
            'No open sessions were found in the current booking window. Try again later.');
      }
    } catch (_) {
      if (_current && generation == _generation) {
        setState(() =>
            _message = 'We could not check the next dates. Please try again.');
      }
    } finally {
      if (_current && generation == _generation) {
        setState(() => _quoteBusy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<LiveBookingCubit,
          LiveBookingState>(
      bloc: controller,
      builder: (context, state) {
        if (!widget.isCurrent()) {
          return const Scaffold(
              body: Center(child: Text('Sign in again to view your booking.')));
        }
        final options = state.options, selected = state.intent;
        final busy = state.busy || _quoteBusy || _opening;
        final canReview = selected != null &&
            !busy &&
            !state.uncertain &&
            (widget.payments == null || _quote != null);
        final held = state.hold != null;
        return PopScope(
            canPop: !busy && !state.uncertain && !_reviewing,
            onPopInvokedWithResult: (didPop, result) {
              if (!didPop && _reviewing && !busy && !state.uncertain) {
                setState(() => _reviewing = false);
              }
            },
            child: Scaffold(
                appBar: AppBar(
                    title:
                        Text(_reviewing ? 'Review booking' : 'Book a session'),
                    leading: _reviewing
                        ? IconButton(
                            icon: const BackButtonIcon(),
                            tooltip: MaterialLocalizations.of(context)
                                .backButtonTooltip,
                            onPressed: busy || state.uncertain
                                ? null
                                : () => setState(() => _reviewing = false))
                        : null,
                    actions: [
                      IconButton(
                          tooltip: 'My bookings',
                          onPressed: busy ? null : widget.onOpenBookings,
                          icon: const Icon(Icons.event_note_outlined))
                    ]),
                bottomNavigationBar: SafeArea(
                    top: false,
                    child: Container(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        decoration: const BoxDecoration(
                            color: AppColors.surface,
                            border: Border(
                                top: BorderSide(color: AppColors.hairline))),
                        child: FilledButton(
                            onPressed: _reviewing
                                ? (busy ||
                                        selected == null ||
                                        (widget.payments != null &&
                                            _quote == null)
                                    ? null
                                    : _reserve)
                                : (canReview ? _review : null),
                            child: Text(busy
                                ? 'Please wait…'
                                : _reviewing
                                    ? (state.uncertain
                                        ? 'Retry reservation'
                                        : (_priceChanged && !_priceAccepted
                                            ? 'Accept updated price'
                                            : held
                                                ? 'Continue reservation'
                                                : 'Reserve session'))
                                    : 'Review Booking')))),
                body: SingleChildScrollView(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (busy) const LinearProgressIndicator(),
                          if (_message != null || state.message != null)
                            _notice(_message ?? _friendly(state.message!),
                                error: true),
                          if (_reviewing && selected != null)
                            ..._reviewContent(state)
                          else ...[
                            _coach(options),
                            const SizedBox(height: 20),
                            _heading('Choose a date'),
                            const SizedBox(height: 10),
                            if (options != null &&
                                options.durationMinutes == 60) ...[
                              _dates(options, busy || held || state.uncertain),
                              const SizedBox(height: 20),
                              _heading('Available starting times'),
                              const SizedBox(height: 4),
                              Text(
                                  options.timeZone == 'Asia/Kuala_Lumpur'
                                      ? 'All times in Malaysia time (MYT)'
                                      : 'All times in ${options.timeZone}',
                                  style: const TextStyle(
                                      color: AppColors.inkSoft, fontSize: 13)),
                              const SizedBox(height: 12),
                              if (options.options.isEmpty)
                                _empty(options, busy)
                              else
                                _times(
                                    options, busy || held || state.uncertain),
                            ] else if (!state.busy) ...[
                              const Text(
                                  'Sessions are temporarily unavailable.'),
                              TextButton(
                                  onPressed: busy ? null : () => _refresh(),
                                  child: const Text('Try again')),
                            ],
                          ],
                          if (_quote == null &&
                              widget.payments != null &&
                              !busy)
                            TextButton(
                                onPressed: _loadQuote,
                                child: const Text('Retry price')),
                          if (held && widget.payments == null) ...[
                            _notice(
                                'Your reservation is saved. It is not confirmed until payment is verified.'),
                            TextButton(
                                onPressed: widget.onOpenBookings,
                                child: const Text('My bookings')),
                          ],
                          if (state.uncertain) ...[
                            _notice(
                                'Your reservation may already be saved. Retry to check the same request, or view My bookings. Please avoid making another reservation.'),
                            TextButton(
                                onPressed: busy ? null : widget.onOpenBookings,
                                child: const Text('View My bookings')),
                          ],
                        ]))));
      });

  Widget _coach(BookingOptionsContext? options) =>
      _surface(Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: AppColors.primaryTint,
                borderRadius: BorderRadius.circular(16)),
            child: const Icon(Icons.fitness_center_rounded,
                color: AppColors.primary, size: 26)),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
              _quote?.coachName ?? options?.coachDisplayName ?? 'Coach profile',
              style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 20,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 5),
          const Text('60-minute coaching session',
              style: TextStyle(color: AppColors.inkSoft, fontSize: 14)),
          if (_quote != null) ...[
            const SizedBox(height: 8),
            Text(_quote!.formattedAmount,
                style: const TextStyle(
                    color: AppColors.primaryDark,
                    fontSize: 20,
                    fontWeight: FontWeight.w700))
          ],
        ])),
      ]));

  Widget _dates(BookingOptionsContext options, bool locked) {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final pageDays = dates.days;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
                pageDays.isEmpty
                    ? 'Checking dates…'
                    : '${bookingFriendlyDate(pageDays.first)} – ${bookingFriendlyDate(pageDays.last)}',
                style: const TextStyle(color: AppColors.inkSoft, fontSize: 13)),
            Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(
                  tooltip: 'Previous dates',
                  onPressed: locked || dates.loading || !dates.hasPrevious
                      ? null
                      : () => _changeDatePage(dates.page - 1),
                  icon: const Icon(Icons.chevron_left_rounded)),
              IconButton(
                  tooltip: 'Next dates',
                  onPressed: locked || dates.loading || !dates.hasNext
                      ? null
                      : () => _changeDatePage(dates.page + 1),
                  icon: const Icon(Icons.chevron_right_rounded)),
              IconButton(
                  tooltip: 'Refresh dates',
                  onPressed: locked || dates.loading
                      ? null
                      : () => _refresh(
                          localDate: options.localDate, autoSelect: true),
                  icon: const Icon(Icons.refresh_rounded)),
            ]),
          ]),
      if (pageDays.isNotEmpty)
        SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: IntrinsicHeight(
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: List.generate(pageDays.length, (index) {
                      final day = pageDays[index],
                          date = DateTime.parse(day),
                          status = dates.state(day);
                      final available = status == BookingDateState.available,
                          failed = status == BookingDateState.failed;
                      final selected = available && day == options.localDate;
                      final enabled =
                          !locked && (available || (failed && !dates.loading));
                      final label = switch (status) {
                        BookingDateState.available => 'Available',
                        BookingDateState.unavailable => 'No sessions available',
                        BookingDateState.failed =>
                          'Could not check, tap to retry',
                        BookingDateState.checking => 'Checking availability'
                      };
                      return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Semantics(
                              button: true,
                              enabled: enabled,
                              selected: selected,
                              label: '${bookingFriendlyDate(day)}, $label',
                              child: Material(
                                  color: selected
                                      ? AppColors.primary
                                      : available || failed
                                          ? AppColors.surface
                                          : AppColors.surfaceAlt,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      side: BorderSide(
                                          color: selected
                                              ? AppColors.primary
                                              : AppColors.hairline)),
                                  child: InkWell(
                                    key: ValueKey('booking-date-$day'),
                                    onTap: enabled
                                        ? () => _chooseCalendarDate(day)
                                        : null,
                                    borderRadius: BorderRadius.circular(16),
                                    child: Container(
                                        width: 76 * scale.clamp(1, 1.5),
                                        padding: const EdgeInsets.all(10),
                                        child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                  const [
                                                    'Mon',
                                                    'Tue',
                                                    'Wed',
                                                    'Thu',
                                                    'Fri',
                                                    'Sat',
                                                    'Sun'
                                                  ][date.weekday - 1],
                                                  style: TextStyle(
                                                      color: selected
                                                          ? Colors.white
                                                          : AppColors.inkSoft,
                                                      fontSize: 13)),
                                              const SizedBox(height: 5),
                                              Text(
                                                  '${date.day} ${_months[date.month - 1]}',
                                                  style: TextStyle(
                                                      color: selected
                                                          ? Colors.white
                                                          : AppColors.inkSoft,
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w700)),
                                              const SizedBox(height: 6),
                                              if (status ==
                                                  BookingDateState.checking)
                                                const Icon(
                                                    Icons.more_horiz_rounded,
                                                    size: 16,
                                                    color: AppColors.inkSoft)
                                              else if (!available)
                                                Text(
                                                    failed
                                                        ? 'Retry'
                                                        : 'No slots',
                                                    style: TextStyle(
                                                        color: failed
                                                            ? AppColors.primary
                                                            : AppColors.inkSoft,
                                                        fontSize: 11)),
                                            ])),
                                  ))));
                    })))),
    ]);
  }

  Widget _times(BookingOptionsContext options, bool locked) {
    final branches = options.options.map((o) => o.branchId).toSet();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final branch in branches) ...[
        Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(_branch(branch, options),
                style: const TextStyle(
                    color: AppColors.inkSoft, fontWeight: FontWeight.w600))),
        LayoutBuilder(builder: (context, constraints) {
          final scale = MediaQuery.textScalerOf(context).scale(1);
          final columns = scale > 1.5
              ? 1
              : constraints.maxWidth >= 340
                  ? 3
                  : 2;
          final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
          return Wrap(spacing: 10, runSpacing: 10, children: [
            for (final option in options.options.where((o) => o.branchId == branch))
              SizedBox(
                  width: width,
                  child: Semantics(
                      selected: controller.state.intent?.startAt == option.startAt &&
                          controller.state.intent?.branchId.value ==
                              option.branchId,
                      child: OutlinedButton(
                          onPressed: locked ? null : () => _select(option),
                          style: OutlinedButton.styleFrom(
                              backgroundColor: controller.state.intent?.startAt == option.startAt &&
                                      controller.state.intent?.branchId.value ==
                                          option.branchId
                                  ? AppColors.primaryTint
                                  : AppColors.surface,
                              side: BorderSide(
                                  color: controller.state.intent?.startAt == option.startAt &&
                                          controller.state.intent?.branchId.value == option.branchId
                                      ? AppColors.primary
                                      : AppColors.hairline),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
                              minimumSize: const Size(48, 48)),
                          child: Text(bookingFriendlyTime(option.startLabel))))),
          ]);
        }),
        const SizedBox(height: 14),
      ]
    ]);
  }

  List<Widget> _reviewContent(LiveBookingState state) {
    final intent = state.intent!, options = state.options!;
    final end = intent.startAt.add(const Duration(minutes: 60));
    return [
      if (_priceChanged)
        _notice(
            'The price changed. Review the updated total and accept it before continuing.',
            error: true),
      _surface(
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _heading(_quote?.coachName ??
            options.coachDisplayName ??
            'Your coaching session'),
        const SizedBox(height: 12),
        _row('Date', bookingFriendlyDate(options.localDate)),
        _row('Time',
            '${bookingFriendlyTime(_label(intent.startAt))} – ${bookingFriendlyTime(_label(end))} MYT'),
        _row('Duration', '60 minutes'),
        _row('Location',
            _quote?.branchName ?? _branch(intent.branchId.value, options)),
        if (_quote != null) ...[
          _row('Session price',
              _money(_quote!.grossAmountMinor ?? _quote!.amountMinor)),
          if (_quote!.voucherApplied)
            _row('Premium voucher', '− ${_money(_quote!.discountMinor!)}'),
          const Divider(height: 24, color: AppColors.hairline),
          _row('Total payable', _quote!.formattedAmount, strong: true),
        ],
      ])),
      const SizedBox(height: 14),
      if (_quote?.voucher?.available == true || _quote?.voucherApplied == true)
        _surface(CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _voucher,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('Use Premium Coach voucher'),
            onChanged: _quoteBusy || state.hold != null
                ? null
                : (value) async {
                    setState(() => _voucher = value == true);
                    await _loadQuote();
                  })),
      const SizedBox(height: 14),
      _surface(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _heading('Before you book'),
        const SizedBox(height: 10),
        const Text('Cancel at least 12 hours before your session.'),
        const SizedBox(height: 8),
        const Text(
            'Reschedule at least 24 hours before your session. Your coach, location, duration and paid price stay the same.'),
        const SizedBox(height: 8),
        const Text(
            'Paid cancellations go to refund review. Cancelling does not mean a refund has been sent.',
            style: TextStyle(color: AppColors.inkSoft, fontSize: 14)),
      ])),
    ];
  }

  Widget _empty(BookingOptionsContext options, bool busy) =>
      _surface(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.event_busy_outlined,
            color: AppColors.primary, size: 30),
        const SizedBox(height: 10),
        _heading('No open sessions on this date'),
        const SizedBox(height: 8),
        Text(
            options.unavailableReason == 'daily_limit'
                ? 'You or your coach have reached the daily booking limit. Check your active reservations or try another date.'
                : 'Try a different day, or let us check the next available dates.',
            style: const TextStyle(color: AppColors.inkSoft)),
        TextButton(
            onPressed: busy ? null : _nextAvailable,
            child: const Text('Find next available date')),
        TextButton(
            onPressed: busy ? null : widget.onOpenBookings,
            child: const Text('View My bookings')),
      ]));
  String _branch(String id, BookingOptionsContext options) =>
      options.branchDisplayNames[id] ??
      (_quoteBranch == id && _quote?.branchName != '-'
          ? _quote?.branchName
          : null) ??
      'Location details unavailable';
  String _label(DateTime time) {
    final local = time.toUtc().add(const Duration(hours: 8));
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  String _friendly(String message) => message
      .replaceAll('Intent', 'Reservation')
      .replaceAll('intent', 'reservation')
      .replaceAll('pending hold', 'reservation');
  String _money(int amount) => 'RM ${(amount / 100).toStringAsFixed(2)}';
  Widget _row(String label, String value, {bool strong = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: LayoutBuilder(builder: (context, constraints) {
        final title = Text(label,
            style: const TextStyle(color: AppColors.inkSoft, fontSize: 14));
        final content = Text(value,
            style: TextStyle(
                color: strong ? AppColors.primaryDark : AppColors.ink,
                fontSize: strong ? 20 : 16,
                fontWeight: strong ? FontWeight.w800 : FontWeight.w600));
        return MediaQuery.textScalerOf(context).scale(1) > 1.3
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [title, const SizedBox(height: 4), content])
            : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: title),
                const SizedBox(width: 12),
                Expanded(flex: 2, child: content)
              ]);
      }));
  Widget _heading(String text) => Semantics(
      header: true,
      child: Text(text,
          style: const TextStyle(
              color: AppColors.ink,
              fontSize: 18,
              fontWeight: FontWeight.w700)));
  Widget _surface(Widget child) => Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.hairline)),
      child: child);
  Widget _notice(String text, {bool error = false}) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _surface(Text(text,
          style: TextStyle(
              color: error ? AppColors.danger : AppColors.inkSoft,
              fontSize: 14))));
}

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec'
];
String bookingFriendlyDate(String day) {
  final d = DateTime.parse(day);
  return '${d.day} ${_months[d.month - 1]} ${d.year}';
}

String bookingFriendlyTime(String label) {
  final m = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(label);
  if (m == null) return 'Time unavailable';
  final h = int.parse(m[1]!);
  return '${h % 12 == 0 ? 12 : h % 12}:${m[2]} ${h < 12 ? 'AM' : 'PM'}';
}
