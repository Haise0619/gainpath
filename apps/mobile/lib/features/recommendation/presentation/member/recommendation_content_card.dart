import 'package:flutter/material.dart';
import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_ui/gainpath_ui.dart';

String recommendationActionLabel(RecommendationKind kind) => switch (kind) {
      RecommendationKind.routine => 'Preview Routine',
      RecommendationKind.trainer => 'View Coach',
      RecommendationKind.content => 'Watch Tutorial',
    };

String recommendationTypeLabel(RecommendationKind kind) => switch (kind) {
      RecommendationKind.routine => 'Routine',
      RecommendationKind.trainer => 'Coach guidance',
      RecommendationKind.content => 'Exercise tutorial',
    };

class RecommendationContentCard extends StatefulWidget {
  const RecommendationContentCard(
      {super.key,
      required this.kind,
      required this.title,
      required this.reason,
      required this.onOpen,
      this.onDetails,
      this.onDismiss,
      this.imageUrl,
      this.photo,
      this.difficulty,
      this.durationMinutes,
      this.exerciseCount,
      this.specialization,
      this.branchLabel,
      this.priceMinor,
      this.currency,
      this.available = true,
      this.busy = false,
      this.useTallRoutineCover = false});

  final RecommendationKind kind;
  final String title, reason;
  final String? imageUrl, difficulty, specialization, branchLabel, currency;
  final int? durationMinutes, exerciseCount, priceMinor;
  final Widget? photo;
  final VoidCallback onOpen;
  final VoidCallback? onDetails, onDismiss;
  final bool available, busy, useTallRoutineCover;

  @override
  State<RecommendationContentCard> createState() =>
      _RecommendationContentCardState();
}

class _RecommendationContentCardState extends State<RecommendationContentCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final artwork = _RecommendationArtwork(
      kind: widget.kind,
      url: widget.available ? widget.imageUrl : null,
      photo: widget.photo,
    );

    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: switch (widget.kind) {
        RecommendationKind.routine => _FeaturedRoutineCard(
            artwork: artwork,
            useTallCover: widget.useTallRoutineCover,
            title: widget.title,
            difficulty: widget.difficulty,
            durationMinutes: widget.durationMinutes,
            exerciseCount: widget.exerciseCount,
            reason: widget.reason,
            available: widget.available,
            busy: widget.busy,
            isExpanded: _expanded,
            onOpen: widget.onOpen,
            onToggleInfo: () => setState(() => _expanded = !_expanded),
            onDetails: widget.onDetails,
            onDismiss: widget.onDismiss,
          ),
        RecommendationKind.content => _CompactTutorialCard(
            artwork: artwork,
            title: widget.title,
            difficulty: widget.difficulty,
            reason: widget.reason,
            available: widget.available,
            busy: widget.busy,
            isExpanded: _expanded,
            onOpen: widget.onOpen,
            onToggleInfo: () => setState(() => _expanded = !_expanded),
            onDetails: widget.onDetails,
            onDismiss: widget.onDismiss,
          ),
        RecommendationKind.trainer => _CoachProfileCard(
            artwork: artwork,
            title: widget.title,
            specialization: widget.specialization,
            branchLabel: widget.branchLabel,
            priceMinor: widget.priceMinor,
            currency: widget.currency,
            reason: widget.reason,
            available: widget.available,
            busy: widget.busy,
            isExpanded: _expanded,
            onOpen: widget.onOpen,
            onToggleInfo: () => setState(() => _expanded = !_expanded),
            onDetails: widget.onDetails,
            onDismiss: widget.onDismiss,
          ),
      },
    );
  }
}

class _FeaturedRoutineCard extends StatelessWidget {
  const _FeaturedRoutineCard({
    required this.artwork,
    required this.useTallCover,
    required this.title,
    required this.difficulty,
    required this.durationMinutes,
    required this.exerciseCount,
    required this.reason,
    required this.available,
    required this.busy,
    required this.isExpanded,
    required this.onOpen,
    required this.onToggleInfo,
    this.onDetails,
    this.onDismiss,
  });

  final Widget artwork;
  final String title, reason;
  final String? difficulty;
  final int? durationMinutes, exerciseCount;
  final bool useTallCover;
  final bool available, busy, isExpanded;
  final VoidCallback onOpen, onToggleInfo;
  final VoidCallback? onDetails, onDismiss;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final open = busy ? null : onOpen;
    final level = difficulty?.trim() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Cover Image with Top Overlays
        InkWell(
          onTap: open,
          child: Stack(
            children: [
              AspectRatio(
                aspectRatio: useTallCover ? 16 / 9 : 2.5,
                child: artwork,
              ),
              if (!useTallCover && level.isNotEmpty)
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      level,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
              if (onDismiss != null)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      shape: BoxShape.circle,
                    ),
                    child: _MoreMenuButton(onDismiss: onDismiss, dark: true),
                  ),
                ),
            ],
          ),
        ),

        // Body Content
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title and Info Action
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (reason.trim().isNotEmpty || onDetails != null)
                    _InfoActionButton(
                      isExpanded: isExpanded,
                      onToggle: onToggleInfo,
                    ),
                ],
              ),

              // Metadata (Duration / Exercises)
              const SizedBox(height: 6),
              Text(
                [
                  if (useTallCover && level.isNotEmpty) level,
                  if (durationMinutes != null) '$durationMinutes min',
                  if (exerciseCount != null) '$exerciseCount exercises',
                ].join(' • '),
                style: text.bodySmall?.copyWith(
                  color: AppColors.inkSoft,
                  fontWeight: FontWeight.w600,
                ),
              ),

              // Recommendation reason (max 2 lines)
              if (reason.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  reason,
                  style: text.bodySmall?.copyWith(color: AppColors.inkSoft),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              // Expanded explanation
              _ExpandedReasonSection(
                isExpanded: isExpanded,
                reason: reason,
                onDetails: onDetails,
              ),

              const SizedBox(height: 12),

              // Primary CTA: Preview Routine
              SizedBox(
                width: double.infinity,
                height: 42,
                child: FilledButton(
                  onPressed: open,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    available ? 'Preview Routine' : 'View details',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CompactTutorialCard extends StatelessWidget {
  const _CompactTutorialCard({
    required this.artwork,
    required this.title,
    required this.difficulty,
    required this.reason,
    required this.available,
    required this.busy,
    required this.isExpanded,
    required this.onOpen,
    required this.onToggleInfo,
    this.onDetails,
    this.onDismiss,
  });

  final Widget artwork;
  final String title, reason;
  final String? difficulty;
  final bool available, busy, isExpanded;
  final VoidCallback onOpen, onToggleInfo;
  final VoidCallback? onDetails, onDismiss;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final open = busy ? null : onOpen;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left side: 112dp Thumbnail with Play Overlay
              InkWell(
                onTap: open,
                borderRadius: BorderRadius.circular(12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 112,
                    height: 88,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        artwork,
                        ColoredBox(color: Colors.black.withValues(alpha: 0.18)),
                        Center(
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.play_arrow_rounded,
                              size: 20,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Right side content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header: Difficulty tag + Info + More menu
                    Row(
                      children: [
                        if (difficulty != null &&
                            difficulty!.trim().isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primaryTint,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              difficulty!,
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                        const Spacer(),
                        if (reason.trim().isNotEmpty || onDetails != null)
                          _InfoActionButton(
                            isExpanded: isExpanded,
                            onToggle: onToggleInfo,
                          ),
                        if (onDismiss != null)
                          _MoreMenuButton(onDismiss: onDismiss),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Exercise Title (max 2 lines)
                    Text(
                      title,
                      style: text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    // Short reason (max 2 lines)
                    if (reason.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        reason,
                        style:
                            text.bodySmall?.copyWith(color: AppColors.inkSoft),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Primary CTA: Watch Tutorial
          SizedBox(
            width: double.infinity,
            height: 36,
            child: FilledButton.tonal(
              onPressed: open,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryTint,
                foregroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                available ? 'Watch Tutorial' : 'View details',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),

          // Expanded section
          _ExpandedReasonSection(
            isExpanded: isExpanded,
            reason: reason,
            onDetails: onDetails,
          ),
        ],
      ),
    );
  }
}

class _CoachProfileCard extends StatelessWidget {
  const _CoachProfileCard({
    required this.artwork,
    required this.title,
    required this.specialization,
    required this.branchLabel,
    required this.priceMinor,
    required this.currency,
    required this.reason,
    required this.available,
    required this.busy,
    required this.isExpanded,
    required this.onOpen,
    required this.onToggleInfo,
    this.onDetails,
    this.onDismiss,
  });

  final Widget artwork;
  final String title, reason;
  final String? specialization, branchLabel, currency;
  final int? priceMinor;
  final bool available, busy, isExpanded;
  final VoidCallback onOpen, onToggleInfo;
  final VoidCallback? onDetails, onDismiss;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final open = busy ? null : onOpen;

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: 76dp circular avatar
              SizedBox.square(
                dimension: 76,
                child: ClipOval(child: artwork),
              ),
              const SizedBox(width: 14),

              // Right: Coach Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Top: Name + Info + Dismiss
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: text.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (reason.trim().isNotEmpty || onDetails != null)
                          _InfoActionButton(
                            isExpanded: isExpanded,
                            onToggle: onToggleInfo,
                          ),
                        if (onDismiss != null)
                          _MoreMenuButton(onDismiss: onDismiss),
                      ],
                    ),

                    // Specialization & Price
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (specialization != null &&
                            specialization!.trim().isNotEmpty)
                          specialization!,
                        if (priceMinor != null && currency != null)
                          '$currency ${(priceMinor! / 100).toStringAsFixed(2)} / session',
                      ].join(' • '),
                      style: text.bodySmall?.copyWith(
                        color: AppColors.inkSoft,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    // Branch label if present
                    if (branchLabel != null &&
                        branchLabel!.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        branchLabel!,
                        style: text.bodySmall?.copyWith(
                          color: AppColors.inkSoft,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],

                    // Reason badge/tip (light purple badge)
                    if (reason.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primaryTint,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          reason,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          // Primary CTA: View Coach
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 38,
            child: FilledButton(
              onPressed: open,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                available ? 'View Coach' : 'View details',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),

          // Expanded section
          _ExpandedReasonSection(
            isExpanded: isExpanded,
            reason: reason,
            onDetails: onDetails,
          ),
        ],
      ),
    );
  }
}

class _MoreMenuButton extends StatelessWidget {
  const _MoreMenuButton({this.onDismiss, this.dark = false});
  final VoidCallback? onDismiss;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    if (onDismiss == null) return const SizedBox.shrink();
    return Material(
      color: Colors.transparent,
      child: PopupMenuButton<String>(
        tooltip: 'More options',
        icon: Icon(
          Icons.more_vert_rounded,
          size: 20,
          color: dark ? Colors.white : AppColors.inkSoft,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onSelected: (value) {
          if (value == 'dismiss') {
            onDismiss?.call();
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 'dismiss',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.visibility_off_outlined,
                    size: 18, color: AppColors.inkSoft),
                SizedBox(width: 8),
                Text('Dismiss recommendation'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoActionButton extends StatelessWidget {
  const _InfoActionButton({required this.isExpanded, required this.onToggle});
  final bool isExpanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        isExpanded ? Icons.info_rounded : Icons.info_outline_rounded,
        size: 18,
        color: AppColors.primary,
      ),
      tooltip: isExpanded ? 'Hide reason' : 'Why this recommendation?',
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      onPressed: onToggle,
    );
  }
}

class _ExpandedReasonSection extends StatelessWidget {
  const _ExpandedReasonSection({
    required this.isExpanded,
    required this.reason,
    this.onDetails,
  });

  final bool isExpanded;
  final String reason;
  final VoidCallback? onDetails;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return AnimatedSize(
      duration:
          reduceMotion ? Duration.zero : const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      child: isExpanded
          ? Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryTint,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.15)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.auto_awesome_rounded,
                            size: 14, color: AppColors.primary),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            'Why this recommendation?',
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      reason,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.ink,
                            height: 1.35,
                          ),
                    ),
                    if (onDetails != null) ...[
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerRight,
                        child: InkWell(
                          onTap: onDetails,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 2, horizontal: 4),
                            child: Text(
                              'View details →',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}

class _RecommendationArtwork extends StatelessWidget {
  const _RecommendationArtwork({required this.kind, this.url, this.photo});
  final RecommendationKind kind;
  final String? url;
  final Widget? photo;

  @override
  Widget build(BuildContext context) {
    final icon = switch (kind) {
      RecommendationKind.routine => Icons.fitness_center_rounded,
      RecommendationKind.content => Icons.ondemand_video_outlined,
      RecommendationKind.trainer => Icons.person_rounded,
    };
    final fallback = ColoredBox(
        color: AppColors.primaryTint,
        child: Center(child: Icon(icon, size: 32, color: AppColors.primary)));
    if (photo != null) return photo!;
    final uri = Uri.tryParse(url ?? '');
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment) {
      return fallback;
    }
    return Image.network(uri.toString(),
        fit: BoxFit.cover,
        excludeFromSemantics: true,
        errorBuilder: (_, error, ___) {
          debugPrint('Recommendation artwork load error: ${error.runtimeType}');
          return fallback;
        },
        frameBuilder: (context, child, frame, synchronous) => synchronous
            ? child
            : AnimatedOpacity(
                opacity: frame == null ? 0 : 1,
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 180),
                child: child));
  }
}
