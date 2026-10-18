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
        });
        showFeedback(text);
      }
    } catch (error) {
      if (mounted) {
        final text = errorMessage(error);
        setState(() => message = text);
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
      });
    }
  }

  void changed(VoidCallback update) => setState(() {
        update();
        requestId = null;
        message = null;
      });

  @override
  Widget build(BuildContext context) {
    final enabled = !busy && baseline != null;
    return CoachUnsavedChangesGuard(
      dirty: dirty,
      busy: busy,
      isCurrent: widget.repository.isCurrent,
      child: Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: PageBody(children: [
          if (busy) const LinearProgressIndicator(),
          if (message != null)
            Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child:
                    Text(message!, key: const Key('coach-settings-feedback'))),
          const Eyebrow('Contact details'),
          Panel(
              key: const Key('coach-settings-contact'),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                        initialValue: widget.repository.email,
                        readOnly: true,
                        decoration: const InputDecoration(
                            labelText: 'Verified sign-in email')),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                        key: const Key('coach-phone-country'),
                        onPressed: enabled ? selectCountry : null,
                        icon: const Icon(Icons.public),
                        label: Text(
                            '${CoachPhoneInput.flag(country)} ${CoachPhoneInput.countryNames[country]} (${country.name}) +${CoachPhoneInput.dialCode(country)}')),
                    const SizedBox(height: 8),
                    TextField(
                        key: const Key('coach-phone-national'),
                        controller: phone,
                        enabled: enabled,
                        keyboardType: TextInputType.phone,
                        onChanged: (_) => changed(() {
                              phoneError = null;
                            }),
                        decoration: InputDecoration(
                            labelText: 'Private contact phone',
                            prefixText:
                                '+${CoachPhoneInput.dialCode(country)} ',
                            helperText:
                                'Enter a local number. Leave blank to remove it.',
                            errorText: phoneError)),
                  ])),
          const SizedBox(height: 18),
          const Eyebrow('Notifications'),
          Panel(
              key: const Key('coach-settings-notifications'),
              padding: EdgeInsets.zero,
              child: Column(children: [
                SwitchListTile(
                    value: bookings,
                    onChanged: enabled
                        ? (v) => changed(() {
                              bookings = v;
                            })
                        : null,
                    title: const Text('New bookings'),
                    subtitle:
                        const Text('When a member books a session with you')),
                const Divider(height: 1),
                SwitchListTile(
                    value: cancellations,
                    onChanged: enabled
                        ? (v) => changed(() {
                              cancellations = v;
                            })
                        : null,
                    title: const Text('Cancellations'),
                    subtitle:
                        const Text('When a member cancels or reschedules')),
                const Divider(height: 1),
                SwitchListTile(
                    value: reminders,
                    onChanged: enabled
                        ? (v) => changed(() {
                              reminders = v;
                            })
                        : null,
                    title: const Text('Session reminders'),
                    subtitle: const Text(
                        'Your preference for upcoming session reminders')),
                const Padding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Text(
                        'Preferences are saved to your account. Delivery depends on the connected notification service.')),
              ])),
          const SizedBox(height: 18),
          const Eyebrow('Security'),
          Panel(
              key: const Key('coach-settings-security'),
              padding: EdgeInsets.zero,
              child: ListTile(
                leading: const Icon(Icons.lock_outline_rounded),
                title: const Text('Change password'),
                subtitle: widget.repository.passwordManagementAvailable
                    ? null
                    : const Text(
                        'Password changes are unavailable in this session.'),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
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
              )),
          const SizedBox(height: 18),
          const Eyebrow('Account'),
          const Panel(
              key: Key('coach-settings-account'),
              padding: EdgeInsets.zero,
              child: ListTile(
                  leading: Icon(Icons.support_agent_rounded),
                  title: Text('Account access'),
                  subtitle: Text(
                      'Account activation and deactivation are managed by your gym Admin. Contact gym staff to change account access.'))),
          const SizedBox(height: 18),
          FilledButton(
              onPressed: enabled && dirty ? save : null,
              child: const Text('Save changes')),
          TextButton(
              onPressed: busy ? null : discardAndReload,
              child: const Text('Discard and reload')),
        ]),
      ),
    );
  }
}
