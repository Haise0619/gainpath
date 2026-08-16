import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../data/mock_data.dart';
import '../../../widgets/change_password_sheet.dart';
import '../../../widgets/shared.dart';

/// AD-M8.2 — Authenticated Session & Settings Management (Fitness Coach).
/// Contact details, notification preferences tuned to a coach's workflow
/// (new bookings, cancellations, session reminders), security, and
/// account management including deactivation.
class CoachSettingsScreen extends StatefulWidget {
  const CoachSettingsScreen({super.key});

  @override
  State<CoachSettingsScreen> createState() => _CoachSettingsScreenState();
}

class _CoachSettingsScreenState extends State<CoachSettingsScreen> {
  bool _newBookings = true;
  bool _cancellations = true;
  bool _reminders = false;
  late final TextEditingController _email;
  late final TextEditingController _phone;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(text: MockData.coachEmail);
    _phone = TextEditingController(text: MockData.coachPhone);
  }

  @override
  void dispose() {
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: PageBody(
        children: [
          const Eyebrow('Contact details'),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Work email'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone number'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Eyebrow('Notifications'),
          Panel(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile(
                  value: _newBookings,
                  onChanged: (v) => setState(() => _newBookings = v),
                  title: const Text('New bookings'),
                  subtitle: const Text('When a member books a session with you'),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  value: _cancellations,
                  onChanged: (v) => setState(() => _cancellations = v),
                  title: const Text('Cancellations'),
                  subtitle: const Text('When a member cancels or reschedules'),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  value: _reminders,
                  onChanged: (v) => setState(() => _reminders = v),
                  title: const Text('Session reminders'),
                  subtitle: const Text('An SMS an hour before each session'),
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
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
              onTap: () => showChangePasswordSheet(context),
            ),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              showToast(context, 'Settings saved.');
            },
            child: const Text('Save changes'),
          ),
          const SizedBox(height: 24),
          const Eyebrow('Account'),
          Panel(
            padding: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.no_accounts_outlined, color: AppColors.danger),
              title: const Text('Deactivate account',
                  style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600)),
              subtitle: const Text('Stop taking new bookings'),
              onTap: _deactivate,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deactivate() async {
    final ok = await confirmSheet(context,
        title: 'Deactivate your account?',
        message:
            'You will be removed from the coach directory and stop receiving new bookings. '
            'Existing confirmed sessions are unaffected. Gym staff can reactivate you later.',
        confirmLabel: 'Deactivate',
        destructive: true);
    if (ok && mounted) showToast(context, 'Request sent to gym staff.');
  }
}
