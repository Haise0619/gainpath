import 'package:flutter/material.dart';
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
        _name.text = value.displayName;
        _workEmail.text = value.email;
        _blocked = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() =>
            _error = 'Could not load your account. Check access and reload.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_original == null || _loading || _saving || _blocked) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saved = await context
          .read<AdminAccountContactRepository>()
          .save(_original!, displayName: _name.text);
      if (!mounted) return;
      setState(() {
        _original = saved;
        _name.text = saved.displayName;
      });
      showToast(context, 'Account name saved.');
      if (widget.onSaved != null) {
        if (Navigator.of(context).canPop()) Navigator.pop(context);
        widget.onSaved!();
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

  @override
  void dispose() {
    _name.dispose();
    _workEmail.dispose();
    super.dispose();
  }

  bool _push = true;
  bool _email = true;
  bool _weeklyDigest = false;

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
                            'Notification preferences and delivery are not connected yet.')),
                  Panel(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        SwitchListTile(
                          value: _live ? false : _push,
                          onChanged:
                              _live ? null : (v) => setState(() => _push = v),
                          title: const Text('Push alerts'),
                          subtitle: const Text(
                              'Refund requests, pending verifications'),
                        ),
                        const Divider(height: 1),
                        SwitchListTile(
                          value: _live ? false : _email,
                          onChanged:
                              _live ? null : (v) => setState(() => _email = v),
                          title: const Text('Email alerts'),
                          subtitle:
                              const Text('Same events, sent to your inbox'),
                        ),
                        const Divider(height: 1),
                        SwitchListTile(
                          value: _live ? false : _weeklyDigest,
                          onChanged: _live
                              ? null
                              : (v) => setState(() => _weeklyDigest = v),
                          title: const Text('Weekly digest'),
                          subtitle: const Text('Facility summary every Monday'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
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
                        ? _loading || _saving || _blocked
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
