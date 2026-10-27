import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:gainpath_domain/gamification.dart';
import 'package:gainpath_ui/gainpath_ui.dart';

class WorkoutRewardDraftPanel extends StatefulWidget {
  const WorkoutRewardDraftPanel({super.key, required this.repository});
  final WorkoutRewardConfigurationRepository repository;
  @override
  State<WorkoutRewardDraftPanel> createState() =>
      _WorkoutRewardDraftPanelState();
}

class _WorkoutRewardDraftPanelState extends State<WorkoutRewardDraftPanel> {
  final _form = GlobalKey<FormState>();
  final _points = TextEditingController(),
      _limit = TextEditingController(),
      _completion = TextEditingController(),
      _reps = TextEditingController(),
      _seconds = TextEditingController(),
      _ids = TextEditingController();
  final _difficulty = {
    for (final level in ['Beginner', 'Intermediate', 'Advanced'])
      level: TextEditingController()
  };
  WorkoutRewardDraft? _draft;
  bool _expanded = false, _loading = false, _saving = false;
  String? _error, _signature, _request;
  int _generation = 0;
  @override
  void didUpdateWidget(WorkoutRewardDraftPanel old) {
    super.didUpdateWidget(old);
    if (old.repository != widget.repository || !widget.repository.current) {
      _generation++;
      _draft = null;
      _expanded = false;
      _loading = false;
      _saving = false;
      _error = null;
      _signature = null;
      _request = null;
      for (final c in [
        _points,
        _limit,
        _completion,
        _reps,
        _seconds,
        _ids,
        ..._difficulty.values
      ]) {
        c.clear();
      }
    }
  }

  @override
  void dispose() {
    for (final c in [
      _points,
      _limit,
      _completion,
      _reps,
      _seconds,
      _ids,
      ..._difficulty.values
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    if (_loading || _saving || !widget.repository.current) return;
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
      _draft = null;
    });
    try {
      final draft = await widget.repository.loadWorkoutRewardDraft();
      if (!mounted || generation != _generation || !widget.repository.current) {
        return;
      }
      setState(() {
        _draft = draft;
        _points.text = '${draft.points}';
        _limit.text = '${draft.dailyClaimLimit}';
        _completion.text = '${draft.minimumCompletionPercent}';
        _reps.text = '${draft.minimumVerifiedReps}';
        _seconds.text = '${draft.minimumTrackedSeconds}';
        _ids.text = draft.eligibleRoutineIds.join('\n');
        for (final level in _difficulty.keys) {
          _difficulty[level]!.text = '${draft.difficultyPoints[level]}';
        }
      });
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() => _error =
            'Workout reward drafts are unavailable. The reward shop is unaffected.');
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  List<String> _routineIds() => _ids.text
      .split(RegExp(r'\r?\n'))
      .map((v) => v.trim())
      .where((v) => v.isNotEmpty)
      .toList();
  Future<void> _save() async {
    if (_saving ||
        _loading ||
        _draft == null ||
        !widget.repository.current ||
        !_form.currentState!.validate()) {
      return;
    }
    final draft = WorkoutRewardDraft(
        revision: _draft!.revision,
        version: _draft!.version,
        points: int.parse(_points.text.trim()),
        dailyClaimLimit: int.parse(_limit.text.trim()),
        minimumCompletionPercent: int.parse(_completion.text.trim()),
        minimumVerifiedReps: int.parse(_reps.text.trim()),
        minimumTrackedSeconds: int.parse(_seconds.text.trim()),
        eligibleRoutineIds: _routineIds(),
        difficultyPoints: {
          for (final entry in _difficulty.entries)
            entry.key: int.parse(entry.value.text.trim())
        });
    final signature =
        jsonEncode({'baseRevision': draft.revision, ...draft.toFields()});
    if (_signature != signature) {
      _signature = signature;
      _request =
          'workout_${DateTime.now().microsecondsSinceEpoch}_${Random.secure().nextInt(1 << 32)}';
    }
    final generation = _generation;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.saveWorkoutRewardDraft(
          requestId: _request!, baseRevision: draft.revision, draft: draft);
      if (!mounted || generation != _generation || !widget.repository.current) {
        return;
      }
      setState(() => _saving = false);
      await _load();
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() => _error =
            'Draft save not confirmed. Retry unchanged values, or reload if another Admin changed the draft.');
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _saving = false);
    }
  }

  Widget _number(TextEditingController c, String label, int max) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
          controller: c,
          enabled: !_saving,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: label),
          validator: (v) {
            final n = int.tryParse(v?.trim() ?? '');
            return n == null || n < 1 || n > max
                ? 'Enter a whole number from 1 to $max'
                : null;
          }));
  @override
  Widget build(BuildContext context) {
    if (!widget.repository.current) return const SizedBox.shrink();
    return Panel(
        child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(top: 16),
            initiallyExpanded: _expanded,
            onExpansionChanged: (open) {
              setState(() => _expanded = open);
              if (open && _draft == null && !_loading) _load();
            },
            title: const Text('Workout reward draft'),
            subtitle: const Text('Disabled · pending physical validation'),
            leading: const Icon(Icons.fitness_center, color: AppColors.primary),
            children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [statusPill('Disabled'), statusPill('Draft only')]),
            const SizedBox(height: 12),
            const Text(
                'Workout rewards remain disabled until physical validation is accepted. Saving changes only this draft; it does not award points or enable rewards.'),
            const SizedBox(height: 8),
            const Text(
                'Workout completion is separate from reward eligibility. Manual-only and mixed routines do not automatically qualify. The daily 50-point app check-in is independent.'),
            const SizedBox(height: 8),
            const Text('Premium 1.5× rewards and Stage C coaching vouchers remain on hold.'),
            const SizedBox(height: 16),
            if (_loading) const LinearProgressIndicator(),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: AppColors.danger)),
            if (!_loading && _draft == null)
              TextButton(
                  onPressed: _load, child: const Text('Retry workout draft')),
            if (_draft != null)
              Form(
                  key: _form,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LayoutBuilder(builder: (context, c) {
                          final fields = [
                            _number(_points, 'Points per qualifying workout',
                                100000),
                            _number(_limit, 'Claims per Malaysia day', 10),
                            _number(_completion,
                                'Minimum target completion (%)', 100),
                            _number(_reps, 'Minimum verified reps', 10000),
                            _number(_seconds, 'Minimum tracked seconds', 86400)
                          ];
                          final width = c.maxWidth >= 800 &&
                                  MediaQuery.textScalerOf(context).scale(14) <
                                      24
                              ? (c.maxWidth - 20) / 2
                              : c.maxWidth;
                          return Wrap(spacing: 20, children: [
                            for (final f in fields)
                              SizedBox(width: width, child: f)
                          ]);
                        }),
                        TextFormField(
                            controller: _ids,
                            enabled: !_saving,
                            minLines: 3,
                            maxLines: 6,
                            decoration: const InputDecoration(
                                labelText: 'Eligible routine IDs',
                                helperText:
                                    'One routine ID per line. Leave empty to keep every routine ineligible.'),
                            validator: (v) {
                              final ids = _routineIds();
                              return ids.length > 100 ||
                                      ids.toSet().length != ids.length ||
                                      ids.any((id) =>
                                          !RegExp(r'^[A-Za-z0-9_-]{1,128}$')
                                              .hasMatch(id))
                                  ? 'Use up to 100 unique routine IDs, one per line'
                                  : null;
                            }),
                        const SizedBox(height: 20),
                        Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text('Future difficulty points',
                                  style:
                                      Theme.of(context).textTheme.titleMedium),
                              statusPill('Disabled')
                            ]),
                        const SizedBox(height: 8),
                        const Text(
                            'Draft amounts for future review. Difficulty multipliers remain disabled.'),
                        const SizedBox(height: 12),
                        for (final entry in _difficulty.entries)
                          _number(entry.value, '${entry.key} points (future)',
                              100000),
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          OutlinedButton(
                              onPressed: _saving ? null : _load,
                              child: const Text('Reload draft')),
                          FilledButton(
                              onPressed: _saving ? null : _save,
                              child: Text(
                                  _saving ? 'Saving…' : 'Save workout draft'))
                        ]),
                      ])),
          ]),
        ]));
  }
}
