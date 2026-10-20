import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import '../../application/live_booking_cubit.dart';
import '../member/booking_schedule_screen.dart';
import '../coach/roster_screen.dart';
import 'persisted_booking_presentation.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
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
  Widget build(BuildContext context) =>
      BlocBuilder<BookingCancellationCubit, BookingCancellationState>(
        bloc: cancellation,
        builder: (context, action) =>
            BlocBuilder<BookingListCubit, BookingListState>(
          bloc: controller,
          builder: (context, state) {
            if (!widget.isCurrent()) {
              return const Scaffold(
                  body: Center(
                      child: Text('Bookings unavailable for this session.')));
            }
            final labels = {
              for (final record in state.records)
                record.bookingId: record.status == BookingStatus.pendingHold
                    ? 'Pending hold'
                    : record.rawStatus
            };
            final header =
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (state.busy || action.busy) const LinearProgressIndicator(),
              if (state.message != null) Text(state.message!),
              if (action.message != null) Text(action.message!),
              if (state.page != null)
                Text(
                    '${state.page!.firstLocalDate} – ${state.page!.throughLocalDate} · ${state.page!.timeZone}'),
              Row(children: [
                TextButton.icon(
                    onPressed:
                        action.busy || state.busy ? null : controller.refresh,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh bookings')),
                if (state.page?.nextCursor != null)
                  TextButton(
                      onPressed: state.busy || action.busy
                          ? null
                          : controller.loadMore,
                      child: const Text('Load more bookings')),
              ]),
              if (action.uncertain && action.request != null) ...[
                const Text(
                    'Cancellation outcome unknown. Retry the same request or refresh server status.'),
                TextButton(
                    onPressed: action.busy || state.busy
                        ? null
                        : () => _cancel(action.request!.bookingId, retry: true),
                    child: const Text('Retry same cancellation')),
              ],
            ]);
            final bookings =
                state.records.map(persistedBookingPresentation).toList();
            final details = {
              for (final record in state.records)
                record.bookingId: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      DetailRow('Booking', record.bookingId),
                      DetailRow(
                          'Status',
                          bookingStatusLabel(
                              record, state.page!.serverNowMillis)),
                      DetailRow(
                          'Time', '${record.startLabel} – ${record.endLabel}'),
                      DetailRow('Timezone', record.timeZone),
                      DetailRow('Hold expiry', record.expiryLabel),
                      if (record.timeZone != state.page!.timeZone)
                        const Text(
                            'Timezone differs from current policy; review original times.'),
                    ])
            };
            if (widget.coachId != null) {
              return CoachRosterScreen(
                  persistedBookings: bookings,
                  statusLabels: labels,
                  details: details,
                  header: header);
            }
            return BookingScheduleScreen(
                persistedBookings: bookings,
                statusLabels: labels,
                header: header,
                onCancelHold: widget.cancellation == null ||
                        state.busy ||
                        action.busy ||
                        action.request != null
                    ? null
                    : (id) => _cancel(id),
                details: details);
          },
        ),
      );
}
