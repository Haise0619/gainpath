import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../application/recommendation_consent_repository.dart';

/// Normal navigation passes no repository and cannot collect consent. Interactive
/// review requires an explicitly injected synthetic/emulator repository + notice.
class PersonalizedRecommendationSettingsScreen extends StatefulWidget {
  const PersonalizedRecommendationSettingsScreen(
      {super.key, required this.isCurrent, this.repository, this.notice});
  final bool Function() isCurrent;
  final RecommendationConsentRepository? repository;
  final RecommendationConsentNotice? notice;
  @override
  State<PersonalizedRecommendationSettingsScreen> createState() =>
      _SettingsState();
}

class _SettingsState extends State<PersonalizedRecommendationSettingsScreen> {
  RecommendationConsentState? _state;
  bool _loading = false, _saving = false;
  String? _error, _message;
  int _loadGeneration = 0, _intent = 0;
  bool get _current =>
      widget.isCurrent() && (widget.repository?.isCurrent ?? true);
  bool get _busy => _loading || _saving;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(
      covariant PersonalizedRecommendationSettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository) {
      _state = null;
      _saving = false;
      _message = null;
      _load();
    }
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    final repository = widget.repository;
    if (!_current || repository == null) {
      if (mounted) {
        setState(() {
          _state = null;
          _loading = false;
        });
      }
      return;
    }
    setState(() {
      _loading = true;
      _state = null;
      _error = null;
    });
    try {
      final loaded = await repository.load();
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _state = _current ? loaded : null;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _state = null;
        _loading = false;
        _error =
            'Could not load current consent. Reload before making a change.';
      });
    }
  }

  Future<void> _change(
      RecommendationConsentPurpose purpose, bool granted) async {
    final state = _state,
        repository = widget.repository,
        notice = widget.notice;
    if (!_current ||
        _busy ||
        state == null ||
        repository == null ||
        granted && notice == null) {
      return;
    }
    // Reserve the screen for one intent, including the confirmation dialog.
    setState(() => _saving = true);
    var acknowledged = false;
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
                  title: Text(
                      '${granted ? 'Allow' : 'Revoke'} ${_title(purpose)}?'),
                  scrollable: true,
                  content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 12),
                        Text(granted
                            ? _explanation(purpose)
                            : 'Stop future use for this purpose. Revoking does not promise deletion of existing records; retention and deletion rules still require review.'),
                        if (granted) ...[
                          const SizedBox(height: 12),
                          Text(notice!.fictional
                              ? 'Use the assessment history available for your account to suggest relevant guidance.'
                              : notice.historyDescription),
                          const SizedBox(height: 8),
                          Text(
                              'Notice ${notice.noticeVersion} · Content ${notice.contentVersion}'),
                          CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text(
                                  'I have read this purpose, notice version and history scope.'),
                              value: acknowledged,
                              onChanged: (value) => setDialogState(
                                  () => acknowledged = value == true)),
                        ],
                      ]),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        child: const Text('Cancel')),
                    FilledButton(
                        onPressed: granted && !acknowledged
                            ? null
                            : () => Navigator.pop(dialogContext, true),
                        child:
                            Text(granted ? 'Confirm grant' : 'Confirm revoke')),
                  ],
                )));
    if (!mounted) return;
    if (!_current || confirmed != true || repository != widget.repository) {
      setState(() {
        _saving = false;
        if (!_current) _state = null;
      });
      return;
    }
    final commandId =
        'consent-${DateTime.now().microsecondsSinceEpoch}-${++_intent}';
    try {
      await repository.change(state, purpose,
          granted: granted,
          commandId: commandId,
          notice: granted ? notice : null);
      if (mounted && _current && repository == widget.repository) {
        setState(() => _message =
            'Change recorded. Review the current server state below.');
      }
    } catch (_) {
      if (mounted && _current && repository == widget.repository) {
        setState(() => _message =
            'Could not verify this change. Reload current state before trying again.');
      }
    } finally {
      // No optimistic switch update and no automatic mutation retries. CAS/replay
      // receipts describe the command, while this separate read describes now.
      if (mounted && repository == widget.repository) {
        await _load();
        if (mounted) setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_current) {
      return const Scaffold(
          body: Center(child: Text('Session changed. Return to sign in.')));
    }
    final injected = widget.repository != null;
    final heading = Theme.of(context)
        .textTheme
        .titleLarge
        ?.copyWith(fontFamily: 'BarlowCondensed');
    return Scaffold(
      appBar: AppBar(
          title: const Text('Personalized Recommendations',
              style: TextStyle(fontFamily: 'BarlowCondensed')),
          actions: [
            IconButton(
                tooltip: 'Reload current state',
                onPressed: !injected || _busy ? null : _load,
                icon: const Icon(Icons.refresh)),
          ]),
      body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Panel(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(
                        injected
                            ? 'Choose what works for you'
                            : 'Personalization settings',
                        style: heading),
                    const SizedBox(height: 8),
                    Text(injected
                        ? 'Control how eligible exercise assessments help personalize your suggestions.'
                        : 'Personalization is not available for your account yet.'),
                    const SizedBox(height: 8),
                    const Text(
                        'Each choice is optional. You can change your choices at any time.'),
                  ])),
              const SizedBox(height: 16),
              if (_loading) const LinearProgressIndicator(),
              if (!injected)
                const Text(
                    'Your saved choices are unavailable. Controls will be enabled when personalization is ready.'),
              if (_error != null)
                Text(_error!, style: const TextStyle(color: AppColors.danger)),
              if (_message != null)
                Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(_message!)),
              if (injected && !_busy)
                Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                        onPressed: _load,
                        child: const Text('Reload current state'))),
              const SizedBox(height: 12),
              if (widget.notice != null)
                ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: const Text('Privacy details'),
                    children: [
                      Text(widget.notice!.fictional
                          ? 'Use the assessment history available for your account to suggest relevant guidance.'
                          : widget.notice!.historyDescription),
                      Text(
                          'Notice ${widget.notice!.noticeVersion} · ${widget.notice!.contentVersion}')
                    ]),
              const SizedBox(height: 12),
              for (final purpose in RecommendationConsentPurpose.values) ...[
                _purposeCard(purpose),
                const SizedBox(height: 12),
              ],
              const Text(
                  'Turning a choice off stops future use for that purpose. Turning this off does not delete existing records.'),
              const SizedBox(height: 16),
            ],
          )),
    );
  }

  Widget _purposeCard(RecommendationConsentPurpose purpose) {
    final value = _state?.purposes[purpose];
    final granted = value?.granted ?? false;
    final canChange = !_busy &&
        _state != null &&
        widget.repository != null &&
        (granted || widget.notice != null);
    final history = value?.historyStartAtMillis;
    final notice = widget.notice;
    final updateRequired = granted &&
        notice != null &&
        (value?.noticePolicyId != notice.policyId ||
            value?.noticeVersion != notice.noticeVersion ||
            value?.contentVersion != notice.contentVersion);
    return Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SwitchListTile(
          key: ValueKey(purpose.name),
          contentPadding: EdgeInsets.zero,
          title: Text(_title(purpose),
              style: const TextStyle(color: AppColors.ink)),
          subtitle: Text(_explanation(purpose),
              style: const TextStyle(color: AppColors.inkSoft)),
          value: granted,
          onChanged: canChange ? (next) => _change(purpose, next) : null),
      Text(_state == null
          ? 'Saved choice unavailable'
          : granted
              ? 'On'
              : 'Off'),
      if (updateRequired)
        TextButton(
            onPressed: canChange ? () => _change(purpose, true) : null,
            child: const Text('Update permission')),
      if (value?.noticeVersion != null)
        Text(
            'Accepted notice: ${value!.noticeVersion} · Content: ${value.contentVersion}'),
      Text(history == 0
          ? 'Uses recent synced workout history.'
          : history == null
              ? 'History scope: no granted history scope.'
              : '${granted ? 'History scope begins' : 'Previous grant history began'} ${DateTime.fromMillisecondsSinceEpoch(history, isUtc: true).toIso8601String()} (UTC).${granted ? '' : ' Revoked: no active history scope.'}'),
    ]));
  }
}

String _title(RecommendationConsentPurpose purpose) => switch (purpose) {
      RecommendationConsentPurpose.exerciseInsights =>
        'Understand my exercise technique',
      RecommendationConsentPurpose.recommendationGeneration =>
        'Personalize my suggestions',
      RecommendationConsentPurpose.externalAiInference =>
        'Optional Gemini assistance',
      RecommendationConsentPurpose.recommendationDelivery =>
        'Receive recommendations',
    };
String _explanation(RecommendationConsentPurpose purpose) => switch (purpose) {
      RecommendationConsentPurpose.exerciseInsights =>
        'Use recent synced workout results to find relevant exercise guidance.',
      RecommendationConsentPurpose.recommendationGeneration =>
        'Suggest routines, tutorials and optional coaching based on your exercise activity and goals.',
      RecommendationConsentPurpose.externalAiInference =>
        'Let Gemini help rank eligible suggestions using minimal, anonymized context. Suggestions also work without Gemini.',
      RecommendationConsentPurpose.recommendationDelivery =>
        'Show your recommendations on Home and in your Notification Center.',
    };
