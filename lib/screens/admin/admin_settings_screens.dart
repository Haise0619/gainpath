import 'package:flutter/material.dart';
import '../../data/mock_data.dart';
import '../../widgets/change_password_sheet.dart';
import '../../widgets/shared.dart';

/// AD-M11.2 — Admin Session and Settings. Distinct from AD-M11.6's
/// platform-wide configuration: this is the signed-in admin's own contact
/// details, notifications, and password — not something every staff member
/// shares.
class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  bool _push = true;
  bool _email = true;
  bool _weeklyDigest = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                  const Eyebrow('Contact details'),
                  Panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: TextEditingController(text: MockData.adminName),
                          decoration: const InputDecoration(labelText: 'Full name'),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: TextEditingController(text: MockData.adminEmail),
                          decoration: const InputDecoration(labelText: 'Work email'),
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
                          title: const Text('Push alerts'),
                          subtitle: const Text('Refund requests, pending verifications'),
                        ),
                        const Divider(height: 1),
                        SwitchListTile(
                          value: _email,
                          onChanged: (v) => setState(() => _email = v),
                          title: const Text('Email alerts'),
                          subtitle: const Text('Same events, sent to your inbox'),
                        ),
                        const Divider(height: 1),
                        SwitchListTile(
                          value: _weeklyDigest,
                          onChanged: (v) => setState(() => _weeklyDigest = v),
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
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                      onTap: () => showChangePasswordSheet(context, asDialog: true),
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
            ),
          ],
        ),
      ),
    );
  }
}

// SystemSettingsScreen (AD-M11.6) now lives at settings/system_settings_screen.dart
// as an in-place sidebar pane rather than a screen pushed from here.
