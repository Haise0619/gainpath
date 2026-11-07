import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/gainpath_domain.dart'
    show AppRole, SessionScope;
import 'package:gainpath_identity/gainpath_identity.dart';
import '../../../../app/di/workout_preferences_factory.dart';
import '../../application/workout_preferences_controller.dart';
import 'workout_privacy_settings_screen.dart' show WorkoutPreferencesFactory;

/// Unmounting the measured route disposes its capture session on withdrawal.
/// A revoked guard never remounts that session, even after consent is re-enabled.
class WorkoutAiConsentGuard extends StatefulWidget {
  const WorkoutAiConsentGuard(
      {super.key,
      required this.scope,
      required this.child,
      this.preferencesFactory = createWorkoutPreferences,
      this.isCurrent});
  final SessionScope scope;
  final Widget child;
  final WorkoutPreferencesFactory preferencesFactory;

  /// Injection seam; production uses the authenticated Member scope policy.
  final bool Function()? isCurrent;
  @override
  State<WorkoutAiConsentGuard> createState() => _WorkoutAiConsentGuardState();
}

class _WorkoutAiConsentGuardState extends State<WorkoutAiConsentGuard> {
  WorkoutPreferencesController? _preferences;
  StreamSubscription<AuthState>? _authSubscription;
  AuthBloc? _auth;
  bool _opened = false, _revoked = false, _hadCapture = false;
  String? _error;
  bool get _current =>
      widget.isCurrent?.call() ??
      (_auth?.state.session?.scope == widget.scope &&
          AuthRolePolicy.canEnter(_auth!.state,
              allowed: const {AppRole.member}));
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_opened) return;
    _opened = true;
    if (widget.isCurrent == null) {
      _auth = context.read<AuthBloc>();
      _authSubscription = _auth!.stream.listen((_) {
        if (!_current) _revoked = true;
        if (mounted) setState(() {});
      });
    }
    _load();
  }

  Future<void> _load() async {
    try {
      final preferences = await widget.preferencesFactory(widget.scope);
      await preferences.load();
      if (!mounted || !_current) return;
      if (preferences.scope != widget.scope) {
        throw StateError('Consent scope mismatch');
      }
      _preferences = preferences;
      preferences.addListener(_changed);
      setState(() {});
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'AI Tracking consent could not be verified. Return to the routine and try again.');
      }
    }
  }

  void _changed() {
    if (_hadCapture && !_preferences!.validConsent) _revoked = true;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _preferences?.removeListener(_changed);
    unawaited(_authSubscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = _preferences;
    if (!_revoked && _current && p?.validConsent == true) {
      _hadCapture = true;
      return widget.child;
    }
    return Scaffold(
        appBar: AppBar(title: const Text('AI Tracking paused')),
        body: SafeArea(
            child: Center(
                child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.privacy_tip_outlined, size: 48),
                      const SizedBox(height: 16),
                      Text(
                          _revoked
                              ? 'AI Tracking has stopped'
                              : 'AI Tracking consent required',
                          style: Theme.of(context).textTheme.headlineSmall,
                          textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      if (p == null && _error == null && _current && !_revoked)
                        const CircularProgressIndicator()
                      else
                        Text(
                            _error ??
                                (_current
                                    ? 'Review your AI Tracking consent in Settings, then return to your routine to start again. Saved workout history has not been deleted.'
                                    : 'Sign in to the same account before starting another AI workout.'),
                            textAlign: TextAlign.center),
                      const SizedBox(height: 24),
                      FilledButton(
                          onPressed: () => Navigator.maybePop(context),
                          child: const Text('Return to routine')),
                    ])))));
  }
}
