import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_domain/coaching.dart'
    show BookingChangeSource, Booking, BookingCommunicationRepository, ConsultationNotesRepository, CoachBookingCancellationRepository, ClientPostureRepository, BookingReviewRepository;
import '../coach/client_posture_screen.dart';
import '../coach/consultation_notes_screen.dart';
import '../../application/live_booking_cubit.dart';
import '../member/booking_schedule_screen.dart';
import '../member/member_booking_change_screen.dart';
import 'package:gainpath_domain/coaching.dart' show MemberBookingChangeRepository;
import '../coach/roster_screen.dart';
import 'persisted_booking_presentation.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../application/booking_cancellation_cubit.dart';
import '../coach/message_inbox_screen.dart';

class LiveBookingListView extends StatefulWidget {
  const LiveBookingListView(
      {super.key,
      required this.repository,
      required this.isCurrent,
      this.cancellation,
      this.memberChanges,
      this.coachCancellation,
      this.onPayment,
      this.communication,
      this.notes,
      this.posture,
      this.review,
      this.loadCoachName,
      this.coachId,
      this.title = 'My bookings'});
  final BookingListRepository repository;
  final void Function(String bookingId)? onPayment;
  final bool Function() isCurrent;
  final BookingCancellationRepository? cancellation;
  final MemberBookingChangeRepository? memberChanges;
  final CoachBookingCancellationRepository? coachCancellation;
  final BookingCommunicationRepository? communication;
  final ConsultationNotesRepository? notes;
  final ClientPostureRepository? posture;
  final BookingReviewRepository? review;
  final Future<String?> Function(String coachId)? loadCoachName;
  final String? coachId;
  final String title;
  @override
  State<LiveBookingListView> createState() => _LiveBookingListViewState();
}

class _LiveBookingListViewState extends State<LiveBookingListView> {
  final Map<String, int> _reviewed = {};
  Timer? _updates;
  StreamSubscription<void>? _liveUpdates;
  @override
  void initState() {
    super.initState();
    final source = widget.repository;
    if (source is BookingChangeSource) {
      var firstSnapshot = true;
      _liveUpdates = (source as BookingChangeSource).watchBookingChanges().listen((_) { if (firstSnapshot) { firstSnapshot = false; return; } _refreshCurrent(); }, onError: (_) { /* The periodic/manual refresh remains available. */ });
    }
    _updates = Timer.periodic(const Duration(seconds: 30), (_) {
      _refreshCurrent();
    });
  }

  void _refreshCurrent() {
    if (mounted && widget.isCurrent() && !cancellation.state.busy && !cancellation.state.uncertain
        && !controller.state.busy && (ModalRoute.of(context)?.isCurrent ?? true)) { controller.refresh(); }
  }
  late final cancellation = BookingCancellationCubit(
      repository: widget.cancellation, isCurrent: widget.isCurrent);
  late final controller = BookingListCubit(
      repository: widget.repository,
      isCurrent: widget.isCurrent,
      coachId: widget.coachId)
    ..refresh();
  @override
  void dispose() {
    _updates?.cancel();
    unawaited(_liveUpdates?.cancel());
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

  Future<void> _changeMemberBooking(PersistedBookingRecord record,{required bool reschedule})async{
    final repository=widget.memberChanges;
    if(repository==null||!widget.isCurrent()||controller.state.busy||cancellation.state.busy)return;
    final changed=await Navigator.push<bool>(context,MaterialPageRoute(builder:(_)=>MemberBookingChangeScreen(repository:repository,booking:record,reschedule:reschedule,isCurrent:widget.isCurrent)));
    if(changed==true&&mounted&&widget.isCurrent())await controller.refresh();
  }

  Future<void> _cancelCoachBooking(Booking booking) async {
    if (widget.coachCancellation == null || !widget.isCurrent()) return;
    final reasonController = TextEditingController();
    String? validationError;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Cancel confirmed session?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cancel session with ' + booking.memberName + ' on ' +
                    booking.start.toLocal().toString().substring(0, 16) + '?' +
                    '\nThe member will be notified, slot lock released, and refund review queued.',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                autofocus: true,
                maxLines: 3,
                maxLength: 500,
                decoration: InputDecoration(
                  labelText: 'Cancellation reason *',
                  hintText: 'e.g. Schedule emergency or illness',
                  errorText: validationError,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) {
                  if (validationError != null) {
                    setDialogState(() => validationError = null);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Keep session'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                final text = reasonController.text.trim();
                if (text.isEmpty) {
                  setDialogState(() => validationError = 'Reason is required');
                  return;
                }
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Cancel session'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted || !widget.isCurrent()) return;

    final reason = reasonController.text.trim();
    final requestId = 'coach-cancel-' + DateTime.now().millisecondsSinceEpoch.toString() + '-' + booking.id.hashCode.abs().toString();

    try {
      final res = await widget.coachCancellation!.cancel(
        bookingId: booking.id,
        requestId: requestId,
        reason: reason,
      );
      if (!mounted || !widget.isCurrent()) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.outcome == 'already_cancelled'
              ? 'Session was already cancelled.'
              : 'Session cancelled. Slot released.'),
        ),
      );
      await controller.refresh();
    } catch (e) {
      if (!mounted || !widget.isCurrent()) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to cancel session: ' + e.toString()),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  Future<void> _showReviewDialog(String bookingId) async {
    if (widget.review == null || !widget.isCurrent()) return;
    int selectedStars = 5;
    final textController = TextEditingController();

    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Rate session'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('How was your coaching consultation?'),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  final star = i + 1;
                  return IconButton(
                    icon: Icon(
                      star <= selectedStars
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: Colors.amber,
                      size: 32,
                    ),
                    onPressed: () => setDialogState(() => selectedStars = star),
                  );
                }),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: textController,
                maxLines: 3,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: 'Feedback (optional)',
                  hintText: 'Share how your session went...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogCtx, true),
              child: const Text('Submit review'),
            ),
          ],
        ),
      ),
    );

    if (submitted != true || !mounted || !widget.isCurrent()) return;

    final requestId =
        'rev-' + DateTime.now().millisecondsSinceEpoch.toString() + '-' + bookingId.hashCode.abs().toString();

    try {
      await widget.review!.submitReview(
        bookingId: bookingId,
        requestId: requestId,
        stars: selectedStars,
        reviewText: textController.text.trim(),
      );
      if (!mounted || !widget.isCurrent()) return;
      setState(() => _reviewed[bookingId] = selectedStars);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Review submitted. Thank you for your feedback!')),
      );
      await controller.refresh();
    } catch (e) {
      if (!mounted || !widget.isCurrent()) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit review: ' + e.toString()),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  void _openPosture(Booking booking, String memberId) {
    if (widget.posture == null || !widget.isCurrent()) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClientPostureScreen(
          name: booking.memberName,
          memberId: memberId,
          bookingId: booking.id,
          repository: widget.posture,
        ),
      ),
    );
  }

  Future<void> _notes(Booking booking) async {
    if (widget.notes == null || !widget.isCurrent()) return;
    await Navigator.push(
        context,
        MaterialPageRoute<void>(
            builder: (_) => ConsultationNotesScreen(
                booking: booking,
                repository: widget.notes,
                isCurrent: widget.isCurrent)));
    if (mounted && widget.isCurrent()) await controller.refresh();
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
              const Text(
                  'Updates every 30 seconds. Counts and filters use loaded bookings; load more for the full date range.'),
              Wrap(children: [
                TextButton.icon(
                    onPressed: state.busy || action.busy || state.page == null
                        ? null
                        : () => controller
                            .showRecentHistory(!controller.recentHistory),
                    icon: const Icon(Icons.history),
                    label: Text(controller.recentHistory
                        ? 'Upcoming bookings'
                        : 'Past 30 days')),
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
                state.records.map((r) { final b = persistedBookingPresentation(r); b.rated = b.rated || _reviewed.containsKey(r.bookingId); b.reviewStars ??= _reviewed[r.bookingId]; return b; }).toList();
            final details = {
              for (final record in state.records)
                record.bookingId: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      DetailRow('Booking', record.bookingId),
                      if (widget.onPayment != null)
                        TextButton(
                            onPressed: state.busy
                                ? null
                                : () => widget.onPayment!(record.bookingId),
                            child: const Text('View payment / continue')),
                      DetailRow(
                          'Status',
                          bookingStatusLabel(
                              record, state.page!.serverNowMillis)),
                      DetailRow(
                          'Time', '${record.startLabel} – ${record.endLabel}'),
                      DetailRow('Timezone', record.timeZone),
                      if(widget.coachId==null&&widget.memberChanges!=null&&record.rawStatus=='confirmed')...[
                        const SizedBox(height:12),
                        const Text('Member changes: cancellation needs 12 hours and rescheduling needs 24 hours before start. Refunds require Admin review.'),
                        Wrap(spacing:12,runSpacing:8,children:[
                          OutlinedButton.icon(onPressed:state.busy||record.startAtMillis-state.page!.serverNowMillis<24*3600000?null:()=>_changeMemberBooking(record,reschedule:true),icon:const Icon(Icons.edit_calendar_outlined),label:const Text('Reschedule confirmed session')),
                          TextButton(onPressed:state.busy||record.startAtMillis-state.page!.serverNowMillis<12*3600000?null:()=>_changeMemberBooking(record,reschedule:false),child:const Text('Cancel confirmed session')),
                        ]),
                      ],
                      DetailRow('Hold expiry', record.expiryLabel),
                      if (widget.coachId == null &&
                          record.rawStatus == 'completed') ...[
                        if (widget.notes != null)
                          TextButton.icon(
                              onPressed: () =>
                                  _notes(persistedBookingPresentation(record)),
                              icon: const Icon(Icons.sticky_note_2_outlined),
                              label: const Text('View consultation notes')),
],
                      if (widget.coachId != null) ...[
                        const Text(
                            'Form history: — · Confirmed booking and authorized cloud measurements required.'),
                        const Text(
                            'Notes can be published after a confirmed session ends. Pending holds cannot be marked delivered. Confirmed cancellation remains unavailable.'),
                      ],
                      if (record.timeZone != state.page!.timeZone)
                        const Text(
                            'Timezone differs from current policy; review original times.'),
                    ])
            };
            if (widget.coachId != null) {
              final memberIds = {for (final r in state.records) r.bookingId: r.memberId};
              return CoachRosterScreen(
                  showAllDates: controller.recentHistory,
                  onNotes: widget.notes == null ? null : _notes,
                  onCancel: widget.coachCancellation == null ? null : _cancelCoachBooking,
                  onPosture: widget.posture == null
                      ? null
                      : (b) => _openPosture(b, memberIds[b.id] ?? ''),
                  onOpenMessages: widget.communication == null
                      ? null
                      : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => CoachMessageInboxScreen(
                                  bookings: bookings,
                                  repository: widget.communication,
                                  isCurrent: widget.isCurrent))),
                  todayLocalDate: state.page?.firstLocalDate,
                  onMessage: widget.communication == null
                      ? null
                      : (booking) => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => CoachMessageThreadScreen(
                                  booking: booking,
                                  repository: widget.communication,
                                  isCurrent: widget.isCurrent))),
                  persistedBookings: bookings,
                  statusLabels: labels,
                  details: details,
                  header: header);
            }
            return BookingScheduleScreen(
                onReview: widget.review == null || state.busy ? null : _showReviewDialog,
                onMessage: widget.communication == null
                    ? null
                    : (booking) => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => CoachMessageThreadScreen(
                                booking: booking,
                                repository: widget.communication,
                                isCurrent: widget.isCurrent,
                                loadCoachName: widget.loadCoachName == null
                                    ? null
                                    : () =>
                                        widget.loadCoachName!(booking.coachId),
                                ownRole: 'Member'))),
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
