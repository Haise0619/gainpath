import 'package:flutter/material.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../../../app/di/workout_preferences_factory.dart';
import '../../../../app/di/workout_store_factory.dart';
import '../../application/workout_preferences_controller.dart';
import '../../domain/workout_audio_port.dart';

typedef WorkoutPreferencesFactory = Future<WorkoutPreferencesController>
    Function(SessionScope);

/// The same versioned information is available from first use and Settings.
Future<bool?> showAiTrackingPrivacyConsent(BuildContext context,
        {bool requestConsent = true}) =>
    showModalBottomSheet<bool>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        builder: (_) => _AiPrivacyNotice(requestConsent: requestConsent));

class _AiPrivacyNotice extends StatefulWidget {
  const _AiPrivacyNotice({required this.requestConsent});
  final bool requestConsent;
  @override
  State<_AiPrivacyNotice> createState() => _AiPrivacyNoticeState();
}

class _AiPrivacyNoticeState extends State<_AiPrivacyNotice> {
  bool _accepted = false;
  @override
  Widget build(BuildContext context) => SafeArea(
      child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.privacy_tip_outlined,
                    size: 36, color: AppColors.primary),
                const SizedBox(height: 16),
                Text('AI Tracking privacy',
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 12),
                const Text(
                    'GainPath uses your camera to estimate body position and count supported exercise movements on this device. Guidance is provisional and does not assess every aspect of your form.'),
                const SizedBox(height: 12),
                const Text(
                    'Workout camera video is not recorded, stored or uploaded. Saved workout results remain subject to the existing optional backup and sharing controls; this acknowledgement does not enable uploads or sharing.'),
                const SizedBox(height: 12),
                const Text(
                    'You can withdraw AI Tracking consent in Settings. This stops future AI sessions until you consent again and does not delete saved workout history. Android camera permission is separate.'),
                const SizedBox(height: 16),
                if (widget.requestConsent)
                  CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: _accepted,
                      onChanged: (value) =>
                          setState(() => _accepted = value ?? false),
                      title: const Text(
                          'I agree to camera-based movement tracking as described above.')),
                const SizedBox(height: 12),
                FilledButton(
                    style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(56)),
                    onPressed: !widget.requestConsent || _accepted
                        ? () => Navigator.pop(context, widget.requestConsent)
                        : null,
                    child: Text(
                        widget.requestConsent ? 'Accept AI Tracking' : 'Done')),
                if (widget.requestConsent)
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Not now')),
                Text(
                    'Privacy notice version ${WorkoutPreferencesController.consentVersion}',
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center),
              ])));
}

class WorkoutPrivacySettingsScreen extends StatefulWidget {
  const WorkoutPrivacySettingsScreen(
      {super.key,
      required this.scope,
      required this.isCurrent,
      this.preferencesFactory = createWorkoutPreferences,
      this.voicePreferencesFactory = createWorkoutVoicePreferences,
      this.onOpenBackup});
  final SessionScope scope;
  final bool Function() isCurrent;
  final WorkoutPreferencesFactory preferencesFactory;
  final Future<WorkoutVoicePreferences> Function(SessionScope)
      voicePreferencesFactory;
  final VoidCallback? onOpenBackup;
  @override
  State<WorkoutPrivacySettingsScreen> createState() =>
      _WorkoutPrivacySettingsScreenState();
}

class _WorkoutPrivacySettingsScreenState
    extends State<WorkoutPrivacySettingsScreen> {
  WorkoutPreferencesController? _preferences;
  WorkoutVoicePreferences? _voicePreferences;
  WorkoutVoiceMode? _voiceMode;
  bool _voiceBusy = false;
  String? _voiceError;
  String? _error;
  bool get _current => mounted && widget.isCurrent();
  @override
  void initState() {
    super.initState();
    _load();
    _loadVoice();
  }

  Future<void> _load() async {
    try {
      final preferences = await widget.preferencesFactory(widget.scope);
      await preferences.load();
      if (!_current) return;
      if (preferences.scope != widget.scope) {
        throw StateError('Settings scope mismatch');
      }
      _preferences = preferences;
      preferences.addListener(_changed);
      setState(() => _error = null);
    } catch (_) {
      if (_current) {
        setState(() =>
            _error = 'Could not load local workout settings. Please retry.');
      }
    }
  }

  void _changed() {
    if (_current) setState(() {});
  }

  Future<void> _loadVoice() async {
    try {
      final preferences = await widget.voicePreferencesFactory(widget.scope);
      final mode = await preferences.read();
      if (!_current) return;
      setState(() {
        _voicePreferences = preferences;
        _voiceMode = mode;
        _voiceError = null;
      });
    } catch (_) {
      if (_current) {
        setState(() => _voiceError = 'Voice preference could not be loaded.');
      }
    }
  }

  Future<void> _setVoice(WorkoutVoiceMode? mode) async {
    final preferences = _voicePreferences;
    if (!_current || preferences == null || mode == null || _voiceBusy) return;
    setState(() => _voiceBusy = true);
    try {
      await preferences.write(mode);
      if (_current) {
        setState(() {
          _voiceMode = mode;
          _voiceError = null;
        });
      }
    } catch (_) {
      if (_current) {
        setState(
            () => _voiceError = 'Could not save the voice mode. Try again.');
      }
    } finally {
      if (_current) setState(() => _voiceBusy = false);
    }
  }

  Widget _voicePanel() => Panel(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Voice mode'),
        DropdownButton<WorkoutVoiceMode>(
            isExpanded: true,
            value: _voiceMode,
            hint: Text(_voicePreferences == null
                ? 'Voice preference unavailable'
                : 'Use account default'),
            items: [
              for (final mode in WorkoutVoiceMode.values)
                DropdownMenuItem(value: mode, child: Text(mode.label)),
            ],
            onChanged:
                _voicePreferences != null && !_voiceBusy ? _setVoice : null),
        const Text(
            'Full Coaching includes reps and transitions. Alerts Only keeps actionable cues. Muted turns speech off.'),
        if (_voiceError != null) ...[
          Text(_voiceError!),
          if (_voicePreferences == null)
            TextButton(
                onPressed: _loadVoice,
                child: const Text('Retry voice settings')),
        ],
      ]));

  Future<void> _save(Future<void> Function() action) async {
    if (!_current || _preferences!.busy) return;
    try {
      await action();
    } catch (_) {/* Controller exposes a persistent inline retry error. */}
    if (_current) setState(() {});
  }

  Future<void> _enableConsent() async {
    if (!_current) return;
    final accepted = await showAiTrackingPrivacyConsent(context);
    if (!_current || accepted != true) return;
    await _save(_preferences!.grantConsent);
  }

  Future<void> _chooseRest() async {
    final p = _preferences!;
    final value = await showModalBottomSheet<int>(
        context: context,
        useSafeArea: true,
        builder: (context) => SingleChildScrollView(
            child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('Suggested between-exercise rest',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  const Text(
                      'Used only when the routine does not prescribe between-exercise rest.'),
                  for (final seconds in const [
                    0,
                    15,
                    30,
                    45,
                    60,
                    90,
                    120,
                    180,
                    300
                  ])
                    ListTile(
                        title: Text(seconds == 0
                            ? 'No suggested rest'
                            : '$seconds seconds'),
                        trailing: p.suggestedRestSeconds == seconds
                            ? const Icon(Icons.check, color: AppColors.primary)
                            : null,
                        onTap: () => Navigator.pop(context, seconds)),
                ]))));
    if (!_current || value == null) return;
    await _save(() => p.updatePreferences(suggestedRestSeconds: value));
  }

  @override
  void dispose() {
    _preferences?.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = _preferences;
    if (!widget.isCurrent()) {
      return const Scaffold(
          body:
              Center(child: Text('Sign in to manage your workout settings.')));
    }
    return Scaffold(
        appBar: AppBar(title: const Text('Workout settings')),
        body: p == null
            ? Center(
                child: _error == null
                    ? const CircularProgressIndicator()
                    : Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(_error!),
                        TextButton(onPressed: _load, child: const Text('Retry'))
                      ]))
            : ListView(padding: const EdgeInsets.all(20), children: [
                const Eyebrow('AI Tracking & privacy'),
                const SizedBox(height: 8),
                Panel(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                      Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                                p.validConsent
                                    ? Icons.verified_user_outlined
                                    : Icons.privacy_tip_outlined,
                                color: AppColors.primary),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Text(
                                    p.validConsent
                                        ? 'AI Tracking consent enabled'
                                        : 'AI Tracking consent required',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium)),
                          ]),
                      const SizedBox(height: 12),
                      Text(p.validConsent
                          ? 'Your consent is remembered for this account on this device.'
                          : 'Accept the privacy notice before starting an AI-tracked exercise.'),
                      const SizedBox(height: 8),
                      const Text(
                          'Camera permission, optional backup and Coach sharing are separate controls. Withdrawing consent does not delete your workout history.'),
                      const SizedBox(height: 8),
                      const Text(
                          'On Android, manage camera access in Settings › Apps › GainPath › Permissions.'),
                      const SizedBox(height: 16),
                      if (p.validConsent) ...[
                        OutlinedButton(
                            onPressed: p.busy
                                ? null
                                : () {
                                    if (_current) {
                                      showAiTrackingPrivacyConsent(context,
                                          requestConsent: false);
                                    }
                                  },
                            child: const Text('Review privacy information')),
                        TextButton(
                            onPressed:
                                p.busy ? null : () => _save(p.withdrawConsent),
                            child: const Text('Withdraw AI Tracking consent')),
                      ] else
                        FilledButton(
                            onPressed: p.busy ? null : _enableConsent,
                            child: const Text('Review and enable AI Tracking')),
                    ])),
                const SizedBox(height: 24),
                const Eyebrow('Workout preferences'),
                const SizedBox(height: 8),
                Panel(
                    padding: EdgeInsets.zero,
                    child: Column(children: [
                      SwitchListTile.adaptive(
                          value: p.autoContinue,
                          onChanged: p.busy
                              ? null
                              : (value) => _save(() =>
                                  p.updatePreferences(autoContinue: value)),
                          title: const Text('Auto-Continue Between Exercises'),
                          subtitle: const Text(
                              'Automatically start the next exercise after your rest countdown when the workout is ready.')),
                      const Divider(height: 1),
                      SwitchListTile.adaptive(
                          value: p.autoContinueBetweenSets,
                          onChanged: p.busy
                              ? null
                              : (value) => _save(() => p.updatePreferences(
                                  autoContinueBetweenSets: value)),
                          title: const Text('Auto-Continue Between Sets'),
                          subtitle: const Text(
                              'Resume AI tracking after rest when the preparation countdown ends and the camera confirms you’re ready.')),
                      const Divider(height: 1),
                      ListTile(
                          title: const Text('Suggested between-exercise rest'),
                          subtitle: Text(
                              '${p.suggestedRestSeconds} seconds · Routine prescriptions take priority'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: p.busy ? null : _chooseRest),
                    ])),
                const SizedBox(height: 12),
                const Text(
                    'These preferences are saved for this account on this device. They are not included in workout backup.'),
                const SizedBox(height: 24),
                const Eyebrow('Voice Coach'),
                const SizedBox(height: 8),
                _voicePanel(),
                const SizedBox(height: 24),
                const Eyebrow('Data & backup'),
                const SizedBox(height: 8),
                Panel(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      const Text(
                          'Results save on this device first. Optional backup covers eligible results and routine progress.'),
                      if (widget.onOpenBackup != null)
                        TextButton.icon(
                            onPressed: widget.onOpenBackup,
                            icon: const Icon(Icons.cloud_upload_outlined),
                            label: const Text('Workout backup')),
                    ])),
                if (p.busy)
                  const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: LinearProgressIndicator()),
                if (p.error != null)
                  Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(p.error!,
                          style: const TextStyle(color: AppColors.danger))),
              ]));
  }
}
