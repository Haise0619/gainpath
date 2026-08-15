import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../data/mock_data.dart';
import '../../widgets/shared.dart';

/// AD-M3.3 — View Gamification Dashboard.
class GamificationDashboardScreen extends StatelessWidget {
  const GamificationDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rewards')),
      body: PageBody(
        children: [
          Panel(
            background: AppColors.primary,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('YOUR POINTS',
                    style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.4,
                        fontWeight: FontWeight.w700,
                        color: Colors.white70)),
                const SizedBox(height: 6),
                Text('${MockData.points}',
                    style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.1,
                        letterSpacing: -1.5)),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _miniStat(Icons.local_fire_department_rounded,
                        '${MockData.streak} day streak'),
                    const SizedBox(width: 18),
                    _miniStat(Icons.military_tech_rounded,
                        '${MockData.badges.where((b) => b.unlocked).length} badges'),
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
          Panel(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _link(context, Icons.videogame_asset_rounded, 'Mini-games',
                    '${MockData.miniGames.length} challenges available',
                    () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const MiniGamesScreen()))),
                const Divider(height: 1, indent: 62),
                _link(context, Icons.military_tech_rounded, 'Badges',
                    'Your unlocked achievements',
                    () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const BadgesScreen()))),
                const Divider(height: 1, indent: 62),
                _link(context, Icons.card_giftcard_rounded, 'Redeem points',
                    'Swap points for rewards at the gym',
                    () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const RewardShopScreen()))),
                const Divider(height: 1, indent: 62),
                _link(context, Icons.leaderboard_rounded, 'Leaderboard',
                    'See where you rank this week',
                    () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const LeaderboardScreen()))),
              ],
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

  Widget _link(BuildContext context, IconData icon, String title,
      String subtitle, VoidCallback onTap) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppColors.accentTint,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(icon, size: 19, color: AppColors.warning),
      ),
      title: Text(title, style: Theme.of(context).textTheme.titleMedium),
      subtitle: Text(subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13)),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
    );
  }
}

/// UC-3.1 / UC-3.2 — Browse and play mini-games.
class MiniGamesScreen extends StatelessWidget {
  const MiniGamesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mini-games')),
      body: PageBody(
        children: [
          Text('Camera-tracked challenges that score your movement.',
              style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 18),
          ...MockData.miniGames.asMap().entries.map((e) {
            final best = 1200 - e.key * 180;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Panel(
                onTap: () => _play(context, e.value),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: AppColors.accentTint,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Icon(Icons.sports_esports_rounded,
                          color: AppColors.warning),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.value,
                              style: Theme.of(context).textTheme.titleMedium),
                          Text('Best score: $best',
                              style: Theme.of(context).textTheme.bodyMedium),
                        ],
                      ),
                    ),
                    const Icon(Icons.play_circle_fill_rounded,
                        size: 28, color: AppColors.primary),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  void _play(BuildContext context, String game) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(game),
        content: const Text(
            'In the full build this launches a camera-tracked challenge. '
            'The prototype jumps straight to a sample result.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => MiniGameResultScreen(game: game)),
              );
            },
            child: const Text('See sample result'),
          ),
        ],
      ),
    );
  }
}

/// UC-3.3 — View Mini-Game Result.
class MiniGameResultScreen extends StatelessWidget {
  final String game;
  const MiniGameResultScreen({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Result')),
      body: PageBody(
        children: [
          Panel(
            background: AppColors.accentTint,
            child: Column(
              children: [
                const Icon(Icons.emoji_events_rounded,
                    size: 44, color: AppColors.warning),
                const SizedBox(height: 10),
                Text(game, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 6),
                const Text('1,340',
                    style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.5)),
                Text('New personal best',
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: const [
              Expanded(child: StatTile('42', 'Reps')),
              SizedBox(width: 10),
              Expanded(child: StatTile('88%', 'Accuracy')),
              SizedBox(width: 10),
              Expanded(child: StatTile('+180', 'Points')),
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
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}

/// UC-3.6 — View Unlocked Achievement.
class BadgesScreen extends StatelessWidget {
  const BadgesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Badges')),
      body: GridView.count(
        padding: const EdgeInsets.all(16),
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.92,
        children: MockData.badges.map((b) {
          return Panel(
            onTap: b.unlocked
                ? () => showToast(context, 'Unlocked: ${b.name}')
                : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: b.unlocked
                        ? AppColors.accentTint
                        : AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                      b.unlocked
                          ? Icons.military_tech_rounded
                          : Icons.lock_outline_rounded,
                      color:
                          b.unlocked ? AppColors.warning : AppColors.inkSoft),
                ),
                const Spacer(),
                Text(b.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: b.unlocked ? AppColors.ink : AppColors.inkSoft)),
                const SizedBox(height: 3),
                Text(b.description,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontSize: 12.5)),
              ],
            ),
          );
        }).toList(),
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
          Panel(
            background: AppColors.primaryTint,
            child: Row(
              children: [
                const Icon(Icons.account_balance_wallet_rounded,
                    color: AppColors.primary),
                const SizedBox(width: 12),
                Text('${MockData.points} points available',
                    style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
          ),
          const SizedBox(height: 18),
          ...MockData.rewards.map((r) {
            final affordable = MockData.points >= r.points;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Panel(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.title,
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 2),
                          Text('${r.points} points  ·  ${r.stock} left',
                              style: Theme.of(context).textTheme.bodyMedium),
                        ],
                      ),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 40),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      onPressed:
                          affordable ? () => _redeem(context, r) : null,
                      child: const Text('Redeem'),
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

class VoucherScreen extends StatelessWidget {
  final RewardItem item;
  const VoucherScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your voucher')),
      body: PageBody(
        children: [
          Panel(
            child: Column(
              children: [
                const Icon(Icons.confirmation_number_rounded,
                    size: 40, color: AppColors.primary),
                const SizedBox(height: 14),
                Text(item.title,
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

/// UC-3.9 — View Leaderboard Standings.
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  int _scope = 0;

  @override
  Widget build(BuildContext context) {
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
          const SizedBox(height: 18),
          ...MockData.leaderboard.map((row) {
            final isYou = row[1] == MockData.memberName;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Panel(
                background: isYou ? AppColors.primaryTint : null,
                child: Row(
                  children: [
                    SizedBox(
                      width: 30,
                      child: Text(row[0],
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w800)),
                    ),
                    Expanded(
                      child: Text(row[1],
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight:
                                  isYou ? FontWeight.w700 : FontWeight.w500)),
                    ),
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
}
