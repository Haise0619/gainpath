import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../application/booking_list_cubit.dart';

typedef AdminBookingFocus = ({
  PersistedBookingRecord booking,
  String? branchName,
  String? coachName
});

class AdminBookingListView extends StatefulWidget {
  const AdminBookingListView(
      {super.key,
      required this.repository,
      required this.isCurrent,
      this.coachId,
      this.branchId,
      this.loadFocusedBooking,
      this.title = 'Coach bookings'});
  final BookingListRepository repository;
  final bool Function() isCurrent;
  final String? coachId;
  final String? branchId;
  final String title;
  final Future<AdminBookingFocus> Function()? loadFocusedBooking;
  @override
  State<AdminBookingListView> createState() => _AdminBookingListViewState();
}

class _AdminBookingListViewState extends State<AdminBookingListView> {
  late final controller = BookingListCubit(
      repository: widget.repository,
      isCurrent: widget.isCurrent,
      branchId: widget.branchId,
      coachId: widget.coachId)
    ..refresh();
  late Future<AdminBookingFocus> _focused = widget.loadFocusedBooking!();

  @override
  void dispose() {
    if (widget.loadFocusedBooking == null) controller.close();
    super.dispose();
  }

  Widget _bookingCard(
    BuildContext context,
    PersistedBookingRecord record,
    int serverNowMillis,
    String timeZone, {
    String? branchName,
    String? coachName,
    String? localDate,
    bool showPaymentMethod = true,
  }) =>
      Card(
          child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Booking ${record.bookingId}',
                        style: Theme.of(context).textTheme.titleMedium),
                    Text(bookingStatusLabel(record, serverNowMillis)),
                    Text(
                        '${localDate ?? record.localDate} · ${record.startLabel} – ${record.endLabel}'),
                    Text('Original timezone: ${record.timeZone}'),
                    if (record.timeZone != timeZone)
                      const Text(
                          'Timezone differs from current policy; review original times.'),
                    Text('Hold expiry: ${record.expiryLabel}'),
                    if (record.resolution != null)
                      Text(record.resolution == 'hold_expired'
                          ? 'Closed by server hold expiry.'
                          : 'Closed by Member cancellation.'),
                    if (showPaymentMethod)
                      Text(
                          'Coach: ${record.coachId} · Member: ${record.memberId}')
                    else
                      Text('Coach: ${coachName ?? 'Unavailable coach'}'),
                    Text(
                        'Branch: ${branchName ?? record.branchId} · ${record.durationMinutes} minutes'),
                    if (showPaymentMethod) const SizedBox(height: 12),
                    if (showPaymentMethod)
                      PaymentMethodSummary(
                          label: record.selectedPaymentMethod == null
                              ? 'Not recorded'
                              : '${record.selectedPaymentMethod!.choice.categoryLabel} · ${record.selectedPaymentMethod!.choice.name}',
                          category: record.selectedPaymentMethod == null
                              ? 'Legacy booking'
                              : 'Preferred payment method',
                          iconKey:
                              record.selectedPaymentMethod?.choice.iconKey ??
                                  'unknown'),
                  ])));

  Widget _focusedView() => Scaffold(
        appBar: AppBar(title: const Text('Booking details'), actions: [
          IconButton(
            tooltip: 'Refresh booking',
            onPressed: () =>
                setState(() => _focused = widget.loadFocusedBooking!()),
            icon: const Icon(Icons.refresh),
          ),
        ]),
        body: FutureBuilder<AdminBookingFocus>(
          future: _focused,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final focus = snapshot.data;
            if (focus == null || !widget.isCurrent()) {
              return const Center(
                  child: Text('This booking is no longer available.'));
            }
            final date = focus.booking.startAt
                .add(const Duration(hours: 8))
                .toIso8601String()
                .substring(0, 10);
            return ListView(padding: const EdgeInsets.all(16), children: [
              _bookingCard(context, focus.booking,
                  DateTime.now().millisecondsSinceEpoch, 'Asia/Kuala_Lumpur',
                  branchName: focus.branchName ?? 'Unavailable branch',
                  coachName: focus.coachName,
                  localDate: date,
                  showPaymentMethod: false),
            ]);
          },
        ),
      );

  @override
  Widget build(BuildContext context) => widget.loadFocusedBooking != null
      ? _focusedView()
      : Scaffold(
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
                final records = state.records.where((record) =>
                    widget.branchId == null ||
                    record.branchId == widget.branchId);
                return ListView(padding: const EdgeInsets.all(16), children: [
                  if (widget.branchId != null)
                    Text('Branch: ${widget.branchId}'),
                  const Text(
                      'Upcoming persisted records. Holds are not paid reservations. No confirmation or payment is available here.'),
                  if (state.busy) const LinearProgressIndicator(),
                  if (state.message != null) Text(state.message!),
                  if (state.page != null)
                    Text(
                        '${state.page!.firstLocalDate} – ${state.page!.throughLocalDate} · ${state.page!.timeZone}'),
                  if (!state.busy && state.page != null && records.isEmpty)
                    Text(state.page?.nextCursor != null
                        ? 'No matching bookings in the loaded results. Load more to continue.'
                        : 'No bookings in this upcoming range.'),
                  for (final record in records)
                    _bookingCard(context, record, state.page!.serverNowMillis,
                        state.page!.timeZone),
                  if (state.page?.nextCursor != null)
                    TextButton(
                        onPressed: state.busy ? null : controller.loadMore,
                        child: const Text('Load more bookings')),
                ]);
              }));
}
