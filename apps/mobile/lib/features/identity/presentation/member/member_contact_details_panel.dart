import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_identity/gainpath_identity.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../../../infrastructure/firebase/firebase_member_contact_details_repository.dart';

class MemberContactDetailsPanel extends StatefulWidget {
  const MemberContactDetailsPanel({super.key, this.session, this.repository});
  final AuthSession? session;
  final MemberContactDetailsRepository? repository;
  @override
  State<MemberContactDetailsPanel> createState() =>
      _MemberContactDetailsPanelState();
}

class _MemberContactDetailsPanelState extends State<MemberContactDetailsPanel> {
  final _text = TextEditingController();
  MemberContactDetailsRepository? _repository;
  MemberContactDetails? _original;
  AuthBloc? _auth;
  StreamSubscription<AuthState>? _subscription;
  bool _initialized = false,
      _busy = false,
      _invalidated = false,
      _reloadRequired = false;
  String? _error, _status;
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
            _original = null;
            _error = 'Your session changed. Sign in again.';
            _status = null;
          });
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
        _reloadRequired = false;
      });
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
        _status = _repository == null
            ? 'Saved in Mock Mode.'
            : 'Contact details saved.';
      });
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

  @override
  void dispose() {
    _invalidated = true;
    unawaited(_subscription?.cancel());
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Panel(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextField(
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
                        : () => setState(_text.clear),
                    icon: const Icon(Icons.clear))),
            onChanged: (_) => setState(() => _status = null)),
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
      ]));
}
