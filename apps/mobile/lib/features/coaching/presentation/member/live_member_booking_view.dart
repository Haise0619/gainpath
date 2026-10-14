import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import '../../application/live_booking_cubit.dart';

class LiveMemberBookingView extends StatefulWidget {
  const LiveMemberBookingView(
      {super.key,
      required this.options,
      required this.writer,
      required this.coachId,
      required this.isCurrent,
      required this.onOpenBookings});
  final MemberBookingOptionsRepository options;
  final BookingRepository writer;
  final String coachId;
  final bool Function() isCurrent;
  final VoidCallback onOpenBookings;
  @override
  State<LiveMemberBookingView> createState() => _LiveMemberBookingViewState();
}

class _LiveMemberBookingViewState extends State<LiveMemberBookingView> {
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
  Widget build(BuildContext context) => BlocBuilder<LiveBookingCubit,
          LiveBookingState>(
      bloc: controller,
      builder: (context, state) {
        final options = state.options;
        final locked = state.busy || state.uncertain || state.hold != null;
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
            child: Scaffold(
                appBar: AppBar(title: const Text('Choose time'), actions: [
                  TextButton(
                      onPressed: state.busy ? null : widget.onOpenBookings,
                      child: const Text('My bookings'))
                ]),
                body: !widget.isCurrent()
                    ? const Center(
                        child: Text('Bookings unavailable for this session.'))
                    : ListView(padding: const EdgeInsets.all(16), children: [
                        Text('Coach: ${widget.coachId}'),
                        const Text(
                            'Available times are a snapshot. Requesting creates a pending hold only; no payment or confirmation is available.'),
                        if (state.busy) const LinearProgressIndicator(),
                        if (state.message != null) Text(state.message!),
                        if (options != null) ...[
                          Text('Organization timezone: ${options.timeZone}'),
                          DropdownButtonFormField<String>(
                              initialValue: options.localDate,
                              decoration:
                                  const InputDecoration(labelText: 'Date'),
                              items: _dates(options.todayLocalDate,
                                      options.throughLocalDate)
                                  .map((date) => DropdownMenuItem(
                                      value: date, child: Text(date)))
                                  .toList(),
                              onChanged: locked
                                  ? null
                                  : (value) =>
                                      controller.refresh(localDate: value)),
                          DropdownButtonFormField<int>(
                              initialValue: options.durationMinutes,
                              decoration:
                                  const InputDecoration(labelText: 'Duration'),
                              items: [30, 60]
                                  .map((duration) => DropdownMenuItem(
                                      value: duration,
                                      child: Text('$duration minutes')))
                                  .toList(),
                              onChanged: locked
                                  ? null
                                  : (value) => controller.refresh(
                                      durationMinutes: value)),
                          if (options.options.isEmpty)
                            Text(options.unavailableReason == 'daily_limit'
                                ? 'Daily booking limit reached.'
                                : 'No open times on this date.'),
                          for (final option in options.options)
                            ListTile(
                                title: Text(
                                    '${option.startLabel} – ${option.endLabel}'),
                                subtitle: Text('Branch: ${option.branchId}'),
                                selected:
                                    state.intent?.startAt == option.startAt &&
                                        state.intent?.branchId.value ==
                                            option.branchId,
                                onTap: locked
                                    ? null
                                    : () => controller.select(option)),
                        ],
                        if (state.hold == null)
                          OutlinedButton(
                              onPressed: locked ? null : controller.refresh,
                              child: const Text(
                                  'Refresh times / retry readiness')),
                        if (state.intent != null && state.hold == null)
                          FilledButton(
                              onPressed: state.busy ? null : controller.submit,
                              child: Text(state.uncertain
                                  ? 'Retry same request'
                                  : 'Request pending hold')),
                        if (state.uncertain) ...[
                          const Text(
                              'Outcome unknown. The same immutable request is retained; retry will recover its receipt if it exists.'),
                          TextButton(
                              onPressed: state.busy ? null : _discard,
                              child: const Text('Discard intent with warning')),
                        ],
                        if (state.hold != null) ...[
                          Text('Booking ${state.hold!.bookingId}'),
                          const Text('Original creation receipt — pending hold, not a paid reservation.'),
                          Text(
                              'Hold expiry (UTC): ${state.hold!.holdExpiresAt.toUtc().toIso8601String()}'),
                          const Text(
                              'This receipt does not renew the hold. Refresh My bookings for its current server status, cancellation or expiry.'),
                          FilledButton(
                              onPressed: widget.onOpenBookings,
                              child: const Text('View persisted bookings')),
                        ],
                      ])));
      });
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
