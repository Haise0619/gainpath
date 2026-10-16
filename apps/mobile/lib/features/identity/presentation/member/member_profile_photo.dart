import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_data/gainpath_data.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_identity/gainpath_identity.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../../../infrastructure/firebase/firebase_member_photo_gateway.dart';
import '../../../../infrastructure/firebase/firebase_member_photo_store.dart';
import '../../../../infrastructure/local/account_photo_picker.dart';

/// Existing Profile avatar/camera, with a private own-account editor.
class MemberProfilePhoto extends StatefulWidget {
  const MemberProfilePhoto(
      {super.key, this.session, this.repository, this.picker});
  final AuthSession? session;
  final MemberPhotoRepository? repository;
  final AccountPhotoPicker? picker;
  @override
  State<MemberProfilePhoto> createState() => _MemberProfilePhotoState();
}

class _MemberProfilePhotoState extends State<MemberProfilePhoto> {
  MemberPhotoRepository? _repository;
  AuthBloc? _auth;
  StreamSubscription<AuthState>? _subscription;
  MemberPhoto? _original;
  Uint8List? _bytes;
  String? _error;
  bool _loading = false, _invalidated = false, _initialized = false;
  bool get _live => widget.session != null || widget.repository != null;
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
            _bytes = null;
            _original = null;
            _error = 'Your session changed. Sign in again.';
          });
        }
      });
    }
    _repository = widget.repository;
    if (widget.session != null && _repository == null) {
      final scope = widget.session!.scope;
      _repository = FirebaseMemberPhotoRepository(
          scope: scope,
          isCurrent: _current,
          gateway: FlutterMemberPhotoGateway(scope: scope, isCurrent: _current),
          photos: FirebaseAccountPhotoStore(scope: scope, isCurrent: _current));
    }
    if (_live) unawaited(_load());
  }

  Future<void> _load() async {
    if (!_current()) return;
    setState(() {
      _loading = true;
      _original = null;
      _error = null;
      _bytes = null;
    });
    try {
      final original = await _repository!.load();
      if (!_current()) return;
      setState(() => _original = original);
      final bytes = await _repository!.readPhoto(original);
      if (!_current()) return;
      setState(() {
        _original = original;
        _bytes = bytes;
      });
    } catch (e) {
      if (_current()) {
        setState(() => _error = e is MemberPhotoException
            ? e.message
            : 'Photo unavailable. Check your connection and retry.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit() async {
    if (!_current() || _loading) return;
    if (_live) {
      await _load();
      if (!_current() || _original == null) return;
    }
    final changed = await showDialog<_PhotoEditResult>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _MemberPhotoEditor(
            original: _original,
            bytes: _bytes,
            repository: _repository,
            picker: widget.picker ?? LocalAccountPhotoPicker(),
            isCurrent: _current));
    if (!_current() || changed == null) return;
    if (_live) {
      await _load();
    } else {
      setState(() => _bytes = changed.bytes);
    }
  }

  @override
  void dispose() {
    _invalidated = true;
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Stack(clipBehavior: Clip.none, children: [
          Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                  gradient: AppColors.heroGradient,
                  borderRadius: BorderRadius.circular(18)),
              clipBehavior: Clip.antiAlias,
              child: _bytes == null
                  ? Center(
                      child: Text(
                          widget.session == null
                              ? 'ZY'
                              : widget.session!.email
                                  .substring(0, 1)
                                  .toUpperCase(),
                          style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)))
                  : Image.memory(_bytes!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.person, color: Colors.white))),
          Positioned(
              right: -4,
              bottom: -4,
              child: Material(
                  color: AppColors.surface,
                  shape: const CircleBorder(),
                  elevation: 1,
                  child: IconButton(
                      tooltip: 'Edit profile picture',
                      visualDensity: VisualDensity.compact,
                      onPressed: _loading || _invalidated ? null : _edit,
                      icon: const Icon(Icons.camera_alt_rounded,
                          size: 16, color: AppColors.primary)))),
        ]),
        if (_loading)
          const SizedBox(width: 60, child: LinearProgressIndicator()),
        if (_error != null)
          SizedBox(
              width: 76,
              child: TextButton(
                  onPressed: _invalidated ? null : _load,
                  child: const Text('Retry photo'))),
      ]);
}

class _PhotoEditResult {
  const _PhotoEditResult(this.bytes);
  final Uint8List? bytes;
}

class _MemberPhotoEditor extends StatefulWidget {
  const _MemberPhotoEditor(
      {required this.original,
      required this.bytes,
      required this.repository,
      required this.picker,
      required this.isCurrent});
  final MemberPhoto? original;
  final Uint8List? bytes;
  final MemberPhotoRepository? repository;
  final AccountPhotoPicker picker;
  final bool Function() isCurrent;
  @override
  State<_MemberPhotoEditor> createState() => _MemberPhotoEditorState();
}

class _MemberPhotoEditorState extends State<_MemberPhotoEditor> {
  AccountPhoto? _selected;
  bool _remove = false, _busy = false, _reloadRequired = false;
  String? _error;
  Uint8List? get _preview => _remove ? null : _selected?.bytes ?? widget.bytes;
  Future<void> _pick() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final selected = await widget.picker.pick();
      if (!mounted || !widget.isCurrent()) return;
      if (selected != null) {
        setState(() {
          _selected = selected;
          _remove = false;
        });
      }
    } on FormatException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Could not open that image. Choose another JPG, PNG or WebP.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (!widget.isCurrent()) {
      setState(() {
        _error = 'Your session changed. Close and sign in again.';
        _reloadRequired = true;
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (widget.repository != null) {
        await widget.repository!
            .save(widget.original!, photo: _selected, remove: _remove);
      }
      if (!mounted) return;
      if (!widget.isCurrent()) {
        throw const MemberPhotoException(
            'Your session changed. Close and sign in again.',
            reloadRequired: true);
      }
      Navigator.pop(context, _PhotoEditResult(_preview));
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e is MemberPhotoException
              ? e.message
              : 'Save was not confirmed. Close and reopen your photo before retrying.';
          // A failed write may have committed; never resubmit an uncertain baseline.
          _reloadRequired = true;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !_busy,
      child: AlertDialog(
        title: const Text('Profile picture'),
        content: SizedBox(
            width: 300,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(
                  width: 128,
                  height: 128,
                  child: _preview == null
                      ? const Icon(Icons.person, size: 96)
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Image.memory(_preview!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const Icon(Icons.broken_image)))),
              const SizedBox(height: 12),
              const Text('JPG, PNG or WebP · up to 5 MB and 24 megapixels'),
              if (widget.repository == null)
                const Text('Mock Mode: photo stays in this session.'),
              TextButton.icon(
                  onPressed: _busy || _reloadRequired ? null : _pick,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Choose image')),
              TextButton(
                  onPressed: _busy || _reloadRequired || _remove ||
                      (_preview == null && (widget.original?.path.isEmpty ?? true))
                      ? null
                      : () => setState(() {
                            _selected = null;
                            _remove = true;
                            _error = null;
                          }),
                  child: const Text('Remove picture')),
              if (_busy) const LinearProgressIndicator(),
              if (_error != null)
                Text(_error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
            ])),
        actions: [
          TextButton(
              onPressed: _busy ? null : () => Navigator.pop(context),
              child: const Text('Close')),
          FilledButton(
              onPressed:
                  _busy || _reloadRequired || (_selected == null && !_remove)
                      ? null
                      : _save,
              child: const Text('Save picture'))
        ],
      ));
}
