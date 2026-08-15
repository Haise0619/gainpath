import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../data/mock_data.dart';
import '../../widgets/shared.dart';
import 'workout_screens.dart';
import 'reports_screens.dart';
import 'chatbot_screens.dart';
import 'gamification_screens.dart';

/// Member landing screen. Pulls together the daily check-in prompt
/// (UC-3.4), broadcast banner (UC-11.14), and quick entry into the
/// core tracked-workout flow.
class MemberHomeScreen extends StatefulWidget {
  const MemberHomeScreen({super.key});

  @override
  State<MemberHomeScreen> createState() => _MemberHomeScreenState();
}

class _MemberHomeScreenState extends State<MemberHomeScreen> {
  bool _claimed = false;
  bool _dismissedBroadcast = false;

  @override
  Widget build(BuildContext context) {
    final firstName = MockData.memberName.split(' ').first;
    return Scaffold(
      appBar: AppBar(
        title: const Text('GainPath'),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline_rounded),
            tooltip: 'AI coach',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ChatbotScreen())),
          ),
        ],
      ),
      body: PageBody(
        children: [
          Text('Hi, $firstName',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 4),
          Text('You are on a ${MockData.streak}-day streak. Keep it going.',
              style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 20),

          if (!_dismissedBroadcast) ...[
            Panel(
              background: AppColors.accentTint,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.campaign_rounded,
                      size: 20, color: AppColors.warning),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Public holiday hours',
                            style: TextStyle(
                                fontSize: 14.5, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 3),
                        Text(
                          'The gym closes at 6pm this Friday. Book your session early.',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: AppColors.ink, fontSize: 13.5),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () =>
                        setState(() => _dismissedBroadcast = true),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Daily check-in, UC-3.4
          Panel(
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: _claimed
                        ? AppColors.primaryTint
                        : AppColors.accentTint,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                      _claimed
                          ? Icons.check_rounded
                          : Icons.local_fire_department_rounded,
                      color: _claimed ? AppColors.success : AppColors.warning),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_claimed ? 'Checked in today' : 'Daily check-in',
                          style: Theme.of(context).textTheme.titleMedium),
                      Text(
                          _claimed
                              ? 'Come back tomorrow to extend your streak.'
                              : 'Claim 50 points for showing up.',
                          style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ),
                if (!_claimed)
                  FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 40),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      backgroundColor: AppColors.accent,
                      foregroundColor: AppColors.ink,
                    ),
                    onPressed: () {
                      setState(() => _claimed = true);
                      showToast(context, 'Claimed. 50 points added.');
                    },
                    child: const Text('Claim'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          const Eyebrow('Today'),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Lower Body Strength',
                              style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 3),
                          Text(
                              '${MockData.routine.length} exercises  ·  about 45 min',
                              style: Theme.of(context).textTheme.bodyMedium),
                        ],
                      ),
                    ),
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: AppColors.heroGradient,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const Icon(Icons.play_arrow_rounded,
                          color: Colors.white, size: 30),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const WorkoutPrepScreen())),
                  child: const Text('Start workout'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          const Eyebrow('Your week'),
          Row(
            children: [
              Expanded(
                  child: StatTile('${MockData.streak}', 'Day streak',
                      valueColor: AppColors.accent)),
              const SizedBox(width: 10),
              const Expanded(child: StatTile('4', 'Sessions')),
              const SizedBox(width: 10),
              const Expanded(child: StatTile('84%', 'Avg form')),
            ],
          ),
          const SizedBox(height: 20),

          const Eyebrow('Shortcuts'),
          Panel(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _shortcut(context, Icons.insights_rounded, 'Progress and reports',
                    'Volume, form trends, and goals',
                    () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ProgressDashboardScreen()))),
                const Divider(height: 1, indent: 62),
                _shortcut(context, Icons.emoji_events_rounded, 'Rewards',
                    'Points, badges, and vouchers',
                    () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                const GamificationDashboardScreen()))),
                const Divider(height: 1, indent: 62),
                _shortcut(context, Icons.chat_bubble_rounded, 'Ask the AI coach',
                    'Form questions and training guidance',
                    () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const ChatbotScreen()))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _shortcut(BuildContext context, IconData icon, String title,
      String subtitle, VoidCallback onTap) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppColors.primaryTint,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(icon, size: 19, color: AppColors.primary),
      ),
      title: Text(title, style: Theme.of(context).textTheme.titleMedium),
      subtitle: Text(subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13)),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
    );
  }
}
