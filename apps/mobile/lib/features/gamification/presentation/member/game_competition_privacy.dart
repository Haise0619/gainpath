import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/gamification.dart';
import 'package:gainpath_identity/gainpath_identity.dart';
import 'package:gainpath_ui/gainpath_ui.dart';

/// Account and policy-version scoped server preference, separate from earning.
class GameCompetitionPrivacy extends StatefulWidget {
  const GameCompetitionPrivacy(
      {super.key, required this.repository, this.onConfirmed});
  final MiniGameCompetitionRepository repository;
  final ValueChanged<MiniGameCompetitionPreference>? onConfirmed;
  @override
  State<GameCompetitionPrivacy> createState() => _GameCompetitionPrivacyState();
}

class _GameCompetitionPrivacyState extends State<GameCompetitionPrivacy> {
  MiniGameCompetitionPreference? _preference;
  bool _busy = false, _failed = false;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    unawaited(_run());
  }

  @override
  void didUpdateWidget(GameCompetitionPrivacy old) {
    super.didUpdateWidget(old);
    if (!identical(old.repository, widget.repository)) {
      _generation++;
      _preference = null;
      _busy = false;
      unawaited(_run());
    }
  }

  Future<void> _run({bool? enabled}) async {
    final repo = widget.repository;
    if (!repo.current || _busy) return;
    final generation = ++_generation;
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      final value = await (enabled == null
              ? repo.preference()
              : repo.setPreference(enabled: enabled))
          .timeout(const Duration(seconds: 12));
      if (!mounted || generation != _generation || !repo.current) return;
      if (value.scope != repo.scope ||
          (enabled != null && value.enabled != enabled)) {
        throw const FormatException('Unconfirmed preference');
      }
      setState(() => _preference = value);
      widget.onConfirmed?.call(value);
    } catch (_) {
      if (mounted && generation == _generation && repo.current) {
        setState(() => _failed = true);
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _generation++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<AuthState>(
      stream: context.read<AuthBloc?>()?.stream,
      builder: (context, _) {
        if (!widget.repository.current) {
          return const Text('Ranking session ended.');
        }
        return Panel(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text("Include my result in this game's rankings",
                  style: TextStyle(
                      color: AppColors.ink, fontWeight: FontWeight.w700)),
              value: _preference?.enabled ?? false,
              onChanged: _busy || _preference == null
                  ? null
                  : (value) => _run(enabled: value)),
          const Text(
              'Optional and separate from Reward Points. Only game events and timing are sent; camera images and pose landmarks stay on-device.'),
          const SizedBox(height: 8),
          const Text(miniGameCompetitionTrustLabel,
              style: TextStyle(color: AppColors.inkSoft, fontSize: 12)),
          const SizedBox(height: 8),
          const Text(
              'Turning this off hides all your previously published scores from both games’ Weekly and All-time rankings. Private history, points and vouchers stay unchanged. Turning it on again includes new rounds only.'),
          const SizedBox(height: 8),
          if (_busy)
            const Text('Updating ranking visibility…')
          else if (_failed) ...[
            const Text(
                'Could not confirm ranking visibility. Your last confirmed choice is unchanged.'),
            TextButton(
                onPressed: () => _run(),
                child: const Text('Retry ranking preference'))
          ] else if (_preference != null)
            Text(
                _preference!.enabled
                    ? 'New completed rounds can enter game rankings.'
                    : 'Hidden from game rankings',
                style: const TextStyle(
                    color: AppColors.ink, fontWeight: FontWeight.w600)),
        ]));
      });
}
