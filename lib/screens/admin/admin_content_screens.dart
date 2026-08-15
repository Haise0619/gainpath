import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../data/mock_data.dart';
import '../../widgets/shared.dart';
import 'admin_settings_screens.dart';

/// AD-M11.4 — Manage Platform Content.
class AdminContentScreen extends StatelessWidget {
  const AdminContentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Eyebrow('Governance'),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _ContentCard(
                  icon: Icons.video_library_rounded,
                  color: AppColors.primary,
                  title: 'Exercise tutorials',
                  metric: '${MockData.tutorials.length}',
                  metricLabel: 'videos published',
                  cta: 'Manage library',
                  onTap: () => Navigator.push(
                      context, MaterialPageRoute(builder: (_) => const TutorialsScreen())),
                ),
                _ContentCard(
                  icon: Icons.list_alt_rounded,
                  color: AppColors.info,
                  title: 'Routine templates',
                  metric: '6',
                  metricLabel: 'templates available',
                  cta: 'Edit templates',
                  onTap: () => showToast(context, 'Routine template editor.'),
                ),
                _ContentCard(
                  icon: Icons.card_giftcard_rounded,
                  color: AppColors.warning,
                  title: 'Reward catalog',
                  metric: '${MockData.rewards.length}',
                  metricLabel: 'items in the shop',
                  cta: 'Manage catalog',
                  onTap: () => Navigator.push(
                      context, MaterialPageRoute(builder: (_) => const RewardCatalogScreen())),
                ),
                _ContentCard(
                  icon: Icons.campaign_rounded,
                  color: AppColors.success,
                  title: 'Announcements',
                  metric: '1',
                  metricLabel: 'active broadcast',
                  cta: 'New announcement',
                  onTap: () => Navigator.push(
                      context, MaterialPageRoute(builder: (_) => const BroadcastScreen())),
                ),
                _ContentCard(
                  icon: Icons.smart_toy_outlined,
                  color: AppColors.inkSoft,
                  title: 'AI chatbot disclaimer',
                  metric: 'v3',
                  metricLabel: 'current version',
                  cta: 'Edit disclaimer',
                  onTap: () => Navigator.push(
                      context, MaterialPageRoute(builder: (_) => const ChatbotDisclaimerScreen())),
                ),
              ],
            ),
            const SizedBox(height: 28),
            const Eyebrow('System settings'),
            SizedBox(
              width: 320,
              child: _SettingCard(
                icon: Icons.tune_rounded,
                title: 'General, rewards, and compliance',
                value: 'Conversion rate, legal documents, and facility defaults',
                onTap: () => Navigator.push(
                    context, MaterialPageRoute(builder: (_) => const SystemSettingsScreen())),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContentCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String metric;
  final String metricLabel;
  final String cta;
  final VoidCallback onTap;

  const _ContentCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.metric,
    required this.metricLabel,
    required this.cta,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 258,
      height: 190,
      child: Panel(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration:
                      BoxDecoration(color: color.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(11)),
                  child: Icon(icon, size: 20, color: color),
                ),
                const Spacer(),
                const Icon(Icons.arrow_outward_rounded, size: 16, color: AppColors.inkSoft),
              ],
            ),
            const Spacer(),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(metric, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(metricLabel,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12.5)),
                ),
              ],
            ),
            const Spacer(),
            Text(cta,
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: color)),
          ],
        ),
      ),
    );
  }
}

class _SettingCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;
  const _SettingCard({required this.icon, required this.title, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 320,
      child: Panel(
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: AppColors.primaryTint, borderRadius: BorderRadius.circular(11)),
              child: Icon(icon, size: 19, color: AppColors.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12.5)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14),
          ],
        ),
      ),
    );
  }
}

class TutorialsScreen extends StatelessWidget {
  const TutorialsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Exercise tutorials'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => showToast(context, 'Add a new tutorial.'),
          ),
        ],
      ),
      body: PageBody(
        children: MockData.tutorials
            .map((t) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Panel(
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.ink,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.play_arrow_rounded,
                              color: Colors.white),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(t[0],
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium),
                              Text(t[1],
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium),
                            ],
                          ),
                        ),
                        statusPill(t[2]),
                      ],
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }
}

class RewardCatalogScreen extends StatelessWidget {
  const RewardCatalogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reward catalog'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => showToast(context, 'Add a reward item.'),
          ),
        ],
      ),
      body: PageBody(
        children: MockData.rewards
            .map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Panel(
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(r.title,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium),
                              Text('${r.points} points',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('${r.stock}',
                                style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700)),
                            Text('in stock',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(fontSize: 12)),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 19),
                          onPressed: () =>
                              showToast(context, 'Edit ${r.title}.'),
                        ),
                      ],
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }
}

class BroadcastScreen extends StatelessWidget {
  const BroadcastScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New announcement')),
      body: PageBody(
        children: [
          const TextField(
            decoration: InputDecoration(
                labelText: 'Title', hintText: 'Public holiday hours'),
          ),
          const SizedBox(height: 12),
          const TextField(
            maxLines: 4,
            decoration: InputDecoration(
                labelText: 'Message',
                hintText: 'What do members need to know?'),
          ),
          const SizedBox(height: 12),
          Row(
            children: const [
              Expanded(
                  child: TextField(
                      decoration: InputDecoration(labelText: 'Show from'))),
              SizedBox(width: 10),
              Expanded(
                  child: TextField(
                      decoration: InputDecoration(labelText: 'Show until'))),
            ],
          ),
          const SizedBox(height: 18),
          Panel(
            background: AppColors.accentTint,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.campaign_rounded,
                    size: 19, color: AppColors.warning),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'This appears at the top of every member home screen the next '
                    'time they open the app.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              showToast(context, 'Announcement published.');
            },
            child: const Text('Publish announcement'),
          ),
        ],
      ),
    );
  }
}

/// AD-M11.4 — Update Disclaimer (ChatbotDisclaimerConfig). Distinct from the
/// compliance/privacy document managed under System Settings (AD-M11.6):
/// this is only the text shown before a member's first AI coach message
/// each day.
class ChatbotDisclaimerScreen extends StatefulWidget {
  const ChatbotDisclaimerScreen({super.key});

  @override
  State<ChatbotDisclaimerScreen> createState() => _ChatbotDisclaimerScreenState();
}

class _ChatbotDisclaimerScreenState extends State<ChatbotDisclaimerScreen> {
  late final _controller = TextEditingController(
    text: 'The AI coach gives general fitness and technique guidance only. It cannot diagnose '
        'injuries, prescribe treatment, or replace advice from a doctor or physiotherapist.\n\n'
        'If something hurts, stop and speak to a qualified professional.',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI chatbot disclaimer')),
      body: PageBody(
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Shown once per day before a member sends their first message.',
                    style: Theme.of(context).textTheme.bodyLarge),
              ),
              statusPill('v3 live'),
            ],
          ),
          const SizedBox(height: 18),
          const Eyebrow('Disclaimer text'),
          TextField(
            controller: _controller,
            maxLines: 8,
            decoration: const InputDecoration(hintText: 'What members see before their first message'),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              showToast(context, 'Disclaimer updated to v4.');
            },
            child: const Text('Publish new version'),
          ),
        ],
      ),
    );
  }
}
