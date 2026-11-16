import 'package:flutter/material.dart';
import 'package:gainpath_domain/chatbot.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'assistant_reply_view_model.dart';

/// Presentation only: all facts and targets have already been authorized.
class AssistantReplyView extends StatelessWidget {
  const AssistantReplyView(
      {super.key,
      required this.reply,
      this.onOpenFact,
      this.onReviewBooking,
      this.onRetry,
      this.onEdit});
  final AssistantReplyViewModel reply;
  final ValueChanged<FitnessFactAction>? onOpenFact;
  final ValueChanged<BookingSuggestionAttachment>? onReviewBooking;
  final VoidCallback? onRetry, onEdit;

  @override
  Widget build(BuildContext context) => switch (reply.kind) {
        AssistantReplyKind.normalText => _NormalReply(reply: reply),
        AssistantReplyKind.membership =>
          _MembershipReply(reply: reply, onOpenFact: onOpenFact),
        AssistantReplyKind.workoutSummary =>
          _WorkoutReply(reply: reply, onOpenFact: onOpenFact),
        AssistantReplyKind.trainingInsight =>
          _InsightReply(reply: reply, onOpenFact: onOpenFact),
        AssistantReplyKind.coachAction => _CoachReply(
            reply: reply,
            onOpenFact: onOpenFact,
            onReviewBooking: onReviewBooking),
        AssistantReplyKind.recommendation =>
          _RecommendationReply(reply: reply, onOpenFact: onOpenFact),
        AssistantReplyKind.errorRetry => _IssueReply(
            reply: reply,
            onRetry: onRetry,
            onEdit: onEdit,
            onOpenFact: onOpenFact),
      };
}

class _NormalReply extends StatelessWidget {
  const _NormalReply({required this.reply});
  final AssistantReplyViewModel reply;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: SelectableText(reply.conclusion,
            style: const TextStyle(
                fontSize: 16, height: 1.6, color: AppColors.ink)),
      );
}

class _ReplyFrame extends StatelessWidget {
  const _ReplyFrame(
      {required this.reply,
      required this.icon,
      required this.category,
      required this.children,
      this.primary});
  final AssistantReplyViewModel reply;
  final IconData icon;
  final String category;
  final List<Widget> children;
  final Widget? primary;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            color: reply.kind == AssistantReplyKind.recommendation
                ? AppColors.primaryTint.withValues(alpha: .65)
                : AppColors.surface,
            gradient: reply.kind == AssistantReplyKind.membership
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.primaryTint, AppColors.surface],
                    stops: [0, .65])
                : null,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.hairline),
            boxShadow: [
              BoxShadow(
                  color: AppColors.primary.withValues(alpha: .035),
                  blurRadius: 14,
                  offset: const Offset(0, 4))
            ]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: reply.kind == AssistantReplyKind.trainingInsight
                        ? AppColors.primary
                        : AppColors.primaryTint,
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(icon,
                    color: reply.kind == AssistantReplyKind.trainingInsight
                        ? Colors.white
                        : AppColors.primary,
                    size: 19)),
            const SizedBox(width: 10),
            Expanded(
                child: Text(category,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary)))
          ]),
          const SizedBox(height: 14),
          Text(reply.title,
              style: const TextStyle(
                  fontSize: 20,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink)),
          if (reply.conclusion.isNotEmpty) ...[
            const SizedBox(height: 9),
            SelectableText(reply.conclusion,
                style: const TextStyle(
                    fontSize: 15.5, height: 1.5, color: AppColors.ink))
          ],
          ...children,
          if (primary != null) ...[
            const SizedBox(height: 18),
            SizedBox(width: double.infinity, child: primary)
          ],
          if (reply.sources.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(_sourceLabel(reply.sources, reply.kind),
                style: const TextStyle(
                    fontSize: 11.5, height: 1.4, color: AppColors.inkSoft))
          ],
          if (reply.details.isNotEmpty || reply.sources.isNotEmpty)
            _Details(reply: reply),
        ]),
      );
}

String _sourceLabel(List<String> sources, AssistantReplyKind kind) {
  final text = sources.join(' ').toLowerCase();
  if (text.contains('fixture')) {
    return 'Preview data · not a real Member account';
  }
  if (text.contains('fyp') || text.contains('fictional')) {
    return kind == AssistantReplyKind.workoutSummary ||
            kind == AssistantReplyKind.trainingInsight
        ? 'Recorded sample history · not physical camera evidence'
        : 'FYP sample account records';
  }
  if (text.contains('device') || text.contains('synced')) {
    return 'Saved workout records · estimates where available';
  }
  if (text.contains('membership')) {
    return 'From your GainPath membership details';
  }
  if (text.contains('published')) {
    return 'Current published GainPath content';
  }
  return 'From authorized GainPath records';
}

class _Stats extends StatelessWidget {
  const _Stats(this.stats);
  final List<AssistantReplyStat> stats;
  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final columns = constraints.maxWidth >= 260 &&
                MediaQuery.textScalerOf(context).scale(14) <= 21
            ? 2
            : 1;
        final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
        return Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: stats
                    .take(4)
                    .map((stat) => Container(
                        width: width,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: AppColors.bg,
                            borderRadius: BorderRadius.circular(13)),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(stat.label,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      height: 1.4,
                                      color: AppColors.inkSoft)),
                              const SizedBox(height: 6),
                              SelectableText(stat.value.replaceAll('→', ' to '),
                                  style: const TextStyle(
                                      fontSize: 17,
                                      height: 1.35,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.ink))
                            ])))
                    .toList()));
      });
}

Widget? _primary(
    AssistantReplyViewModel reply, ValueChanged<FitnessFactAction>? callback) {
  if (reply.actions.isEmpty) return null;
  final action = reply.actions.first;
  return FilledButton(
      onPressed: callback == null ? null : () => callback(action),
      child: Text(action.label, textAlign: TextAlign.center));
}

class _MembershipReply extends StatelessWidget {
  const _MembershipReply({required this.reply, this.onOpenFact});
  final AssistantReplyViewModel reply;
  final ValueChanged<FitnessFactAction>? onOpenFact;
  @override
  Widget build(BuildContext context) => _ReplyFrame(
          reply: reply,
          icon: Icons.workspace_premium_outlined,
          category: 'YOUR MEMBERSHIP',
          primary: _primary(reply, onOpenFact),
          children: [
            if (reply.stats.isNotEmpty) _Stats(reply.stats),
            if (reply.highlights.isNotEmpty) ...[
              const SizedBox(height: 18),
              Text(reply.benefitsLabel ?? 'Core benefits',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink)),
              const SizedBox(height: 8),
              ...reply.highlights.take(3).map((benefit) =>
                  _Highlight(benefit, icon: Icons.check_circle_outline_rounded))
            ],
            if (reply.moreBenefits.isNotEmpty)
              ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text('View all benefits',
                      style: TextStyle(fontSize: 13, color: AppColors.primary)),
                  children: reply.moreBenefits
                      .map((benefit) => _Highlight(benefit,
                          icon: Icons.check_circle_outline_rounded))
                      .toList()),
          ]);
}

class _WorkoutReply extends StatelessWidget {
  const _WorkoutReply({required this.reply, this.onOpenFact});
  final AssistantReplyViewModel reply;
  final ValueChanged<FitnessFactAction>? onOpenFact;
  @override
  Widget build(BuildContext context) => _ReplyFrame(
          reply: reply,
          icon: Icons.fitness_center_rounded,
          category: 'WORKOUT SUMMARY',
          primary: _primary(reply, onOpenFact),
          children: [
            if (reply.stats.isNotEmpty) _Stats(reply.stats),
            if (reply.highlights.isNotEmpty) ...[
              const SizedBox(height: 14),
              ...reply.highlights.take(2).map((line) => _Highlight(line))
            ],
          ]);
}

class _InsightReply extends StatelessWidget {
  const _InsightReply({required this.reply, this.onOpenFact});
  final AssistantReplyViewModel reply;
  final ValueChanged<FitnessFactAction>? onOpenFact;
  @override
  Widget build(BuildContext context) => _ReplyFrame(
          reply: reply,
          icon: Icons.insights_rounded,
          category: 'TRAINING INSIGHT',
          primary: _primary(reply, onOpenFact),
          children: [
            if (reply.stats.isNotEmpty) _Stats(reply.stats),
            if (reply.highlights.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Text('Estimated form · same measurement group',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.inkSoft, height: 1.4))
            ],
          ]);
}

class _CoachReply extends StatelessWidget {
  const _CoachReply(
      {required this.reply, this.onOpenFact, this.onReviewBooking});
  final AssistantReplyViewModel reply;
  final ValueChanged<FitnessFactAction>? onOpenFact;
  final ValueChanged<BookingSuggestionAttachment>? onReviewBooking;
  @override
  Widget build(BuildContext context) {
    final booking = reply.booking;
    Widget tile(AssistantCoachOption coach) =>
        _CoachOptionTile(coach: coach, onOpenFact: onOpenFact);
    return _ReplyFrame(
        reply: reply,
        icon: Icons.sports_rounded,
        category: 'COACHING',
        primary: booking == null
            ? null
            : FilledButton(
                onPressed: booking.expired || onReviewBooking == null
                    ? null
                    : () => onReviewBooking!(booking),
                child: Text(
                    booking.expired ? 'Suggestion expired' : 'Book session')),
        children: [
          if (reply.stats.isNotEmpty) _Stats(reply.stats),
          ...reply.coaches.take(3).map(tile),
          if (reply.coaches.length > 3)
            ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text('More coaches (${reply.coaches.length - 3})',
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.primary)),
                children: reply.coaches.skip(3).map(tile).toList()),
          if (booking != null) ...[
            const SizedBox(height: 12),
            ...reply.highlights.map((text) => _Highlight(text)),
            const Text(
                'Not reserved or paid. Review the current price and availability before continuing.',
                style: TextStyle(
                    fontSize: 12, height: 1.5, color: AppColors.inkSoft))
          ],
        ]);
  }
}

class _CoachOptionTile extends StatelessWidget {
  const _CoachOptionTile({required this.coach, this.onOpenFact});
  final AssistantCoachOption coach;
  final ValueChanged<FitnessFactAction>? onOpenFact;
  @override
  Widget build(BuildContext context) => Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: AppColors.bg, borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(coach.name,
            style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.ink)),
        const SizedBox(height: 5),
        Text(coach.branchName,
            style: const TextStyle(fontSize: 14, color: AppColors.inkSoft)),
        const SizedBox(height: 12),
        Wrap(spacing: 12, runSpacing: 8, children: [
          Text('RM ${(coach.amountMinor / 100).toStringAsFixed(2)}',
              style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary)),
          Text('${coach.durationMinutes} min',
              style: const TextStyle(color: AppColors.inkSoft))
        ]),
        const SizedBox(height: 12),
        SizedBox(
            width: double.infinity,
            child: FilledButton(
                onPressed: onOpenFact == null
                    ? null
                    : () => onOpenFact!(FitnessFactAction(
                        'Book session', FitnessFactTarget.coaches,
                        id: coach.coachId)),
                child: const Text('Book session'))),
      ]));
}

class _RecommendationReply extends StatelessWidget {
  const _RecommendationReply({required this.reply, this.onOpenFact});
  final AssistantReplyViewModel reply;
  final ValueChanged<FitnessFactAction>? onOpenFact;
  @override
  Widget build(BuildContext context) => _ReplyFrame(
          reply: reply,
          icon: Icons.auto_awesome_outlined,
          category: 'FOR YOUR TRAINING',
          primary: _primary(reply, onOpenFact),
          children: [
            if (reply.highlights.isNotEmpty) ...[
              const SizedBox(height: 16),
              _Highlight(reply.highlights.first,
                  icon: Icons.arrow_forward_rounded)
            ],
            if (reply.stats.isNotEmpty) _Stats(reply.stats),
            if (reply.actions.length > 1 || reply.highlights.length > 1)
              ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text('More options',
                      style: TextStyle(fontSize: 13, color: AppColors.primary)),
                  children: [
                    ...reply.highlights.skip(1).map((line) =>
                        _Highlight(line, icon: Icons.arrow_forward_rounded)),
                    ...reply.actions.skip(1).map((action) => Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                            onPressed: onOpenFact == null
                                ? null
                                : () => onOpenFact!(action),
                            child: Text(action.label))))
                  ]),
          ]);
}

class _Highlight extends StatelessWidget {
  const _Highlight(this.text, {this.icon = Icons.info_outline_rounded});
  final String text;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 17, color: AppColors.primary),
        const SizedBox(width: 9),
        Expanded(
            child: SelectableText(text,
                style: const TextStyle(
                    fontSize: 14, height: 1.5, color: AppColors.ink)))
      ]));
}

class _Details extends StatelessWidget {
  const _Details({required this.reply});
  final AssistantReplyViewModel reply;
  @override
  Widget build(BuildContext context) => Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
          key: ValueKey('reply-details-${reply.kind.name}'),
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(top: 4),
          title: Text(
              reply.kind == AssistantReplyKind.trainingInsight
                  ? 'How this was assessed'
                  : 'Details and source',
              style: const TextStyle(fontSize: 12, color: AppColors.inkSoft)),
          children: [
            if (reply.kind == AssistantReplyKind.trainingInsight)
              ...reply.highlights.map((line) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SelectableText(line,
                      style: const TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: AppColors.inkSoft)))),
            ...reply.details.map((fact) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Align(
                    alignment: Alignment.centerLeft,
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(fact.label,
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.inkSoft)),
                          const SizedBox(height: 3),
                          SelectableText(fact.value,
                              style: const TextStyle(
                                  fontSize: 13,
                                  height: 1.5,
                                  color: AppColors.inkSoft))
                        ])))),
            if (reply.sources.isNotEmpty)
              Align(
                  alignment: Alignment.centerLeft,
                  child: SelectableText(reply.sources.join('\n'),
                      style: const TextStyle(
                          fontSize: 12,
                          height: 1.5,
                          color: AppColors.inkSoft))),
          ]));
}

class _IssueReply extends StatelessWidget {
  const _IssueReply(
      {required this.reply, this.onRetry, this.onEdit, this.onOpenFact});
  final ValueChanged<FitnessFactAction>? onOpenFact;
  final AssistantReplyViewModel reply;
  final VoidCallback? onRetry, onEdit;
  @override
  Widget build(BuildContext context) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.hairline)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.cloud_off_rounded,
              color: AppColors.inkSoft, size: 20),
          const SizedBox(width: 9),
          Expanded(
              child: Text(reply.title,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink)))
        ]),
        const SizedBox(height: 8),
        SelectableText(reply.conclusion,
            style: const TextStyle(
                fontSize: 14, height: 1.5, color: AppColors.inkSoft)),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (reply.actions.isNotEmpty)
            TextButton(
                onPressed: onOpenFact == null
                    ? null
                    : () => onOpenFact!(reply.actions.first),
                child: Text(reply.actions.first.label)),
          if (onRetry != null)
            FilledButton(
                onPressed: onRetry,
                child: Text(reply.retryLabel ?? 'Try again')),
          if (onEdit != null)
            TextButton(onPressed: onEdit, child: const Text('Edit question'))
        ]),
      ]));
}
