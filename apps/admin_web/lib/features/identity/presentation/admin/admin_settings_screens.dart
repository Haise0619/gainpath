import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:typed_data';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show AuthSession;

/// AD-M11.2 — Admin Session and Settings. Distinct from AD-M11.6's
/// platform-wide configuration: this is the signed-in admin's own contact
/// details, notifications, and password — not something every staff member
/// shares.
class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key, this.liveSession, this.onSaved});
  final AuthSession? liveSession;
  final VoidCallback? onSaved;

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  final _name = TextEditingController();
  final _workEmail = TextEditingController();
  AdminAccountContact? _original;
  bool _started = false, _loading = false, _saving = false, _blocked = false;
  String? _error;
  AccountPhoto? _selectedPhoto;
  Uint8List? _savedPhoto;
  bool _removePhoto = false, _picking = false, _loadingPhoto = false;
  String? _photoError;
  int _photoGeneration = 0;
  bool get _live => widget.liveSession != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (_live) {
      _workEmail.text = widget.liveSession!.email;
      _load();
    } else {
      final accounts = context.read<UserAccountRepository>();
      _name.text = accounts.adminName;
      _workEmail.text = accounts.adminEmail;
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _blocked = true;
      _error = null;
    });
    try {
      final value = await context.read<AdminAccountContactRepository>().load();
      if (!mounted) return;
      setState(() {
        _original = value;
        _push = value.notificationPreferences?['pushAlerts'] ?? false;
        _email = value.notificationPreferences?['emailAlerts'] ?? false;
        _weeklyDigest = value.notificationPreferences?['weeklyDigest'] ?? false;
        _name.text = value.displayName;
        _workEmail.text = value.email;
        _blocked = false;
        _selectedPhoto = null;
        _removePhoto = false;
      });
      unawaited(_loadPhoto(value));
    } catch (_) {
      if (mounted) {
        setState(() =>
            _error = 'Could not load your account. Check access and reload.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadPhoto(AdminAccountContact value) async {
    final generation = ++_photoGeneration;
    setState(() {
      _savedPhoto = null;
      _loadingPhoto = true;
      _photoError = null;
    });
    try {
      final bytes =
          await context.read<AdminAccountContactRepository>().readPhoto(value);
      if (mounted && generation == _photoGeneration) {
        setState(() => _savedPhoto = bytes);
      }
    } catch (_) {
      if (mounted && generation == _photoGeneration) {
        setState(() => _photoError =
            'Your saved photo could not be loaded. Reload to retry.');
      }
    } finally {
      if (mounted && generation == _photoGeneration) {
        setState(() => _loadingPhoto = false);
      }
    }
  }

  Future<void> _pickPhoto() async {
    setState(() {
      _picking = true;
      _photoError = null;
    });
    try {
      final photo = await context.read<AccountPhotoPicker>().pick();
      if (mounted && photo != null) {
        setState(() {
          _selectedPhoto = photo;
          _removePhoto = false;
        });
      }
    } on FormatException catch (e) {
      if (mounted) setState(() => _photoError = e.message);
    } catch (_) {
      if (mounted) {
        setState(() =>
            _photoError = 'Could not open the photo. Choose another image.');
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _save() async {
    if (_original == null || _loading || _saving || _picking || _blocked) {
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final photoChanged = _selectedPhoto != null || _removePhoto;
    try {
      final saved = await context.read<AdminAccountContactRepository>().save(
          _original!,
          displayName: _name.text,
          photo: _selectedPhoto,
          removePhoto: _removePhoto);
      if (!mounted) return;
      setState(() {
        _original = saved;
        _name.text = saved.displayName;
        _selectedPhoto = null;
        _removePhoto = false;
      });
      unawaited(_loadPhoto(saved));
      showToast(context,
          photoChanged ? 'Account photo saved.' : 'Account name saved.');
      if (widget.onSaved != null) {
        if (Navigator.of(context).canPop()) Navigator.pop(context);
        widget.onSaved!();
      }
    } on AccountPhotoUnavailable {
      if (mounted) {
        setState(() => _error =
            'The photo could not be uploaded. Check access and try again.');
      }
    } on FormatException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on AdminAccountContactConflict {
      if (mounted) {
        setState(() {
          _blocked = true;
          _error = 'Your account changed. Reload before saving again.';
        });
      }
    } on AdminAccountContactSessionChanged {
      if (mounted) {
        setState(() {
          _blocked = true;
          _error = 'Account or permissions changed. Sign in again.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _blocked = true;
          _error =
              'Save could not be verified. Reload to check your saved name.';
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveNotifications() async {
    if (_original == null || _loading || _saving || _blocked || _picking) {
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saved = await context
          .read<AdminAccountContactRepository>()
          .saveNotificationPreferences(_original!,
              pushAlerts: _push,
              emailAlerts: _email,
              weeklyDigest: _weeklyDigest);
      if (!mounted) return;
      setState(() => _original = saved);
      showToast(
          context, 'Notification preferences saved. Delivery is unavailable.');
    } catch (_) {
      if (mounted) {
        setState(() {
          _blocked = true;
          _error =
              'Preferences could not be verified. Reload your account before saving again.';
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _photoGeneration++;
    _name.dispose();
    _workEmail.dispose();
    super.dispose();
  }

  bool _push = true;
  bool _email = true;
  bool _weeklyDigest = false;

  Widget _photoEditor() {
    final bytes = _removePhoto ? null : _selectedPhoto?.bytes ?? _savedPhoto;
    final disabled = _loading || _saving || _picking || _blocked;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Eyebrow('Profile photo'),
      Panel(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CircleAvatar(
            radius: 48,
            backgroundColor: AppColors.primaryTint,
            child: bytes == null
                ? const Icon(Icons.person_rounded,
                    size: 40, color: AppColors.primary)
                : ClipOval(
                    child: Image.memory(bytes,
                        width: 96,
                        height: 96,
                        fit: BoxFit.cover,
                        cacheWidth: 192,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.person_rounded, size: 40)))),
        const SizedBox(height: 12),
        if (_loadingPhoto && _selectedPhoto == null && !_removePhoto)
          const LinearProgressIndicator(),
        Text(_removePhoto
            ? 'Photo will be removed when you save.'
            : _selectedPhoto != null
                ? 'New photo selected. Save modifications to upload it.'
                : _original?.avatarPath.isNotEmpty == true
                    ? 'Your saved private photo.'
                    : 'No profile photo saved.'),
        const SizedBox(height: 8),
        const Text(
            'JPG, PNG or WebP · up to 5 MB · visible only to your account.'),
        if (_photoError != null)
          Text(_photoError!, style: const TextStyle(color: AppColors.danger)),
        const SizedBox(height: 12),
        Wrap(spacing: 12, runSpacing: 8, children: [
          OutlinedButton(
              onPressed: disabled ? null : _pickPhoto,
              child: Text(_picking ? 'Choosing…' : 'Choose photo')),
          if (!_removePhoto &&
              (_selectedPhoto != null ||
                  _original?.avatarPath.isNotEmpty == true))
            TextButton(
                onPressed: disabled
                    ? null
                    : () => setState(() {
                          _selectedPhoto = null;
                          _removePhoto = true;
                        }),
                child: const Text('Remove photo')),
        ]),
      ])),
      const SizedBox(height: 18),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _live ? AppBar(title: const Text('My account')) : null,
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 520,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Expanded(child: Eyebrow('Contact details')),
                    if (_live)
                      IconButton(
                          tooltip: 'Reload account',
                          onPressed: _loading || _saving ? null : _load,
                          icon: const Icon(Icons.refresh)),
                  ]),
                  if (_loading) const LinearProgressIndicator(),
                  if (_error != null)
                    Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(_error!,
                            style: const TextStyle(color: AppColors.danger))),
                  if (_live) _photoEditor(),
                  Panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _name,
                          enabled:
                              !_live || (!_loading && !_saving && !_blocked),
                          maxLength: _live ? 80 : null,
                          decoration: InputDecoration(
                              labelText: 'Full name',
                              helperText: _live
                                  ? 'Optional. Clear to use your sign-in email.'
                                  : null),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _workEmail,
                          readOnly: _live,
                          decoration: InputDecoration(
                              labelText: 'Work email',
                              helperText: _live
                                  ? 'Your sign-in email is read-only here.'
                                  : null),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Eyebrow('Notifications'),
                  if (_live)
                    const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Text(
                            'Save your choices here. Notification delivery is unavailable.')),
                  Panel(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        SwitchListTile(
                          value: _push,
                          onChanged: _live && (_loading || _saving || _blocked)
                              ? null
                              : (v) => setState(() => _push = v),
                          title: const Text('Push alerts'),
                          subtitle: Text(_live
                              ? 'Stored preference only'
                              : 'Refund requests, pending verifications'),
                        ),
                        const Divider(height: 1),
                        SwitchListTile(
                          value: _email,
                          onChanged: _live && (_loading || _saving || _blocked)
                              ? null
                              : (v) => setState(() => _email = v),
                          title: const Text('Email alerts'),
                          subtitle: Text(_live
                              ? 'Stored preference only'
                              : 'Same events, sent to your inbox'),
                        ),
                        const Divider(height: 1),
                        SwitchListTile(
                          value: _weeklyDigest,
                          onChanged: _live && (_loading || _saving || _blocked)
                              ? null
                              : (v) => setState(() => _weeklyDigest = v),
                          title: const Text('Weekly digest'),
                          subtitle: Text(_live
                              ? 'Stored preference only'
                              : 'Facility summary every Monday'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (_live) ...[
                    Text(_original?.notificationPreferences == null
                        ? 'No notification choices saved yet.'
                        : 'Your saved choices are stored privately.'),
                    const SizedBox(height: 8),
                    OutlinedButton(
                        onPressed: _loading || _saving || _blocked || _picking
                            ? null
                            : _saveNotifications,
                        child: const Text('Save notification preferences')),
                    const SizedBox(height: 18),
                  ],
                  const Eyebrow('Security'),
                  Panel(
                    padding: EdgeInsets.zero,
                    child: ListTile(
                      leading: const Icon(Icons.lock_outline_rounded),
                      title: const Text('Change password'),
                      enabled: !_live,
                      subtitle: _live
                          ? const Text('Password changes are unavailable here.')
                          : null,
                      trailing:
                          const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                      onTap: _live
                          ? null
                          : () =>
                              showChangePasswordSheet(context, asDialog: true),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _live
                        ? _loading || _saving || _picking || _blocked
                            ? null
                            : _save
                        : () {
                            Navigator.pop(context);
                            showToast(context, 'Settings saved.');
                          },
                    child: Text(_saving ? 'Saving…' : 'Save modifications'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// SystemSettingsScreen (AD-M11.6) now lives at settings/system_settings_screen.dart
// as an in-place sidebar pane rather than a screen pushed from here.
