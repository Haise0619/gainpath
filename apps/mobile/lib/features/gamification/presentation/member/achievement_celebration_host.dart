import 'package:flutter/material.dart';
import '../../application/member_achievements_controller.dart';
import '../../domain/member_achievements.dart';
import 'achievement_artwork.dart';
import 'member_achievements_screen.dart';

class AchievementCelebrationHost extends StatefulWidget {
  const AchievementCelebrationHost(
      {super.key, required this.controller, required this.child});

  final MemberAchievementsController controller;
  final Widget child;

  @override
  State<AchievementCelebrationHost> createState() =>
      _AchievementCelebrationHostState();
}

class _AchievementCelebrationHostState
    extends State<AchievementCelebrationHost> {
  final _queue = <MemberAchievement>[];

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    _queue.addAll(widget.controller.takeUnlocks());
  }

  @override
  void didUpdateWidget(AchievementCelebrationHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.removeListener(_changed);
    widget.controller.addListener(_changed);
    _queue
      ..clear()
      ..addAll(widget.controller.takeUnlocks());
  }

  void _changed() {
    if (!widget.controller.current) {
      if (_queue.isNotEmpty) setState(_queue.clear);
      return;
    }
    final unlocked = widget.controller.takeUnlocks();
    if (unlocked.isNotEmpty) setState(() => _queue.addAll(unlocked));
  }

  void _close() => setState(() => _queue.removeAt(0));

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(fit: StackFit.expand, children: [
        widget.child,
        if (_queue.isNotEmpty && widget.controller.current) _banner(context),
      ]);

  Widget _banner(BuildContext context) {
    final badge = _queue.first;
    final theme = Theme.of(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final card = Material(
      elevation: 9,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side:
            BorderSide(color: theme.colorScheme.primary.withValues(alpha: .25)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            AchievementArtwork(id: badge.id, unlocked: true, size: 53),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Achievement Unlocked!',
                        style: theme.textTheme.titleSmall),
                    Text(badge.title, style: theme.textTheme.titleLarge),
                    const Text('A new milestone in your collection.'),
                  ]),
            ),
            IconButton(
                onPressed: _close,
                icon: const Icon(Icons.close),
                tooltip: 'Dismiss achievement'),
          ]),
          Wrap(spacing: 4, children: [
            TextButton(
                onPressed: () {
                  _close();
                  showAchievementDetails(context, widget.controller, badge);
                },
                child: const Text('View Achievement')),
            AchievementShareButton(
                badge: badge, controller: widget.controller, compact: true),
          ]),
        ]),
      ),
    );
    return Positioned(
      left: 12,
      right: 12,
      bottom: 8,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxWidth: 460,
              maxHeight: MediaQuery.sizeOf(context).height * .48),
          child: Semantics(
            liveRegion: true,
            child: reduceMotion
                ? card
                : TweenAnimationBuilder<double>(
                    key: ValueKey(badge.id),
                    duration: const Duration(milliseconds: 360),
                    tween: Tween(begin: 0, end: 1),
                    curve: Curves.easeOutCubic,
                    builder: (_, progress, child) => Opacity(
                      opacity: progress,
                      child: Transform.scale(
                        scale: .92 + progress * .08,
                        alignment: Alignment.bottomCenter,
                        child: child,
                      ),
                    ),
                    child: card,
                  ),
          ),
        ),
      ),
    );
  }
}
