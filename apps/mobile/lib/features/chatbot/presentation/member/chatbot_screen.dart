import 'assistant_reply_view.dart';
import 'assistant_reply_view_model.dart';
import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../app/routing/branch_directions.dart';
import 'package:flutter/services.dart';
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
    errorBuilder: (context, error, stack) => const DecoratedBox(
        decoration: BoxDecoration(gradient: AppColors.heroGradient)),
  );
}

String _adviceText(String text, ChatAttachment? attachment) {
  if (attachment is CoachAvailabilityAttachment) {
    final value = [
      text,
      '${attachment.localDate} (${attachment.timeZone})',
      ...attachment.items.map((slot) =>
          '${slot.name} · ${slot.branchName} · ${slot.startLabel} – ${slot.endLabel} · RM ${(slot.amountMinor / 100).toStringAsFixed(2)} · 60 min'),
      if (attachment.truncated) 'More times may exist.'
    ].join('\n');
    return value.length > 6000 ? value.substring(0, 6000) : value;
  }
  if (attachment is CoachDirectoryAttachment) {
    final value = [
      text,
      ...attachment.coaches.map((coach) =>
          '${coach.name} · ${coach.branchName} · RM ${(coach.amountMinor / 100).toStringAsFixed(2)} · ${coach.durationMinutes} minutes')
    ].join('\n');
    return value.length > 6000 ? value.substring(0, 6000) : value;
  }
  if (attachment is! FitnessFactsAttachment) return text;
  final value = [
    text,
    attachment.title,
    attachment.subtitle,
    ...attachment.facts.map((fact) => '${fact.label}: ${fact.value}')
  ].join('\n');
  return value.length > 6000 ? value.substring(0, 6000) : value;
}

/// AD-M6.1 — Consult AI Fitness Coach. Provides a [ChatBloc] scoped to this
/// screen; the view below renders [ChatState] and dispatches events.
class ChatbotScreen extends StatelessWidget {
  const ChatbotScreen(
      {super.key,
      this.connected = false,
      this.openSavedAdvice = false,
      this.onOpenFact,
      this.onReviewBooking});
  final ValueChanged<FitnessFactAction>? onOpenFact;
  final ValueChanged<BookingSuggestionAttachment>? onReviewBooking;
  final bool connected;
  final bool openSavedAdvice;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ChatBloc(
        chat: context.read<ChatRepository>(),
        equipment: connected ? null : context.read<EquipmentRepository>(),
        analytics: connected ? null : context.read<AnalyticsRepository>(),
      ),
      child: _ChatbotView(
          onOpenFact: onOpenFact,
          openSavedAdvice: openSavedAdvice,
          onReviewBooking: onReviewBooking),
    );
  }
}

class _ChatbotView extends StatefulWidget {
  const _ChatbotView(
      {this.openSavedAdvice = false, this.onReviewBooking, this.onOpenFact});
  final ValueChanged<FitnessFactAction>? onOpenFact;
  final ValueChanged<BookingSuggestionAttachment>? onReviewBooking;
  final bool openSavedAdvice;

  @override
  State<_ChatbotView> createState() => _ChatbotViewState();
}

class _ChatbotViewState extends State<_ChatbotView> {
  static const _demoPrompts = [
    'Which equipment works my chest?',
    'How was my last workout?',
    'Show me tutorials for my exercises.',
    'What benefits does Premium offer?',
    'Why was this coach recommended to me?',
  ];

  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final _latestReply = GlobalKey();
  bool _disclaimerShown = false;
  bool _savedAdviceOpened = false;
  int _lastMessageCount = 0;

  void _openSavedAdvice() {
    if (!mounted || !widget.openSavedAdvice || _savedAdviceOpened) return;
    final bloc = context.read<ChatBloc>();
    if (!bloc.state.acknowledged || bloc.state.isLoading || _disclaimerShown) {
      return;
    }
    _savedAdviceOpened = true;
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => BlocProvider.value(
                value: bloc, child: const SavedAdviceScreen())));
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _showFirstOpenDisclaimer());
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _showFirstOpenDisclaimer() async {
    final chat = context.read<ChatBloc>().state;
    if (_disclaimerShown ||
        chat.isLoading ||
        !chat.acknowledged && chat.notice == null) {
      return;
    }
    if (chat.notice != null && chat.acknowledged) {
      _openSavedAdvice();
      return;
    }
    _disclaimerShown = true;
    await showChatbotAboutSheet(context,
        dismissible: false, notice: chat.notice);
    if (mounted && chat.notice != null) {
      context.read<ChatBloc>().add(const DisclaimerAcknowledged());
    }
    _disclaimerShown = false;
    _openSavedAdvice();
  }

  void _send() {
    if (!context.read<ChatBloc>().state.canSend) return;
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    if (text.length > 2000) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Your question is too long. Shorten it before sending.')));
      return;
    }
    _controller.clear();
    context.read<ChatBloc>().add(MessageSent(text));
  }

  void _jump({required bool showReplyStart}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final duration = MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 250);
      final replyContext = showReplyStart ? _latestReply.currentContext : null;
      if (replyContext != null &&
          (replyContext.size?.height ?? 0) >
              _scroll.position.viewportDimension * .75) {
        Scrollable.ensureVisible(replyContext,
            duration: duration, curve: Curves.easeOut);
      } else if (duration == Duration.zero) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      } else {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: duration, curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ChatBloc, ChatState>(
      listener: (_, chat) {
        if (chat.messages.length != _lastMessageCount) {
          if (!_scroll.hasClients ||
              _scroll.position.extentAfter < 160 ||
              chat.isReplying) {
            _jump(
                showReplyStart: chat.messages.length == _lastMessageCount + 1 &&
                    chat.messages.isNotEmpty &&
                    !chat.messages.last.fromUser);
          }
          _lastMessageCount = chat.messages.length;
        }
        _openSavedAdvice();
        if (chat.notice != null &&
            !chat.acknowledged &&
            !chat.isLoading &&
            chat.error == null) {
          _showFirstOpenDisclaimer();
        }
      },
      builder: _buildChat,
    );
  }

  Widget _buildChat(BuildContext context, ChatState chat) {
    final bloc = context.read<ChatBloc>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('GainPath Assistant',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
              icon: const Icon(Icons.bookmark_border_rounded),
              tooltip: 'Saved advice',
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => BlocProvider.value(
                          value: bloc, child: const SavedAdviceScreen())))),
          PopupMenuButton<String>(
              tooltip: 'Assistant options',
              onSelected: (value) async {
                if (value == 'about') {
                  showChatbotAboutSheet(context, notice: chat.notice);
                }
                if (value == 'progress' && chat.canSend) {
                  bloc.add(const ProgressAuditRequested());
                }
                if (value == 'clear') {
                  final ok = await confirmSheet(context,
                      title: 'Clear this conversation?',
                      message:
                          'Messages disappear from this screen. Anything you bookmarked stays saved.',
                      confirmLabel: 'Clear',
                      destructive: true);
                  if (ok) bloc.add(const HistoryCleared());
                }
              },
              itemBuilder: (_) => const [
                    PopupMenuItem(
                        value: 'about', child: Text('About this assistant')),
                    PopupMenuItem(
                        value: 'progress', child: Text('My progress')),
                    PopupMenuItem(value: 'clear', child: Text('Clear chat'))
                  ]),
        ],
      ),
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          if (chat.isLoading) const LinearProgressIndicator(),
          if (chat.error != null)
            Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: AssistantReplyView(
                    reply: AssistantReplyViewModel.error(chat.error!,
                        retryLabel: 'Retry'),
                    onRetry: () => bloc.add(const ChatRetried()),
                    onEdit: chat.failedText == null
                        ? null
                        : () {
                            _controller.text = chat.failedText!;
                            _controller.selection = TextSelection.collapsed(
                                offset: _controller.text.length);
                          })),
          if (!chat.acknowledged && !chat.isLoading && chat.notice != null)
            TextButton(
                onPressed: () => _showFirstOpenDisclaimer(),
                child: const Text('Review and accept the notice')),
          Expanded(
            child: chat.messages.isEmpty
                ? SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                              width: 104,
                              height: 104,
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                  color: AppColors.primaryTint,
                                  shape: BoxShape.circle),
                              child: ClipOval(
                                  child: Image.asset(
                                      'assets/images/ai_coach_mascot.png',
                                      excludeFromSemantics: true))),
                          const SizedBox(height: 20),
                          Text('A stronger you starts here.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  inherit: false,
                                  fontFamily: 'BarlowCondensed',
                                  fontSize: 28,
                                  height: 1.2,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.ink)),
                          const SizedBox(height: 14),
                          Text(
                              'Explore your workouts, find your next tutorial, or ask a fitness question.',
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
                                    avatar: const Icon(
                                        Icons.auto_awesome_rounded,
                                        size: 15,
                                        color: AppColors.primary),
                                    backgroundColor: AppColors.primaryTint,
                                    side: BorderSide.none,
                                    labelStyle: const TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12.5),
                                    onPressed: chat.canSend
                                        ? () => bloc.add(MessageSent(q))
                                        : null,
                                  )),
                              ...context
                                  .read<ChatRepository>()
                                  .faqPrompts
                                  .map((p) => ActionChip(
                                        label: Text(p.question),
                                        backgroundColor: AppColors.primaryTint,
                                        side: BorderSide.none,
                                        labelStyle: const TextStyle(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12.5),
                                        onPressed: chat.canSend
                                            ? () => bloc.add(PromptSent(p))
                                            : null,
                                      )),
                            ],
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    itemCount: chat.messages.length + (chat.isReplying ? 1 : 0),
                    itemBuilder: (ctx, i) {
                      if (i == chat.messages.length) {
                        return _Thinking(
                            onStop: () => bloc.add(const ReplyCancelled()));
                      }
                      final m = chat.messages[i];
                      return _Bubble(
                        key: !m.fromUser && i == chat.messages.length - 1
                            ? _latestReply
                            : null,
                        onRetry: m.fromUser || i == 0
                            ? null
                            : () {
                                for (var previous = i - 1;
                                    previous >= 0;
                                    previous--) {
                                  final question = chat.messages[previous];
                                  if (question.fromUser) {
                                    bloc.add(MessageSent(question.text));
                                    return;
                                  }
                                }
                              },
                        onOpenFact: widget.onOpenFact,
                        sources: m.sources,
                        onReviewBooking: widget.onReviewBooking,
                        text: m.text,
                        fromUser: m.fromUser,
                        attachment: m.attachment,
                        isBookmarked: chat.savedAdvice
                            .contains(_adviceText(m.text, m.attachment)),
                        helpful: chat.ratings[m.id ?? m.text],
                        onRate: m.fromUser
                            ? null
                            : (helpful) => bloc.add(AdviceRated(m, helpful)),
                        onToggleBookmark: m.fromUser
                            ? null
                            : () => bloc.add(AdviceBookmarkToggled(
                                _adviceText(m.text, m.attachment))),
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
                    enabled: chat.acknowledged && !chat.isLoading,
                    minLines: 1,
                    maxLines:
                        MediaQuery.textScalerOf(context).scale(16) > 24 ? 3 : 5,
                    maxLength: 2000,
                    textCapitalization: TextCapitalization.sentences,
                    controller: _controller,
                    textInputAction: TextInputAction.newline,
                    onSubmitted: (_) => _send(),
                    decoration: const InputDecoration(
                      hintText: 'Ask GainPath…',
                      labelText: 'Your question',
                      counterText: '',
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: 'Send message',
                  onPressed: chat.canSend ? _send : null,
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
  const _Bubble(
      {super.key,
      this.onOpenFact,
      this.onRetry,
      this.sources = const [],
      this.onReviewBooking,
      required this.text,
      required this.fromUser,
      this.attachment,
      this.isBookmarked = false,
      this.onToggleBookmark,
      this.helpful,
      this.onRate});
  final ValueChanged<FitnessFactAction>? onOpenFact;
  final ValueChanged<BookingSuggestionAttachment>? onReviewBooking;
  final List<String> sources;
  final String text;
  final bool fromUser, isBookmarked;
  final VoidCallback? onRetry;
  final ChatAttachment? attachment;
  final VoidCallback? onToggleBookmark;
  final bool? helpful;
  final ValueChanged<bool>? onRate;
  @override
  Widget build(BuildContext context) {
    final compactActions = MediaQuery.textScalerOf(context).scale(16) > 24;
    final reply = fromUser
        ? null
        : AssistantReplyViewModel.fromMessage(
            ChatMessage(text, false, attachment: attachment, sources: sources));
    return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
            crossAxisAlignment:
                fromUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (fromUser)
                Container(
                    constraints: BoxConstraints(
                        maxWidth: MediaQuery.sizeOf(context).width * .80),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: const BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(18),
                            topRight: Radius.circular(18),
                            bottomLeft: Radius.circular(18),
                            bottomRight: Radius.circular(5))),
                    child: SelectableText(text,
                        style: const TextStyle(
                            fontSize: 16, height: 1.5, color: Colors.white)))
              else
                AssistantReplyView(
                    reply: reply!,
                    onRetry: onRetry,
                    onOpenFact: onOpenFact,
                    onReviewBooking: onReviewBooking),
              if (attachment case EquipmentAttachment(:final equipment))
                Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: _EquipmentCard(equipment: equipment)),
              if (attachment case BranchChatAttachment gym)
                Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: _BranchChatCard(gym: gym)),
              if (attachment
                  case ProgressChartAttachment(
                    :final title,
                    :final unit,
                    :final values,
                    :final delta
                  ))
                Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: _ChartCard(
                        title: title,
                        unit: unit,
                        values: values,
                        delta: delta)),
              if (onToggleBookmark != null)
                Padding(
                    padding: EdgeInsets.only(
                      left:
                          reply?.kind == AssistantReplyKind.normalText ? 36 : 0,
                    ),
                    child: Wrap(spacing: 2, children: [
                      _action(
                          Icons.copy_rounded,
                          'Copy',
                          compactActions,
                          () => Clipboard.setData(ClipboardData(
                              text: _adviceText(text, attachment)))),
                      _action(
                          isBookmarked
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                          isBookmarked ? 'Saved' : 'Save',
                          compactActions,
                          onToggleBookmark!,
                          selected: isBookmarked),
                      _action(
                          helpful == true
                              ? Icons.thumb_up_rounded
                              : Icons.thumb_up_outlined,
                          'Helpful',
                          compactActions,
                          () => onRate?.call(true),
                          selected: helpful == true),
                      _action(
                          helpful == false
                              ? Icons.thumb_down_rounded
                              : Icons.thumb_down_outlined,
                          'Not helpful',
                          compactActions,
                          () => onRate?.call(false),
                          selected: helpful == false),
                    ])),
            ]));
  }

  Widget _action(IconData icon, String label, bool compact, VoidCallback onTap,
      {bool? selected}) {
    final content = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon,
                    size: compact ? 20 : 15,
                    color: selected == true
                        ? AppColors.primary
                        : AppColors.inkSoft),
                if (!compact) ...[
                  const SizedBox(width: 5),
                  Text(label,
                      style: const TextStyle(
                          fontSize: 11.5, color: AppColors.inkSoft)),
                ],
              ]),
        ),
      ),
    );
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: compact
          ? Tooltip(message: label, excludeFromSemantics: true, child: content)
          : content,
    );
  }
}

class _BranchChatCard extends StatelessWidget {
  const _BranchChatCard({required this.gym});
  final BranchChatAttachment gym;

  @override
  Widget build(BuildContext context) {
    final branch = gym.branch;
    final cover = branch['coverUrl'];
    final address = branch['address'];
    final hours = branch['openingHours'];
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (cover is String && cover.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(height: 126, width: double.infinity, child: _networkHero(cover)),
            ),
          Text(branch['displayName'] as String, style: Theme.of(context).textTheme.titleMedium),
          if (address is String && address.isNotEmpty) Text(address),
          Text(branchOpeningStatus(hours is List ? hours : const [])),
          Wrap(
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => BranchDirectoryPage(
                    initialDetails: branch,
                    request: (input) async {
                      final result = await FirebaseFunctions.instanceFor(region: 'asia-southeast1')
                          .httpsCallable('branchManagementCommand')
                          .call({'organizationId': gym.organizationId, ...input});
                      return Map<String, dynamic>.from(result.data as Map);
                    },
                    openDirections: (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
                  ),
                )),
                child: const Text('View branch'),
              ),
              if (branchDestination(branch) != null)
                TextButton.icon(
                  onPressed: () => openBranchDirections(context, branch),
                  icon: const Icon(Icons.directions_outlined),
                  label: const Text('Get directions'),
                ),
            ],
          ),
        ],
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
        onTap: () => Navigator.pushNamed(context, FeatureNavigation.equipment,
            arguments: equipment),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: Container(
                color: const Color(0xFFF3F4F8),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Padding(
                    padding: const EdgeInsets.all(6.0),
                    child:
                        _networkHero(equipment.imageUrl, fit: BoxFit.contain),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(equipment.name,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(equipment.muscleGroup,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(fontSize: 12)),
                  if (equipment.howToUse.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.check_circle_outline_rounded,
                            size: 15, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(equipment.howToUse.first,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 12.5, height: 1.35)),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  const Row(
                    children: [
                      Flexible(
                          child: Text('View full guide',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF7B390B)))),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward_rounded,
                          size: 13, color: AppColors.primary),
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
  const _ChartCard(
      {required this.title,
      required this.unit,
      required this.values,
      required this.delta});

  @override
  Widget build(BuildContext context) {
    final points =
        List.generate(values.length, (i) => _Point('S${i + 1}', values[i]));
    final positive = !delta.trim().startsWith('-');
    return SizedBox(
      width: 260,
      child: Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(title,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontSize: 13.5)),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color:
                        positive ? AppColors.successTint : AppColors.dangerTint,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(delta,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color:
                              positive ? AppColors.success : AppColors.danger)),
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
                  majorGridLines:
                      MajorGridLines(width: 0.6, color: AppColors.hairline),
                  axisLine: AxisLine(width: 0),
                  labelStyle: TextStyle(fontSize: 9, color: AppColors.inkSoft),
                ),
                tooltipBehavior: TooltipBehavior(
                    enable: true,
                    header: '',
                    format: 'point.x  ·  point.y $unit'),
                series: <CartesianSeries<_Point, String>>[
                  SplineSeries<_Point, String>(
                    dataSource: points,
                    xValueMapper: (d, _) => d.label,
                    yValueMapper: (d, _) => d.value,
                    color: AppColors.primary,
                    width: 2.2,
                    markerSettings: const MarkerSettings(
                        isVisible: true, height: 5, width: 5),
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

class _Thinking extends StatelessWidget {
  const _Thinking({required this.onStop});
  final VoidCallback onStop;
  @override
  Widget build(BuildContext context) => Semantics(
      liveRegion: true,
      label: 'Preparing a reply',
      child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(children: [
            const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 12),
            const Expanded(
                child: Text('Preparing your reply…',
                    style: TextStyle(color: AppColors.inkSoft))),
            TextButton(onPressed: onStop, child: const Text('Stop waiting')),
          ])));
}
