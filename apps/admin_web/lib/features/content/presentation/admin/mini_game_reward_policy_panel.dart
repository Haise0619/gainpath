import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:gainpath_domain/gamification.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_ui/gainpath_ui.dart';

class MiniGameRewardPolicyPanel extends StatefulWidget {
  const MiniGameRewardPolicyPanel({super.key, required this.repository});
  final MiniGameRewardConfigurationRepository repository;
  @override
  State<MiniGameRewardPolicyPanel> createState() =>
      _MiniGameRewardPolicyPanelState();
}

class _MiniGameRewardPolicyPanelState extends State<MiniGameRewardPolicyPanel> {
  final _form = GlobalKey<FormState>();
  final _points = TextEditingController();
  final _limit = TextEditingController();
  final _cap = TextEditingController();
  late SessionScope _scope;
  MiniGameRewardPolicy? _policy;
  bool _expanded = false, _loading = false, _saving = false;
  bool _conflict = false, _invalidated = false;
  int _generation = 0;
  String? _error, _success, _request, _signature;

  @override
  void initState() {
    super.initState();
    _scope = widget.repository.scope;
  }

  @override
  void didUpdateWidget(MiniGameRewardPolicyPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.repository, widget.repository)) {
      _generation++;
      _scope = widget.repository.scope;
      _invalidated = false;
      _policy = null;
      _expanded = _loading = _saving = _conflict = false;
      _error = _success = _request = _signature = null;
      _points.clear();
      _limit.clear();
      _cap.clear();
    }
  }

  @override
  void dispose() {
    _generation++;
    _points.dispose();
    _limit.dispose();
    _cap.dispose();
    super.dispose();
  }

  bool get _current {
    if (!widget.repository.current || widget.repository.scope != _scope) {
      _invalidated = true;
    }
    return !_invalidated;
  }

  bool _accept(
          int generation, MiniGameRewardConfigurationRepository repository) =>
      mounted &&
      generation == _generation &&
      identical(repository, widget.repository) &&
      _current;

  void _apply(MiniGameRewardPolicy policy) {
    policy.toFields();
    final game = policy.games
        .singleWhere((game) => game.gameId == MiniGameContent.supportedId);
    _policy = policy;
    _points.text = '${game.points}';
    _limit.text = '${game.dailyClaimLimit}';
    _cap.text = '${policy.dailyPointsCap}';
    _request = _signature = null;
    _conflict = false;
  }

  Future<void> _load() async {
    if (_loading || _saving || !_current) return;
    final generation = ++_generation;
    final repository = widget.repository;
    setState(() {
      _loading = true;
      _policy = null;
      _error = _success = null;
    });
    try {
      final policy = await repository.loadPolicy();
      if (!_accept(generation, repository)) return;
      setState(() => _apply(policy));
    } on MiniGameRewardSessionChanged {
      if (mounted && generation == _generation) {
        setState(() => _invalidated = true);
      }
    } catch (_) {
      if (_accept(generation, repository)) {
        setState(() => _error =
            'Mini-game reward policy is unavailable. Check Admin access and reload.');
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _save() async {
    if (_saving ||
        _loading ||
        _conflict ||
        _policy == null ||
        !_current ||
        !(_form.currentState?.validate() ?? false)) {
      return;
    }
    final baseline = _policy!;
    final policy =
        baseline.copyWith(dailyPointsCap: int.parse(_cap.text.trim()), games: [
      for (final game in baseline.games)
        if (game.gameId == MiniGameContent.supportedId)
          MiniGameRewardGame(
              gameId: game.gameId,
              points: int.parse(_points.text.trim()),
              dailyClaimLimit: int.parse(_limit.text.trim()))
        else
          game
    ]);
    final signature = jsonEncode({
      'baseRevision': baseline.revision,
      ...policy.toFields(),
    });
    if (signature != _signature) {
      _signature = signature;
      final random = Random.secure();
      _request = List.generate(
              16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'))
          .join();
    }
    final repository = widget.repository;
    final generation = _generation;
    setState(() {
      _saving = true;
      _error = _success = null;
    });
    try {
      final saved = await repository.savePolicy(
          requestId: _request!,
          baseRevision: baseline.revision,
          policy: policy);
      if (!_accept(generation, repository)) return;
      final readback = await repository.loadPolicy();
      if (!_accept(generation, repository)) return;
      if (readback.revision != saved.revision ||
          readback.revision <= baseline.revision ||
          jsonEncode(readback.toFields()) != jsonEncode(policy.toFields())) {
        throw const MiniGameRewardConflict();
      }
      setState(() {
        _apply(readback);
        _success = 'Settings saved.';
      });
    } on MiniGameRewardConflict {
      if (_accept(generation, repository)) {
        setState(() {
          _conflict = true;
          _error =
              'The policy changed. Reload policy to review the current values before saving again.';
        });
      }
    } on MiniGameRewardSessionChanged {
      if (mounted && generation == _generation) {
        setState(() => _invalidated = true);
      }
    } catch (_) {
      if (_accept(generation, repository)) {
        setState(() => _error =
            'Save not confirmed. Retry unchanged values, or reload the current policy.');
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _saving = false);
      }
    }
  }

  Widget _number({
    required String keyName,
    required String label,
    required String helper,
    required TextEditingController controller,
    required int maximum,
    String? invalid,
  }) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Semantics(
                label: label,
                child: TextFormField(
                    key: Key(keyName),
                    controller: controller,
                    enabled: !_saving && !_conflict,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        helperText: helper,
                        helperMaxLines: 6,
                        errorMaxLines: 6),
                    validator: (value) {
                      final number = int.tryParse(value?.trim() ?? '');
                      return number == null || number < 0 || number > maximum
                          ? invalid ??
                              'Enter a whole number from 0 to $maximum.'
                          : null;
                    })),
          ]));

  @override
  Widget build(BuildContext context) {
    if (!_current) {
      return const Panel(
          child: Text(
              'This Admin session has ended. Reopen the policy with your current account.'));
    }
    return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Panel(
            child: ExpansionTile(
                key: ObjectKey(widget.repository),
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(top: 16),
                initiallyExpanded: _expanded,
                title: const Text('Mini-game reward policy',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('Points and daily limits',
                    style: TextStyle(color: AppColors.primary)),
                onExpansionChanged: (expanded) {
                  setState(() => _expanded = expanded);
                  if (expanded && _policy == null && !_loading) _load();
                },
                children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text(
                    'Set points per completed round and daily earning limits.'),
                const SizedBox(height: 12),
                const Text(
                    'Mini-game points use the Member’s reward balance. Daily Check-in and Workout Rewards keep separate earning limits.'),
                const SizedBox(height: 20),
                if (_loading) const LinearProgressIndicator(),
                if (_error != null) ...[
                  Text(_error!,
                      style: const TextStyle(color: AppColors.danger)),
                  const SizedBox(height: 12),
                ],
                if (_success != null) ...[
                  Text(_success!,
                      style: const TextStyle(color: AppColors.primary)),
                  const SizedBox(height: 12),
                ],
                if (_policy != null) ...[
                  Text(_policy!.revision == 0
                      ? 'Default settings'
                      : 'Saved settings · revision ${_policy!.revision}'),
                  const SizedBox(height: 8),
                  const Text(
                      'Limits reset by Malaysia calendar day (Asia/Kuala_Lumpur). The shared cap applies across all mini-game types.'),
                  const SizedBox(height: 20),
                  Form(
                      key: _form,
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _number(
                                keyName: 'mini-game-cap',
                                label: 'Shared daily point cap',
                                helper:
                                    'Across all mini-games. 0 prevents mini-game rewards.',
                                controller: _cap,
                                maximum: 10000),
                            const Text('Move & Catch',
                                style: TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800)),
                            const SizedBox(height: 16),
                            _number(
                                keyName: 'mini-game-points',
                                label: 'Points per eligible round',
                                helper:
                                    'A fixed amount for a completed participation round; independent of game score.',
                                controller: _points,
                                maximum: 1000),
                            _number(
                                keyName: 'mini-game-limit',
                                label: 'Rewarded rounds per game type',
                                helper:
                                    'Per Malaysia day. 1 allows one eligible round; 0 disables rewards for this game.',
                                controller: _limit,
                                maximum: 1,
                                invalid:
                                    'Enter 0 or 1. Each game type can reward once per day.'),
                            FilledButton.icon(
                                style: FilledButton.styleFrom(
                                    minimumSize: const Size(48, 48),
                                    padding: const EdgeInsets.all(16),
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white),
                                onPressed: _saving || _loading || _conflict
                                    ? null
                                    : _save,
                                icon: const Icon(Icons.save_outlined),
                                label: const Text('Save settings')),
                          ])),
                ],
                const SizedBox(height: 12),
                OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size(48, 48),
                        padding: const EdgeInsets.all(16)),
                    onPressed: _saving || _loading ? null : _load,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Reload policy')),
                if (_saving) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(
                      semanticsLabel: 'Saving settings'),
                ]
              ])
            ])));
  }
}
