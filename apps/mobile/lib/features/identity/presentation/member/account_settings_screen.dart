import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../infrastructure/audio/sound_effects_setting.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_identity/gainpath_identity.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../../../infrastructure/firebase/firebase_member_contact_details_repository.dart';
import '../../../../navigation/feature_navigation.dart';
import 'member_contact_details_edit_screen.dart';
import 'member_deactivation_dialog.dart';
import 'privacy_and_data_settings_screen.dart';

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen(
      {super.key,
      this.repository,
      this.contactSession,
      this.contactRepository,
      this.lifecycleRepository,
      this.onAccountDeactivated,
      this.verifyCurrentPassword,
      this.saveNewPassword,
      this.module9Repository,
      this.isSessionCurrent,
      this.legalPrivacyBuilder});

  final MemberPreferencesRepository? repository;
  final AuthSession? contactSession;
  final MemberContactDetailsRepository? contactRepository;
  final MemberAccountLifecycleRepository? lifecycleRepository;
  final VoidCallback? onAccountDeactivated;
  final Future<void> Function(String)? verifyCurrentPassword;
  final Future<void> Function(String)? saveNewPassword;
  final Module9Repository? module9Repository;
  final bool Function()? isSessionCurrent;
  final WidgetBuilder? legalPrivacyBuilder;

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  bool _workoutSettingsCurrent(SessionScope scope) {
    if (widget.isSessionCurrent != null) return widget.isSessionCurrent!();
    try {
      final state = context.read<AuthBloc>().state;
      return state.session?.scope == scope &&
          AuthRolePolicy.canEnter(state, allowed: const {AppRole.member});
    } catch (_) {
      return false;
    }
  }

  bool _push = true;
  bool _email = false;
  bool _voice = true;
  bool _loading = false;
  bool _saving = false;
  String? _loadError;
  MemberPreferences? _loadedPreferences;
  bool _reloadRequired = false;

  MemberContactDetails? _contactDetails;

  @override
  void initState() {
    super.initState();
    if (widget.repository != null) _load();
    if (widget.contactSession != null || widget.contactRepository != null) {
      _loadContactDetails();
    }
  }

  Future<void> _loadContactDetails() async {
    MemberContactDetailsRepository? repo = widget.contactRepository;
    if (repo == null && widget.contactSession != null) {
      repo = FirebaseMemberContactDetailsRepository(
          scope: widget.contactSession!.scope, isCurrent: () => mounted);
    }
    if (repo == null) return;
    try {
      final details = await repo.load();
      if (mounted) {
        setState(() => _contactDetails = details);
      }
    } catch (_) {}
  }

  Future<void> _openEditProfile() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MemberContactDetailsEditScreen(
          session: widget.contactSession,
          repository: widget.contactRepository,
          onDisplayNameSaved: (name) {
            if (mounted) {
              setState(() {
                if (_contactDetails != null) {
                  _contactDetails = MemberContactDetails(
                    value: _contactDetails!.value,
                    editBaseline: _contactDetails!.editBaseline,
                    displayName: name,
                  );
                }
              });
            }
          },
        ),
      ),
    );
    if (mounted) {
      await _loadContactDetails();
    }
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

  Widget _settingsIcon(IconData icon, Color color, Color bgColor) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 20, color: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    AuthSession? session;
    try {
      session = widget.contactSession ?? context.read<AuthBloc>().state.session;
    } catch (_) {
      session = widget.contactSession;
    }

    final effectiveName = _contactDetails?.displayName.isNotEmpty == true
        ? _contactDetails!.displayName
        : (session?.displayName != null && session!.displayName!.isNotEmpty
            ? session.displayName!
            : null);

    final effectiveContact = _contactDetails?.value.isNotEmpty == true
        ? _contactDetails!.value
        : null;

    return Scaffold(
      backgroundColor: isDark ? null : const Color(0xFFF9F7FC),
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: false,
      ),
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
                      _ProfileSummaryCard(
                        name: effectiveName,
                        contact: effectiveContact,
                        email: session?.email,
                        onTap: _openEditProfile,
                      ),
                      const SizedBox(height: 18),
                    ],
                    if (_reloadRequired) ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3E2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline_rounded,
                                color: Color(0xFFD97706), size: 20),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'Reload saved settings before making another change.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF92400E),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: _load,
                              child: const Text('Reload settings'),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const Eyebrow('Notifications'),
                    Panel(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          SwitchListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            secondary: _settingsIcon(
                              Icons.notifications_outlined,
                              const Color(0xFF6A26B8),
                              isDark
                                  ? const Color(0xFF38235A)
                                  : const Color(0xFFF1E9FB),
                            ),
                            title: const Text('Push notifications'),
                            subtitle: const Text(
                                'Session reminders and streak alerts'),
                            value: _push,
                            onChanged: _saving || _reloadRequired
                                ? null
                                : (v) => widget.repository == null
                                    ? setState(() => _push = v)
                                    : _change(_current.copyWith(
                                        pushNotifications: v)),
                            activeTrackColor: AppColors.primary,
                            activeThumbColor: Colors.white,
                            inactiveTrackColor: isDark
                                ? const Color(0xFF2C223D)
                                : AppColors.hairline,
                            inactiveThumbColor: Colors.white,
                            trackOutlineColor: WidgetStateProperty.resolveWith(
                                (states) =>
                                    states.contains(WidgetState.selected)
                                        ? Colors.transparent
                                        : (isDark
                                            ? const Color(0xFF38235A)
                                            : const Color(0xFFD1D5DB))),
                          ),
                          const _GroupDivider(),
                          SwitchListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            secondary: _settingsIcon(
                              Icons.mail_outline_rounded,
                              const Color(0xFF2563EB),
                              isDark
                                  ? const Color(0xFF1E293B)
                                  : const Color(0xFFEFF6FF),
                            ),
                            title: const Text('Email updates'),
                            subtitle: const Text('Weekly progress summary'),
                            value: _email,
                            onChanged: _saving || _reloadRequired
                                ? null
                                : (v) => widget.repository == null
                                    ? setState(() => _email = v)
                                    : _change(
                                        _current.copyWith(emailUpdates: v)),
                            activeTrackColor: AppColors.primary,
                            activeThumbColor: Colors.white,
                            inactiveTrackColor: isDark
                                ? const Color(0xFF2C223D)
                                : AppColors.hairline,
                            inactiveThumbColor: Colors.white,
                            trackOutlineColor: WidgetStateProperty.resolveWith(
                                (states) =>
                                    states.contains(WidgetState.selected)
                                        ? Colors.transparent
                                        : (isDark
                                            ? const Color(0xFF38235A)
                                            : const Color(0xFFD1D5DB))),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    _GroupFooter(
                      widget.repository != null
                          ? 'Your choices are saved. Notification delivery and voice coaching are not active yet.'
                          : 'Configure your notification preferences.',
                    ),
                    const SizedBox(height: 18),
                    const Eyebrow('Workout'),
                    Panel(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          const SoundEffectsSetting(),
                          if (widget.contactSession?.scope != null ||
                              widget.repository != null) ...[
                            ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 4),
                              leading: _settingsIcon(
                                Icons.videocam_outlined,
                                const Color(0xFF7C3AED),
                                isDark
                                    ? const Color(0xFF352054)
                                    : const Color(0xFFF3EDFA),
                              ),
                              title: const Text('Privacy & AI Tracking'),
                              subtitle: const Text(
                                  'Consent, Auto-Continue and rest preferences'),
                              trailing: const Icon(
                                Icons.chevron_right_rounded,
                                size: 20,
                                color: Color(0xFF9CA3AF),
                              ),
                              onTap: () {
                                final scope = widget.contactSession?.scope ??
                                    widget.repository!.scope;
                                Navigator.pushNamed<void>(
                                    context, FeatureNavigation.workoutPrivacy,
                                    arguments: WorkoutPrivacyArguments(
                                        scope: scope,
                                        isCurrent: () =>
                                            mounted &&
                                            _workoutSettingsCurrent(scope)));
                              },
                            ),
                            const _GroupDivider(),
                          ],
                          SwitchListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            secondary: _settingsIcon(
                              Icons.record_voice_over_outlined,
                              const Color(0xFFD97706),
                              isDark
                                  ? const Color(0xFF3A2B14)
                                  : const Color(0xFFFEF3E2),
                            ),
                            title: const Text('Voice coaching'),
                            subtitle: const Text(
                                'Spoken cues during tracked sessions'),
                            value: _voice,
                            onChanged: _saving || _reloadRequired
                                ? null
                                : (v) => widget.repository == null
                                    ? setState(() => _voice = v)
                                    : _change(
                                        _current.copyWith(voiceCoaching: v)),
                            activeTrackColor: AppColors.primary,
                            activeThumbColor: Colors.white,
                            inactiveTrackColor: isDark
                                ? const Color(0xFF2C223D)
                                : AppColors.hairline,
                            inactiveThumbColor: Colors.white,
                            trackOutlineColor: WidgetStateProperty.resolveWith(
                                (states) =>
                                    states.contains(WidgetState.selected)
                                        ? Colors.transparent
                                        : (isDark
                                            ? const Color(0xFF38235A)
                                            : const Color(0xFFD1D5DB))),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Eyebrow('Security'),
                    Panel(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            leading: _settingsIcon(
                              Icons.lock_outline_rounded,
                              const Color(0xFF4B5563),
                              isDark
                                  ? const Color(0xFF262626)
                                  : const Color(0xFFF1F2F6),
                            ),
                            title: const Text('Change password'),
                            subtitle: const Text(
                                'Update your account sign-in password'),
                            trailing: const Icon(
                              Icons.chevron_right_rounded,
                              size: 20,
                              color: Color(0xFF9CA3AF),
                            ),
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
                          const _GroupDivider(),
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            leading: _settingsIcon(
                              Icons.shield_outlined,
                              const Color(0xFF0284C7),
                              isDark
                                  ? const Color(0xFF0C4A6E)
                                  : const Color(0xFFE0F2FE),
                            ),
                            title: const Text('Privacy and data'),
                            subtitle:
                                const Text('Posture & camera data sharing'),
                            trailing: const Icon(
                              Icons.chevron_right_rounded,
                              size: 20,
                              color: Color(0xFF9CA3AF),
                            ),
                            onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        PrivacyAndDataSettingsScreen(
                                          repository: widget.module9Repository,
                                          isCurrent: widget.isSessionCurrent ??
                                              () => true,
                                        ))),
                          ),
                          if (widget.legalPrivacyBuilder case final legal?) ...[
                            const _GroupDivider(),
                            ListTile(
                              leading: const Icon(Icons.policy_outlined),
                              title: const Text('Legal & Privacy'),
                              subtitle: const Text(
                                  'Current documents and versions you agreed to'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => Navigator.of(context)
                                  .push(MaterialPageRoute(builder: legal)),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (widget.repository == null ||
                        widget.lifecycleRepository != null) ...[
                      const SizedBox(height: 24),
                      const Eyebrow('Account Deactivation'),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF2A1519)
                              : const Color(0xFFFFF5F5),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark
                                ? const Color(0xFF5A2228)
                                : const Color(0xFFFEE2E2),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF3F1B20)
                                        : const Color(0xFFFDE8E8),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  alignment: Alignment.center,
                                  child: const Icon(
                                    Icons.warning_amber_rounded,
                                    size: 18,
                                    color: AppColors.danger,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Deactivate account',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        color: AppColors.danger,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              widget.lifecycleRepository == null
                                  ? 'Your account is held for 30 days before deletion. You can sign back in during that window to keep it.'
                                  : 'Account access stops immediately. You can recover within 30 days after a 65-minute security wait. Automatic permanent deletion is not enabled.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: isDark
                                        ? const Color(0xFFD1A5A9)
                                        : const Color(0xFF7F1D1D),
                                    fontSize: 12.5,
                                    height: 1.4,
                                  ),
                            ),
                            const SizedBox(height: 14),
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.danger,
                                side: const BorderSide(
                                    color: Color(0xFFFCA5A5), width: 1),
                                minimumSize: const Size(0, 42),
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
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
                      const SizedBox(height: 24),
                    ],
                  ],
                ),
    );
  }
}

class _ProfileSummaryCard extends StatelessWidget {
  const _ProfileSummaryCard({
    required this.name,
    required this.contact,
    required this.email,
    required this.onTap,
  });

  final String? name;
  final String? contact;
  final String? email;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final displayName = (name != null && name!.trim().isNotEmpty)
        ? name!.trim()
        : ((email != null && email!.trim().isNotEmpty)
            ? email!.trim()
            : 'Member');

    final initials = displayName.isNotEmpty
        ? displayName.trim().substring(0, 1).toUpperCase()
        : 'M';

    final subtitle = (contact != null && contact!.trim().isNotEmpty)
        ? contact!.trim()
        : ((email != null && email!.trim().isNotEmpty && email != displayName)
            ? email!.trim()
            : 'Tap to manage contact details');

    return Container(
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF2C223D) : const Color(0xFFF0EBF5),
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF38235A)
                        : const Color(0xFFF1E9FB),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF4C3078)
                          : const Color(0xFFE2D4F8),
                      width: 1.5,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initials,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? const Color(0xFFD8C5FF)
                          : const Color(0xFF5C19D9),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color:
                              isDark ? Colors.white : const Color(0xFF1E1430),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 13,
                          color: isDark
                              ? const Color(0xFF9CA3AF)
                              : const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF302046)
                        : const Color(0xFFF5EEFB),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Edit',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? const Color(0xFFD8C5FF)
                              : const Color(0xFF5C19D9),
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color: isDark
                            ? const Color(0xFFD8C5FF)
                            : const Color(0xFF5C19D9),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GroupDivider extends StatelessWidget {
  const _GroupDivider();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Divider(
      height: 1,
      thickness: 1,
      indent: 68,
      endIndent: 0,
      color: isDark ? const Color(0xFF2C223D) : const Color(0xFFF0EBF5),
    );
  }
}

class _GroupFooter extends StatelessWidget {
  const _GroupFooter(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 4, top: 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
              fontSize: 12,
              height: 1.35,
            ),
      ),
    );
  }
}
