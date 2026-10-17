import 'coach_unsaved_changes_guard.dart';
import 'package:flutter/material.dart';
import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../../../infrastructure/firebase/firebase_coach_account_repository.dart';
import '../../../../infrastructure/firebase/firebase_password_actions.dart';

class LiveCoachAccountSettings extends StatefulWidget {
  const LiveCoachAccountSettings({super.key, required this.repository});
  final FirebaseCoachAccountRepository repository;
  @override
  State<LiveCoachAccountSettings> createState() =>
      _LiveCoachAccountSettingsState();
}

class _LiveCoachAccountSettingsState extends State<LiveCoachAccountSettings> {
  final phone = TextEditingController();
  CoachAccountSettings? baseline;
  bool bookings = false, cancellations = false, reminders = false, busy = false;
  String? message;
  String? requestId;
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
      final data = await widget.repository.loadSettings();
      if (!mounted) return;
      setState(() {
        baseline = data;
        phone.text = data.contactPhone;
        bookings = data.newBookings;
        cancellations = data.cancellations;
        reminders = data.reminders;
        requestId = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() => message = 'Settings could not be loaded. Retry.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> save() async {
    setState(() {
      busy = true;
      message = null;
    });
    requestId ??= FirebaseCoachAccountRepository.randomId();
    try {
      final data = await widget.repository.saveSettings(baseline!,
          phone.text.trim(), bookings, cancellations, reminders, requestId!);
      if (mounted) {
        setState(() {
          baseline = data;
          phone.text = data.contactPhone;
          requestId = null;
          message = 'Settings saved.';
        });
      }
    } on FormatException catch (e) {
      if (mounted) {
        setState(() {
          message = e.message.toString();
          requestId = null;
        });
      }
    } on CoachRepositoryException catch (e) {
      if (mounted) setState(() => message = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => message =
            'Could not save settings. Retry the same request or reload.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = !busy && baseline != null;
    return CoachUnsavedChangesGuard(
        dirty: baseline != null &&
            (phone.text.trim() != baseline!.contactPhone ||
                bookings != baseline!.newBookings ||
                cancellations != baseline!.cancellations ||
                reminders != baseline!.reminders),
        busy: busy,
        isCurrent: widget.repository.isCurrent,
        child: Scaffold(
            appBar: AppBar(title: const Text('Settings')),
            body: PageBody(children: [
              if (busy) const LinearProgressIndicator(),
              if (message != null) Text(message!),
              TextFormField(
                  initialValue: widget.repository.email,
                  readOnly: true,
                  decoration: const InputDecoration(
                      labelText: 'Verified sign-in email')),
              TextField(
                  controller: phone,
                  onChanged: (_) => setState(() => requestId = null),
                  enabled: enabled,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                      labelText: 'Private contact phone (+country code)')),
              const SizedBox(height: 18),
              const Eyebrow('Notification preferences'),
              const Text(
                  'Preferences are saved to your account. Delivery depends on the connected notification service.'),
              SwitchListTile(
                  value: bookings,
                  onChanged: enabled
                      ? (v) => setState(() {
                            bookings = v;
                            requestId = null;
                          })
                      : null,
                  title: const Text('New bookings')),
              SwitchListTile(
                  value: cancellations,
                  onChanged: enabled
                      ? (v) => setState(() {
                            cancellations = v;
                            requestId = null;
                          })
                      : null,
                  title: const Text('Cancellations')),
              SwitchListTile(
                  value: reminders,
                  onChanged: enabled
                      ? (v) => setState(() {
                            reminders = v;
                            requestId = null;
                          })
                      : null,
                  title: const Text('Session reminders')),
              FilledButton(
                  onPressed: enabled ? save : null,
                  child: const Text('Save changes')),
              TextButton(
                  onPressed: busy ? null : load,
                  child: const Text('Discard and reload')),
              ListTile(
                  leading: const Icon(Icons.lock_outline),
                  title: const Text('Change password'),
                  onTap: enabled
                      ? () {
                          final actions = FirebasePasswordActions(
                              scope: widget.repository.scope);
                          showChangePasswordSheet(context,
                              verifyCurrent: (password) async {
                            widget.repository.check();
                            await actions.verifyCurrent(password);
                            widget.repository.check();
                          }, saveNew: (password) async {
                            widget.repository.check();
                            await actions.saveNew(password);
                            widget.repository.check();
                          });
                        }
                      : null),
              const Text(
                  'Account activation and deactivation are managed by your gym Admin. Contact gym staff to change account access.'),
            ])));
  }
}
