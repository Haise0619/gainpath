import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gainpath_ui/gainpath_ui.dart';

/// A vibrant, premium orange-and-golden gradient button for Daily Check-in rewards.
///
/// Features:
/// - Vibrant gradient from `#FFB020` to `#FF7A00`
/// - Small golden coin icon (`reward_point.svg`)
/// - Bold, dark purple text (“Claim +50” / “Claim +10”)
/// - Rounded corners, subtle glossy highlight rim, and soft 3D orange shadow
/// - Tactile press bounce animation
/// - Coin collection particle burst effect when clicked
/// - Switches to a subtle disabled “✓ Claimed today” state once claimed
class DailyCheckInClaimButton extends StatefulWidget {
  const DailyCheckInClaimButton({
    super.key,
    required this.claimed,
    required this.onClaim,
    this.points = 50,
    this.claiming = false,
  });

  final bool claimed;
  final Future<void> Function()? onClaim;
  final int points;
  final bool claiming;

  @override
  State<DailyCheckInClaimButton> createState() =>
      _DailyCheckInClaimButtonState();
}

class _DailyCheckInClaimButtonState extends State<DailyCheckInClaimButton>
    with TickerProviderStateMixin {
  late final AnimationController _pressController;
  late final Animation<double> _scaleAnimation;
  late final AnimationController _coinEffectController;
  bool _isLocalClaiming = false;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 110),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.93).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeInOut),
    );
    _coinEffectController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    _coinEffectController.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    if (widget.claimed ||
        widget.claiming ||
        _isLocalClaiming ||
        widget.onClaim == null) {
      return;
    }
    setState(() => _isLocalClaiming = true);
    unawaited(_pressController.forward().then((_) {
      if (mounted) _pressController.reverse();
    }));
    _coinEffectController.forward(from: 0.0);
    try {
      await widget.onClaim!();
    } finally {
      if (mounted) {
        setState(() => _isLocalClaiming = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.claimed) {
      return Semantics(
        label: '✓ Claimed today',
        button: false,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F1F7),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE4DFEC)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(
                Icons.check_rounded,
                size: 14,
                color: AppColors.inkSoft,
              ),
              SizedBox(width: 4),
              Flexible(
                child: Text(
                  'Claimed today',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.inkSoft,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final isBusy = widget.claiming || _isLocalClaiming;

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) => Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          ),
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFFFB020),
                  Color(0xFFFF7A00),
                ],
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFFFFE58F).withValues(alpha: 0.70),
                width: 1.0,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x38FF7A00),
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
                BoxShadow(
                  color: Color(0x18FF5400),
                  blurRadius: 2,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: FilledButton(
              onPressed: isBusy ? null : _handleTap,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.transparent,
                disabledBackgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SvgPicture.asset(
                    'assets/icons/reward_point.svg',
                    width: 16,
                    height: 16,
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      isBusy ? 'Claiming…' : 'Claim +${widget.points}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: Color(0x38000000),
                            offset: Offset(0, 1),
                            blurRadius: 2,
                          ),
                        ],
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Floating coin collection animation
        AnimatedBuilder(
          animation: _coinEffectController,
          builder: (context, child) {
            if (!_coinEffectController.isAnimating &&
                _coinEffectController.value == 0) {
              return const SizedBox.shrink();
            }
            final t = _coinEffectController.value;
            final progress = Curves.easeOutCubic.transform(t);
            final opacity = (1.0 - Curves.easeIn.transform(t)).clamp(0.0, 1.0);
            return Positioned.fill(
              child: IgnorePointer(
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    // Center coin floating upward
                    Transform.translate(
                      offset: Offset(0, -32 * progress),
                      child: Opacity(
                        opacity: opacity,
                        child: Transform.scale(
                          scale: 0.9 + 0.3 * math.sin(progress * math.pi),
                          child: SvgPicture.asset(
                            'assets/icons/reward_point.svg',
                            width: 16,
                            height: 16,
                          ),
                        ),
                      ),
                    ),
                    // Left particle
                    Transform.translate(
                      offset: Offset(-14 * progress, -24 * progress),
                      child: Opacity(
                        opacity: opacity,
                        child: Transform.scale(
                          scale: 0.7 + 0.2 * math.sin(progress * math.pi),
                          child: SvgPicture.asset(
                            'assets/icons/reward_point.svg',
                            width: 13,
                            height: 13,
                          ),
                        ),
                      ),
                    ),
                    // Right particle
                    Transform.translate(
                      offset: Offset(14 * progress, -26 * progress),
                      child: Opacity(
                        opacity: opacity,
                        child: Transform.scale(
                          scale: 0.7 + 0.2 * math.sin(progress * math.pi),
                          child: SvgPicture.asset(
                            'assets/icons/reward_point.svg',
                            width: 13,
                            height: 13,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
