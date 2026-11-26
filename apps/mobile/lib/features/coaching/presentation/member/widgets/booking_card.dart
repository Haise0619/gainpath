import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_domain/gainpath_domain.dart'
    show PersistedBookingRecord;
import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../booking_details_screen.dart';
import '../../shared/booking_coach_info.dart';
import '../../shared/persisted_booking_presentation.dart';

/// Compact, modern Member appointment card (approximately 150–190dp height)
/// displaying only essential booking information:
/// Coach photo/name, single status badge (Expired distinct from Cancelled), session
/// type & duration, appointment date & time in MYT, actual recorded branch/location
/// (omitted if not recorded, never placeholder), and price (omitted if missing/zero,
/// never RM 0 or Free).
///
/// Tapping anywhere on the card or tapping "View details" opens the dedicated
/// [BookingDetailsScreen] with comprehensive 6-section booking information.
class BookingCard extends StatelessWidget {
  final Booking booking;
  final PersistedBookingRecord? record;
  final bool live;
  final String? statusLabel;
  final String? locationLabel;
  final Widget? details;
  final Widget? photo;
  final Future<BookingCoachInfo>? coachInfoFuture;
  final String? coachSpecialty;
  final VoidCallback? onViewDetails;
  final VoidCallback? onReschedule;
  final void Function(BuildContext)? onCancel;
  final VoidCallback? onMessage;
  final VoidCallback? onRate;
  final VoidCallback? onBookAgain;
  final VoidCallback? onPayment;
  final VoidCallback? onNotes;

  const BookingCard({
    super.key,
    required this.booking,
    this.record,
    this.live = false,
    this.statusLabel,
    this.locationLabel,
    this.details,
    this.photo,
    this.coachInfoFuture,
    this.coachSpecialty,
    this.onViewDetails,
    this.onReschedule,
    this.onCancel,
    this.onMessage,
    this.onRate,
    this.onBookAgain,
    this.onPayment,
    this.onNotes,
  });

  Coach? _coach(BuildContext context) {
    try {
      for (final c in context.read<CoachRepository>().coaches) {
        if (c.id == booking.coachId) return c;
      }
    } catch (_) {}
    return null;
  }

  void _openDetails(BuildContext context) {
    if (onViewDetails != null) {
      onViewDetails!();
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (detailsContext) => BookingDetailsScreen(
          booking: booking,
          record: record,
          live: live,
          statusLabel: statusLabel,
          locationLabel: locationLabel,
          coach: live ? null : _coach(context),
          coachPhoto: photo,
          coachInfoFuture: coachInfoFuture,
          coachSpecialty: coachSpecialty,
          onCancel: onCancel == null ? null : () => onCancel!(detailsContext),
          onReschedule: onReschedule,
          onMessage: onMessage,
          onReview: onRate,
          onNotes: onNotes,
          onPayment: onPayment,
          onBookAgain: onBookAgain,
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    final lower = status.toLowerCase();
    if (lower.contains('pending') || lower.contains('awaiting payment')) {
      return StatusChip(status,
          color: AppColors.warning, background: AppColors.accentTint);
    } else if (lower == 'expired' || lower == 'hold_expired') {
      return const StatusChip('Expired',
          color: AppColors.inkSoft, background: AppColors.surfaceAlt);
    } else if (lower.contains('refund')) {
      return StatusChip(status,
          color: AppColors.primary, background: AppColors.primaryTint);
    }
    return statusPill(status);
  }

  @override
  Widget build(BuildContext context) {
    final coach = live ? null : _coach(context);
    final coachName =
        resolveCoachName(booking.coachName, fallback: coach?.name);
    final initial = coachName.isNotEmpty ? coachName[0].toUpperCase() : 'C';
    final rawLocation = locationLabel ?? resolveBranchLocation(booking.branch);
    final hasRecordedLocation = rawLocation.isNotEmpty &&
        rawLocation != '-' &&
        rawLocation != 'Location confirmed when booking';
    final feeText = resolveBookingFee(booking.fee, feeMinor: record?.feeMinor);
    final refundStatus = memberBookingRefundStatus(record);
    final hasActualRefundProgress =
        refundStatus != null && refundStatus != 'Refund unavailable';
    final resolvedStatus = resolveStatusLabel(
      booking.status,
      rawStatus: record?.rawStatus,
      labelOverride: statusLabel,
      resolution: record?.resolution,
    );
    // Do not confuse refund eligibility with booking status: keep actual booking
    // status unless there is active/completed refund progress.
    final displayStatus =
        hasActualRefundProgress ? refundStatus : resolvedStatus;
    final specialty = (coachSpecialty != null && coachSpecialty!.isNotEmpty)
        ? coachSpecialty
        : (coach != null && coach.specialty.isNotEmpty
            ? coach.specialty
            : null);

    return Panel(
      onTap: () => _openDetails(context),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header: Coach photo/initials (50x50), Name, Specialty/duration, and primary Status badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 50,
                  height: 50,
                  child: photo ??
                      (coach != null && coach.imageUrl.isNotEmpty
                          ? networkAvatar(coach.imageUrl)
                          : Container(
                              color: AppColors.primaryTint,
                              child: Center(
                                child: Text(
                                  initial,
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
                    SizedBox(
                      width: double.infinity,
                      child: Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Text(
                            coachName,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15.5,
                                  color: AppColors.ink,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          _buildStatusChip(displayStatus),
                        ],
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      specialty != null && specialty.isNotEmpty
                          ? '$specialty · ${booking.durationMin} min'
                          : '1-on-1 Consultation · ${booking.durationMin} min',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.inkSoft,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Metadata rows: clean separated Date/Time, Location (if recorded), and Price
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                Icons.calendar_today_rounded,
                size: 13.5,
                color: AppColors.primary,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  _formatDate(booking.start),
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ],
          ),
          if (hasRecordedLocation) ...[
            const SizedBox(height: 5),
            Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 14,
                  color: AppColors.inkSoft,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    rawLocation,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.inkSoft,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          if (feeText != null) ...[
            const SizedBox(height: 5),
            Row(
              children: [
                const Icon(
                  Icons.payments_outlined,
                  size: 14,
                  color: AppColors.inkSoft,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    feeText,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (displayStatus == 'Session ended') ...[
            const SizedBox(height: 8),
            const Text(
              'Awaiting your coach’s session notes. Completion has not been recorded.',
              style: TextStyle(fontSize: 11.5, color: AppColors.inkSoft),
            ),
          ],
          const SizedBox(height: 10),
          const Divider(height: 1, color: AppColors.hairline),
          const SizedBox(height: 6),

          // Actions row: "View details" on left, quick contextual action on right
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              TextButton.icon(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  foregroundColor: AppColors.primary,
                ),
                onPressed: () => _openDetails(context),
                icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                label: const Text(
                  'View details',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
              ),
              _buildQuickAction(context, displayStatus),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAction(BuildContext context, String statusText) {
    final lower = statusText.toLowerCase();
    if (memberBookingRefundStatus(record) != null && onPayment != null) {
      return OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: BorderSide(color: AppColors.primary.withValues(alpha: 0.35)),
          visualDensity: VisualDensity.compact,
          minimumSize: const Size(0, 34),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        onPressed: onPayment,
        child: const Text('Refund Details',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      );
    }
    if (booking.status == BookingStatus.pending) {
      return !lower.contains('elapsed') && onPayment != null
          ? FilledButton(
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
                minimumSize: const Size(0, 36),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: onPayment,
              child: const Text('Continue to Payment',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            )
          : const SizedBox.shrink();
    }

    // Completed: If reviewed show small score pill, else show Leave a review button
    if (booking.status == BookingStatus.completed || lower == 'completed') {
      if (booking.rated) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.accentTint,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.star_rounded, size: 14, color: AppColors.accent),
              const SizedBox(width: 4),
              const Flexible(
                child: Text(
                  'You reviewed this session',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accentDark,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (booking.reviewStars != null)
                Text(
                  ' · ${booking.reviewStars}/5',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accentDark,
                  ),
                ),
            ],
          ),
        );
      }
      if (onRate != null) {
        return OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: BorderSide(color: AppColors.primary.withValues(alpha: 0.35)),
            visualDensity: VisualDensity.compact,
            minimumSize: const Size(0, 34),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: onRate,
          icon: const Icon(Icons.star_rate_rounded, size: 14),
          label: const Text('Leave a review',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        );
      }
    }

    // Cancelled: Show Book again button if callback provided
    if (booking.status == BookingStatus.cancelled || lower == 'cancelled') {
      if (onBookAgain != null) {
        return OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            visualDensity: VisualDensity.compact,
            minimumSize: const Size(0, 36),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: onBookAgain,
          icon: const Icon(Icons.replay_rounded, size: 13),
          label: const Text('Book again',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        );
      }
    }

    return const SizedBox.shrink();
  }

  String _formatDate(DateTime d) {
    const months = [
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
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    final period = d.hour >= 12 ? 'PM' : 'AM';
    return '${d.day} ${months[d.month - 1]} ${d.year} · $h:$m $period MYT';
  }
}
