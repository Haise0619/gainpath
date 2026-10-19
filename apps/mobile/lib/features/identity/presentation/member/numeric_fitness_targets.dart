import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_identity/gainpath_identity.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../../../infrastructure/firebase/member_profile_repositories.dart';

/// Reuses the profile's target cards and Add affordance in both modes.
class NumericFitnessTargets extends StatefulWidget {
  const NumericFitnessTargets(
      {super.key,
      this.live = false,
      this.session,
      this.repository,
      this.isSessionCurrent});
  final bool live;
  final AuthSession? session;
  final NumericFitnessGoalRepository? repository;
  final bool Function()? isSessionCurrent;
  @override
  State<NumericFitnessTargets> createState() => _NumericFitnessTargetsState();
}

class _NumericFitnessTargetsState extends State<NumericFitnessTargets> {
  NumericFitnessGoalRepository? _repository;
  AuthBloc? _auth;
  AuthSession? _session;
  StreamSubscription<AuthState>? _subscription;
  BuildContext? _editorContext;
  List<NumericFitnessGoal> _goals = [];
  bool _initialized = false,
      _invalidated = false,
      _loading = true,
      _busy = false;
  String? _error;
  String? _initializationFailure;
  bool get _live =>
      widget.live || widget.session != null || widget.repository != null;
  bool _current() {
    if ((widget.isSessionCurrent != null && !widget.isSessionCurrent!()) ||
        (_auth != null &&
            (_auth!.state.session != _session ||
                !AuthRolePolicy.canEnter(_auth!.state,
                    allowed: const {AppRole.member})))) {
      _invalidated = true;
    }
    return mounted && !_invalidated;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _repository = widget.repository;
    if (_live &&
        (_repository == null || widget.session != null || widget.live)) {
      _auth = context.read<AuthBloc>();
      _session = widget.session ?? _auth!.state.session;
      if (_repository != null && _session?.scope != _repository!.scope) {
        _invalidated = true;
      }
      _subscription = _auth!.stream.listen((_) {
        if (!_current() && mounted) {
          final editor = _editorContext;
          if (editor != null && editor.mounted) Navigator.of(editor).pop(false);
          setState(() {
            _goals = [];
            _error = 'Your session changed. Sign in again.';
          });
        }
      });
      if (_repository == null && _session != null && _current()) {
        try {
          _repository =
              createNumericFitnessGoalRepository(_session!.scope, _current);
        } catch (_) {
          _initializationFailure =
              'Targets unavailable. Restart the app and sign in again.';
        }
      }
    } else if (!_live) {
      _repository = _PreviewGoals();
    }
    unawaited(_load());
  }

  Future<void> _load() async {
    if (!_current()) return;
    setState(() {
      _loading = true;
      _error = null;
      _goals = [];
    });
    try {
      if (_repository == null) {
        throw NumericGoalException(
            _initializationFailure ?? 'Sign in to load your targets.');
      }
      final goals = await _repository!.loadActive();
      if (_current()) setState(() => _goals = goals);
    } catch (e) {
      if (_current()) setState(() => _error = _message(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _message(Object error) => error is NumericGoalException
      ? error.message
      : 'Targets unavailable. Check your connection and retry.';

  Future<void> _edit([NumericFitnessGoal? original]) async {
    if (!_current() || _busy || _loading) return;
    setState(() => _busy = true);
    try {
      // Allocate exactly once per dialog; every retry uses the same document.
      final id = original?.id ?? _repository!.allocateId();
      final saved = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) {
            _editorContext = dialogContext;
            return _TargetEditor(
                original: original,
                id: id,
                repository: _repository!,
                isCurrent: _current,
                preview: !_live);
          });
      _editorContext = null;
      if (_current() && saved == true) {
        showToast(context,
            _live ? 'Target saved.' : 'Preview target saved for this screen.');
        await _load();
      } else if (_current()) {
        // A closed form may have had an unconfirmed request. Read back before
        // allowing a newly allocated create form, without claiming success.
        await _load();
      }
    } catch (error) {
      if (_current()) setState(() => _error = _message(error));
    } finally {
      _editorContext = null;
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _archive(NumericFitnessGoal original) async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('Archive target?'),
                content: const Text(
                    'This removes the target from your active list. Its previous versions stay available for future progress comparisons.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Keep target')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Archive'))
                ]));
    if (confirmed != true || !_current() || _busy) return;
    setState(() => _busy = true);
    try {
      await _repository!.archive(original);
      if (_current()) {
        showToast(
            context, _live ? 'Target archived.' : 'Preview target archived.');
        await _load();
      }
    } catch (error) {
      if (_current()) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _invalidated = true;
    _goals = [];
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_current()) return const Text('Your session changed. Sign in again.');
    final enabled = !_loading && !_busy && !_invalidated && _error == null;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Eyebrow('Specific targets'),
      Text(
          _live
              ? 'Save measurable targets with clear units and periods. Actual progress is not available yet.'
              : 'Preview targets. Changes last for this screen only; no real progress is calculated.',
          style: Theme.of(context).textTheme.bodyMedium),
      const SizedBox(height: 12),
      if (_loading)
        const Center(child: CircularProgressIndicator())
      else if (_error != null) ...[
        Text(_error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error)),
        TextButton.icon(
            onPressed: _invalidated || _busy ? null : _load,
            icon: const Icon(Icons.refresh),
            label: const Text('Reload targets')),
      ] else ...[
        if (_goals.isEmpty)
          const Text('No active numeric targets. Add one when you are ready.'),
        ..._goals.map((goal) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Panel(
                child: Row(children: [
              const Icon(Icons.flag_rounded,
                  color: AppColors.primary, size: 20),
              const SizedBox(width: 14),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('${goal.category.label}: ${goal.targetLabel}',
                        style: Theme.of(context).textTheme.titleMedium),
                    Text(goal.category.periodLabel,
                        style: Theme.of(context).textTheme.bodyMedium),
                    Text('Actual: unavailable · Version ${goal.revision}',
                        style: Theme.of(context).textTheme.bodySmall),
                  ])),
              IconButton(
                  tooltip: 'Edit ${goal.category.label}',
                  icon: const Icon(Icons.edit_outlined, size: 19),
                  onPressed: enabled ? () => _edit(goal) : null),
              IconButton(
                  tooltip: 'Archive ${goal.category.label}',
                  icon: const Icon(Icons.archive_outlined, size: 19),
                  onPressed: enabled ? () => _archive(goal) : null),
            ])))),
        if (_goals.length >= 21)
          const Text(
              'Showing the first 21 active targets. Archive an existing target before adding another.'),
        OutlinedButton.icon(
            onPressed: enabled && _goals.length < 21 ? _edit : null,
            icon: const Icon(Icons.add_rounded, size: 20),
            label: const Text('Add a goal')),
        if (_live)
          TextButton.icon(
              onPressed: !_busy && !_invalidated ? _load : null,
              icon: const Icon(Icons.refresh),
              label: const Text('Reload targets')),
      ],
    ]);
  }
}

class _TargetEditor extends StatefulWidget {
  const _TargetEditor(
      {required this.id,
      required this.original,
      required this.repository,
      required this.isCurrent,
      required this.preview});
  final String id;
  final NumericFitnessGoal? original;
  final NumericFitnessGoalRepository repository;
  final bool Function() isCurrent;
  final bool preview;
  @override
  State<_TargetEditor> createState() => _TargetEditorState();
}

class _TargetEditorState extends State<_TargetEditor> {
  late NumericGoalCategory _category =
      widget.original?.category ?? NumericGoalCategory.trainingFrequency;
  late final _value = TextEditingController(
      text: widget.original == null ? '' : '${widget.original!.targetValue}');
  bool _saving = false;
  bool _allowClose = false, _confirmingDiscard = false;
  String? _error;
  bool _submitted = false;
  bool get _dirty =>
      _submitted ||
      _value.text.trim() !=
          (widget.original == null ? '' : '${widget.original!.targetValue}') ||
      _category !=
          (widget.original?.category ?? NumericGoalCategory.trainingFrequency);

  Future<void> _back(bool didPop) async {
    if (didPop || _saving || _confirmingDiscard) return;
    _confirmingDiscard = true;
    final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('Close target editor?'),
                content: Text(_submitted
                    ? 'A request without confirmation may already have saved. Reload targets after closing to check its status.'
                    : 'Your unsaved target will be discarded.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Keep editing')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Close editor'))
                ]));
    _confirmingDiscard = false;
    if (discard == true && mounted) {
      setState(() => _allowClose = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context, false);
      });
    }
  }

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !widget.isCurrent()) return;
    final raw = _value.text.trim();
    final value = double.tryParse(raw);
    final error =
        value == null ? 'Enter a numeric target.' : _category.validate(value);
    // Text precision is explicit too: scientific notation and extra zeros must
    // not slip past the domain's numeric precision check.
    final validText = _category == NumericGoalCategory.bodyWeight
        ? RegExp(r'^\d+(\.\d)?$').hasMatch(raw)
        : RegExp(r'^\d+(\.0)?$').hasMatch(raw);
    if (error != null || !validText) {
      setState(() => _error = error ??
          (_category == NumericGoalCategory.bodyWeight
              ? 'Use at most one decimal place.'
              : 'Enter a whole number.'));
      return;
    }
    if (widget.original != null && value == widget.original!.targetValue) {
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
      _submitted = true;
    });
    try {
      if (widget.original == null) {
        await widget.repository
            .create(id: widget.id, category: _category, targetValue: value!);
      } else {
        await widget.repository.update(widget.original!, targetValue: value!);
      }
      if (mounted && widget.isCurrent()) Navigator.pop(context, true);
    } catch (e) {
      if (mounted && widget.isCurrent()) {
        setState(() => _error = e is NumericGoalException
            ? '${e.message}${e.reloadRequired ? ' If this is an edit, close and reload before retrying.' : ''}'
            : 'Save was not confirmed. Retry this same form.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !_saving && (!_dirty || _allowClose),
      onPopInvokedWithResult: (didPop, _) => _back(didPop),
      child: AlertDialog(
          title: Text(
              widget.original == null ? 'Add a numeric target' : 'Edit target'),
          content: SingleChildScrollView(
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                DropdownButtonFormField<NumericGoalCategory>(
                    initialValue: _category,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: NumericGoalCategory.values
                        .map((c) =>
                            DropdownMenuItem(value: c, child: Text(c.label)))
                        .toList(),
                    onChanged: _saving || widget.original != null || _submitted
                        ? null
                        : (c) {
                            if (c != null) {
                              setState(() {
                                _category = c;
                                _value.clear();
                                _error = null;
                              });
                            }
                          }),
                const SizedBox(height: 12),
                Text(_category.periodLabel),
                TextFormField(
                    controller: _value,
                    onChanged: (_) => setState(() {}),
                    enabled: !_saving && !_submitted,
                    keyboardType: TextInputType.numberWithOptions(
                        decimal: _category == NumericGoalCategory.bodyWeight),
                    decoration: InputDecoration(
                        labelText: 'Target (${_category.unit})',
                        helperText:
                            '${_category.minimum.toInt()}–${_category.maximum.toInt()} ${_category.unit}',
                        errorText: _error),
                    onFieldSubmitted: (_) => _save()),
                const SizedBox(height: 12),
                const Text(
                    'Your target is an intention. Actual performance and achievement are unavailable.'),
                if (_submitted && !_saving)
                  const Text(
                      'The submitted value is kept unchanged for a safe retry. Close and reopen to choose a different value.'),
              ])),
          actions: [
            TextButton(
                onPressed: _saving
                    ? null
                    : () {
                        if (_dirty) {
                          _back(false);
                        } else {
                          Navigator.pop(context, false);
                        }
                      },
                child: const Text('Cancel')),
            FilledButton(
                onPressed: _saving ||
                        !widget.isCurrent() ||
                        (widget.original != null &&
                            double.tryParse(_value.text.trim()) ==
                                widget.original!.targetValue)
                    ? null
                    : _save,
                child: Text(_saving
                    ? 'Saving…'
                    : widget.preview
                        ? 'Save preview'
                        : 'Save target'))
          ]));
}

/// Deliberately screen-local: no prototype data can be mistaken for Firebase.
class _PreviewGoals implements NumericFitnessGoalRepository {
  @override
  final scope = SessionScope(userId: 'preview', organizationId: 'preview');
  final Map<String, NumericFitnessGoal> _goals = {};
  int _next = 0;
  @override
  String allocateId() => 'preview-${++_next}';
  @override
  Future<List<NumericFitnessGoal>> loadActive() async =>
      _goals.values.where((g) => g.status == NumericGoalStatus.active).toList();
  @override
  Future<void> create(
      {required String id,
      required NumericGoalCategory category,
      required double targetValue}) async {
    if (_goals.containsKey(id)) return;
    _goals[id] = NumericFitnessGoal(
        id: id,
        category: category,
        targetValue: targetValue,
        status: NumericGoalStatus.active,
        revision: 1,
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc());
  }

  Future<void> _change(NumericFitnessGoal original, double value,
      NumericGoalStatus status) async {
    if (_goals[original.id]?.revision != original.revision) {
      throw const NumericGoalException('Reload targets.', reloadRequired: true);
    }
    _goals[original.id] = NumericFitnessGoal(
        id: original.id,
        category: original.category,
        targetValue: value,
        status: status,
        revision: original.revision + 1,
        createdAt: original.createdAt,
        updatedAt: DateTime.now().toUtc());
  }

  @override
  Future<void> update(NumericFitnessGoal original,
          {required double targetValue}) =>
      _change(original, targetValue, original.status);
  @override
  Future<void> archive(NumericFitnessGoal original) =>
      _change(original, original.targetValue, NumericGoalStatus.archived);
}
