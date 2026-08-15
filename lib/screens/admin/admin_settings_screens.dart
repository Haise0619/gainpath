import 'package:flutter/material.dart';
import '../../app/theme.dart';
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
            ),
          ],
        ),
      ),
    );
  }
}

/// AD-M11.6 — Configure System Settings. A tabbed configuration panel
/// across three areas, per the design doc: General Preferences, Reward
/// Conversion Rates, and Legal / Compliance Documents — the last kept
/// deliberately separate from AD-M11.4's chatbot disclaimer, since
/// publishing it has a real data-integrity side effect (member consent
/// records are flagged unverified against the new version).
class SystemSettingsScreen extends StatelessWidget {
  const SystemSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('System settings'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'General'),
              Tab(text: 'Reward conversion'),
              Tab(text: 'Legal & compliance'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _GeneralPreferencesTab(),
            _ConversionRateTab(),
            _ComplianceDocumentTab(),
          ],
        ),
      ),
    );
  }
}

class _GeneralPreferencesTab extends StatefulWidget {
  const _GeneralPreferencesTab();

  @override
  State<_GeneralPreferencesTab> createState() => _GeneralPreferencesTabState();
}

class _GeneralPreferencesTabState extends State<_GeneralPreferencesTab> {
  late final _name = TextEditingController(text: 'Fury Fitness, Kulim');
  String _timezone = 'Asia/Kuala_Lumpur (GMT+8)';
  bool _maintenance = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageBody(
      children: [
        const Eyebrow('Facility'),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(controller: _name, decoration: const InputDecoration(labelText: 'Facility name')),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _timezone,
                decoration: const InputDecoration(labelText: 'Timezone'),
                items: const [
                  DropdownMenuItem(value: 'Asia/Kuala_Lumpur (GMT+8)', child: Text('Asia/Kuala_Lumpur (GMT+8)')),
                  DropdownMenuItem(value: 'Asia/Singapore (GMT+8)', child: Text('Asia/Singapore (GMT+8)')),
                ],
                onChanged: (v) => setState(() => _timezone = v ?? _timezone),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const Eyebrow('Availability'),
        Panel(
          padding: EdgeInsets.zero,
          child: SwitchListTile(
            value: _maintenance,
            onChanged: (v) => setState(() => _maintenance = v),
            title: const Text('Maintenance mode'),
            subtitle: const Text('Shows a banner and blocks new bookings platform-wide'),
          ),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: () => showToast(context, 'Preferences deployed.'),
          child: const Text('Deploy changes'),
        ),
      ],
    );
  }
}

class _ConversionRateTab extends StatefulWidget {
  const _ConversionRateTab();

  @override
  State<_ConversionRateTab> createState() => _ConversionRateTabState();
}

class _ConversionRateTabState extends State<_ConversionRateTab> {
  late final _rate = TextEditingController(text: '200');
  String? _error;

  @override
  void dispose() {
    _rate.dispose();
    super.dispose();
  }

  void _save() {
    final value = int.tryParse(_rate.text.trim());
    if (value == null || value <= 0) {
      setState(() => _error = 'Enter a whole number greater than zero.');
      return;
    }
    setState(() => _error = null);
    showToast(context, 'Conversion rate updated to $value pts = RM 1.00.');
  }

  @override
  Widget build(BuildContext context) {
    return PageBody(
      children: [
        Text('How many gamification points equal RM 1.00 in the reward shop.',
            style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 18),
        Panel(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _rate,
                  keyboardType: TextInputType.number,
                  onChanged: (_) {
                    if (_error != null) setState(() => _error = null);
                  },
                  decoration: InputDecoration(labelText: 'Points per RM 1.00', errorText: _error),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        FilledButton(onPressed: _save, child: const Text('Save conversion rate')),
      ],
    );
  }
}

class _ComplianceDocumentTab extends StatefulWidget {
  const _ComplianceDocumentTab();

  @override
  State<_ComplianceDocumentTab> createState() => _ComplianceDocumentTabState();
}

class _ComplianceDocumentTabState extends State<_ComplianceDocumentTab> {
  late final _controller = TextEditingController(
    text: 'GainPath collects biometric movement data solely to power on-device pose tracking. '
        'No video is ever recorded, stored, or transmitted off your device...',
  );

  Future<void> _publish() async {
    final ok = await confirmSheet(
      context,
      title: 'Publish a new version?',
      message: 'This increments the document version and flags every member\'s consent record as '
          'unverified against it — they will be asked to re-consent the next time they open the app.',
      confirmLabel: 'Publish new version',
    );
    if (ok && mounted) {
      showToast(context, 'Compliance document updated to v6. Members will be asked to re-consent.');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageBody(
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Privacy and liability document shown during onboarding consent.',
                  style: Theme.of(context).textTheme.bodyLarge),
            ),
            statusPill('v5 live'),
          ],
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _controller,
          maxLines: 10,
          decoration: const InputDecoration(hintText: 'Compliance document text'),
        ),
        const SizedBox(height: 14),
        Panel(
          background: AppColors.accentTint,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.warning),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Publishing forces every member to re-consent before their next session — this is not a routine edit.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        FilledButton(onPressed: _publish, child: const Text('Publish new version')),
      ],
    );
  }
}
