import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show PersistedBookingRecord;
import 'package:gainpath_ui/gainpath_ui.dart';
import '../member/booking_details_screen.dart' show resolveBranchLocation;
import 'client_posture_screen.dart';
import 'consultation_notes_screen.dart';
import 'message_inbox_screen.dart';
import 'roster_screen.dart' show ClientStats;

/// Detailed Session & Member Management screen for coaches.
/// Structured into 9 distinct sections following professional appointment patterns.
class CoachSessionDetailsScreen extends StatelessWidget {
  final Booking booking;
  final PersistedBookingRecord? record;
  final bool live;
  final String? statusLabel;
  final VoidCallback? onMessage;
  final VoidCallback? onNotes;
  final VoidCallback? onCancel;
  final VoidCallback? onPosture;
  final int? serverNowMillis;

  const CoachSessionDetailsScreen({
    super.key,
    required this.booking,
    this.record,
    this.live = false,
    this.statusLabel,
    this.onMessage,
    this.onNotes,
    this.onCancel,
    this.onPosture,
    this.serverNowMillis,
  });

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

  String _formatDate(DateTime d) {
    final weekday = _weekdays[d.weekday - 1];
    return '$weekday, ${d.day} ${_months[d.month - 1]} ${d.year}';
  }

  String _formatTime(DateTime start, int durationMin) {
    final end = start.add(Duration(minutes: durationMin));
    final sh = start.hour.toString().padLeft(2, '0');
    final sm = start.minute.toString().padLeft(2, '0');
    final eh = end.hour.toString().padLeft(2, '0');
    final em = end.minute.toString().padLeft(2, '0');
    return '$sh:$sm - $eh:$em';
  }

  Color _statusColor(BookingStatus status) {
    switch (status) {
      case BookingStatus.confirmed:
        return AppColors.success;
      case BookingStatus.completed:
        return AppColors.accent;
      case BookingStatus.pending:
        return AppColors.warning;
      case BookingStatus.cancelled:
        return AppColors.danger;
    }
  }

  bool get _hasSessionEnded {
    final now = serverNowMillis ?? DateTime.now().millisecondsSinceEpoch;
    if (record != null) {
      return record!.endAtMillis <= now;
    }
    final end = booking.start.add(Duration(minutes: booking.durationMin));
    return end.millisecondsSinceEpoch <= now;
  }

  bool get _canWriteNotes {
    if (booking.status == BookingStatus.cancelled) return false;
    if (record != null) {
      return record!.rawStatus == 'completed' ||
          (record!.rawStatus == 'confirmed' && _hasSessionEnded);
    }
    return booking.status == BookingStatus.completed ||
        (booking.status == BookingStatus.confirmed && _hasSessionEnded);
  }

  bool get _canCancel {
    if (record != null) {
      return record!.rawStatus == 'confirmed' && !_hasSessionEnded;
    }
    return booking.status == BookingStatus.confirmed && !_hasSessionEnded;
  }

  @override
  Widget build(BuildContext context) {
    final resolvedLocation = resolveBranchLocation(
      record?.branchId ?? booking.branch,
    );
    final stats = ClientStats.of(context, booking.memberName,
        persistedList: live ? [booking] : null);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Session details'),
        actions: [
          if (onMessage != null)
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline_rounded),
              tooltip: 'Message member',
              onPressed: onMessage,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          // 1. Session Overview Card
          _buildSessionOverview(context),
          const SizedBox(height: 16),

          // 2. Member Information Card
          _buildMemberInfo(context, stats),
          const SizedBox(height: 16),

          // 3. Date, Time & Location
          _buildDateTimeLocation(context, resolvedLocation),
          const SizedBox(height: 16),

          // 4. Booking Status
          _buildStatusSection(context),
          const SizedBox(height: 16),

          // 5. Payment Information
          _buildPaymentSection(context),
          const SizedBox(height: 16),

          // 6. Consultation Notes Section
          _buildConsultationNotesSection(context),
          const SizedBox(height: 16),

          // 7. Form History Section
          _buildFormHistorySection(context),
          const SizedBox(height: 16),

          // 8. Booking Management Actions
          if (_canCancel && onCancel != null) ...[
            _buildManagementActions(context),
            const SizedBox(height: 16),
          ],

          // 9. Booking Reference & Technical Details (Collapsible)
          _buildReferenceSection(context),
        ],
      ),
    );
  }

  Widget _buildSessionOverview(BuildContext context) {
    final color = _statusColor(booking.status);
    final label = statusLabel ?? booking.status.label;

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${booking.durationMin} min',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.inkSoft,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '1-on-1 Coaching Consultation',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            _formatDate(booking.start),
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            _formatTime(booking.start, booking.durationMin),
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.inkSoft,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberInfo(BuildContext context, ClientStats stats) {
    final initials = booking.memberName
        .trim()
        .split(' ')
        .where((p) => p.isNotEmpty)
        .map((p) => p[0].toUpperCase())
        .take(2)
        .join();

    final relationshipText = live
        ? 'Client Consultation'
        : stats.sessionsTogether <= 1
            ? 'New client'
            : '${stats.sessionsTogether} sessions together';

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Eyebrow('MEMBER INFORMATION'),
          const SizedBox(height: 12),
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primaryTint,
                child: Text(
                  initials.isNotEmpty ? initials : 'M',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking.memberName.isNotEmpty && booking.memberName != '-'
                          ? booking.memberName
                          : (record?.memberDisplayName ?? 'Member'),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      relationshipText,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.inkSoft,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  '${stats.sessionsTogether}',
                  'Together',
                  compact: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StatTile(
                  '${stats.completed}',
                  'Completed',
                  compact: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StatTile(
                  booking.fee > 0
                      ? 'RM ${booking.fee.toStringAsFixed(0)}'
                      : 'RM ${stats.revenue.toStringAsFixed(0)}',
                  'Fee',
                  compact: true,
                  valueColor: AppColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onMessage ??
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            CoachMessageThreadScreen(booking: booking),
                      ),
                    );
                  },
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 42),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
              label: const Text('Message Member',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateTimeLocation(BuildContext context, String location) {
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Eyebrow('DATE, TIME & LOCATION'),
          const SizedBox(height: 12),
          _detailRow('Date', _formatDate(booking.start)),
          const Divider(height: 16, color: AppColors.hairline),
          _detailRow(
              'Time Slot', _formatTime(booking.start, booking.durationMin)),
          const Divider(height: 16, color: AppColors.hairline),
          _detailRow('Location', location),
          const Divider(height: 16, color: AppColors.hairline),
          _detailRow('Session Area', 'Gym Floor · Consultation Area'),
        ],
      ),
    );
  }

  Widget _buildStatusSection(BuildContext context) {
    final isConfirmed = booking.status == BookingStatus.confirmed;
    final isCompleted = booking.status == BookingStatus.completed;
    final isCancelled = booking.status == BookingStatus.cancelled;
    final isPending = booking.status == BookingStatus.pending;

    String statusDescription;
    if (isCompleted) {
      statusDescription =
          'This consultation has completed. Consultation notes and feedback are saved in member history.';
    } else if (isConfirmed) {
      statusDescription = _hasSessionEnded
          ? 'Session time has passed. Please complete consultation notes to finalize member records.'
          : 'Appointment confirmed. Please arrive at the consultation area 5 minutes before scheduled start.';
    } else if (isPending) {
      statusDescription =
          'Reservation hold is pending payment. Slot will automatically release if unconfirmed.';
    } else if (isCancelled) {
      statusDescription = booking.cancellationReason != null
          ? 'Session was cancelled. Reason: ${booking.cancellationReason}'
          : 'This session was cancelled and released.';
    } else {
      statusDescription = 'Booking status is registered on the schedule.';
    }

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Eyebrow('BOOKING STATUS'),
          const SizedBox(height: 10),
          Text(
            statusDescription,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.inkSoft,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentSection(BuildContext context) {
    final feeText = booking.fee > 0
        ? 'RM ${booking.fee.toStringAsFixed(2)}'
        : (record?.feeMinor != null && record!.feeMinor! > 0
            ? 'RM ${(record!.feeMinor! / 100).toStringAsFixed(2)}'
            : null);

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Eyebrow('PAYMENT INFORMATION'),
          const SizedBox(height: 12),
          _detailRow('Consultation Fee', feeText ?? 'Included in Plan'),
          const Divider(height: 16, color: AppColors.hairline),
          _detailRow(
            'Payment Status',
            booking.status == BookingStatus.cancelled
                ? 'Cancelled / Released'
                : (booking.status == BookingStatus.pending
                    ? 'Pending hold'
                    : 'Confirmed & Settled'),
          ),
        ],
      ),
    );
  }

  Widget _buildConsultationNotesSection(BuildContext context) {
    final hasNotes = booking.notes != null && booking.notes!.trim().isNotEmpty;

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Eyebrow('CONSULTATION NOTES'),
              const Spacer(),
              if (hasNotes)
                const Icon(Icons.check_circle_rounded,
                    size: 15, color: AppColors.success),
            ],
          ),
          const SizedBox(height: 12),
          if (hasNotes) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.hairline),
              ),
              child: Text(
                booking.notes!,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.ink,
                  height: 1.45,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ] else ...[
            Text(
              _canWriteNotes
                  ? 'Consultation notes have not been published yet. Share observations and workout recommendations.'
                  : 'Notes can be published once the confirmed consultation ends.',
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.inkSoft,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (_canWriteNotes)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onNotes ??
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              ConsultationNotesScreen(booking: booking),
                        ),
                      );
                    },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size(0, 42),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: Icon(
                  hasNotes ? Icons.edit_note_rounded : Icons.add_circle_outline,
                  size: 16,
                ),
                label: Text(
                  hasNotes ? 'Edit Consultation Notes' : 'Write Consultation Notes',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFormHistorySection(BuildContext context) {
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Eyebrow('FORM HISTORY & MEASUREMENTS'),
          const SizedBox(height: 8),
          const Text(
            'Review AI-assisted posture and movement analysis captured during workouts.',
            style: TextStyle(
              fontSize: 12.5,
              color: AppColors.inkSoft,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onPosture ??
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ClientPostureScreen(name: booking.memberName),
                      ),
                    );
                  },
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 42),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.insights_rounded, size: 16),
              label: const Text('View Form History',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManagementActions(BuildContext context) {
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Eyebrow('BOOKING MANAGEMENT'),
          const SizedBox(height: 10),
          const Text(
            'Need to cancel this session? Cancelling will release the slot and notify the member.',
            style: TextStyle(
              fontSize: 12.5,
              color: AppColors.inkSoft,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onCancel,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
                side: const BorderSide(color: AppColors.danger),
                minimumSize: const Size(0, 42),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.cancel_outlined, size: 16),
              label: const Text('Cancel Session',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReferenceSection(BuildContext context) {
    final bookingId = record?.bookingId ?? booking.id;

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: const Eyebrow('BOOKING REFERENCE'),
        subtitle: Text(
          'ID: $bookingId',
          style: const TextStyle(
            fontSize: 11.5,
            color: AppColors.inkSoft,
          ),
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.hairline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: _detailRow('Booking ID', bookingId),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      tooltip: 'Copy ID',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: bookingId));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Booking ID copied to clipboard')),
                        );
                      },
                    ),
                  ],
                ),
                if (record?.requestId != null) ...[
                  const Divider(height: 14, color: AppColors.hairline),
                  _detailRow('Request ID', record!.requestId),
                ],
                if (record?.timeZone != null) ...[
                  const Divider(height: 14, color: AppColors.hairline),
                  _detailRow('Timezone', record!.timeZone),
                ],
                const Divider(height: 14, color: AppColors.hairline),
                _detailRow('Coach ID', booking.coachId),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12.5,
            color: AppColors.inkSoft,
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
        ),
      ],
    );
  }
}
