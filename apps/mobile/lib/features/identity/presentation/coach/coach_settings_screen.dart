import 'coach_unsaved_changes_guard.dart';
import 'coach_phone_input.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';
import 'package:flutter/material.dart';
import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../application/coach_account_gateway.dart';

class CoachSettingsScreen extends StatefulWidget {
  const CoachSettingsScreen({super.key, required this.repository});
  final CoachAccountGateway repository;
  @override
  State<CoachSettingsScreen> createState() => _CoachSettingsScreenState();
}

class _CoachSettingsScreenState extends State<CoachSettingsScreen> {
  final phone = TextEditingController();
  CoachAccountSettings? baseline;
  bool bookings = false, cancellations = false, reminders = false, busy = false;
  bool conflict = false, uncertain = false;
  String? message;
  String? requestId;
  IsoCode country = IsoCode.MY;
  CoachPhoneInput initialPhone =
      const CoachPhoneInput(country: IsoCode.MY, national: '');
  String? phoneError;

  void applySettings(CoachAccountSettings data) {
    baseline = data;
    initialPhone = CoachPhoneInput.restore(data.contactPhone);
    country = initialPhone.country;
    phone.text = initialPhone.national;
    bookings = data.newBookings;
    cancellations = data.cancellations;
    reminders = data.reminders;
    requestId = null;
    phoneError = null;
    conflict = false;
    uncertain = false;
  }

  bool get phoneDirty {
    if (country == initialPhone.country &&
        phone.text.trim() == initialPhone.national.trim()) {
      return false;
    }
    try {
      return CoachPhoneInput.normalize(phone.text, country) !=
          baseline?.contactPhone;
    } on FormatException {
      return true;
    }
  }

  String errorMessage(Object error) {
    if (error is FormatException) return error.message.toString();
    if (error is CoachRepositoryException) {
      return switch (error.code) {
        'already-exists' =>
          'This phone number is already linked to another account. Use a different number or contact gym staff.',
        'aborted' =>
          'Your settings changed elsewhere. Discard and reload before saving again.',
        'permission-denied' ||
        'unauthenticated' =>
          'Your account could not be verified. Sign in again, then retry.',
        'invalid-argument' =>
          'The phone number or preferences were rejected. Check the entries and retry.',
        'unavailable' ||
        'deadline-exceeded' =>
          'Could not confirm the save. Check your connection and retry or reload.',
        _ => error.message,
      };
    }
    return 'Could not confirm the save. Check your connection and retry or reload.';
  }

  void showFeedback(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    phone.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      busy = true;
      message = null;
    });
    try {
      final data = await widget.repository
          .loadSettings()
          .timeout(const Duration(seconds: 20));
      if (!mounted) return;
      setState(() {
        applySettings(data);
      });
    } catch (error) {
      if (mounted) {
        setState(() =>
            message = 'Settings could not be loaded. ${errorMessage(error)}');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> save() async {
    if (busy || baseline == null) return;
    String normalizedPhone;
    try {
      normalizedPhone = CoachPhoneInput.normalize(phone.text, country);
    } on FormatException catch (error) {
      setState(() {
        phoneError = error.message.toString();
        message = null;
      });
      return;
    }
    setState(() {
      busy = true;
      message = null;
      phoneError = null;
      conflict = false;
      uncertain = false;
    });
    requestId ??= newCoachRequestId();
    try {
      final data = await widget.repository
          .saveSettings(baseline!, normalizedPhone, bookings, cancellations,
              reminders, requestId!)
          .timeout(const Duration(seconds: 20));
      final confirmed = await widget.repository
          .loadSettings()
          .timeout(const Duration(seconds: 20));
      if (confirmed.revision < data.revision ||
          confirmed.contactPhone != normalizedPhone ||
          confirmed.newBookings != bookings ||
          confirmed.cancellations != cancellations ||
          confirmed.reminders != reminders) {
        throw const CoachRepositoryException('aborted');
      }
      if (mounted) {
        setState(() {
          applySettings(confirmed);
          message = 'Settings saved.';
        });
        showFeedback('Settings saved.');
      }
    } on FormatException catch (e) {
      if (mounted) {
        setState(() {
          phoneError = e.message.toString();
          requestId = null;
        });
      }
    } on CoachRepositoryException catch (e) {
      if (mounted) {
        final text = errorMessage(e);
        setState(() {
          message = text;
          if (e.code == 'already-exists') phoneError = text;
          if (e.code == 'aborted') conflict = true;
          if (e.code == 'unavailable' || e.code == 'deadline-exceeded') {
            uncertain = true;
          }
        });
        showFeedback(text);
      }
    } catch (error) {
      if (mounted) {
        final text = errorMessage(error);
        setState(() {
          message = text;
          uncertain = true;
        });
        showFeedback(text);
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  bool get dirty =>
      baseline != null &&
      (phoneDirty ||
          bookings != baseline!.newBookings ||
          cancellations != baseline!.cancellations ||
          reminders != baseline!.reminders);

  Future<void> discardAndReload() async {
    if (busy) return;
    if (dirty &&
        !await confirmSheet(context,
            title: 'Discard unsaved changes?',
            message: 'Your unsaved settings will be lost.',
            confirmLabel: 'Discard',
            destructive: true)) {
      return;
    }
    if (mounted && widget.repository.isCurrent()) await load();
  }

  Future<void> selectCountry() async {
    FocusScope.of(context).unfocus();
    final selected = await showCoachPhoneCountryPicker(context);
    if (mounted && selected != null && widget.repository.isCurrent()) {
      setState(() {
        country = selected;
        requestId = null;
        phoneError = null;
        message = null;
        conflict = false;
        uncertain = false;
      });
    }
  }

  void changed(VoidCallback update) => setState(() {
        update();
        requestId = null;
        message = null;
        conflict = false;
        uncertain = false;
      });

  Widget? _saveBar(bool enabled) {
    final hasUnsavedOrUnresolved = dirty || conflict || uncertain || busy;
    if (!hasUnsavedOrUnresolved) return null;

    final statusText = busy
        ? 'Saving…'
        : conflict
            ? 'Changes need attention'
            : uncertain
                ? 'Could not save · Retry'
                : 'Unsaved changes';

    final statusColor = conflict || uncertain
        ? AppColors.warning
        : (busy ? AppColors.inkSoft : AppColors.primary);

    return SafeArea(
      top: false,
      child: Container(
        key: const Key('coach-settings-save-bar'),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.hairline)),
          boxShadow: [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 8,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  busy
                      ? Icons.sync_rounded
                      : conflict
                          ? Icons.warning_amber_rounded
                          : uncertain
                              ? Icons.error_outline_rounded
                              : Icons.edit_note_rounded,
                  size: 16,
                  color: statusColor,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    statusText,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: busy ? null : discardAndReload,
                    child: const Text(
                      'Discard and reload',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    key: const Key('coach-settings-save-button'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: (enabled && dirty && !conflict) ? save : null,
                    child: busy
                        ? const Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  'Save changes',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          )
                        : Text(
                            uncertain ? 'Retry save' : 'Save changes',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final enabled = !busy && baseline != null;
    return CoachUnsavedChangesGuard(
      dirty: dirty,
      busy: busy,
      isCurrent: widget.repository.isCurrent,
      child: Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        bottomNavigationBar: _saveBar(enabled),
        body: PageBody(
          children: [
            if (busy && baseline == null) const LinearProgressIndicator(),
            if (message != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: message == 'Settings saved.'
                        ? AppColors.successTint
                        : (conflict || uncertain
                            ? AppColors.accentTint
                            : AppColors.dangerTint),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: message == 'Settings saved.'
                          ? AppColors.success.withValues(alpha: 0.3)
                          : (conflict || uncertain
                              ? AppColors.warning.withValues(alpha: 0.3)
                              : AppColors.danger.withValues(alpha: 0.3)),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        message == 'Settings saved.'
                            ? Icons.check_circle_outline_rounded
                            : (conflict || uncertain
                                ? Icons.warning_amber_rounded
                                : Icons.error_outline_rounded),
                        size: 18,
                        color: message == 'Settings saved.'
                            ? AppColors.success
                            : (conflict || uncertain
                                ? AppColors.warning
                                : AppColors.danger),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          message!,
                          key: const Key('coach-settings-feedback'),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: message == 'Settings saved.'
                                ? AppColors.success
                                : (conflict || uncertain
                                    ? AppColors.ink
                                    : AppColors.danger),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const Eyebrow('Contact details'),
            Panel(
              key: const Key('coach-settings-contact'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.hairline),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.lock_outline_rounded,
                            size: 18, color: AppColors.inkSoft),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            initialValue: widget.repository.email,
                            readOnly: true,
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppColors.ink),
                            decoration: const InputDecoration(
                              labelText: 'Verified sign-in email',
                              labelStyle: TextStyle(
                                  fontSize: 12, color: AppColors.inkSoft),
                              isDense: true,
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(
                            minWidth: 105, maxWidth: 135),
                        child: OutlinedButton(
                          key: const Key('coach-phone-country'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            side: const BorderSide(color: AppColors.hairline),
                            backgroundColor: AppColors.surfaceAlt,
                          ),
                          onPressed: enabled ? selectCountry : null,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Text(
                                  '${CoachPhoneInput.flag(country)} ${CoachPhoneInput.countryNames[country]} +${CoachPhoneInput.dialCode(country)}',
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.ink,
                                  ),
                                ),
                              ),
                              const Icon(Icons.arrow_drop_down,
                                  size: 16, color: AppColors.inkSoft),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          key: const Key('coach-phone-national'),
                          controller: phone,
                          enabled: enabled,
                          keyboardType: TextInputType.phone,
                          onChanged: (_) => changed(() {
                            phoneError = null;
                          }),
                          decoration: InputDecoration(
                            labelText: 'Private phone',
                            isDense: true,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                            errorText: phoneError,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Enter a local number. Clearing the phone number will remove it.',
                    style: TextStyle(fontSize: 12, color: AppColors.inkSoft),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Eyebrow('Notifications'),
            Panel(
              key: const Key('coach-settings-notifications'),
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  SwitchListTile(
                    value: bookings,
                    activeTrackColor: AppColors.primary,
                    activeThumbColor: Colors.white,
                    inactiveTrackColor: AppColors.hairline,
                    inactiveThumbColor: Colors.white,
                    onChanged: enabled
                        ? (v) => changed(() {
                              bookings = v;
                            })
                        : null,
                    title: const Text('New bookings',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: const Text(
                        'When a member books a session with you',
                        style:
                            TextStyle(fontSize: 12, color: AppColors.inkSoft)),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    value: cancellations,
                    activeTrackColor: AppColors.primary,
                    activeThumbColor: Colors.white,
                    inactiveTrackColor: AppColors.hairline,
                    inactiveThumbColor: Colors.white,
                    onChanged: enabled
                        ? (v) => changed(() {
                              cancellations = v;
                            })
                        : null,
                    title: const Text('Cancellations',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: const Text(
                        'When a member cancels or reschedules',
                        style:
                            TextStyle(fontSize: 12, color: AppColors.inkSoft)),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    value: false,
                    onChanged: null,
                    title: const Text(
                      'Session reminders',
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.hairline.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Unavailable',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.inkSoft),
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Automated session reminder delivery is currently unavailable',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.inkSoft),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.fromLTRB(14, 4, 14, 14),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.hairline),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline_rounded,
                            size: 16, color: AppColors.inkSoft),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Preferences are saved to your account. Push notification delivery to Android devices requires future backend integration.',
                            style: TextStyle(
                                fontSize: 12,
                                color: AppColors.inkSoft,
                                height: 1.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Eyebrow('Security'),
            Panel(
              key: const Key('coach-settings-security'),
              padding: EdgeInsets.zero,
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryTint,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.lock_outline_rounded,
                      size: 18, color: AppColors.primary),
                ),
                title: const Text('Change password',
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: widget.repository.passwordManagementAvailable
                    ? const Text('Update your sign-in password',
                        style:
                            TextStyle(fontSize: 12, color: AppColors.inkSoft))
                    : const Text(
                        'Password changes are unavailable in this session.',
                        style:
                            TextStyle(fontSize: 12, color: AppColors.inkSoft)),
                trailing:
                    const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                onTap: enabled && widget.repository.passwordManagementAvailable
                    ? () {
                        showChangePasswordSheet(context,
                            verifyCurrent: (password) async {
                          widget.repository.check();
                          await widget.repository
                              .verifyCurrentPassword(password);
                          widget.repository.check();
                        }, saveNew: (password) async {
                          widget.repository.check();
                          await widget.repository.changePassword(password);
                          widget.repository.check();
                        });
                      }
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            const Eyebrow('Account'),
            Panel(
              key: const Key('coach-settings-account'),
              padding: EdgeInsets.zero,
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.admin_panel_settings_outlined,
                      size: 18, color: AppColors.inkSoft),
                ),
                title: const Text('Account access',
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: const Text(
                    'Managed by your gym administrator. Contact gym staff to update account permissions or status.',
                    style: TextStyle(fontSize: 12, color: AppColors.inkSoft)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
