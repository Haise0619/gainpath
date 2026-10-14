import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import '../../application/live_booking_cubit.dart';
import '../../application/booking_cancellation_cubit.dart';

class LiveBookingListView extends StatefulWidget {
  const LiveBookingListView(
      {super.key,
      required this.repository,
      required this.isCurrent,
      this.cancellation,
      this.coachId,
      this.title = 'My bookings'});
  final BookingListRepository repository;
  final bool Function() isCurrent;
  final BookingCancellationRepository? cancellation;
  final String? coachId;
  final String title;
  @override
  State<LiveBookingListView> createState() => _LiveBookingListViewState();
}

class _LiveBookingListViewState extends State<LiveBookingListView> {
  late final cancellation = BookingCancellationCubit(
      repository: widget.cancellation, isCurrent: widget.isCurrent);
  late final controller = BookingListCubit(
      repository: widget.repository,
      isCurrent: widget.isCurrent,
      coachId: widget.coachId)
    ..refresh();
  @override
  void dispose() {
    controller.close();
    cancellation.close();
    super.dispose();
  }

  Future<void> _cancel(String bookingId, {bool retry = false}) async {
    if (!retry) {
      final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
                  title: const Text('Cancel pending hold?'),
                  content: const Text(
                      'The server will release this pending hold. If its deadline has passed, it will be recorded as expired. Confirmed or paid bookings cannot be cancelled here.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Keep hold')),
                    TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Cancel hold'))
                  ]));
      if (confirmed != true || !mounted || !widget.isCurrent()) return;
    }
    if (await cancellation.cancel(bookingId) && mounted) {
      await controller.refresh();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: Text(widget.title), actions: [
        IconButton(
            tooltip: 'Refresh bookings',
            onPressed: () {
              if (!cancellation.state.busy) controller.refresh();
            },
            icon: const Icon(Icons.refresh))
      ]),
      body: BlocBuilder<BookingCancellationCubit, BookingCancellationState>(
          bloc: cancellation,
          builder: (context, action) => BlocBuilder<BookingListCubit,
                  BookingListState>(
              bloc: controller,
              builder: (context, state) {
                if (!widget.isCurrent()) {
                  return const Center(
                      child: Text('Bookings unavailable for this session.'));
                }
                return ListView(padding: const EdgeInsets.all(16), children: [
                  const Text(
                      'Upcoming persisted records. Holds are not paid reservations. No confirmation or payment is available here.'),
                  if (state.busy) const LinearProgressIndicator(),
                  if (state.message != null) Text(state.message!),
                  if (action.busy) const LinearProgressIndicator(),
                  if (action.message != null) Text(action.message!),
                  if (action.uncertain && action.request != null) ...[
                    const Text(
                        'Cancellation outcome unknown. Retry the same request or refresh server status. Leaving this screen does not undo a committed cancellation.'),
                    TextButton(
                        onPressed: action.busy || state.busy
                            ? null
                            : () =>
                                _cancel(action.request!.bookingId, retry: true),
                        child: const Text('Retry same cancellation')),
                  ],
                  if (state.page != null)
                    Text(
                        '${state.page!.firstLocalDate} – ${state.page!.throughLocalDate} · ${state.page!.timeZone}'),
                  if (!state.busy &&
                      state.page != null &&
                      state.records.isEmpty)
                    const Text('No bookings in this upcoming range.'),
                  for (final record in state.records)
                    Card(
                        child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Booking ${record.bookingId}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium),
                                  Text(bookingStatusLabel(
                                      record, state.page!.serverNowMillis)),
                                  Text(
                                      '${record.localDate} · ${record.startLabel} – ${record.endLabel}'),
                                  Text('Original timezone: ${record.timeZone}'),
                                  if (record.timeZone != state.page!.timeZone)
                                    const Text(
                                        'Timezone differs from current policy; review original times.'),
                                  Text('Hold expiry: ${record.expiryLabel}'),
                                  if (record.resolution != null)
                                    Text(record.resolution == 'hold_expired'
                                        ? 'Closed by server hold expiry.'
                                        : 'Closed by Member cancellation.'),
                                  Text(
                                      'Coach: ${record.coachId} · Member: ${record.memberId}'),
                                  Text(
                                      'Branch: ${record.branchId} · ${record.durationMinutes} minutes'),
                                  if (widget.cancellation != null &&
                                      record.status ==
                                          BookingStatus.pendingHold)
                                    TextButton(
                                        onPressed: state.busy ||
                                                action.busy ||
                                                action.request != null
                                            ? null
                                            : () => _cancel(record.bookingId),
                                        child:
                                            const Text('Cancel pending hold')),
                                ]))),
                  if (state.page?.nextCursor != null)
                    TextButton(
                        onPressed: state.busy || action.busy
                            ? null
                            : controller.loadMore,
                        child: const Text('Load more bookings')),
                ]);
              })));
}
