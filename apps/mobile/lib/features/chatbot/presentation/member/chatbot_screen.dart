import 'package:flutter/material.dart';
import '../../application/chat_bloc.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../../../navigation/feature_navigation.dart';
import 'saved_advice_screen.dart';
import 'widgets/chatbot_about_sheet.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/analytics.dart';
import 'package:gainpath_domain/chatbot.dart';
import 'package:gainpath_domain/workout.dart';

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

/// AD-M6.1 — Consult AI Fitness Coach. Provides a [ChatBloc] scoped to this
/// screen; the view below renders [ChatState] and dispatches events.
class ChatbotScreen extends StatelessWidget {
  const ChatbotScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ChatBloc(
        chat: context.read<ChatRepository>(),
        equipment: context.read<EquipmentRepository>(),
        analytics: context.read<AnalyticsRepository>(),
      ),
      child: const _ChatbotView(),
    );
  }
}

class _ChatbotView extends StatefulWidget {
  const _ChatbotView();

  @override
  State<_ChatbotView> createState() => _ChatbotViewState();
}

class _ChatbotViewState extends State<_ChatbotView> {
  static const _demoPrompts = [
    'Which equipment works my chest?',
    'How is my workout progress trending?',
  ];

  final _controller = TextEditingController();
  final _scroll = ScrollController();
  bool _disclaimerShown = false;

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

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    context.read<ChatBloc>().add(MessageSent(text));
  }

  void _jump() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ChatBloc, ChatState>(
      listenWhen: (a, b) => a.messages.length != b.messages.length || a.isReplying != b.isReplying,
      listener: (_, __) => _jump(),
      builder: (context, chat) {
        final bloc = context.read<ChatBloc>();
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
                onPressed: () => bloc.add(const ProgressAuditRequested()),
              ),
              IconButton(
                icon: const Icon(Icons.bookmark_border_rounded),
                tooltip: 'Saved advice',
                onPressed: () =>
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const SavedAdviceScreen())),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded),
                tooltip: 'Clear chat',
                onPressed: () async {
                  final ok = await confirmSheet(context,
                      title: 'Clear this conversation?',
                      message: 'Messages disappear from this screen. Anything you bookmarked stays saved.',
                      confirmLabel: 'Clear',
                      destructive: true);
                  if (ok) bloc.add(const HistoryCleared());
                },
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: chat.messages.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.chat_bubble_outline_rounded, size: 40, color: AppColors.hairline),
                              const SizedBox(height: 14),
                              Text('Ask about form, programming, or nutrition.',
                                  textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
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
                                        onPressed: () => bloc.add(MessageSent(q)),
                                      )),
                                  ...context.read<ChatRepository>().faqPrompts.map((p) => ActionChip(
                                        label: Text(p.question),
                                        backgroundColor: AppColors.primaryTint,
                                        side: BorderSide.none,
                                        labelStyle: const TextStyle(
                                            color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 12.5),
                                        onPressed: () => bloc.add(PromptSent(p)),
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
                        itemCount: chat.messages.length + (chat.isReplying ? 1 : 0),
                        itemBuilder: (ctx, i) {
                          if (i == chat.messages.length) {
                            return const _Bubble(text: 'Thinking...', fromUser: false);
                          }
                          final m = chat.messages[i];
                          return _Bubble(
                            text: m.text,
                            fromUser: m.fromUser,
                            attachment: m.attachment,
                            isBookmarked: chat.isBookmarked(m),
                            onToggleBookmark: m.fromUser ? null : () => bloc.add(AdviceBookmarkToggled(m.text)),
                          );
                        },
                      ),
              ),
              Container(
                padding: EdgeInsets.fromLTRB(12, 10, 12, 10 + MediaQuery.of(context).padding.bottom),
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
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 13),
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
      },
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
        onTap: () => Navigator.pushNamed(context, FeatureNavigation.equipment, arguments: equipment),
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
