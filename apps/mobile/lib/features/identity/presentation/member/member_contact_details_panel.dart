import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_identity/gainpath_identity.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../../../infrastructure/firebase/firebase_member_contact_details_repository.dart';
import 'module1_edit_guard.dart';

class MemberContactDetailsPanel extends StatefulWidget {
  const MemberContactDetailsPanel(
      {super.key,
      this.session,
      this.repository,
      this.onDisplayNameSaved,
      this.onDirtyChanged});
  final AuthSession? session;
  final MemberContactDetailsRepository? repository;
  final ValueChanged<String>? onDisplayNameSaved;
  final ValueChanged<bool>? onDirtyChanged;
  @override
  State<MemberContactDetailsPanel> createState() =>
      _MemberContactDetailsPanelState();
}

class _MemberContactDetailsPanelState extends State<MemberContactDetailsPanel> {
  final _text = TextEditingController();
  final _name = TextEditingController();
  MemberContactDetailsRepository? _repository;
  MemberContactDetails? _original;
  AuthBloc? _auth;
  StreamSubscription<AuthState>? _subscription;
  bool _initialized = false,
      _busy = false,
      _invalidated = false,
      _reloadRequired = false;
  String? _error, _status;
  String _mockContact = '', _mockName = '';
  bool get _dirty =>
      !_invalidated &&
      (_text.text != (_original?.value ?? _mockContact) ||
          _name.text != (_original?.displayName ?? _mockName));
  void _changed() {
    setState(() => _status = null);
    widget.onDirtyChanged?.call(_dirty);
  }

  bool _current() {
    if (widget.session != null &&
        (_auth?.state.session != widget.session ||
            !AuthRolePolicy.canEnter(_auth!.state,
                allowed: const {AppRole.member}))) {
      _invalidated = true;
    }
    return mounted && !_invalidated;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    if (widget.session != null) {
      _auth = context.read<AuthBloc>();
      _subscription = _auth!.stream.listen((_) {
        if (!_current() && mounted) {
          setState(() {
            _text.clear();
            _name.clear();
            _original = null;
            _error = 'Your session changed. Sign in again.';
            _status = null;
          });
          widget.onDirtyChanged?.call(false);
        }
      });
    }
    _repository = widget.repository;
    if (widget.session != null && _repository == null) {
      _repository = FirebaseMemberContactDetailsRepository(
          scope: widget.session!.scope, isCurrent: _current);
    }
    if (_repository != null) unawaited(_load());
  }

  Future<void> _load() async {
    if (!_current()) return;
    setState(() {
      _busy = true;
      _error = null;
      _status = null;
    });
    try {
      final saved = await _repository!.load();
      if (!_current()) return;
      setState(() {
        _original = saved;
        _text.text = saved.value;
        _name.text = saved.displayName;
        _reloadRequired = false;
      });
      widget.onDirtyChanged?.call(_dirty);
    } catch (e) {
      if (_current()) {
        setState(() {
          _error = e is MemberContactDetailsException
              ? e.message
              : 'Contact details unavailable. Check your connection and retry.';
          _reloadRequired = true;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (!_current() || _busy || _reloadRequired) return;
    final value = _text.text;
    if (value.trim().runes.length > 200 ||
        RegExp(r'[\x00-\x1f\x7f]').hasMatch(value)) {
      setState(() => _error =
          'Use up to 200 characters without line breaks or control characters.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _status = null;
    });
    try {
      final saved = _repository == null
          ? null
          : await _repository!.save(_original!, value);
      if (!_current()) return;
      setState(() {
        _original = saved;
        _text.text = saved?.value ?? value.trim();
        _mockContact = _text.text;
        _status = _repository == null
            ? 'Saved in Mock Mode.'
            : 'Contact details saved.';
      });
      widget.onDirtyChanged?.call(_dirty);
    } catch (e) {
      if (_current()) {
        setState(() {
          _error = e is MemberContactDetailsException
              ? e.message
              : 'Save was not confirmed. Reload contact details before retrying.';
          _reloadRequired =
              e is! MemberContactDetailsException || e.reloadRequired;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveName() async {
    if (!_current() || _busy || _reloadRequired) return;
    final value = _name.text;
    if (value.trim().isEmpty ||
        value.trim().runes.length > 120 ||
        RegExp(r'[\x00-\x1f\x7f]').hasMatch(value)) {
      setState(() => _error =
          'Use a display name of 1–120 characters without line breaks or control characters.');
      return;
    }
    if (_repository != null && _text.text != _original!.value) {
      setState(() => _error =
          'Save your contact changes before changing your display name.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _status = null;
    });
    try {
      final saved = _repository == null
          ? null
          : await (_repository as MemberDisplayNameRepository)
              .saveDisplayName(_original!, value);
      if (!_current()) return;
      final confirmed = saved?.displayName ?? value.trim();
      setState(() {
        _original = saved;
        _name.text = confirmed;
        _mockName = confirmed;
        _status =
            _repository == null ? 'Saved in Mock Mode.' : 'Display name saved.';
      });
      widget.onDirtyChanged?.call(_dirty);
      if (widget.onDisplayNameSaved != null) {
        widget.onDisplayNameSaved!(confirmed);
      } else if (_auth != null) {
        // Reuse the existing authoritative account restore, rather than editing
        // AuthSession or Firebase Auth metadata with a client-supplied name.
        final auth = _auth!;
        if (Navigator.of(context).canPop()) Navigator.pop(context);
        auth.add(const AuthRestoreRequested());
      }
    } catch (e) {
      if (_current()) {
        setState(() {
          _error = e is MemberContactDetailsException
              ? e.message
              : 'Save was not confirmed. Reload account details before retrying.';
          _reloadRequired =
              e is! MemberContactDetailsException || e.reloadRequired;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _invalidated = true;
    unawaited(_subscription?.cancel());
    _text.dispose();
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Module1EditGuard(
      dirty: _dirty,
      busy: _busy,
      child: Panel(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (_repository == null ||
            _repository is MemberDisplayNameRepository) ...[
          TextField(
              key: const ValueKey('member-display-name'),
              controller: _name,
              enabled: !_busy && !_reloadRequired && !_invalidated,
              maxLength: 120,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                  labelText: 'Display name',
                  helperText: 'Used on your profile and Home greeting.',
                  helperMaxLines: 2),
              onChanged: (_) => _changed()),
          FilledButton(
              onPressed: _busy ||
                      _reloadRequired ||
                      _invalidated ||
                      (_repository != null && _original == null)
                  ? null
                  : _saveName,
              child: const Text('Save display name')),
          const SizedBox(height: 18),
          const Divider(),
        ],
        TextField(
            key: const ValueKey('member-contact-details'),
            controller: _text,
            enabled: !_busy && !_reloadRequired && !_invalidated,
            maxLength: 200,
            textCapitalization: TextCapitalization.none,
            autocorrect: false,
            decoration: InputDecoration(
                labelText: 'Contact details',
                helperText:
                    'Optional contact information, such as a phone number.',
                helperMaxLines: 2,
                suffixIcon: IconButton(
                    tooltip: 'Clear contact details',
                    onPressed: _busy || _reloadRequired || _invalidated
                        ? null
                        : () {
                            _text.clear();
                            _changed();
                          },
                    icon: const Icon(Icons.clear))),
            onChanged: (_) => _changed()),
        if (_busy) const LinearProgressIndicator(),
        if (_error != null)
          Text(_error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
        if (_status != null) Text(_status!),
        if (_reloadRequired && !_invalidated)
          TextButton(
              onPressed: _busy ? null : _load,
              child: const Text('Reload contact details')),
        const SizedBox(height: 8),
        FilledButton(
            onPressed: _busy ||
                    _reloadRequired ||
                    _invalidated ||
                    (_repository != null && _original == null)
                ? null
                : _save,
            child: const Text('Save contact details')),
      ])));
}
