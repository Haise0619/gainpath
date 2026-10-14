import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import '../../application/live_booking_cubit.dart';

class LiveBookingListView extends StatefulWidget {
  const LiveBookingListView(
      {super.key,
      required this.repository,
      required this.isCurrent,
      this.coachId,
      this.title = 'My bookings'});
  final BookingListRepository repository;
  final bool Function() isCurrent;
  final String? coachId;
  final String title;
  @override
  State<LiveBookingListView> createState() => _LiveBookingListViewState();
}

class _LiveBookingListViewState extends State<LiveBookingListView> {
  late final controller = BookingListCubit(
      repository: widget.repository,
      isCurrent: widget.isCurrent,
      coachId: widget.coachId)
    ..refresh();
  @override
  void dispose() {
    controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: Text(widget.title), actions: [
        IconButton(
            tooltip: 'Refresh bookings',
            onPressed: controller.refresh,
            icon: const Icon(Icons.refresh))
      ]),
      body: BlocBuilder<BookingListCubit, BookingListState>(
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
              if (state.page != null)
                Text(
                    '${state.page!.firstLocalDate} – ${state.page!.throughLocalDate} · ${state.page!.timeZone}'),
              if (!state.busy && state.page != null && state.records.isEmpty)
                const Text('No bookings in this upcoming range.'),
              for (final record in state.records)
                Card(
                    child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Booking ${record.bookingId}',
                                  style:
                                      Theme.of(context).textTheme.titleMedium),
                              Text(bookingStatusLabel(
                                  record, state.page!.serverNowMillis)),
                              Text(
                                  '${record.localDate} · ${record.startLabel} – ${record.endLabel}'),
                              Text('Original timezone: ${record.timeZone}'),
                              if (record.timeZone != state.page!.timeZone)
                                const Text(
                                    'Timezone differs from current policy; review original times.'),
                              Text('Hold expiry: ${record.expiryLabel}'),
                              Text(
                                  'Coach: ${record.coachId} · Member: ${record.memberId}'),
                              Text(
                                  'Branch: ${record.branchId} · ${record.durationMinutes} minutes'),
                            ]))),
              if (state.page?.nextCursor != null)
                TextButton(
                    onPressed: state.busy ? null : controller.loadMore,
                    child: const Text('Load more bookings')),
            ]);
          }));
}
