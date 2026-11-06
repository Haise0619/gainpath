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
                        const Text(
                            'Synthetic review only. This does not activate production processing.'),
                        const SizedBox(height: 12),
                        Text(granted
                            ? _explanation(purpose)
                            : 'Stop future use for this purpose. Revoking does not promise deletion of existing records; retention and deletion rules still require review.'),
                        if (granted) ...[
                          const SizedBox(height: 12),
                          Text(notice!.historyDescription),
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
                            ? 'Synthetic consent review'
                            : 'Privacy settings preview',
                        style: heading),
                    const SizedBox(height: 8),
                    Text(injected
                        ? 'Local test data only. These choices do not enroll production Members.'
                        : 'Consent collection is unavailable while wording, AI data transfer, history scope and retention await approval.'),
                    const SizedBox(height: 8),
                    const Text(
                        'Each purpose is independent and starts off. Camera and backup permissions do not grant recommendation consent.'),
                  ])),
              const SizedBox(height: 16),
              if (_loading) const LinearProgressIndicator(),
              if (!injected)
                const Text(
                    'Current server state unavailable. Switches show the default-off preview, not saved account choices.'),
              if (_state != null)
                Text('Current server state · revision ${_state!.revision}'),
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
              Text(widget.notice == null
                  ? 'Notice and history policy awaiting owner review.'
                  : 'Review notice: ${widget.notice!.noticeVersion} · Content: ${widget.notice!.contentVersion}'),
              const SizedBox(height: 12),
              for (final purpose in RecommendationConsentPurpose.values) ...[
                _purposeCard(purpose),
                const SizedBox(height: 12),
              ],
              const Text(
                  'Revocation stops future authorized use for the selected purpose. It does not confirm deletion of prior records. Retention, audit access and deletion rules are pending owner review.'),
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
              ? 'Granted on server'
              : 'Not granted'),
      if (value?.noticeVersion != null)
        Text(
            'Accepted notice: ${value!.noticeVersion} · Content: ${value.contentVersion}'),
      Text(history == null
          ? 'History scope: no granted history scope.'
          : '${granted ? 'History scope begins' : 'Previous grant history began'} ${DateTime.fromMillisecondsSinceEpoch(history, isUtc: true).toIso8601String()} (UTC).${granted ? '' : ' Revoked: no active history scope.'}'),
    ]));
  }
}

String _title(RecommendationConsentPurpose purpose) => switch (purpose) {
      RecommendationConsentPurpose.exerciseInsights => 'Exercise Insights',
      RecommendationConsentPurpose.recommendationGeneration =>
        'Recommendation Generation',
      RecommendationConsentPurpose.externalAiInference =>
        'External AI Inference',
      RecommendationConsentPurpose.recommendationDelivery =>
        'Recommendation Delivery',
    };
String _explanation(RecommendationConsentPurpose purpose) => switch (purpose) {
      RecommendationConsentPurpose.exerciseInsights =>
        'Use compatible workout form scores and session evidence to describe exercises needing attention. These are educational estimates, not a medical risk assessment.',
      RecommendationConsentPurpose.recommendationGeneration =>
        'Use eligible exercise evidence to prepare Coach and tutorial suggestions for Admin review. This does not book a Coach or change your workouts.',
      RecommendationConsentPurpose.externalAiInference =>
        'Send minimized eligible exercise evidence and candidate descriptions to an external AI provider for semantic ranking. Provider, fields, transfer safeguards and retention require approval before release.',
      RecommendationConsentPurpose.recommendationDelivery =>
        'Receive Admin-approved suggestions in your existing Notification Center. Opening a suggestion does not create a booking, payment or reward.',
    };
