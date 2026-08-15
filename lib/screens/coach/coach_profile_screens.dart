import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../data/mock_data.dart';
import '../../widgets/change_password_sheet.dart';
import '../../widgets/shared.dart';
import '../auth/role_select_screen.dart';

/// AD-M8.3 — Manage Professional Profile.
class CoachProfileScreen extends StatelessWidget {
  const CoachProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: PageBody(
        children: [
          Panel(
            child: Column(
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: AppColors.primaryTint,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Center(
                    child: Text('JL',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary)),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(MockData.coachName,
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(width: 6),
                    const Icon(Icons.verified_rounded,
                        size: 18, color: AppColors.primary),
                  ],
                ),
                const SizedBox(height: 3),
                Text('Strength and Conditioning',
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Eyebrow('Public profile'),
          Panel(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _row(context, Icons.edit_note_rounded, 'Bio and specialties',
                    'What members see in the directory',
                    () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const EditCoachProfileScreen()))),
                const Divider(height: 1, indent: 62),
                _row(context, Icons.workspace_premium_rounded,
                    'Certifications', '2 verified, 1 pending review',
                    () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const CertificationsScreen()))),
                const Divider(height: 1, indent: 62),
                _row(context, Icons.photo_camera_rounded, 'Profile photo',
                    'Update your directory picture',
                    () => showToast(context, 'Opening photo picker.')),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Eyebrow('Account'),
          Panel(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _row(context, Icons.settings_outlined, 'Settings',
                    'Password, contact details, notifications',
                    () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const CoachSettingsScreen()))),
              ],
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () async {
              final ok = await confirmSheet(context,
                  title: 'Sign out?',
                  message: 'You will need to sign in again next time.',
                  confirmLabel: 'Sign out',
                  destructive: true);
              if (ok && context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const RoleSelectScreen()),
                  (r) => false,
                );
              }
            },
            icon: const Icon(Icons.logout_rounded, size: 19),
            label: const Text('Sign out'),
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, IconData icon, String title,
      String subtitle, VoidCallback onTap) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(icon, size: 19, color: AppColors.primary),
      ),
      title: Text(title, style: Theme.of(context).textTheme.titleMedium),
      subtitle: Text(subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13)),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
    );
  }
}

class EditCoachProfileScreen extends StatelessWidget {
  const EditCoachProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: PageBody(
        children: [
          const Eyebrow('Bio'),
          TextField(
            maxLines: 6,
            maxLength: 1000,
            controller: TextEditingController(text: MockData.coaches[0].bio),
            decoration: const InputDecoration(
                hintText: 'Tell members about your coaching approach'),
          ),
          const SizedBox(height: 10),
          const Eyebrow('Specialties'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...['Strength', 'Powerlifting', 'Beginners']
                  .map((s) => Chip(
                        label: Text(s),
                        backgroundColor: AppColors.primaryTint,
                        onDeleted: () {},
                      )),
              ActionChip(
                avatar: const Icon(Icons.add_rounded, size: 17),
                label: const Text('Add'),
                onPressed: () {},
              ),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              showToast(context, 'Profile published.');
            },
            child: const Text('Publish changes'),
          ),
        ],
      ),
    );
  }
}

class CertificationsScreen extends StatelessWidget {
  const CertificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const docs = [
      ['NASM-CPT Certificate', 'Verified', Icons.verified_rounded],
      ['First Aid and CPR', 'Verified', Icons.verified_rounded],
      ['Strength Specialist L2', 'Pending review', Icons.schedule_rounded],
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Certifications')),
      body: PageBody(
        children: [
          ...docs.map((d) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Panel(
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: const Icon(Icons.description_outlined,
                            size: 19, color: AppColors.primary),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(d[0] as String,
                            style: Theme.of(context).textTheme.titleMedium),
                      ),
                      statusPill(d[1] as String),
                    ],
                  ),
                ),
              )),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => showToast(context, 'Opening file picker.'),
            icon: const Icon(Icons.upload_file_rounded, size: 19),
            label: const Text('Upload a certificate'),
          ),
          const SizedBox(height: 14),
          Panel(
            background: AppColors.surfaceAlt,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded,
                    size: 18, color: AppColors.inkSoft),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'New certificates stay hidden from members until gym staff have '
                    'checked them.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// AD-M8.2 — Authenticated Session and Settings Management (Fitness Coach).
class CoachSettingsScreen extends StatefulWidget {
  const CoachSettingsScreen({super.key});

  @override
  State<CoachSettingsScreen> createState() => _CoachSettingsScreenState();
}

class _CoachSettingsScreenState extends State<CoachSettingsScreen> {
  bool _push = true;
  bool _sms = false;
  late final _phone = TextEditingController(text: '+60 12-345 6789');

  @override
  void dispose() {
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
                  controller: TextEditingController(text: MockData.coachEmail),
                  decoration: const InputDecoration(labelText: 'Work email'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _phone,
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
                  value: _push,
                  onChanged: (v) => setState(() => _push = v),
                  title: const Text('Push notifications'),
                  subtitle: const Text('New bookings and cancellations'),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  value: _sms,
                  onChanged: (v) => setState(() => _sms = v),
                  title: const Text('SMS reminders'),
                  subtitle: const Text('Session starting within the hour'),
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
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              showToast(context, 'Settings saved.');
            },
            child: const Text('Save modifications'),
          ),
        ],
      ),
    );
  }
}
