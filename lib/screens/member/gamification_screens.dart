import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../data/mock_data.dart';
import '../../widgets/shared.dart';

/// Full-bleed network image with a graceful gradient fallback so a dead
/// link never breaks the layout — the same defensive pattern used across
/// onboarding, profile setup, and the workout module.
Widget _networkHero(String url, {BoxFit fit = BoxFit.cover}) {
  return Image.network(
    url,
    fit: fit,
    loadingBuilder: (context, child, progress) =>
        progress == null ? child : Container(color: AppColors.ink),
    errorBuilder: (context, error, stack) =>
        const DecoratedBox(decoration: BoxDecoration(gradient: AppColors.heroGradient)),
  );
}

/// AD-M3.3 — View Gamification Dashboard.
class GamificationDashboardScreen extends StatelessWidget {
  const GamificationDashboardScreen({super.key});

  static const _activity = [
    ['Daily check-in claimed', '+50 pts', Icons.local_fire_department_rounded, AppColors.warning],
    ['New high score — Squat Rush', '+180 pts', Icons.sports_esports_rounded, AppColors.primary],
    ['Redeemed Protein Shake Voucher', '-400 pts', Icons.card_giftcard_rounded, AppColors.danger],
  ];

  @override
  Widget build(BuildContext context) {
    final unlocked = MockData.badges.where((b) => b.unlocked).length;
    final rank = MockData.leaderboard.firstWhere((r) => r[1] == MockData.memberName, orElse: () => const ['—', '', '']);

    return Scaffold(
      appBar: AppBar(title: const Text('Rewards')),
      body: PageBody(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppColors.heroGradient,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: AppColors.primary.withValues(alpha: 0.28), blurRadius: 22, offset: const Offset(0, 10)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('YOUR POINTS',
                              style: TextStyle(
                                  fontSize: 11, letterSpacing: 1.4, fontWeight: FontWeight.w700, color: Colors.white70)),
                          const SizedBox(height: 6),
                          TweenAnimationBuilder<int>(
                            tween: IntTween(begin: 0, end: MockData.points),
                            duration: const Duration(milliseconds: 900),
                            curve: Curves.easeOutCubic,
                            builder: (context, value, _) => Text('$value',
                                style: const TextStyle(
                                    fontSize: 40,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    height: 1.1,
                                    letterSpacing: -1.5)),
                          ),
                        ],
                      ),
                    ),
                    InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: () => Navigator.push(
                          context, MaterialPageRoute(builder: (_) => const LeaderboardScreen())),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.leaderboard_rounded, size: 14, color: Colors.white),
                            const SizedBox(width: 5),
                            Text('#${rank[0]} this week',
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _miniStat(Icons.local_fire_department_rounded, '${MockData.streak} day streak'),
                    const SizedBox(width: 18),
                    _miniStat(Icons.military_tech_rounded, '$unlocked badges'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Eyebrow('Streak'),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ProgressRow(
                  'Progress to 14-day badge',
                  MockData.streak / 14,
                  '${MockData.streak}/14',
                  color: AppColors.accent,
                ),
                const SizedBox(height: 6),
                Text('Longest streak so far: ${MockData.longestStreak} days',
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Eyebrow('Explore'),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.25,
            children: [
              _ExploreCard(
                icon: Icons.sports_esports_rounded,
                color: AppColors.primary,
                title: 'Mini-games',
                stat: '${MockData.miniGames.length} challenges',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MiniGamesScreen())),
              ),
              _ExploreCard(
                icon: Icons.military_tech_rounded,
                color: AppColors.warning,
                title: 'Badges',
                stat: '$unlocked/${MockData.badges.length} unlocked',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BadgesScreen())),
              ),
              _ExploreCard(
                icon: Icons.card_giftcard_rounded,
                color: AppColors.success,
                title: 'Redeem points',
                stat: '${MockData.rewards.length} rewards',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RewardShopScreen())),
              ),
              _ExploreCard(
                icon: Icons.leaderboard_rounded,
                color: AppColors.info,
                title: 'Leaderboard',
                stat: 'Rank #${rank[0]}',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LeaderboardScreen())),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Eyebrow('Recent activity'),
          Panel(
            padding: EdgeInsets.zero,
            child: Column(
              children: List.generate(_activity.length, (i) {
                final a = _activity[i];
                final positive = (a[1] as String).startsWith('+');
                return Column(
                  children: [
                    if (i > 0) const Divider(height: 1, indent: 62),
                    ListTile(
                      leading: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: (a[3] as Color).withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Icon(a[2] as IconData, size: 18, color: a[3] as Color),
                      ),
                      title: Text(a[0] as String,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.ink)),
                      trailing: Text(a[1] as String,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: positive ? AppColors.success : AppColors.danger)),
                    ),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniStat(IconData icon, String label) => Row(
        children: [
          Icon(icon, size: 16, color: AppColors.accent),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ],
      );
}

class _ExploreCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String stat;
  final VoidCallback onTap;

  const _ExploreCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.stat,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Panel(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(13)),
            child: Icon(icon, color: color, size: 21),
          ),
          const Spacer(),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 2),
          Text(stat, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12)),
        ],
      ),
    );
  }
}

/// AD-M3.1 — Browse Mini-Games. A featured "Challenge of the Day" hero
/// plus a media-card grid for the rest, so the camera-tracked challenges
/// read as something worth picking, not settings rows.
class MiniGamesScreen extends StatelessWidget {
  const MiniGamesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const games = MockData.miniGames;
    final featured = games.first;
    final rest = games.skip(1).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Mini-games')),
      body: PageBody(
        children: [
          Text('Camera-tracked challenges that score your movement.',
              style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 16),
          const Eyebrow('Challenge of the day'),
          _FeaturedGameCard(game: featured),
          const SizedBox(height: 20),
          const Eyebrow('All challenges'),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.72,
            children: rest.map((g) => _MiniGameCard(game: g)).toList(),
          ),
        ],
      ),
    );
  }
}

Color _difficultyColor(String difficulty) {
  switch (difficulty) {
    case 'Easy':
      return AppColors.success;
    case 'Hard':
      return AppColors.danger;
    default:
      return AppColors.warning;
  }
}

/// A bigger, banner-style card for the day's spotlighted challenge — the
/// kind of "featured" slot mobile game hubs use to make one item feel like
/// an event rather than just first in a list.
class _FeaturedGameCard extends StatelessWidget {
  final MiniGame game;
  const _FeaturedGameCard({required this.game});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () =>
            Navigator.push(context, MaterialPageRoute(builder: (_) => LiveMiniGameScreen(game: game))),
        child: Container(
          height: 168,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: AppColors.accent.withValues(alpha: 0.28), blurRadius: 20, offset: const Offset(0, 10)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              fit: StackFit.expand,
              children: [
                _networkHero(game.imageUrl),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.ink.withValues(alpha: 0.35), AppColors.ink.withValues(alpha: 0.82)],
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(999)),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.local_fire_department_rounded, size: 13, color: AppColors.ink),
                        SizedBox(width: 4),
                        Text('FEATURED TODAY',
                            style: TextStyle(
                                fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5, color: AppColors.ink)),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: 14,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(game.name,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(color: Colors.white, fontSize: 21)),
                            const SizedBox(height: 4),
                            Text(game.tagline,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        width: 46,
                        height: 46,
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        child: const Icon(Icons.play_arrow_rounded, color: AppColors.primary, size: 28),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniGameCard extends StatelessWidget {
  final MiniGame game;
  const _MiniGameCard({required this.game});

  @override
  Widget build(BuildContext context) {
    final color = _difficultyColor(game.difficulty);
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () =>
            Navigator.push(context, MaterialPageRoute(builder: (_) => LiveMiniGameScreen(game: game))),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.hairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: AspectRatio(
                  aspectRatio: 16 / 11,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _networkHero(game.imageUrl),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, AppColors.ink.withValues(alpha: 0.6)],
                          ),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(7)),
                          child: Text(game.difficulty,
                              style: const TextStyle(
                                  fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white)),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.22),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
                          ),
                          child: Icon(game.icon, size: 14, color: Colors.white),
                        ),
                      ),
                      const Center(
                        child: Icon(Icons.play_circle_fill_rounded, size: 34, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(game.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 13.5)),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(Icons.emoji_events_rounded, size: 12, color: AppColors.warning),
                          const SizedBox(width: 3),
                          Text('${game.bestScore}',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.inkSoft)),
                          const SizedBox(width: 8),
                          const Icon(Icons.groups_rounded, size: 12, color: AppColors.inkSoft),
                          const SizedBox(width: 3),
                          Text(_formatPlays(game.plays),
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.inkSoft)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatPlays(int plays) => plays >= 1000 ? '${(plays / 1000).toStringAsFixed(1)}k' : '$plays';
}

/// UC-3.1 — Play Mini-Game Journey. A motion-based gameplay simulation:
/// a moving target reticle the member "hits" in real time, a countdown,
/// live score, and combo streak — the camera-tracking equivalent of
/// LiveWorkoutScreen but tuned to feel like a game rather than a serious
/// tracker (different palette, faster pace, celebratory combo flashes).
class LiveMiniGameScreen extends StatefulWidget {
  final MiniGame game;
  const LiveMiniGameScreen({super.key, required this.game});

  @override
  State<LiveMiniGameScreen> createState() => _LiveMiniGameScreenState();
}

class _LiveMiniGameScreenState extends State<LiveMiniGameScreen> with TickerProviderStateMixin {
  static const _gameSeconds = 20;

  late final AnimationController _reticleController;
  Timer? _timer;
  final _rng = math.Random();

  int _secondsLeft = _gameSeconds;
  int _score = 0;
  int _hits = 0;
  int _combo = 0;
  String? _flashText;
  Alignment _target = Alignment.center;

  @override
  void initState() {
    super.initState();
    _reticleController = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))
      ..repeat(reverse: true);
    _moveTarget();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _moveTarget() {
    _target = Alignment(_rng.nextDouble() * 1.4 - 0.7, _rng.nextDouble() * 1.1 - 0.6);
  }

  void _tick() {
    if (!mounted) return;
    setState(() {
      _secondsLeft--;
      // Simulate a hit roughly every tick with a chance of a combo streak,
      // standing in for the real pose-tracking hit-detection pipeline.
      final hit = _rng.nextDouble() < 0.82;
      if (hit) {
        _hits++;
        _combo++;
        final base = 40 + _rng.nextInt(40);
        final comboBonus = _combo >= 3 ? 30 : 0;
        _score += base + comboBonus;
        _flashText = comboBonus > 0 ? '+${base + comboBonus} COMBO x$_combo' : '+$base';
      } else {
        _combo = 0;
        _flashText = null;
      }
      _moveTarget();
      if (_secondsLeft <= 0) {
        _finish();
      }
    });
  }

  void _finish() {
    _timer?.cancel();
    final accuracy = ((_hits / _gameSeconds) * 100).clamp(0, 100).round();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => MiniGameResultScreen(
          game: widget.game,
          score: _score,
          hits: _hits,
          accuracy: accuracy,
        ),
      ),
    );
  }

  Future<void> _quit() async {
    _timer?.cancel();
    final ok = await confirmSheet(
      context,
      title: 'Quit this game?',
      message: 'Your score so far will not be saved.',
      confirmLabel: 'Quit',
      destructive: true,
    );
    if (ok && mounted) {
      Navigator.pop(context);
    } else {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _reticleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.primaryDark, AppColors.ink],
                      ),
                    ),
                  ),
                  AnimatedAlign(
                    duration: const Duration(milliseconds: 650),
                    curve: Curves.easeInOut,
                    alignment: _target,
                    child: AnimatedBuilder(
                      animation: _reticleController,
                      builder: (context, child) {
                        final scale = 1.0 + (_reticleController.value * 0.18);
                        return Transform.scale(scale: scale, child: child);
                      },
                      child: Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.overlay, width: 3),
                          color: AppColors.overlay.withValues(alpha: 0.12),
                        ),
                        child: const Icon(Icons.adjust_rounded, color: AppColors.overlay, size: 30),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    left: 16,
                    right: 16,
                    child: Row(
                      children: [
                        _pill(Icons.timer_outlined, '0:${_secondsLeft.toString().padLeft(2, '0')}'),
                        const Spacer(),
                        IconButton(
                          style: IconButton.styleFrom(backgroundColor: Colors.black38),
                          icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                          onPressed: _quit,
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 60,
                    child: Column(
                      children: [
                        Text('$_score',
                            style: const TextStyle(
                                fontSize: 56,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                height: 1.0,
                                letterSpacing: -2)),
                        const Text('SCORE',
                            style: TextStyle(
                                fontSize: 11, letterSpacing: 3, fontWeight: FontWeight.w700, color: Colors.white54)),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 24,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      transitionBuilder: (child, anim) =>
                          ScaleTransition(scale: anim, child: FadeTransition(opacity: anim, child: child)),
                      child: _flashText == null
                          ? const SizedBox(key: ValueKey('empty'), height: 34)
                          : Container(
                              key: ValueKey(_flashText),
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                              decoration: BoxDecoration(
                                color: AppColors.accent,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(_flashText!,
                                  style: const TextStyle(
                                      color: AppColors.ink, fontSize: 14, fontWeight: FontWeight.w800)),
                            ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              color: AppColors.ink,
              child: Text(widget.game.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(IconData icon, String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(999)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: Colors.white70),
            const SizedBox(width: 6),
            Text(text, style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w700)),
          ],
        ),
      );
}

/// UC-3.3 — View Mini-Game Result, driven by the real score the member
/// just earned in LiveMiniGameScreen rather than fixed sample numbers.
class MiniGameResultScreen extends StatefulWidget {
  final MiniGame game;
  final int score;
  final int hits;
  final int accuracy;

  const MiniGameResultScreen({
    super.key,
    required this.game,
    required this.score,
    required this.hits,
    required this.accuracy,
  });

  @override
  State<MiniGameResultScreen> createState() => _MiniGameResultScreenState();
}

class _MiniGameResultScreenState extends State<MiniGameResultScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _entrance;
  late final Animation<double> _scale;

  bool get _personalBest => widget.score > widget.game.bestScore;
  int get _pointsEarned => (widget.score / 10).round();

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.6, end: 1.08), weight: 55),
      TweenSequenceItem(tween: Tween(begin: 1.08, end: 1.0), weight: 45),
    ]).animate(CurvedAnimation(parent: _entrance, curve: Curves.easeOut));
    _entrance.forward();
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Result')),
      body: PageBody(
        children: [
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              ScaleTransition(
                scale: _scale,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 26),
                  decoration: BoxDecoration(
                    gradient: AppColors.heroGradient,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.emoji_events_rounded, size: 44, color: Colors.white),
                      const SizedBox(height: 10),
                      Text(widget.game.name,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white)),
                      const SizedBox(height: 6),
                      TweenAnimationBuilder<int>(
                        tween: IntTween(begin: 0, end: widget.score),
                        duration: const Duration(milliseconds: 900),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, _) => Text('$value',
                            style: const TextStyle(
                                fontSize: 40, fontWeight: FontWeight.w800, letterSpacing: -1.5, color: Colors.white)),
                      ),
                      Text(_personalBest ? 'New personal best!' : 'Best: ${widget.game.bestScore}',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13)),
                    ],
                  ),
                ),
              ),
              _sparkle(top: -10, left: 24, size: 20, delayMs: 0),
              _sparkle(top: 6, right: 20, size: 16, delayMs: 180),
              _sparkle(top: -18, right: 90, size: 14, delayMs: 340),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: StatTile('${widget.hits}', 'Hits')),
              const SizedBox(width: 10),
              Expanded(child: StatTile('${widget.accuracy}%', 'Accuracy')),
              const SizedBox(width: 10),
              Expanded(child: StatTile('+$_pointsEarned', 'Points')),
            ],
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () => showToast(context, 'Opening your device share sheet.'),
            icon: const Icon(Icons.ios_share_rounded, size: 19),
            label: const Text('Share result'),
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: () => Navigator.pushReplacement(
                context, MaterialPageRoute(builder: (_) => LiveMiniGameScreen(game: widget.game))),
            child: const Text('Play again'),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
            child: const Text('Back to home'),
          ),
        ],
      ),
    );
  }

  /// A single sparkle particle: fades and drifts upward, staggered by
  /// [delayMs] so the three of them don't all pop at once.
  Widget _sparkle({double? top, double? left, double? right, required double size, required int delayMs}) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: Duration(milliseconds: 700 + delayMs),
        curve: Curves.easeOut,
        builder: (context, value, child) {
          final fadeIn = (value * 5).clamp(0.0, 1.0);
          final fadeOut = (1 - value).clamp(0.0, 1.0);
          return Opacity(
            opacity: math.min(fadeIn, fadeOut),
            child: Transform.translate(offset: Offset(0, -24 * value), child: child),
          );
        },
        child: Icon(Icons.auto_awesome_rounded, color: AppColors.accent, size: size),
      ),
    );
  }
}

/// UC-3.6 — View Unlocked Achievement.
class BadgesScreen extends StatelessWidget {
  const BadgesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final unlocked = MockData.badges.where((b) => b.unlocked).length;
    return Scaffold(
      appBar: AppBar(title: const Text('Badges')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Panel(
              background: AppColors.primaryTint,
              child: Row(
                children: [
                  const Icon(Icons.military_tech_rounded, color: AppColors.primary),
                  const SizedBox(width: 12),
                  Text('$unlocked of ${MockData.badges.length} badges unlocked',
                      style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
            ),
          ),
          Expanded(
            child: GridView.count(
              padding: const EdgeInsets.all(16),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.92,
              children: MockData.badges.map((b) => _BadgeCard(badge: b)).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgeCard extends StatelessWidget {
  final AchievementBadge badge;
  const _BadgeCard({required this.badge});

  @override
  Widget build(BuildContext context) {
    return Panel(
      onTap: () => badge.unlocked ? _showDetail(context) : showToast(context, 'Keep training to unlock this.'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: badge.unlocked ? AppColors.heroGradient : null,
              color: badge.unlocked ? null : AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Opacity(
                    opacity: badge.unlocked ? 1 : 0.35,
                    child: _networkHero(badge.imageUrl, fit: BoxFit.contain),
                  ),
                ),
                if (!badge.unlocked)
                  const Icon(Icons.lock_outline_rounded, size: 16, color: AppColors.inkSoft),
              ],
            ),
          ),
          const Spacer(),
          Text(badge.name,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: badge.unlocked ? AppColors.ink : AppColors.inkSoft)),
          const SizedBox(height: 3),
          Text(badge.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12)),
          if (!badge.unlocked && badge.progressValue != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: badge.progressValue,
                minHeight: 5,
                backgroundColor: AppColors.hairline,
                valueColor: const AlwaysStoppedAnimation(AppColors.accent),
              ),
            ),
            const SizedBox(height: 4),
            Text(badge.progressLabel ?? '',
                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.inkSoft)),
          ],
        ],
      ),
    );
  }

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + MediaQuery.of(ctx).padding.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(gradient: AppColors.heroGradient, shape: BoxShape.circle),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: _networkHero(badge.imageUrl, fit: BoxFit.contain),
              ),
            ),
            const SizedBox(height: 16),
            Text(badge.name, style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(badge.description, textAlign: TextAlign.center, style: Theme.of(ctx).textTheme.bodyLarge),
            const SizedBox(height: 14),
            statusPill('Unlocked'),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => showToast(ctx, 'Opening your device share sheet.'),
                icon: const Icon(Icons.ios_share_rounded, size: 18),
                label: const Text('Share badge'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// UC-3.8 — Generate Reward Redemption Voucher.
class RewardShopScreen extends StatelessWidget {
  const RewardShopScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Redeem points')),
      body: PageBody(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: AppColors.heroGradient,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.account_balance_wallet_rounded, color: Colors.white),
                const SizedBox(width: 12),
                TweenAnimationBuilder<int>(
                  tween: IntTween(begin: 0, end: MockData.points),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) => Text('$value points available',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          ...MockData.rewards.map((r) {
            final affordable = MockData.points >= r.points;
            final needed = r.points - MockData.points;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Panel(
                padding: EdgeInsets.zero,
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
                      child: SizedBox(
                        width: 74,
                        height: 74,
                        child: Opacity(opacity: affordable ? 1 : 0.45, child: _networkHero(r.imageUrl)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.title, style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 2),
                          Text('${r.points} points  ·  ${r.stock} left',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12.5)),
                          if (!affordable) ...[
                            const SizedBox(height: 2),
                            Text('$needed more points needed',
                                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.warning)),
                          ],
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 38),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                        ),
                        onPressed: affordable ? () => _redeem(context, r) : null,
                        child: const Text('Redeem'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 6),
          Panel(
            background: AppColors.surfaceAlt,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded,
                    size: 18, color: AppColors.inkSoft),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Show your voucher code at the front desk. Staff will confirm '
                    'the reward and mark the code as used.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _redeem(BuildContext context, RewardItem item) async {
    final ok = await confirmSheet(
      context,
      title: 'Redeem ${item.title}?',
      message:
          'This uses ${item.points} points and creates a voucher code you show at the front desk.',
      confirmLabel: 'Redeem',
    );
    if (ok && context.mounted) {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => VoucherScreen(item: item)));
    }
  }
}

class VoucherScreen extends StatefulWidget {
  final RewardItem item;
  const VoucherScreen({super.key, required this.item});

  @override
  State<VoucherScreen> createState() => _VoucherScreenState();
}

class _VoucherScreenState extends State<VoucherScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _entrance;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.7, end: 1.05), weight: 55),
      TweenSequenceItem(tween: Tween(begin: 1.05, end: 1.0), weight: 45),
    ]).animate(CurvedAnimation(parent: _entrance, curve: Curves.easeOut));
    _entrance.forward();
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your voucher')),
      body: PageBody(
        children: [
          ScaleTransition(
            scale: _scale,
            child: Panel(
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(height: 110, width: double.infinity, child: _networkHero(widget.item.imageUrl)),
                  ),
                  const SizedBox(height: 16),
                  Text(widget.item.title,
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.hairline),
                    ),
                    child: const Text('GP-4K7M-92XA',
                        style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 3)),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      color: AppColors.ink,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.qr_code_2_rounded,
                        size: 90, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  Text('Show this at the front desk to claim your reward.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}

/// UC-3.9 — View Leaderboard Standings, with a top-3 podium above the
/// ranked list.
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  int _scope = 0;

  static const _podiumColors = [Color(0xFFFFD700), Color(0xFFC0C0C0), Color(0xFFCD7F32)];
  // Comfortably fits the tallest slot's content (avatar 44 + spacing 14 +
  // name/points ~30 + tallest bar 108 ≈ 196) with headroom to spare, so the
  // podium can never overflow regardless of name length.
  static const _podiumHeight = 216.0;
  static const _barHeights = [108.0, 82.0, 62.0]; // 1st, 2nd, 3rd

  @override
  Widget build(BuildContext context) {
    final top3 = MockData.leaderboard.take(3).toList();
    final rest = MockData.leaderboard.skip(3).toList();
    final you = MockData.leaderboard.firstWhere((r) => r[1] == MockData.memberName,
        orElse: () => const ['—', '', '0']);
    final youPoints = int.tryParse(you[2].replaceAll(',', '')) ?? 0;
    final ahead = MockData.leaderboard
        .where((r) => (int.tryParse(r[2].replaceAll(',', '')) ?? 0) > youPoints)
        .toList();
    final gap = ahead.isEmpty
        ? 0
        : (int.tryParse(ahead.last[2].replaceAll(',', '')) ?? 0) - youPoints;

    return Scaffold(
      appBar: AppBar(title: const Text('Leaderboard')),
      body: PageBody(
        children: [
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('This week')),
              ButtonSegment(value: 1, label: Text('All time')),
            ],
            selected: {_scope},
            onSelectionChanged: (s) => setState(() => _scope = s.first),
          ),
          if (gap > 0) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                gradient: AppColors.heroGradient,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.trending_up_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('You are rank #${you[0]} — just $gap points from #${ahead.last[0]}.',
                        style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          if (top3.length == 3)
            SizedBox(
              height: _podiumHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(child: _podiumSlot(context, top3[1], 1)),
                  const SizedBox(width: 8),
                  Expanded(child: _podiumSlot(context, top3[0], 0)),
                  const SizedBox(width: 8),
                  Expanded(child: _podiumSlot(context, top3[2], 2)),
                ],
              ),
            ),
          const SizedBox(height: 20),
          ...rest.map((row) {
            final isYou = row[1] == MockData.memberName;
            final rankNum = int.tryParse(row[0]) ?? 0;
            final trendUp = rankNum.isEven;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Panel(
                background: isYou ? AppColors.primaryTint : null,
                child: Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isYou ? AppColors.primary : AppColors.surfaceAlt,
                        shape: BoxShape.circle,
                      ),
                      child: Text(row[0],
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: isYou ? Colors.white : AppColors.inkSoft)),
                    ),
                    const SizedBox(width: 10),
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: isYou ? AppColors.primary : AppColors.surfaceAlt,
                      child: Text(
                        row[1].substring(0, 1),
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: isYou ? Colors.white : AppColors.inkSoft),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(row[1],
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight:
                                  isYou ? FontWeight.w700 : FontWeight.w500)),
                    ),
                    Icon(trendUp ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                        size: 14, color: trendUp ? AppColors.success : AppColors.danger),
                    const SizedBox(width: 4),
                    Text(row[2],
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary)),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _podiumSlot(BuildContext context, List<String> row, int podiumIndex) {
    final isYou = row[1] == MockData.memberName;
    final color = _podiumColors[podiumIndex];
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 2.5),
                boxShadow: podiumIndex == 0
                    ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 14, spreadRadius: 1)]
                    : null,
              ),
              padding: const EdgeInsets.all(2),
              child: CircleAvatar(
                backgroundColor: isYou ? AppColors.primary : AppColors.surfaceAlt,
                child: Text(row[1].substring(0, 1),
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: isYou ? Colors.white : AppColors.inkSoft)),
              ),
            ),
            if (podiumIndex == 0)
              Positioned(
                top: -16,
                child: Icon(Icons.emoji_events_rounded, color: color, size: 20),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(row[1],
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, fontWeight: isYou ? FontWeight.w800 : FontWeight.w600)),
        Text(row[2],
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.primary)),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          height: _barHeights[podiumIndex],
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.18),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            border: Border(top: BorderSide(color: color, width: 3)),
          ),
          alignment: Alignment.topCenter,
          padding: const EdgeInsets.only(top: 8),
          child: Text(row[0], style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
        ),
      ],
    );
  }
}
