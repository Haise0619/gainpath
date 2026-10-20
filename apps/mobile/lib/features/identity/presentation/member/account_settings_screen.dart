import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_domain/identity.dart';
import 'member_contact_details_panel.dart';
import 'member_deactivation_dialog.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_identity/gainpath_identity.dart';

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen(
      {super.key,
      this.repository,
      this.contactSession,
      this.contactRepository,
      this.lifecycleRepository,
      this.onAccountDeactivated,
      this.verifyCurrentPassword,
      this.saveNewPassword});

  final MemberPreferencesRepository? repository;
  final AuthSession? contactSession;
  final MemberContactDetailsRepository? contactRepository;
  final MemberAccountLifecycleRepository? lifecycleRepository;
  final VoidCallback? onAccountDeactivated;
  final Future<void> Function(String)? verifyCurrentPassword;
  final Future<void> Function(String)? saveNewPassword;

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  bool _push = true;
  bool _email = false;
  bool _voice = true;
  bool _loading = false;
  bool _saving = false;
  String? _loadError;
  MemberPreferences? _loadedPreferences;
  bool _reloadRequired = false;

  @override
  void initState() {
    super.initState();
    if (widget.repository != null) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final value = await widget.repository!.load();
      if (!mounted) return;
      setState(() {
        _push = value.pushNotifications;
        _email = value.emailUpdates;
        _voice = value.voiceCoaching;
        _loadedPreferences = value;
        _reloadRequired = false;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = error is MemberPreferencesException
            ? error.message
            : 'Could not load settings. Please retry.';
      });
    }
  }

  Future<void> _change(MemberPreferences next) async {
    if (_saving || _reloadRequired) return;
    setState(() => _saving = true);
    try {
      await widget.repository!.save(next);
      if (!mounted) return;
      MemberPreferences confirmed;
      try {
        confirmed = await widget.repository!.load();
      } catch (_) {
        throw const MemberPreferencesException(
            'The save could not be verified. Reload settings before trying again.',
            reloadRequired: true);
      }
      if (!mounted) return;
      setState(() {
        _push = confirmed.pushNotifications;
        _email = confirmed.emailUpdates;
        _voice = confirmed.voiceCoaching;
        _loadedPreferences = confirmed;
        _saving = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _reloadRequired =
            error is MemberPreferencesException && error.reloadRequired;
      });
      showToast(
          context,
          error is MemberPreferencesException
              ? error.message
              : 'Could not save settings. Please retry.');
    }
  }

  MemberPreferences get _current => MemberPreferences(
      pushNotifications: _push,
      emailUpdates: _email,
      voiceCoaching: _voice,
      editBaseline: _loadedPreferences?.editBaseline);

  Future<void> _deactivate() async {
    final repository = widget.lifecycleRepository;
    if (repository == null) return;
    final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => MemberDeactivationDialog(repository: repository));
    if (!mounted || confirmed != true) return;
    if (widget.onAccountDeactivated != null) {
      widget.onAccountDeactivated!();
    } else {
      context.read<AuthBloc>().add(const LoggedOut());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(_loadError!, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _load, child: const Text('Retry'))
                ]))
              : PageBody(
                  children: [
                    if (widget.contactSession != null ||
                        widget.contactRepository != null ||
                        widget.repository == null) ...[
                      const Eyebrow('Account'),
                      MemberContactDetailsPanel(
                          key: ValueKey(widget.contactSession),
                          session: widget.contactSession,
                          repository: widget.contactRepository),
                      const SizedBox(height: 18),
                    ],
                    if (_reloadRequired) ...[
                      const Text(
                          'Reload saved settings before making another change.'),
                      TextButton(
                          onPressed: _load,
                          child: const Text('Reload settings')),
                    ],
                    const Eyebrow('Notifications'),
                    if (widget.repository != null) ...[
                      const Text(
                          'Your choices are saved. Notification delivery and voice coaching are not active yet.'),
                      const SizedBox(height: 12),
                    ],
                    Panel(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          SwitchListTile(
                            value: _push,
                            onChanged: _saving || _reloadRequired
                                ? null
                                : (v) => widget.repository == null
                                    ? setState(() => _push = v)
                                    : _change(_current.copyWith(
                                        pushNotifications: v)),
                            title: const Text('Push notifications'),
                            subtitle: const Text(
                                'Session reminders and streak alerts'),
                          ),
                          const Divider(height: 1),
                          SwitchListTile(
                            value: _email,
                            onChanged: _saving || _reloadRequired
                                ? null
                                : (v) => widget.repository == null
                                    ? setState(() => _email = v)
                                    : _change(
                                        _current.copyWith(emailUpdates: v)),
                            title: const Text('Email updates'),
                            subtitle: const Text('Weekly progress summary'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Eyebrow('Workout'),
                    Panel(
                      padding: EdgeInsets.zero,
                      child: SwitchListTile(
                        value: _voice,
                        onChanged: _saving || _reloadRequired
                            ? null
                            : (v) => widget.repository == null
                                ? setState(() => _voice = v)
                                : _change(_current.copyWith(voiceCoaching: v)),
                        title: const Text('Voice coaching'),
                        subtitle:
                            const Text('Spoken cues during tracked sessions'),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Eyebrow('Security'),
                    Panel(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          ListTile(
                            leading: const Icon(Icons.lock_outline_rounded),
                            title: const Text('Change password'),
                            trailing: const Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 14),
                            onTap: () {
                              if (widget.repository != null &&
                                  (widget.verifyCurrentPassword == null ||
                                      widget.saveNewPassword == null)) {
                                showUnavailable(context);
                                return;
                              }
                              showChangePasswordSheet(context,
                                  verifyCurrent: widget.verifyCurrentPassword,
                                  saveNew: widget.saveNewPassword);
                            },
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: const Icon(Icons.privacy_tip_outlined),
                            title: const Text('Privacy and data'),
                            trailing: const Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 14),
                            onTap: () => widget.repository == null
                                ? showToast(context, 'Privacy settings.')
                                : showUnavailable(context),
                          ),
                        ],
                      ),
                    ),
                    if (widget.repository == null ||
                        widget.lifecycleRepository != null) ...[
                      const SizedBox(height: 18),
                      Panel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Deactivate account',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(color: AppColors.danger)),
                            const SizedBox(height: 6),
                            Text(
                              widget.lifecycleRepository == null
                                  ? 'Your account is held for 30 days before deletion. You can sign back in during that window to keep it.'
                                  : 'Account access stops immediately. You can recover within 30 days after a 65-minute security wait. Automatic permanent deletion is not enabled.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 14),
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.danger,
                                minimumSize: const Size(0, 44),
                              ),
                              onPressed: widget.lifecycleRepository != null
                                  ? _deactivate
                                  : () => confirmSheet(context,
                                      title: 'Deactivate your account?',
                                      message:
                                          'Access stops immediately. Everything is deleted for good after 30 days.',
                                      confirmLabel: 'Deactivate',
                                      destructive: true),
                              child: const Text('Deactivate account'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
    );
  }
}
