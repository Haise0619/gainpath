import 'booking_payment_screen.dart';
import 'package:flutter/material.dart';
import '../../application/booking_bloc.dart';
import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../../../navigation/feature_navigation.dart';
import 'booking_confirmed_screen.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_domain/gainpath_domain.dart' as persisted;
import '../../application/live_booking_cubit.dart';
import 'widgets/booking_selection_page.dart';

/// AD-M7.2 — Book Coaching Session. Fee, day, and time all come from the
/// coach passed in; confirming payment creates a real `Booking` and adds
/// it to `allBookings`, so it shows up both on the member's "My
/// bookings" and on that coach's own roster — the two are filtered views
/// over one shared list, not separate data.
class BookSessionScreen extends StatefulWidget {
  final Coach? coach;
  final BookingPaymentRepository? payments;
  final persisted.MemberBookingOptionsRepository? options;
  final persisted.BookingRepository? writer;
  final String? coachId;
  final bool Function()? isCurrent;
  final VoidCallback? onOpenBookings;
  const BookSessionScreen(
      {super.key,
      this.coach,
      this.payments,
      this.options,
      this.writer,
      this.coachId,
      this.isCurrent,
      this.onOpenBookings});

  @override
  State<BookSessionScreen> createState() => _BookSessionScreenState();
}

class _BookSessionScreenState extends State<BookSessionScreen> {
  int _day = 0;
  int? _slot;

  final _slots = const ['09:00', '10:30', '14:00', '15:30', '17:00', '18:30'];

  @override
  Widget build(BuildContext context) {
    if (widget.options != null) {
      return _PersistedBookSessionView(
          options: widget.options!,
          writer: widget.writer!,
          payments: widget.payments,
          coachId: widget.coachId!,
          isCurrent: widget.isCurrent!,
          onOpenBookings: widget.onOpenBookings!);
    }
    final days =
        List.generate(5, (i) => DateTime.now().add(Duration(days: i + 1)));
    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return BookingSelectionPage(
      days: [
        for (final entry in days.indexed)
          BookingDayOption(
              date: entry.$2,
              selected: entry.$1 == _day,
              onTap: () => setState(() {
                    _day = entry.$1;
                    _slot = null;
                  }))
      ],
      times: [
        for (final entry in _slots.indexed)
          BookingTimeOption(
              label: entry.$2,
              selected: entry.$1 == _slot,
              unavailable: entry.$1 == 2,
              onTap:
                  entry.$1 == 2 ? null : () => setState(() => _slot = entry.$1))
      ],
      details: [
        DetailRow('Coach', widget.coach!.name),
        DetailRow(
            'Date', '${dayNames[days[_day].weekday - 1]} ${days[_day].day}'),
        DetailRow('Time', _slot == null ? 'Not selected' : _slots[_slot!]),
        DetailRow('Location', widget.coach!.branch),
        DetailRow('Total', 'RM ${widget.coach!.fee.toStringAsFixed(2)}')
      ],
      footer: [
        FilledButton(
            onPressed: _slot == null ? null : _pay,
            child: const Text('Continue to payment'))
      ],
    );
  }

  Future<void> _pay() async {
    final days =
        List.generate(5, (i) => DateTime.now().add(Duration(days: i + 1)));
    final selectedDay = days[_day];
    final timeParts = _slots[_slot!].split(':');
    final start = DateTime(selectedDay.year, selectedDay.month, selectedDay.day,
        int.parse(timeParts[0]), int.parse(timeParts[1]));

    final success = await Navigator.pushNamed<bool>(
      context,
      FeatureNavigation.checkout,
      arguments: CheckoutArguments(
        amount: widget.coach!.fee,
        description: 'Coaching session with ${widget.coach!.name}',
      ),
    );
    if (success != true || !mounted) return;

    final booking = Booking(
      id: 'b${DateTime.now().millisecondsSinceEpoch}',
      coachId: widget.coach!.id,
      coachName: widget.coach!.name,
      memberName: context.read<MemberProfileRepository>().memberName,
      start: start,
      branch: widget.coach!.branch,
      status: BookingStatus.confirmed,
      fee: widget.coach!.fee,
    );
    context.read<BookingBloc>().add(BookingCreated(booking));

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
          builder: (_) => BookingConfirmedScreen(booking: booking)),
    );
  }
}

class _PersistedBookSessionView extends StatefulWidget {
  const _PersistedBookSessionView(
      {required this.options,
      required this.writer,
      this.payments,
      required this.coachId,
      required this.isCurrent,
      required this.onOpenBookings});
  final persisted.MemberBookingOptionsRepository options;
  final persisted.BookingRepository writer;
  final BookingPaymentRepository? payments;
  final String coachId;
  final bool Function() isCurrent;
  final VoidCallback onOpenBookings;
  @override
  State<_PersistedBookSessionView> createState() =>
      __PersistedBookSessionViewState();
}

class __PersistedBookSessionViewState extends State<_PersistedBookSessionView> {
  late final controller = LiveBookingCubit(
      options: widget.options,
      writer: widget.writer,
      coachId: widget.coachId,
      isCurrent: widget.isCurrent)
    ..refresh();
  @override
  void dispose() {
    controller.close();
    super.dispose();
  }

  BookingPaymentQuote? _quote;
  String? _quoteError;
  bool _quoteBusy = false;
  int _quoteGeneration = 0;
  Future<void> _refresh({String? localDate, int? durationMinutes}) async {
    _quoteGeneration++;
    setState(() {
      _quote = null;
      _quoteBusy = false;
      _quoteError = null;
    });
    await controller.refresh(
        localDate: localDate, durationMinutes: durationMinutes);
  }

  Future<void> _select(persisted.BookingOption option) async {
    controller.select(option);
    await _loadQuote();
  }

  Future<void> _loadQuote() async {
    final intent = controller.state.intent;
    final repo = widget.payments;
    if (repo == null || intent == null) return;
    final generation = ++_quoteGeneration;
    setState(() {
      _quote = null;
      _quoteBusy = true;
      _quoteError = null;
    });
    try {
      final result = await repo.loadQuote(
          coachId: widget.coachId,
          branchId: intent.branchId.value,
          durationMinutes: intent.durationMinutes);
      if (mounted && widget.isCurrent() && generation == _quoteGeneration) {
        setState(() => _quote = result);
      }
    } catch (_) {
      if (mounted && widget.isCurrent() && generation == _quoteGeneration) {
        setState(() => _quoteError =
            'Fee unavailable. Retry the quote before continuing.');
      }
    } finally {
      if (mounted && generation == _quoteGeneration) {
        setState(() => _quoteBusy = false);
      }
    }
  }

  Future<void> _continuePayment() async {
    if (_quote == null || _quoteBusy || !widget.isCurrent()) return;
    await controller.submit();
    final hold = controller.state.hold;
    if (!mounted || !widget.isCurrent() || hold == null) return;
    await Navigator.push(
        context,
        MaterialPageRoute<void>(
            builder: (_) => BookingPaymentScreen(
                repository: widget.payments!,
                bookingId: hold.bookingId,
                isCurrent: widget.isCurrent,
                create: true)));
  }

  Future<bool> _discard() async {
    final result = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('Discard this intent?'),
                content: const Text(
                    'The original pending hold may already exist. Discarding only clears this screen and does not cancel it. Check My bookings or retry the same request before choosing another time.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Keep intent')),
                  TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Discard intent'))
                ]));
    if (result == true && mounted && widget.isCurrent()) {
      controller.discardUncertainIntent();
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<LiveBookingCubit, LiveBookingState>(
        bloc: controller,
        builder: (context, state) {
          final options = state.options;
          final locked = state.busy || state.uncertain || state.hold != null;
          if (!widget.isCurrent()) {
            return const Scaffold(
                body: Center(
                    child: Text('Bookings unavailable for this session.')));
          }
          return PopScope(
            canPop: !state.busy && !state.uncertain,
            onPopInvokedWithResult: (didPop, result) async {
              if (!didPop &&
                  !state.busy &&
                  state.uncertain &&
                  await _discard() &&
                  context.mounted) {
                Navigator.pop(context);
              }
            },
            child: BookingSelectionPage(
              actions: [
                TextButton(
                    onPressed: state.busy ? null : widget.onOpenBookings,
                    child: const Text('My bookings'))
              ],
              header: [
                const Text(
                    'Available times are a snapshot. Requesting creates a pending hold only; no payment or confirmation is available.'),
                if (state.busy) const LinearProgressIndicator(),
                if (state.message != null) Text(state.message!),
                if (options != null)
                  Text('Organization timezone: ${options.timeZone}'),
                if (options != null && options.options.isEmpty)
                  Text(options.unavailableReason == 'daily_limit'
                      ? 'Daily booking limit reached.'
                      : 'No open times on this date.'),
              ],
              days: options == null
                  ? []
                  : [
                      for (final date in _dates(
                          options.todayLocalDate, options.throughLocalDate))
                        BookingDayOption(
                            date: DateTime.parse(date),
                            selected: date == options.localDate,
                            onTap:
                                locked ? null : () => _refresh(localDate: date))
                    ],
              times: options == null
                  ? []
                  : [
                      for (final option in options.options)
                        BookingTimeOption(
                            label:
                                '${option.startLabel} – ${option.endLabel} · ${option.branchId}',
                            selected: state.intent?.startAt == option.startAt &&
                                state.intent?.branchId.value == option.branchId,
                            onTap: locked ? null : () => _select(option))
                    ],
              duration: options == null
                  ? null
                  : DropdownButtonFormField<int>(
                      initialValue: options.durationMinutes,
                      decoration: const InputDecoration(labelText: 'Duration'),
                      items: [30, 60]
                          .map((value) => DropdownMenuItem(
                              value: value, child: Text('$value minutes')))
                          .toList(),
                      onChanged: locked
                          ? null
                          : (value) => _refresh(durationMinutes: value)),
              details: [
                DetailRow('Coach', _quote?.coachName ?? '-'),
                DetailRow('Date', options?.localDate ?? '-'),
                DetailRow(
                    'Time',
                    state.intent == null
                        ? 'Not selected'
                        : options?.options
                                .where((o) =>
                                    o.startAt == state.intent!.startAt &&
                                    o.branchId == state.intent!.branchId.value)
                                .map((o) => '${o.startLabel} – ${o.endLabel}')
                                .firstOrNull ??
                            '-'),
                DetailRow('Location',
                    _quote?.branchName ?? state.intent?.branchId.value ?? '-'),
                DetailRow(
                    'Total',
                    _quoteBusy
                        ? 'Loading fee…'
                        : _quote?.formattedAmount ?? '-'),
              ],
              footer: [
                if (_quoteError != null) Text(_quoteError!),
                if (widget.payments != null &&
                    state.intent != null &&
                    _quote == null)
                  TextButton(
                      onPressed: _quoteBusy ? null : _loadQuote,
                      child: const Text('Retry fee quote')),
                if (state.hold == null)
                  OutlinedButton(
                      onPressed: locked ? null : _refresh,
                      child: const Text('Refresh times / retry readiness')),
                if (state.intent != null && state.hold == null)
                  FilledButton(
                      onPressed: state.busy ||
                              (widget.payments != null &&
                                  (_quote == null || _quoteBusy))
                          ? null
                          : widget.payments == null
                              ? controller.submit
                              : _continuePayment,
                      child: Text(state.uncertain
                          ? 'Retry same request'
                          : widget.payments == null
                              ? 'Request pending hold'
                              : 'Continue to payment')),
                if (state.uncertain) ...[
                  const Text(
                      'Outcome unknown. The same immutable request is retained; retry will recover its receipt if it exists.'),
                  TextButton(
                      onPressed: state.busy ? null : _discard,
                      child: const Text('Discard intent with warning')),
                ],
                if (state.hold != null) ...[
                  if (widget.payments != null)
                    FilledButton(
                        onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                                builder: (_) => BookingPaymentScreen(
                                    repository: widget.payments!,
                                    bookingId: state.hold!.bookingId,
                                    isCurrent: widget.isCurrent))),
                        child: const Text('Check / continue payment')),
                  Text('Booking ${state.hold!.bookingId}'),
                  const Text(
                      'Original creation receipt — pending hold, not a paid reservation.'),
                  Text(
                      'Hold expiry (UTC): ${state.hold!.holdExpiresAt.toUtc().toIso8601String()}'),
                  const Text(
                      'This receipt does not renew the hold. Refresh My bookings for its current server status, cancellation or expiry.'),
                  FilledButton(
                      onPressed: widget.onOpenBookings,
                      child: const Text('View persisted bookings')),
                ],
              ],
            ),
          );
        },
      );
  List<String> _dates(String first, String last) {
    final start = DateTime.parse('${first}T00:00:00Z');
    final count = DateTime.parse('${last}T00:00:00Z').difference(start).inDays;
    return List.generate(
        count + 1,
        (index) => start
            .add(Duration(days: index))
            .toIso8601String()
            .substring(0, 10));
  }
}
