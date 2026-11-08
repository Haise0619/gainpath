import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_domain/gainpath_domain.dart'
    show PersistedBookingRecord;
import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../shared/coach_profile_screen.dart';
import '../shared/booking_coach_info.dart';

/// Formats a branch ID into a human-readable location name.
/// Never exposes raw IDs like 'branch_internal_42' or 'removed-branch'.
String resolveBranchLocation(String branchId,
    {Map<String, String> branchNames = const {}}) {
  final trimmed = branchId.trim();
  if (branchNames.containsKey(trimmed)) {
    return branchNames[trimmed]!;
  }
  if (trimmed.isEmpty ||
      trimmed == '-' ||
      trimmed.contains('internal') ||
      trimmed.contains('removed') ||
      (trimmed.contains('_') && !trimmed.contains(' '))) {
    return 'Location confirmed when booking';
  }
  return trimmed.contains(' ') ? trimmed : 'Location confirmed when booking';
}

/// Resolves fee for display. Returns null if missing or <= 0.
/// NEVER returns "RM 0.00" or "Free".
String? resolveBookingFee(double fee, {int? feeMinor}) {
  if (feeMinor != null) {
    if (feeMinor <= 0) return null;
    return 'RM ${(feeMinor / 100.0).toStringAsFixed(2)}';
  }
  if (fee <= 0) return null;
  return 'RM ${fee.toStringAsFixed(2)}';
}

/// Resolves a displayable coach name. Never returns raw ID or empty.
String resolveCoachName(String name, {String? fallback}) {
  final trimmed = name.trim();
  if (trimmed.isNotEmpty && trimmed != '-') {
    return trimmed;
  }
  if (fallback != null && fallback.trim().isNotEmpty && fallback != '-') {
    return fallback.trim();
  }
  return 'Coach';
}

/// Formats booking status label, keeping Expired distinct from Cancelled.
String resolveStatusLabel(BookingStatus status,
    {String? rawStatus, String? labelOverride, String? resolution}) {
  if (labelOverride != null && labelOverride.trim().isNotEmpty) {
    final lower = labelOverride.trim().toLowerCase();
    if (lower == 'expired' || lower == 'hold_expired') return 'Expired';
    return labelOverride;
  }
  if (rawStatus != null && rawStatus.toLowerCase() == 'expired') {
    return 'Expired';
  }
  if (resolution == 'hold_expired') {
    return 'Expired';
  }
  switch (status) {
    case BookingStatus.pending:
      return 'Pending hold';
    case BookingStatus.confirmed:
      return 'Confirmed';
    case BookingStatus.completed:
      return 'Completed';
    case BookingStatus.cancelled:
      return 'Cancelled';
  }
}

/// Dedicated Booking Details page organizing booking information into 6
/// structured sections: Overview, Coach & Location, Payment, Management,
/// Session Activity, and Booking Reference.
class BookingDetailsScreen extends StatefulWidget {
  final Booking booking;
  final PersistedBookingRecord? record;
  final bool live;
  final String? statusLabel;
  final String? locationLabel;
  final Coach? coach;
  final Widget? coachPhoto;
  final Future<BookingCoachInfo>? coachInfoFuture;
  final String? coachSpecialty;
  final VoidCallback? onCancel;
  final VoidCallback? onReschedule;
  final VoidCallback? onMessage;
  final VoidCallback? onReview;
  final VoidCallback? onNotes;
  final VoidCallback? onPayment;
  final VoidCallback? onBookAgain;

  const BookingDetailsScreen({
    super.key,
    required this.booking,
    this.record,
    this.live = false,
    this.statusLabel,
    this.locationLabel,
    this.coach,
    this.coachPhoto,
    this.coachInfoFuture,
    this.coachSpecialty,
    this.onCancel,
    this.onReschedule,
    this.onMessage,
    this.onReview,
    this.onNotes,
    this.onPayment,
    this.onBookAgain,
  });

  @override
  State<BookingDetailsScreen> createState() => _BookingDetailsScreenState();
}

class _BookingDetailsScreenState extends State<BookingDetailsScreen> {
  Coach? _resolvedCoach;

  @override
  void initState() {
    super.initState();
    _resolvedCoach = widget.coach;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_resolvedCoach == null && !widget.live) {
      try {
        final coaches = context.read<CoachRepository>().coaches;
        for (final c in coaches) {
          if (c.id == widget.booking.coachId) {
            _resolvedCoach = c;
            break;
          }
        }
      } catch (_) {}
    }
  }

  static const _months = [
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

  static const _weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday'
  ];

  String _formatFullDate(DateTime d) {
    final weekday = _weekdays[d.weekday - 1];
    final month = _months[d.month - 1];
    return '$weekday, ${d.day} $month ${d.year}';
  }

  String _formatTime(DateTime d) {
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _formatEndTime(DateTime start, int durationMin) {
    final end = start.add(Duration(minutes: durationMin));
    return _formatTime(end);
  }

  String _formatTimestamp(int? millis) {
    if (millis == null || millis <= 0) return '-';
    final d = DateTime.fromMillisecondsSinceEpoch(millis);
    return '${d.day} ${_months[d.month - 1]} ${d.year}, ${_formatTime(d)}';
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 8),
      child: Eyebrow(title),
    );
  }

  Widget _detailRow(String label, String value, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.inkSoft,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.coachInfoFuture == null
        ? _build(context)
        : FutureBuilder<BookingCoachInfo>(
            future: widget.coachInfoFuture,
            builder: (context, snapshot) => _build(context, snapshot.data));
  }

  Widget _build(BuildContext context, [BookingCoachInfo? coachInfo]) {
    final b = widget.booking;
    final r = widget.record;
    final statusText = resolveStatusLabel(
      b.status,
      rawStatus: r?.rawStatus,
      labelOverride: widget.statusLabel,
      resolution: r?.resolution,
    );
    final coachName = resolveCoachName(coachInfo?.name ?? b.coachName,
        fallback: _resolvedCoach?.name);
    final location = widget.locationLabel ?? resolveBranchLocation(b.branch);
    final feeText = resolveBookingFee(b.fee, feeMinor: r?.feeMinor);

    final isExpired = statusText.toLowerCase() == 'expired';
    final isCancelled = statusText.toLowerCase() == 'cancelled';
    final isCompleted = statusText.toLowerCase() == 'completed' ||
        b.status == BookingStatus.completed;
    final sessionEnded = statusText == 'Session ended';
    final holdElapsed = statusText == 'Hold time elapsed';
    final isConfirmed = !sessionEnded &&
        (statusText.toLowerCase() == 'confirmed' ||
            b.status == BookingStatus.confirmed);
    final isPending = !holdElapsed &&
        (statusText.toLowerCase().contains('pending') ||
            b.status == BookingStatus.pending);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Booking Details'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // 1. Booking Overview
          _sectionTitle('Booking Overview'),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    statusPill(statusText),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primaryTint,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${b.durationMin} min',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                if (sessionEnded) ...[
                  const SizedBox(height: 12),
                  const Text('The scheduled session time has passed.'),
                  const Text('Completion has not been recorded.'),
                  if (r != null)
                    Text('Recorded booking status: ${r.rawStatus}'),
                ],
                if (holdElapsed) ...[
                  const SizedBox(height: 12),
                  const Text(
                      'The hold time has elapsed. Awaiting a server status update; this is not a confirmed reservation.'),
                ],
                const SizedBox(height: 12),
                Text(
                  '1-on-1 Consultation',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.calendar_month_rounded,
                        size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _formatFullDate(b.start),
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.schedule_rounded,
                        size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        r != null
                            ? '${r.startLabel} – ${r.endLabel}'
                            : '${_formatTime(b.start)} – ${_formatEndTime(b.start, b.durationMin)}',
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                  ],
                ),
                if (isPending && (r?.expiryLabel != null || !widget.live)) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.accentTint,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.hourglass_top_rounded,
                            size: 15, color: AppColors.accentDark),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            r?.expiryLabel != null
                                ? 'Hold expires: ${r!.expiryLabel}'
                                : 'Slot held for booking. Complete confirmation before expiry.',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.accentDark,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // 2. Coach & Location
          _sectionTitle('Coach & Location'),
          Panel(
            child: Column(
              children: [
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: (coachInfo == null
                                ? widget.coachPhoto
                                : coachInfo.photo) ??
                            (_resolvedCoach != null &&
                                    _resolvedCoach!.imageUrl.isNotEmpty
                                ? networkAvatar(_resolvedCoach!.imageUrl)
                                : Container(
                                    color: AppColors.primaryTint,
                                    child: Center(
                                      child: Text(
                                        coachName.isNotEmpty
                                            ? coachName[0].toUpperCase()
                                            : 'C',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                  )),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            coachName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _resolvedCoach?.specialty.isNotEmpty == true
                                ? _resolvedCoach!.specialty
                                : (_resolvedCoach
                                            ?.specializationTags.isNotEmpty ==
                                        true
                                    ? _resolvedCoach!.specializationTags
                                        .join(' · ')
                                    : ((coachInfo == null
                                            ? widget.coachSpecialty
                                            : coachInfo.specialty) ??
                                        'Coach information unavailable')),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.inkSoft,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_resolvedCoach != null && !widget.live)
                      IconButton(
                        tooltip: 'View Coach Profile',
                        icon: const Icon(Icons.chevron_right_rounded),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  CoachProfileScreen(coach: _resolvedCoach!),
                            ),
                          );
                        },
                      ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Divider(height: 1, color: AppColors.hairline),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on_outlined,
                        size: 18, color: AppColors.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            location,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Please arrive 5 minutes before your scheduled appointment.',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: AppColors.inkSoft,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 3. Payment Details
          _sectionTitle('Payment Details'),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _detailRow(
                  'Consultation Fee',
                  feeText ?? 'Price unavailable',
                ),
                _detailRow(
                  'Payment Status',
                  widget.live
                      ? 'See payment details'
                      : isConfirmed
                          ? 'Paid'
                          : isPending
                              ? 'Pending payment'
                              : isCancelled
                                  ? 'Cancelled'
                                  : isExpired
                                      ? 'Expired'
                                      : 'Completed',
                  trailing: !widget.live && (isConfirmed || isCompleted)
                      ? const Icon(Icons.check_circle_rounded,
                          size: 16, color: AppColors.success)
                      : null,
                ),
                if (widget.onPayment != null) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        minimumSize: const Size(0, 42),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: widget.onPayment,
                      child: Text(isPending && !holdElapsed
                          ? 'View payment / continue'
                          : 'View payment details'),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // 4. Booking Management
          if (isPending || isConfirmed || isCancelled || isExpired) ...[
            _sectionTitle('Booking Management'),
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isPending && widget.onCancel != null) ...[
                    const Text(
                      'This slot is held for you. If you changed your mind, you can cancel the hold to free the slot.',
                      style: TextStyle(
                          fontSize: 12.5,
                          color: AppColors.inkSoft,
                          height: 1.35),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        side: const BorderSide(color: AppColors.danger),
                        minimumSize: const Size(double.infinity, 42),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: widget.onCancel,
                      icon: const Icon(Icons.cancel_outlined, size: 16),
                      label: const Text('Cancel hold'),
                    ),
                  ],
                  if (isConfirmed) ...[
                    const Text(
                      'Member policies: cancellations require 12 hours and rescheduling requires 24 hours before session start.',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.inkSoft, height: 1.35),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        if (widget.onReschedule != null)
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 40),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: widget.onReschedule,
                            icon: const Icon(Icons.edit_calendar_outlined,
                                size: 16),
                            label: const Text('Reschedule'),
                          ),
                        if (widget.onCancel != null)
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.danger,
                              side: const BorderSide(color: AppColors.danger),
                              minimumSize: const Size(0, 40),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: widget.onCancel,
                            icon: const Icon(Icons.cancel_outlined, size: 16),
                            label: const Text('Cancel session'),
                          ),
                      ],
                    ),
                  ],
                  if ((isCancelled || isExpired)) ...[
                    if (b.cancellationReason != null &&
                        b.cancellationReason!.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.dangerTint,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.info_outline_rounded,
                                size: 15, color: AppColors.danger),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                b.cancellationReason!,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: AppColors.danger,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (widget.onBookAgain != null)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 42),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: widget.onBookAgain,
                          icon: const Icon(Icons.replay_rounded, size: 16),
                          label: const Text('Book again with coach'),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ],

          // 5. Session Activity
          _sectionTitle('Session Activity'),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.onMessage != null) ...[
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 42),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: widget.onMessage,
                    icon:
                        const Icon(Icons.chat_bubble_outline_rounded, size: 17),
                    label: Text('Message $coachName'),
                  ),
                  const SizedBox(height: 10),
                ],
                if (b.notes != null && b.notes!.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.sticky_note_2_outlined,
                                size: 15, color: AppColors.inkSoft),
                            SizedBox(width: 6),
                            Text(
                              'Consultation Notes',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.inkSoft,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          b.notes!,
                          style: const TextStyle(fontSize: 13, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                if (widget.onNotes != null) ...[
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 42),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: widget.onNotes,
                    icon: const Icon(Icons.sticky_note_2_outlined, size: 17),
                    label: const Text('View consultation notes'),
                  ),
                  const SizedBox(height: 10),
                ],
                if (isCompleted) ...[
                  if (b.rated)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.accentTint,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.star_rounded,
                              size: 17, color: AppColors.accent),
                          const SizedBox(width: 6),
                          Text(
                            'Session reviewed · ${b.reviewStars ?? 5}/5',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.accentDark,
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (widget.onReview != null)
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        minimumSize: const Size(double.infinity, 42),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: widget.onReview,
                      icon: const Icon(Icons.star_rate_rounded, size: 17),
                      label: const Text('Leave a review'),
                    ),
                ],
              ],
            ),
          ),

          // 6. Booking Reference (Collapsible)
          _sectionTitle('Booking Reference'),
          Panel(
            child: Theme(
              data:
                  Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(top: 8),
                title: const Text(
                  'Technical Details & Identifiers',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                subtitle: Text(
                  'ID: ${b.id}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.inkSoft,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                children: [
                  _detailRow(
                    'Booking ID',
                    b.id,
                    trailing: IconButton(
                      iconSize: 16,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Copy ID',
                      icon: const Icon(Icons.copy_rounded,
                          color: AppColors.primary),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: b.id));
                        showToast(context, 'Booking ID copied to clipboard');
                      },
                    ),
                  ),
                  if (r?.requestId != null)
                    _detailRow('Request ID', r!.requestId),
                  if (r?.policyVersion != null)
                    _detailRow('Policy Version', r!.policyVersion),
                  if (r?.timeZone != null) _detailRow('Timezone', r!.timeZone),
                  if (r?.createdAtMillis != null)
                    _detailRow(
                        'Created At', _formatTimestamp(r!.createdAtMillis)),
                  if (r?.resolvedAtMillis != null)
                    _detailRow('Resolved At',
                        '${_formatTimestamp(r!.resolvedAtMillis)} (${r.resolution ?? '-'})'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
