import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../widgets/shared.dart';
import '../admin_dialogs.dart';

/// AD-M11.6 — Configure System Settings. Platform-wide configuration
/// across three areas — General Preferences, Reward Conversion Rates,
/// and Legal / Compliance Documents — kept deliberately separate from
/// AD-M11.4's chatbot disclaimer, since publishing the compliance
/// document has a real data-integrity side effect (every member's
/// consent record is flagged unverified against it).
///
/// Lives directly in the sidebar as an in-place content pane — the
/// internal `TabBar` below is a section switch within the pane, not a
/// pushed screen, so there's still no back button anywhere in this flow.
/// Every field is laid out label-left/control-right, and each tab pairs
/// its form with a contextual info rail on the right (current status, a
/// live example, version history) — a capped-width form alone left the
/// right half of a wide desktop screen empty; this fills it with
/// something actually useful instead of just stretching fields wider.
class SystemSettingsScreen extends StatefulWidget {
  const SystemSettingsScreen({super.key});

  @override
  State<SystemSettingsScreen> createState() => _SystemSettingsScreenState();
}

class _SystemSettingsScreenState extends State<SystemSettingsScreen>
    with SingleTickerProviderStateMixin {
  late final _tabs = TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
            child: Text('System settings', style: Theme.of(context).textTheme.headlineMedium),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Text('Platform-wide configuration that applies to every member and coach.',
                style: Theme.of(context).textTheme.bodyLarge),
          ),
          const SizedBox(height: 18),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 28),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.hairline),
            ),
            child: TabBar(
              controller: _tabs,
              isScrollable: false,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.inkSoft,
              indicatorSize: TabBarIndicatorSize.tab,
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              tabs: const [
                Tab(text: 'General'),
                Tab(text: 'Reward conversion'),
                Tab(text: 'Legal & compliance'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: const [
                _GeneralPreferencesTab(),
                _ConversionRateTab(),
                _ComplianceDocumentTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A single label-left/description/control-right settings row.
class _SettingsRow extends StatelessWidget {
  final String label;
  final String? description;
  final Widget control;
  const _SettingsRow({required this.label, this.description, required this.control});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 200,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                if (description != null) ...[
                  const SizedBox(height: 2),
                  Text(description!, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 24),
          Expanded(child: control),
        ],
      ),
    );
  }
}

/// Splits a settings tab into a form (left) and a contextual info rail
/// (right) on wide screens, stacking on narrow ones — the AWS-console
/// pattern of a form paired with a status/help panel, instead of a lone
/// centered column leaving half the page empty.
class _SettingsTabLayout extends StatelessWidget {
  final Widget form;
  final Widget rail;
  const _SettingsTabLayout({required this.form, required this.rail});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= 900;
      return wide
          ? IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: form),
                  const SizedBox(width: 20),
                  Expanded(flex: 2, child: rail),
                ],
              ),
            )
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [form, const SizedBox(height: 20), rail]);
    });
  }
}

class _GeneralPreferencesTab extends StatefulWidget {
  const _GeneralPreferencesTab();

  @override
  State<_GeneralPreferencesTab> createState() => _GeneralPreferencesTabState();
}

class _GeneralPreferencesTabState extends State<_GeneralPreferencesTab> {
  late final _name = TextEditingController(text: 'GainPath, Kulim');
  String _timezone = 'Asia/Kuala_Lumpur (GMT+8)';
  bool _maintenance = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 32),
      child: _SettingsTabLayout(
        form: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Eyebrow('Facility'),
            Panel(
              child: Column(
                children: [
                  _SettingsRow(
                    label: 'Facility name',
                    description: 'Shown across the console and member-facing receipts.',
                    control: TextField(
                        controller: _name,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(isDense: true)),
                  ),
                  const Divider(height: 1),
                  _SettingsRow(
                    label: 'Timezone',
                    description: 'Used for all scheduling and reporting.',
                    control: DropdownButtonFormField<String>(
                      initialValue: _timezone,
                      isExpanded: true,
                      decoration: const InputDecoration(isDense: true),
                      items: const [
                        DropdownMenuItem(value: 'Asia/Kuala_Lumpur (GMT+8)', child: Text('Asia/Kuala_Lumpur (GMT+8)')),
                        DropdownMenuItem(value: 'Asia/Singapore (GMT+8)', child: Text('Asia/Singapore (GMT+8)')),
                      ],
                      onChanged: (v) => setState(() => _timezone = v ?? _timezone),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Eyebrow('Availability'),
            Panel(
              child: _SettingsRow(
                label: 'Maintenance mode',
                description: 'Shows a banner and blocks new bookings platform-wide.',
                control: Align(
                  alignment: Alignment.centerLeft,
                  child: Switch(value: _maintenance, onChanged: (v) => setState(() => _maintenance = v)),
                ),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => showToast(context, 'Preferences deployed.'),
              child: const Text('Deploy changes'),
            ),
          ],
        ),
        rail: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Eyebrow('Current status'),
            Panel(
              child: Column(
                children: [
                  DetailRow('Facility', _name.text.isEmpty ? '—' : _name.text),
                  const Divider(height: 20),
                  DetailRow('Timezone', _timezone),
                  const Divider(height: 20),
                  DetailRow('Bookings', _maintenance ? 'Blocked' : 'Open'),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (_maintenance)
              Panel(
                background: AppColors.dangerTint,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.danger),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Maintenance mode is on — members see a banner and cannot make new bookings until this is switched off.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              )
            else
              Panel(
                background: AppColors.primaryTint,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Timezone changes apply to every future booking slot and report immediately — existing bookings keep their original time.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
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
    final rate = int.tryParse(_rate.text.trim()) ?? 0;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 32),
      child: _SettingsTabLayout(
        form: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Eyebrow('Reward shop'),
            Panel(
              child: _SettingsRow(
                label: 'Points per RM 1.00',
                description: 'How many gamification points equal RM 1.00 in the reward shop.',
                control: TextField(
                  controller: _rate,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {
                    if (_error != null) _error = null;
                  }),
                  decoration: InputDecoration(isDense: true, errorText: _error),
                ),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: _save, child: const Text('Save conversion rate')),
          ],
        ),
        rail: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Eyebrow('Worked example'),
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('At $rate points = RM 1.00:', style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: 14),
                  DetailRow('RM 10 reward', rate == 0 ? '—' : '${rate * 10} pts'),
                  const Divider(height: 20),
                  DetailRow('RM 25 reward', rate == 0 ? '—' : '${rate * 25} pts'),
                  const Divider(height: 20),
                  DetailRow('RM 50 reward', rate == 0 ? '—' : '${rate * 50} pts'),
                ],
              ),
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
                      'Raising this rate makes every reward in the catalog cost more points immediately — it does not change points members have already earned.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
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

class _ComplianceDocumentTab extends StatefulWidget {
  const _ComplianceDocumentTab();

  @override
  State<_ComplianceDocumentTab> createState() => _ComplianceDocumentTabState();
}

class _ComplianceDocumentTabState extends State<_ComplianceDocumentTab> {
  static const _history = [
    ['v5', 'Current — clarified biometric data retention wording'],
    ['v4', 'Added third-party analytics disclosure'],
    ['v3', 'Initial GDPR-aligned rewrite'],
  ];

  late final _controller = TextEditingController(
    text: 'GainPath collects biometric movement data solely to power on-device pose tracking. '
        'No video is ever recorded, stored, or transmitted off your device...',
  );

  Future<void> _publish() async {
    final ok = await confirmDialog(
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
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 32),
      child: _SettingsTabLayout(
        form: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
            const SizedBox(height: 16),
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
        ),
        rail: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Eyebrow('Version history'),
            Panel(
              padding: EdgeInsets.zero,
              child: Column(
                children: List.generate(_history.length, (i) {
                  final h = _history[i];
                  return Column(
                    children: [
                      if (i > 0) const Divider(height: 1, indent: 16),
                      ListTile(
                        dense: true,
                        leading: statusPill(h[0]),
                        title: Text(h[1], style: const TextStyle(fontSize: 12.5)),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
