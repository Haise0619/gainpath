import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  bool _push = true;
  bool _email = false;
  bool _voice = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: PageBody(
        children: [
          const Eyebrow('Notifications'),
          Panel(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile(
                  value: _push,
                  onChanged: (v) => setState(() => _push = v),
                  title: const Text('Push notifications'),
                  subtitle: const Text('Session reminders and streak alerts'),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  value: _email,
                  onChanged: (v) => setState(() => _email = v),
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
              onChanged: (v) => setState(() => _voice = v),
              title: const Text('Voice coaching'),
              subtitle: const Text('Spoken cues during tracked sessions'),
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
                  trailing:
                      const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                  onTap: () => showChangePasswordSheet(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('Privacy and data'),
                  trailing:
                      const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                  onTap: () => showToast(context, 'Privacy settings.'),
                ),
              ],
            ),
          ),
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
                  'Your account is held for 30 days before everything is permanently '
                  'deleted. You can sign back in during that window to keep it.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 14),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    minimumSize: const Size(0, 44),
                  ),
                  onPressed: () => confirmSheet(context,
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
      ),
    );
  }
}
