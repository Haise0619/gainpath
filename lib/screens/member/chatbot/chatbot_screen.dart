import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import '../../../app/theme.dart';
import '../../../data/mock_data.dart';
import '../../../widgets/shared.dart';
import '../equipment/equipment_detail_screen.dart';
import 'saved_advice_screen.dart';
import 'widgets/chatbot_about_sheet.dart';

/// Defensive network image loader, same pattern used across the member
/// modules — a broken/slow link never breaks the layout.
Widget _networkHero(String url, {BoxFit fit = BoxFit.cover}) {
  return Image.network(
    url,
    fit: fit,
    loadingBuilder: (context, child, progress) =>
        progress == null ? child : Container(color: AppColors.surfaceAlt),
    errorBuilder: (context, error, stack) =>
        const DecoratedBox(decoration: BoxDecoration(gradient: AppColors.heroGradient)),
  );
}

/// AD-M6.1 — Consult AI Fitness Coach.
class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  static const _demoPrompts = [
    'Which equipment works my chest?',
    'How is my workout progress trending?',
  ];

  static const _genericReply =
      'Good question. Focus on controlling the eccentric, keep your core '
      'braced, and add weight only once the movement feels repeatable.\n\n'
      'This is general educational guidance, not medical advice.';

  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final List<ChatMessage> _messages = [...MockData.chatSeed];
  bool _disclaimerShown = false;
  bool _thinking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showFirstOpenDisclaimer());
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _showFirstOpenDisclaimer() async {
    if (_disclaimerShown) return;
    _disclaimerShown = true;
    await showChatbotAboutSheet(context, dismissible: false);
  }

  void _sendMessage(String userText, ChatMessage reply) {
    setState(() {
      _messages.add(ChatMessage(userText, true));
      _thinking = true;
    });
    _jump();
    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      setState(() {
        _thinking = false;
        _messages.add(reply);
      });
      _jump();
    });
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    _sendMessage(text, _buildReply(text));
  }

  void _sendPrompt(FaqPrompt prompt) {
    _sendMessage(prompt.question, ChatMessage(prompt.reply, false));
  }

  /// Rough keyword routing standing in for real NLU: an equipment or
  /// workout-progress question gets a rich reply — an equipment card
  /// with a photo, or a small trend chart — instead of every answer
  /// being plain text.
  ChatMessage _buildReply(String userText) {
    final q = userText.toLowerCase();

    final equipmentKeywords = ['equipment', 'machine', 'rack', 'bench', 'treadmill', 'cable', 'dumbbell'];
    if (equipmentKeywords.any(q.contains)) {
      GymEquipment? match;
      for (final e in MockData.gymEquipment.where((e) => e.isActive)) {
        if (q.contains(e.name.toLowerCase()) || q.contains(e.muscleGroup.toLowerCase())) {
          match = e;
          break;
        }
      }
      match ??= MockData.gymEquipment.firstWhere((e) => e.isActive, orElse: () => MockData.gymEquipment.first);
      return ChatMessage(
        'This one fits — tap the card for the full setup and safety guide.',
        false,
        attachment: EquipmentAttachment(match),
      );
    }

    final progressKeywords = ['workout', 'progress', 'how am i doing', 'routine', 'improving', 'form score'];
    if (progressKeywords.any(q.contains)) {
      final delta = MockData.postureTrend.last - MockData.postureTrend.first;
      return ChatMessage(
        'Here is how your form score has trended over your last ${MockData.postureTrend.length} sessions.',
        false,
        attachment: ProgressChartAttachment(
          'Form score trend',
          'pts',
          MockData.postureTrend,
          '${delta >= 0 ? '+' : ''}$delta pts',
        ),
      );
    }

    return const ChatMessage(_genericReply, false);
  }

  void _toggleBookmark(String text) {
    setState(() {
      if (MockData.savedAdvice.contains(text)) {
        MockData.savedAdvice.remove(text);
      } else {
        MockData.savedAdvice.add(text);
      }
    });
  }

  void _jump() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI coach'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline_rounded),
            tooltip: 'About this assistant',
            onPressed: () => showChatbotAboutSheet(context),
          ),
          IconButton(
            icon: const Icon(Icons.auto_awesome_rounded),
            tooltip: 'Progress audit',
            onPressed: () {
              final delta = MockData.volumeTrend.last - MockData.volumeTrend.first;
              setState(() {
                _messages.add(const ChatMessage(
                    'Give me a summary of my progress.', true));
                _messages.add(ChatMessage(
                  MockData.buildProgressAuditReply(),
                  false,
                  attachment: ProgressChartAttachment(
                    'Training volume trend',
                    'kg',
                    MockData.volumeTrend,
                    '${delta >= 0 ? '+' : ''}$delta kg',
                  ),
                ));
              });
              _jump();
            },
          ),
          IconButton(
            icon: const Icon(Icons.bookmark_border_rounded),
            tooltip: 'Saved advice',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SavedAdviceScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'Clear chat',
            onPressed: () async {
              final ok = await confirmSheet(context,
                  title: 'Clear this conversation?',
                  message:
                      'Messages disappear from this screen. Anything you bookmarked stays saved.',
                  confirmLabel: 'Clear',
                  destructive: true);
              if (ok) setState(() => _messages.clear());
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.chat_bubble_outline_rounded,
                              size: 40, color: AppColors.hairline),
                          const SizedBox(height: 14),
                          Text('Ask about form, programming, or nutrition.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium),
                          const SizedBox(height: 20),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: [
                              ..._demoPrompts.map((q) => ActionChip(
                                    label: Text(q),
                                    avatar: const Icon(Icons.auto_awesome_rounded, size: 15, color: AppColors.accent),
                                    backgroundColor: AppColors.accentTint,
                                    side: BorderSide.none,
                                    labelStyle: const TextStyle(
                                        color: AppColors.accentDark, fontWeight: FontWeight.w600, fontSize: 12.5),
                                    onPressed: () => _sendMessage(q, _buildReply(q)),
                                  )),
                              ...MockData.faqPrompts.map((p) => ActionChip(
                                    label: Text(p.question),
                                    backgroundColor: AppColors.primaryTint,
                                    side: BorderSide.none,
                                    labelStyle: const TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12.5),
                                    onPressed: () => _sendPrompt(p),
                                  )),
                            ],
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    itemCount: _messages.length + (_thinking ? 1 : 0),
                    itemBuilder: (ctx, i) {
                      if (i == _messages.length) {
                        return const _Bubble(
                            text: 'Thinking...', fromUser: false);
                      }
                      final m = _messages[i];
                      final isBookmarked =
                          !m.fromUser && MockData.savedAdvice.contains(m.text);
                      return _Bubble(
                        text: m.text,
                        fromUser: m.fromUser,
                        attachment: m.attachment,
                        isBookmarked: isBookmarked,
                        onToggleBookmark:
                            m.fromUser ? null : () => _toggleBookmark(m.text),
                      );
                    },
                  ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(
                12, 10, 12, 10 + MediaQuery.of(context).padding.bottom),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.hairline)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: const InputDecoration(
                      hintText: 'Ask a question',
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 16, vertical: 13),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _send,
                  icon: const Icon(Icons.arrow_upward_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final String text;
  final bool fromUser;
  final ChatAttachment? attachment;
  final bool isBookmarked;
  final VoidCallback? onToggleBookmark;
  const _Bubble({
    required this.text,
    required this.fromUser,
    this.attachment,
    this.isBookmarked = false,
    this.onToggleBookmark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment:
            fromUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.80),
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
            decoration: BoxDecoration(
              color: fromUser ? AppColors.primary : AppColors.surface,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(fromUser ? 16 : 4),
                bottomRight: Radius.circular(fromUser ? 4 : 16),
              ),
              border: fromUser
                  ? null
                  : Border.all(color: AppColors.hairline),
            ),
            child: Text(text,
                style: TextStyle(
                    fontSize: 14.5,
                    height: 1.45,
                    color: fromUser ? Colors.white : AppColors.ink)),
          ),
          if (attachment != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: switch (attachment!) {
                EquipmentAttachment(:final equipment) => _EquipmentCard(equipment: equipment),
                ProgressChartAttachment(:final title, :final unit, :final values, :final delta) =>
                  _ChartCard(title: title, unit: unit, values: values, delta: delta),
              },
            ),
          if (onToggleBookmark != null)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4),
              child: Row(
                children: [
                  _tinyAction(
                    isBookmarked
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    isBookmarked ? 'Saved' : 'Save',
                    onToggleBookmark!,
                  ),
                  const SizedBox(width: 12),
                  _tinyAction(Icons.thumb_up_outlined, 'Helpful',
                      () => showToast(context, 'Thanks for the feedback.')),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _tinyAction(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          children: [
            Icon(icon, size: 14, color: AppColors.inkSoft),
            const SizedBox(width: 4),
            Text(label,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.inkSoft)),
          ],
        ),
      ),
    );
  }
}

/// Equipment attachment — a photo card with the essentials, tapping
/// through to the full setup and safety guide instead of dumping that
/// much detail into a chat bubble.
class _EquipmentCard extends StatelessWidget {
  final GymEquipment equipment;
  const _EquipmentCard({required this.equipment});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 250,
      child: Panel(
        padding: EdgeInsets.zero,
        onTap: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => EquipmentDetailScreen(equipment: equipment))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: AspectRatio(aspectRatio: 16 / 9, child: _networkHero(equipment.imageUrl)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(equipment.name, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(equipment.muscleGroup,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12)),
                  if (equipment.howToUse.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.check_circle_outline_rounded, size: 15, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(equipment.howToUse.first,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12.5, height: 1.35)),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  const Row(
                    children: [
                      Text('View full guide',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward_rounded, size: 13, color: AppColors.primary),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Trend-chart attachment — a small Syncfusion spline instead of reading
/// a paragraph of "your form score went from X to Y."
class _ChartCard extends StatelessWidget {
  final String title;
  final String unit;
  final List<int> values;
  final String delta;
  const _ChartCard({required this.title, required this.unit, required this.values, required this.delta});

  @override
  Widget build(BuildContext context) {
    final points = List.generate(values.length, (i) => _Point('S${i + 1}', values[i]));
    final positive = !delta.trim().startsWith('-');
    return SizedBox(
      width: 260,
      child: Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 13.5)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: positive ? AppColors.successTint : AppColors.dangerTint,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(delta,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: positive ? AppColors.success : AppColors.danger)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 110,
              child: SfCartesianChart(
                plotAreaBorderWidth: 0,
                primaryXAxis: const CategoryAxis(
                  majorGridLines: MajorGridLines(width: 0),
                  axisLine: AxisLine(width: 0),
                  labelStyle: TextStyle(fontSize: 9, color: AppColors.inkSoft),
                ),
                primaryYAxis: const NumericAxis(
                  majorGridLines: MajorGridLines(width: 0.6, color: AppColors.hairline),
                  axisLine: AxisLine(width: 0),
                  labelStyle: TextStyle(fontSize: 9, color: AppColors.inkSoft),
                ),
                tooltipBehavior: TooltipBehavior(enable: true, header: '', format: 'point.x  ·  point.y $unit'),
                series: <CartesianSeries<_Point, String>>[
                  SplineSeries<_Point, String>(
                    dataSource: points,
                    xValueMapper: (d, _) => d.label,
                    yValueMapper: (d, _) => d.value,
                    color: AppColors.primary,
                    width: 2.2,
                    markerSettings: const MarkerSettings(isVisible: true, height: 5, width: 5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Point {
  final String label;
  final int value;
  const _Point(this.label, this.value);
}
