import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_domain/coaching.dart'
    show
        BookingChangeSource,
        Booking,
        BookingCommunicationRepository,
        ConsultationNotesRepository,
        CoachBookingCancellationRepository,
        ClientPostureRepository,
        BookingReviewRepository,
        PairConversationRepository;
import '../coach/client_posture_screen.dart';
import '../coach/consultation_notes_screen.dart';
import '../../application/live_booking_cubit.dart';
import '../member/booking_schedule_screen.dart';
import '../member/member_booking_change_screen.dart';
import 'package:gainpath_domain/coaching.dart'
    show MemberBookingChangeRepository;
import '../coach/roster_screen.dart';
import 'persisted_booking_presentation.dart';
import 'booking_coach_info.dart';
import 'package:gainpath_domain/identity.dart' show PublishedCoachProfile;
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../application/booking_cancellation_cubit.dart';
import '../coach/message_inbox_screen.dart';
import 'pair_chat_screen.dart';

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
      this.loadCoachProfile,
      this.coachPhotoBuilder,
      this.coachId,
      this.onFindCoach,
      this.onBookAgain,
      this.title = 'My bookings',
      this.embedded = false});
  final bool embedded;
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
  final Future<PublishedCoachProfile?> Function(String coachId)?
      loadCoachProfile;
  final Widget? Function(PublishedCoachProfile)? coachPhotoBuilder;
  final String? coachId;
  final VoidCallback? onFindCoach;
  final void Function(String coachId)? onBookAgain;
  final String title;
  @override
  State<LiveBookingListView> createState() => _LiveBookingListViewState();
}

class _LiveBookingListViewState extends State<LiveBookingListView> {
  void _openConversation(Booking booking) {
    final repository = widget.communication;
    Navigator.push(
        context,
        MaterialPageRoute<void>(
            builder: (_) => repository is PairConversationRepository
                ? PairChatScreen(
                    repository: repository as PairConversationRepository,
                    isCurrent: widget.isCurrent,
                    ownRole: widget.coachId == null ? 'member' : 'coach',
                    bookingId: booking.id,
                    onBookAgain: widget.onBookAgain)
                : CoachMessageThreadScreen(
                    booking: booking,
                    repository: repository,
                    isCurrent: widget.isCurrent,
                    ownRole: widget.coachId == null ? 'Member' : 'Coach',
                    loadCoachName: widget.loadCoachName == null
                        ? null
                        : () => widget.loadCoachName!(booking.coachId))));
  }

  void _openInbox(List<Booking> bookings) {
    final repository = widget.communication;
    Navigator.push(
        context,
        MaterialPageRoute<void>(
            builder: (_) => repository is PairConversationRepository
                ? PairChatInboxScreen(
                    repository: repository as PairConversationRepository,
                    isCurrent: widget.isCurrent,
                    ownRole: widget.coachId == null ? 'member' : 'coach',
                    onBookAgain: widget.onBookAgain)
                : CoachMessageInboxScreen(
                    bookings: bookings,
                    repository: repository,
                    isCurrent: widget.isCurrent)));
  }

  final Map<String, int> _reviewed = {};
  final Map<String, PublishedCoachProfile?> _coachProfiles = {};
  final Map<String, String> _coachNames = {};
  final Set<String> _requestedCoaches = {};
  final Map<String, DateTime> _coachReadAt = {};
  final Map<String, Completer<BookingCoachInfo>> _coachResults = {};

  Future<void> _loadCoachInfo(List<PersistedBookingRecord> records) async {
    if (widget.coachId != null ||
        !widget.isCurrent() ||
        (widget.loadCoachProfile == null && widget.loadCoachName == null)) {
      return;
    }
    final scope = widget.repository.scope;
    final ids = records
        .map((r) => r.coachId)
        .toSet()
        .where((id) =>
            !_requestedCoaches.contains(id) ||
            (_coachReadAt[id] != null &&
                DateTime.now().difference(_coachReadAt[id]!) >=
                    const Duration(minutes: 2)))
        .toList();
    _requestedCoaches.addAll(ids);
    for (final id in ids) {
      _coachResults[id] = Completer<BookingCoachInfo>();
    }
    for (final id in ids) {
      _coachReadAt.remove(id);
    }
    for (var offset = 0; offset < ids.length; offset += 4) {
      if (!mounted || !widget.isCurrent() || widget.repository.scope != scope) {
        for (final id in ids.skip(offset)) {
          final result = _coachResults[id];
          if (result != null && !result.isCompleted) {
            result.complete(unavailableBookingCoachInfo);
          }
        }
        return;
      }
      await Future.wait(ids.skip(offset).take(4).map((id) async {
        PublishedCoachProfile? profile;
        String? name;
        var failed = false;
        try {
          if (widget.loadCoachProfile != null) {
            profile = await widget.loadCoachProfile!(id);
            if (profile != null && (profile.id != id || !profile.isPublished)) {
              profile = null;
            }
            name = profile?.fields.displayName;
          } else {
            name = await widget.loadCoachName!(id);
          }
        } catch (_) {
          failed = true;
        }
        if (!mounted ||
            !widget.isCurrent() ||
            widget.repository.scope != scope) {
          final result = _coachResults[id];
          if (result != null && !result.isCompleted) {
            result.complete(unavailableBookingCoachInfo);
          }
          return;
        }
        setState(() {
          // Failed optional identity reads retry after a short backoff; successful
          // public profile snapshots are refreshed without a query per card.
          _coachReadAt[id] = DateTime.now()
              .subtract(failed ? const Duration(seconds: 90) : Duration.zero);
          if (!failed) {
            _coachProfiles[id] = profile;
          }
          _coachNames[id] = name?.trim().isNotEmpty == true
              ? name!.trim()
              : failed
                  ? 'Coach information unavailable'
                  : 'Coach profile unavailable';
          final result = _coachResults[id];
          if (result != null && !result.isCompleted) {
            result.complete((
              name: _coachNames[id]!,
              specialty: profile?.fields.specialty,
              photo: profile == null
                  ? null
                  : widget.coachPhotoBuilder?.call(profile)
            ));
          }
        });
      }));
    }
  }

  Timer? _updates;
  StreamSubscription<void>? _liveUpdates;
  bool? _wasActive;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final active = !widget.embedded || TickerMode.of(context);
    if (_wasActive == false && active) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _refreshCurrent();
      });
    }
    _wasActive = active;
  }

  @override
  void initState() {
    super.initState();
    final source = widget.repository;
    if (source is BookingChangeSource) {
      var firstSnapshot = true;
      _liveUpdates =
          (source as BookingChangeSource).watchBookingChanges().listen((_) {
        if (firstSnapshot) {
          firstSnapshot = false;
          return;
        }
        _refreshCurrent();
      }, onError: (_) {/* The periodic/manual refresh remains available. */});
    }
    _updates = Timer.periodic(const Duration(seconds: 30), (_) {
      _refreshCurrent();
    });
  }

  void _refreshCurrent() {
    if (mounted &&
        (!widget.embedded || TickerMode.of(context)) &&
        widget.isCurrent() &&
        !cancellation.state.busy &&
        !cancellation.state.uncertain &&
        !controller.state.busy &&
        (ModalRoute.of(context)?.isCurrent ?? true)) {
      controller.refresh();
    }
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
    for (final result in _coachResults.values) {
      if (!result.isCompleted) result.complete(unavailableBookingCoachInfo);
    }
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

  Future<void> _changeMemberBooking(PersistedBookingRecord record,
      {required bool reschedule}) async {
    final repository = widget.memberChanges;
    if (repository == null ||
        !widget.isCurrent() ||
        controller.state.busy ||
        cancellation.state.busy) {
      return;
    }
    final changed = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
            builder: (_) => MemberBookingChangeScreen(
                repository: repository,
                booking: record,
                reschedule: reschedule,
                isCurrent: widget.isCurrent)));
    if (changed == true && mounted && widget.isCurrent()) {
      await controller.refresh();
    }
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
                'Cancel session with ' +
                    booking.memberName +
                    ' on ' +
                    booking.start.toLocal().toString().substring(0, 16) +
                    '?' +
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
    final requestId = 'coach-cancel-' +
        DateTime.now().millisecondsSinceEpoch.toString() +
        '-' +
        booking.id.hashCode.abs().toString();

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

    final requestId = 'rev-' +
        DateTime.now().millisecondsSinceEpoch.toString() +
        '-' +
        bookingId.hashCode.abs().toString();

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
        const SnackBar(
            content: Text('Review submitted. Thank you for your feedback!')),
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
            BlocConsumer<BookingListCubit, BookingListState>(
          bloc: controller,
          listener: (context, state) {
            unawaited(_loadCoachInfo(state.records));
          },
          builder: (context, state) {
            if (!widget.isCurrent()) {
              return const Scaffold(
                  body: Center(
                      child: Text('Bookings unavailable for this session.')));
            }
            final labels = {
              for (final record in state.records)
                record.bookingId: state.page != null
                    ? widget.coachId == null
                        ? memberBookingStatus(
                            record, state.page!.serverNowMillis)
                        : bookingStatusLabel(
                            record, state.page!.serverNowMillis)
                    : (record.status == BookingStatus.pendingHold
                        ? 'Pending hold'
                        : record.rawStatus)
            };
            final header =
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (state.busy || action.busy)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: LinearProgressIndicator(
                    minHeight: 2.5,
                    color: AppColors.primary,
                    backgroundColor: AppColors.surfaceAlt,
                  ),
                ),
              if (state.message != null || action.message != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.dangerTint,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.danger.withValues(alpha: .2),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          size: 16, color: AppColors.danger),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          state.message ?? action.message!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.danger,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap:
                                state.busy || action.busy || state.page == null
                                    ? null
                                    : () => controller.showRecentHistory(
                                        !controller.recentHistory),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.primaryTint,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color:
                                      AppColors.primary.withValues(alpha: .2),
                                ),
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      controller.recentHistory
                                          ? Icons.history_rounded
                                          : Icons.calendar_month_rounded,
                                      size: 15,
                                      color: AppColors.primary,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      controller.recentHistory
                                          ? 'Past 30 days'
                                          : 'Next 30 days',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(
                                      Icons.swap_horiz_rounded,
                                      size: 14,
                                      color: AppColors.primary,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      tooltip: 'Refresh bookings',
                      iconSize: 20,
                      padding: const EdgeInsets.all(6),
                      constraints: const BoxConstraints(),
                      onPressed:
                          action.busy || state.busy ? null : controller.refresh,
                      icon: const Icon(Icons.refresh_rounded,
                          color: AppColors.inkSoft),
                    ),
                  ],
                ),
              ),
              if (state.page != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(
                          Icons.info_outline_rounded,
                          size: 13,
                          color: AppColors.inkSoft,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${state.page!.timeZone} · Auto-syncs 30s · ${state.records.length} loaded session${state.records.length == 1 ? '' : 's'}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.inkSoft,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (state.page?.nextCursor != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: OutlinedButton.icon(
                    onPressed:
                        state.busy || action.busy ? null : controller.loadMore,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 38),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.expand_more_rounded, size: 18),
                    label: const Text(
                      'Load more bookings',
                      style: TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              if (action.uncertain && action.request != null) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.accentTint,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.warning.withValues(alpha: .3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Cancellation outcome unknown. Retry the same request or refresh server status.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.ink,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: action.busy || state.busy
                            ? null
                            : () =>
                                _cancel(action.request!.bookingId, retry: true),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Retry same cancellation',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 12.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ]);
            final recordMap = {for (final r in state.records) r.bookingId: r};
            final bookings = state.records.map((r) {
              final b = persistedBookingPresentation(r,
                  coachName: _coachNames[r.coachId] ??
                      ((widget.loadCoachProfile != null ||
                                  widget.loadCoachName != null) &&
                              widget.coachId == null
                          ? 'Loading coach…'
                          : null));
              b.rated = b.rated || _reviewed.containsKey(r.bookingId);
              b.reviewStars ??= _reviewed[r.bookingId];
              return b;
            }).toList();
            final details = {
              for (final record in state.records)
                record.bookingId: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 6),
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
                      if (widget.coachId == null &&
                          widget.memberChanges != null &&
                          record.rawStatus == 'confirmed') ...[
                        const SizedBox(height: 12),
                        const Text(
                            'Member changes: cancellation needs 12 hours and rescheduling needs 24 hours before start. Refunds require Admin review.'),
                        Wrap(spacing: 12, runSpacing: 8, children: [
                          OutlinedButton.icon(
                              onPressed: state.busy ||
                                      record.startAtMillis -
                                              state.page!.serverNowMillis <
                                          24 * 3600000
                                  ? null
                                  : () => _changeMemberBooking(record,
                                      reschedule: true),
                              icon: const Icon(Icons.edit_calendar_outlined),
                              label:
                                  const Text('Reschedule confirmed session')),
                          TextButton(
                              onPressed: state.busy ||
                                      record.startAtMillis -
                                              state.page!.serverNowMillis <
                                          12 * 3600000
                                  ? null
                                  : () => _changeMemberBooking(record,
                                      reschedule: false),
                              child: const Text('Cancel confirmed session')),
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
              final memberIds = {
                for (final r in state.records) r.bookingId: r.memberId
              };
              return CoachRosterScreen(
                  showAllDates: controller.recentHistory,
                  onNotes: widget.notes == null ? null : _notes,
                  onCancel: widget.coachCancellation == null
                      ? null
                      : _cancelCoachBooking,
                  onPosture: widget.posture == null
                      ? null
                      : (b) => _openPosture(b, memberIds[b.id] ?? ''),
                  onOpenMessages: widget.communication == null
                      ? null
                      : () => _openInbox(bookings),
                  todayLocalDate: state.page?.firstLocalDate,
                  onMessage:
                      widget.communication == null ? null : _openConversation,
                  persistedBookings: bookings,
                  statusLabels: labels,
                  details: details,
                  header: header);
            }
            return BookingScheduleScreen(
                embedded: widget.embedded,
                serverNowMillis: state.page?.serverNowMillis,
                coachInfoFor: (id) => _coachResults[id]?.future,
                coachSpecialtyFor: (id) => _coachProfiles[id]?.fields.specialty,
                coachPhotoBuilder: (booking) {
                  final profile = _coachProfiles[booking.coachId];
                  return profile == null
                      ? null
                      : widget.coachPhotoBuilder?.call(profile);
                },
                onFindCoach: widget.onFindCoach,
                onReview: widget.review == null || state.busy
                    ? null
                    : _showReviewDialog,
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
                recordFor: (id) => recordMap[id],
                onPayment: widget.onPayment,
                onNotes: widget.notes != null ? (b) => _notes(b) : null,
                onRescheduleBooking: widget.memberChanges != null
                    ? (b) {
                        final r = recordMap[b.id];
                        if (r != null) {
                          _changeMemberBooking(r, reschedule: true);
                        }
                      }
                    : null,
                onCancelBooking: widget.memberChanges != null
                    ? (b) {
                        final r = recordMap[b.id];
                        if (r != null) {
                          _changeMemberBooking(r, reschedule: false);
                        }
                      }
                    : null,
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
