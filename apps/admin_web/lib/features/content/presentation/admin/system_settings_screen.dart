import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/content.dart';

/// AD-M11.6 — System Settings. Mock mode retains all prototype tabs.
/// Firebase mode supports facility names and compliance drafts; publication and member
/// consent remain separate from ordinary text authoring.
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
  const SystemSettingsScreen({super.key, this.live = false});
  final bool live;

  @override
  State<SystemSettingsScreen> createState() => _SystemSettingsScreenState();
}

class _SystemSettingsScreenState extends State<SystemSettingsScreen>
    with SingleTickerProviderStateMixin {
  late final _tabs =
      TabController(length: 3, initialIndex: 0, vsync: this);

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
            child: Text('System settings',
                style: Theme.of(context).textTheme.headlineMedium),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Text(
                widget.live
                    ? 'Organization name and compliance drafts. Operational policies are managed separately.'
                    : 'Platform-wide configuration that applies to every member and coach.',
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
              labelStyle:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
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
              children: [
                _GeneralPreferencesTab(live: widget.live),
                _ConversionRateTab(live: widget.live),
                _ComplianceDocumentTab(live: widget.live),
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
  const _SettingsRow(
      {required this.label, this.description, required this.control});

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
                Text(label,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                if (description != null) ...[
                  const SizedBox(height: 2),
                  Text(description!,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(fontSize: 12)),
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
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: form),
                const SizedBox(width: 20),
                Expanded(flex: 2, child: rail),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [form, const SizedBox(height: 20), rail]);
    });
  }
}

class _GeneralPreferencesTab extends StatefulWidget {
  const _GeneralPreferencesTab({this.live = false});
  final bool live;

  @override
  State<_GeneralPreferencesTab> createState() => _GeneralPreferencesTabState();
}

class _GeneralPreferencesTabState extends State<_GeneralPreferencesTab> {
  late final _name =
      TextEditingController(text: widget.live ? '' : 'GainPath, Kulim');
  String _timezone = 'Asia/Kuala_Lumpur (GMT+8)';
  bool _maintenance = false;
  FacilityNameSnapshot? _original;
  bool _loading = false, _saving = false, _blocked = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    if (widget.live) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _blocked = false;
      _error = null;
      _original = null;
      _name.clear();
    });
    try {
      final value = await context.read<FacilitySettingsRepository>().load();
      if (!mounted) return;
      setState(() {
        _original = value;
        _name.text = value.displayName;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Could not load the facility name. Check your Admin access and reload.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_original == null || _loading || _saving || _blocked) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saved = await context
          .read<FacilitySettingsRepository>()
          .save(_original!, displayName: _name.text);
      if (!mounted) return;
      setState(() {
        _original = saved;
        _name.text = saved.displayName;
      });
      showToast(context, 'Facility name saved.');
    } on FormatException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on FacilitySettingsConflict {
      if (mounted) {
        setState(() {
          _blocked = true;
          _error = 'Facility settings changed. Reload before saving again.';
        });
      }
    } on FacilitySettingsSessionChanged {
      if (mounted) {
        setState(() {
          _blocked = true;
          _error = 'Account or permissions changed. Sign in again.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _blocked = true;
          _error =
              'Save could not be verified. Reload to check the current facility name.';
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

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
            if (_loading) const LinearProgressIndicator(),
            if (_error != null)
              Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(_error!,
                      style: const TextStyle(color: AppColors.danger))),
            Panel(
              child: Column(
                children: [
                  _SettingsRow(
                    label: 'Facility name',
                    description: widget.live
                        ? 'Organization display name.'
                        : 'Shown across the console and member-facing receipts.',
                    control: TextField(
                        enabled: !widget.live ||
                            (!_loading && !_saving && _original != null),
                        maxLength: widget.live ? 120 : null,
                        controller: _name,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                            isDense: true,
                            labelText: widget.live ? 'Facility name' : null)),
                  ),
                  const Divider(height: 1),
                  _SettingsRow(
                    label: 'Timezone',
                    description: widget.live
                        ? 'Booking configuration is managed separately.'
                        : 'Used for all scheduling and reporting.',
                    control: widget.live
                        ? const Text('Unchanged · not editable here')
                        : DropdownButtonFormField<String>(
                            initialValue: _timezone,
                            isExpanded: true,
                            decoration: const InputDecoration(isDense: true),
                            items: const [
                              DropdownMenuItem(
                                  value: 'Asia/Kuala_Lumpur (GMT+8)',
                                  child: Text('Asia/Kuala_Lumpur (GMT+8)')),
                              DropdownMenuItem(
                                  value: 'Asia/Singapore (GMT+8)',
                                  child: Text('Asia/Singapore (GMT+8)')),
                            ],
                            onChanged: (v) =>
                                setState(() => _timezone = v ?? _timezone),
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
                description: widget.live
                    ? 'Operational availability is managed separately.'
                    : 'Shows a banner and blocks new bookings platform-wide.',
                control: widget.live
                    ? const Text('Not editable here')
                    : Align(
                        alignment: Alignment.centerLeft,
                        child: Switch(
                            value: _maintenance,
                            onChanged: (v) => setState(() => _maintenance = v)),
                      ),
              ),
            ),
            const SizedBox(height: 24),
            if (widget.live)
              Wrap(spacing: 12, runSpacing: 8, children: [
                FilledButton(
                    onPressed:
                        _loading || _saving || _blocked || _original == null
                            ? null
                            : _save,
                    child: Text(_saving ? 'Saving…' : 'Save facility name')),
                OutlinedButton(
                    onPressed: _loading || _saving ? null : _load,
                    child: const Text('Reload facility name')),
              ])
            else
              FilledButton(
                onPressed: () => showToast(context, 'Preferences deployed.'),
                child: const Text('Deploy changes'),
              ),
          ],
        ),
        rail: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Eyebrow(widget.live ? 'Saved settings' : 'Current status'),
            Panel(
              child: Column(
                children: [
                  DetailRow(
                      'Facility',
                      widget.live
                          ? (_original?.displayName ?? 'Unavailable')
                          : _name.text.isEmpty
                              ? '—'
                              : _name.text),
                  const Divider(height: 20),
                  if (widget.live)
                    DetailRow('Organization',
                        _original?.organizationId ?? 'Unavailable')
                  else ...[
                    DetailRow('Timezone', _timezone),
                    const Divider(height: 20),
                    DetailRow('Bookings', _maintenance ? 'Blocked' : 'Open'),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (widget.live)
              const Panel(
                  child: Text('Only the facility display name is saved here.'))
            else if (_maintenance)
              Panel(
                background: AppColors.dangerTint,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        size: 18, color: AppColors.danger),
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
                    const Icon(Icons.info_outline_rounded,
                        size: 18, color: AppColors.primary),
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
  final bool live;
  const _ConversionRateTab({this.live = false});

  @override
  State<_ConversionRateTab> createState() => _ConversionRateTabState();
}

class _ConversionRateTabState extends State<_ConversionRateTab> {
  late final _rate = TextEditingController(text: widget.live ? '—' : '200');
  String? _error;

  @override
  void dispose() {
    _rate.dispose();
    super.dispose();
  }

  void _save() {
    if (widget.live) return;
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
    final rate = widget.live ? 0 : (int.tryParse(_rate.text.trim()) ?? 0);
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
                description:
                    'How many gamification points equal RM 1.00 in the reward shop.',
                control: TextField(
                  controller: _rate,
                  enabled: !widget.live,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {
                    if (_error != null) _error = null;
                  }),
                  decoration: InputDecoration(isDense: true, errorText: _error),
                ),
              ),
            ),
            if (widget.live) ...[
              const SizedBox(height: 12),
              Panel(
                background: AppColors.surface,
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        size: 18, color: AppColors.inkSoft),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Reward conversion policy is managed by organization operations and is read-only in this console.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
                onPressed: widget.live ? null : _save,
                child: const Text('Save conversion rate')),
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
                  Text(
                      widget.live
                          ? 'Conversion rate: —'
                          : 'At $rate points = RM 1.00:',
                      style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: 14),
                  DetailRow(
                      'RM 10 reward', rate == 0 ? '—' : '${rate * 10} pts'),
                  const Divider(height: 20),
                  DetailRow(
                      'RM 25 reward', rate == 0 ? '—' : '${rate * 25} pts'),
                  const Divider(height: 20),
                  DetailRow(
                      'RM 50 reward', rate == 0 ? '—' : '${rate * 50} pts'),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Panel(
              background: AppColors.accentTint,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      size: 18, color: AppColors.warning),
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
  const _ComplianceDocumentTab({this.live = false});
  final bool live;

  @override
  State<_ComplianceDocumentTab> createState() => _ComplianceDocumentTabState();
}

class _ComplianceDocumentTabState extends State<_ComplianceDocumentTab> {
  ComplianceDocumentSnapshot? _snapshot;
  bool _loading = false, _saving = false, _blocked = false, _started = false;
  String? _error;
  bool get _busy => _loading || _saving;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.live && !_started) {
      _started = true;
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _blocked = true;
      _error = null;
    });
    try {
      final loaded = await context.read<ComplianceDocumentRepository>().load();
      if (!mounted) return;
      setState(() {
        _snapshot = loaded;
        _controller.text = loaded.current?.text ?? '';
        _blocked = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Could not load the compliance draft. Check access and retry.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save({bool? isArchived}) async {
    if (_snapshot == null || _busy || _blocked) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saved = await context.read<ComplianceDocumentRepository>().save(
          _snapshot!,
          text: _controller.text,
          isArchived: isArchived ?? _snapshot!.current?.isArchived ?? false);
      if (!mounted) return;
      setState(() {
        _snapshot = saved;
        _controller.text = saved.current!.text;
      });
      showToast(context, 'Compliance draft v${saved.current!.revision} saved.');
    } on FormatException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on ComplianceDocumentConflict {
      if (mounted) {
        setState(() {
          _blocked = true;
          _error = 'The compliance draft changed. Reload before saving again.';
        });
      }
    } on ComplianceDocumentSessionChanged {
      if (mounted) {
        setState(() {
          _blocked = true;
          _error = 'Account or permissions changed. Sign in again.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _blocked = true;
          _error =
              'Save could not be verified. Reload to check the saved version.';
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  static const _history = [
    ['v5', 'Current — clarified biometric data retention wording'],
    ['v4', 'Added third-party analytics disclosure'],
    ['v3', 'Initial GDPR-aligned rewrite'],
  ];

  late final _controller = TextEditingController(
    text: widget.live
        ? ''
        : 'GainPath collects biometric movement data solely to power on-device pose tracking. '
            'No video is ever recorded, stored, or transmitted off your device...',
  );

  Future<void> _publish() async {
    final ok = await confirmDialog(
      context,
      title: 'Publish a new version?',
      message:
          'This increments the document version and flags every member\'s consent record as '
          'unverified against it — they will be asked to re-consent the next time they open the app.',
      confirmLabel: 'Publish new version',
    );
    if (ok && mounted) {
      showToast(context,
          'Compliance document updated to v6. Members will be asked to re-consent.');
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
                  child: Text(
                      widget.live
                          ? 'Privacy and liability draft for review.'
                          : 'Privacy and liability document shown during onboarding consent.',
                      style: Theme.of(context).textTheme.bodyLarge),
                ),
                if (widget.live)
                  IconButton(
                      tooltip: 'Reload compliance draft',
                      onPressed: _busy ? null : _load,
                      icon: const Icon(Icons.refresh)),
                statusPill(widget.live
                    ? _snapshot?.current == null
                        ? 'No saved draft'
                        : 'v${_snapshot!.current!.revision} ${_snapshot!.current!.isArchived ? 'archived' : 'draft'}'
                    : 'v5 live'),
              ],
            ),
            const SizedBox(height: 16),
            if (_loading) const LinearProgressIndicator(),
            if (_error != null)
              Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(_error!)),
            if (widget.live &&
                !_busy &&
                _error == null &&
                _snapshot?.current == null)
              const Panel(
                  child: Text(
                      'No compliance draft has been saved. Enter text to create the first draft.')),
            TextField(
              controller: _controller,
              enabled: !widget.live ||
                  (!_busy &&
                      !_blocked &&
                      _snapshot?.current?.isArchived != true),
              maxLength: widget.live ? 12000 : null,
              maxLines: 10,
              decoration:
                  const InputDecoration(hintText: 'Compliance document text'),
            ),
            const SizedBox(height: 14),
            Panel(
              background: AppColors.accentTint,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      size: 18, color: AppColors.warning),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.live
                          ? 'Drafts are visible only to organization Administrators. Saving or archiving does not publish legal text or change member consent.'
                          : 'Publishing forces every member to re-consent before their next session — this is not a routine edit.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (widget.live)
              Wrap(spacing: 12, runSpacing: 12, children: [
                FilledButton(
                    onPressed: _busy ||
                            _blocked ||
                            _snapshot?.current?.isArchived == true
                        ? null
                        : () => _save(),
                    child: Text(_saving ? 'Saving…' : 'Save draft version')),
                if (_snapshot?.current != null)
                  OutlinedButton(
                      onPressed: _busy || _blocked
                          ? null
                          : () => _save(
                              isArchived: !_snapshot!.current!.isArchived),
                      child: Text(_snapshot!.current!.isArchived
                          ? 'Restore draft'
                          : 'Archive draft')),
              ])
            else
              FilledButton(
                  onPressed: _publish,
                  child: const Text('Publish new version')),
          ],
        ),
        rail: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Eyebrow(widget.live
                ? 'Version history · latest 20'
                : 'Version history'),
            Panel(
              padding: EdgeInsets.zero,
              child: Column(
                children: List.generate(
                    widget.live
                        ? _snapshot?.history.length ?? 0
                        : _history.length, (i) {
                  final saved = widget.live ? _snapshot!.history[i] : null;
                  final h = saved == null
                      ? _history[i]
                      : [
                          'v${saved.revision}',
                          '${saved.isArchived ? 'Archived' : 'Draft'} · ${saved.updatedAt.toLocal()}\n${saved.text}'
                        ];
                  return Column(
                    children: [
                      if (i > 0) const Divider(height: 1, indent: 16),
                      ListTile(
                        dense: true,
                        leading: statusPill(h[0]),
                        title:
                            Text(h[1], style: const TextStyle(fontSize: 12.5)),
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
