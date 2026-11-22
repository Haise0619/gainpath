part of 'canonical_admin_recommendation_panel.dart';

String _readableRecommendationValue(String value) {
  if (!RegExp(r'^[a-z][a-zA-Z0-9_]*$').hasMatch(value)) return value;
  final separated = value
      .replaceAllMapped(
          RegExp(r'([a-z0-9])([A-Z])'), (match) => '${match[1]} ${match[2]}')
      .replaceAll('_', ' ')
      .toLowerCase();
  return '${separated[0].toUpperCase()}${separated.substring(1)}';
}

String _recommendationSourceKey(CanonicalAdminRecommendation record) =>
    record.evidenceFingerprint == 'Withheld' ? 'withheld' : record.source;

String _recommendationSource(CanonicalAdminRecommendation record) =>
    switch (_recommendationSourceKey(record)) {
      'withheld' => 'Withheld',
      'admin_outreach' => 'Admin Outreach',
      _ => 'Automatic',
    };

String _recommendationMember(CanonicalAdminRecommendation record) =>
    record.memberLabel ?? 'Member name unavailable';

Widget _recommendationBadge(String label, Color color, {IconData? icon}) =>
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 4)
          ],
          Flexible(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: color, fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

class _RecommendationDetailsDrawer extends StatelessWidget {
  const _RecommendationDetailsDrawer({
    required this.record,
    required this.status,
    required this.issue,
    this.onDeliveryIssues,
  });

  final CanonicalAdminRecommendation record;
  final String status;
  final bool issue;
  final VoidCallback? onDeliveryIssues;

  @override
  Widget build(BuildContext context) {
    final viewport = MediaQuery.sizeOf(context);
    final width = viewport.width < 620 ? viewport.width : 568.0;
    final ai = record.ai;
    final outlook = record.source == 'admin_outreach';
    final contextLabel = ai?.workoutContext ?? record.evidenceSummary;
    return Dialog(
      alignment: Alignment.centerRight,
      insetPadding: EdgeInsets.zero,
      shape: const RoundedRectangleBorder(),
      clipBehavior: Clip.antiAlias,
      backgroundColor: Colors.white,
      child: SizedBox(
        key: const ValueKey('recommendation-details-drawer'),
        width: width,
        height: viewport.height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 13, 12, 13),
              child: Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text('Recommendation Details',
                          style: Theme.of(context).textTheme.titleLarge),
                    ),
                  ),
                  IconButton(
                    autofocus: true,
                    tooltip: 'Close details',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.hairline),
            Expanded(
              child: SelectionArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        _recommendationBadge(
                            record.typeLabel, AppColors.primaryDark),
                        _recommendationBadge(
                            record.aiMethodLabel, AppColors.ink),
                        _recommendationBadge(
                            status, _statusColor(issue, record)),
                      ]),
                      const SizedBox(height: 9),
                      Text('${malaysiaTime(record.createdAt)} MYT',
                          style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 20),
                      _section(
                          context,
                          'Recommended content',
                          Icons.bookmark_border_rounded,
                          [
                            Text(record.targetLabel,
                                style: Theme.of(context).textTheme.titleMedium),
                            if (record.title != record.targetLabel) ...[
                              const SizedBox(height: 4),
                              Text(record.title,
                                  style:
                                      Theme.of(context).textTheme.bodyMedium),
                            ],
                          ],
                          emphasized: true),
                      if (record.status == 'withdrawn')
                        _section(context, 'Availability',
                            Icons.lock_outline_rounded, [
                          Text(record.summary),
                        ])
                      else
                        _section(
                            context,
                            record.deliveredAt != null
                                ? 'Message sent to member'
                                : 'Saved member message',
                            Icons.chat_bubble_outline_rounded,
                            [
                              Text(record.summary),
                            ]),
                      if (record.status != 'withdrawn')
                        _section(context, 'Why this was recommended',
                            Icons.lightbulb_outline_rounded, [
                          if (ai?.factors.isNotEmpty == true) ...[
                            const Text('Selection factors'),
                            const SizedBox(height: 8),
                            Wrap(spacing: 7, runSpacing: 7, children: [
                              for (final factor in ai!.factors)
                                _recommendationBadge(
                                    _readableRecommendationValue(factor),
                                    AppColors.primaryDark),
                            ]),
                          ],
                          for (final explanation in record.explanations
                              .where((item) => item != record.summary))
                            Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(explanation)),
                          if (ai?.factors.isNotEmpty != true &&
                              !record.explanations
                                  .any((item) => item != record.summary))
                            const Text(
                                'The saved message contains the available recommendation explanation.'),
                        ]),
                      _section(context, 'Member and workout context',
                          Icons.person_outline_rounded, [
                        _field(
                            context, 'Member', _recommendationMember(record)),
                        _field(context, 'Exercise', record.exerciseLabel),
                        _field(context, 'Objective',
                            _readableRecommendationValue(record.objective)),
                        _field(
                            context,
                            'Workout context',
                            contextLabel ??
                                'Workout context was not recorded.'),
                        _field(
                            context,
                            'Fitness goals',
                            ai?.fitnessGoals.isNotEmpty == true
                                ? ai!.fitnessGoals
                                    .map(_readableRecommendationValue)
                                    .join(' · ')
                                : 'Fitness goals were not recorded.'),
                      ]),
                      _section(context, 'Delivery information',
                          Icons.outgoing_mail, [
                        _field(
                            context, 'Source', _recommendationSource(record)),
                        if (record.sentBy != null)
                          _field(context, 'Sent by', record.sentBy!),
                        _field(context, 'Delivery status', status),
                        _field(
                            context,
                            'Delivered',
                            record.deliveredAt == null
                                ? 'Delivery has not been confirmed'
                                : '${malaysiaTime(record.deliveredAt!)} MYT'),
                        if (issue && onDeliveryIssues != null)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: () {
                                Navigator.of(context).pop(true);
                                onDeliveryIssues!();
                              },
                              icon: const Icon(Icons.arrow_outward_rounded,
                                  size: 17),
                              label: const Text('Open Delivery Issues'),
                            ),
                          ),
                      ]),
                      _section(
                        context,
                        outlook
                            ? 'Recommendation selection'
                            : 'Ranking comparison',
                        Icons.rule_rounded,
                        [
                          _field(
                              context,
                              'Eligible candidates',
                              ai?.technical['candidateCount']?.toString() ??
                                  'Not recorded'),
                          if (outlook)
                            _field(
                                context, 'Selected content', record.targetLabel)
                          else ...[
                            _field(context, 'Rule-based first choice',
                                ai?.ruleFirstLabel ?? 'Not recorded'),
                            _field(
                                context,
                                'Gemini first choice',
                                ai?.geminiFirstLabel ??
                                    (ai?.method == 'rule_fallback'
                                        ? 'Rule-based result used'
                                        : 'Not recorded')),
                            _field(
                                context,
                                'Did Gemini change the first choice?',
                                switch (ai?.changedTopChoice) {
                                  true => 'Yes',
                                  false => 'No',
                                  null => ai?.method == 'rule_fallback'
                                      ? 'Rule-based result used'
                                      : 'Not recorded',
                                }),
                          ],
                        ],
                      ),
                      ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        expandedCrossAxisAlignment: CrossAxisAlignment.start,
                        title: const Text('Technical Details'),
                        children: [
                          Text(_technical(record)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Close')),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _technical(CanonicalAdminRecommendation record) {
    final ai = record.ai;
    const fields = {
      'candidateCount': 'Eligible candidates',
      'latencyMillis': 'AI generation duration (ms)',
      'inputTokens': 'Input tokens',
      'outputTokens': 'Output tokens',
      'changedOrder': 'Changed rule ranking',
      'fallbackReason': 'Fallback reason',
    };
    return [
      'Member account: ${record.memberId}',
      'Record: ${record.id}',
      'Revision: ${record.revision}',
      'Policy: ${record.policyVersion}',
      'Evidence: ${record.evidenceFingerprint}',
      'Expires: ${malaysiaTime(record.expiresAt)} MYT',
      if (record.status != 'withdrawn') 'Objective key: ${record.objective}',
      if (ai?.model != null) 'Model: ${ai!.model}',
      if (ai?.factors.isNotEmpty == true)
        'Factor values: ${ai!.factors.join(', ')}',
      if (ai?.fitnessGoals.isNotEmpty == true)
        'Goal values: ${ai!.fitnessGoals.join(', ')}',
      if (record.evidenceSummary != null && ai != null) record.evidenceSummary!,
      for (final entry in (ai?.technical ?? const <String, Object?>{}).entries)
        '${fields[entry.key] ?? entry.key}: ${entry.value}',
    ].join('\n');
  }

  Widget _section(BuildContext context, String label, IconData icon,
          List<Widget> children,
          {bool emphasized = false}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: emphasized ? AppColors.surfaceAlt : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.hairline),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(icon, size: 17, color: AppColors.primaryDark),
                const SizedBox(width: 8),
                Expanded(
                    child: Semantics(
                        header: true,
                        child: Text(label,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                    color: AppColors.ink,
                                    fontWeight: FontWeight.w700)))),
              ]),
              const SizedBox(height: 10),
              ...children,
            ]),
          ),
        ),
      );

  Widget _field(BuildContext context, String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.inkSoft)),
          Text(value),
        ]),
      );
}

Color _statusColor(bool issue, CanonicalAdminRecommendation record) => issue
    ? const Color(0xff865014)
    : record.status == 'delivered'
        ? const Color(0xff21734c)
        : AppColors.inkSoft;

class _RecommendationDetailsAction extends StatefulWidget {
  const _RecommendationDetailsAction(
      {required super.key, required this.target, required this.onReview});
  final String target;
  final Future<bool> Function()? onReview;

  @override
  State<_RecommendationDetailsAction> createState() =>
      _RecommendationDetailsActionState();
}

class _RecommendationDetailsActionState
    extends State<_RecommendationDetailsAction> {
  final _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    final restore = await widget.onReview?.call() ?? false;
    if (!restore || !mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.onReview != null) {
        _focus.requestFocus();
      }
    });
  }

  @override
  Widget build(BuildContext context) => Tooltip(
      message: 'View details for ${widget.target}',
      child: TextButton(
        focusNode: _focus,
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 4),
        ),
        onPressed: widget.onReview == null ? null : _open,
        child: const Text('View Details', maxLines: 1),
      ));
}
