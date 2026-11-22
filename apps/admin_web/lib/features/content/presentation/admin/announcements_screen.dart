// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/content.dart';

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec'
];

DateTime _myt(DateTime date) => date.toUtc().add(const Duration(hours: 8));

String _fmt(DateTime date) {
  final d = _myt(date);
  return '${d.day} ${_months[d.month - 1]} ${d.year}';
}

String _label(AnnouncementDisplayStatus? status) => status == null
    ? 'All'
    : status.name[0].toUpperCase() + status.name.substring(1);

/// AD-M11.4 — asynchronous scoped announcement authoring. Repository saves
/// retain the original edit baseline; only verified persistence reports success.
class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen(
      {super.key, this.loadBranches, this.initialAnnouncementId});

  final String? initialAnnouncementId;

  final Future<Map<String, ({String name, bool active})>> Function()?
      loadBranches;

  @override
  State<AnnouncementsScreen> createState() => AnnouncementsScreenState();
}

class AnnouncementsScreenState extends State<AnnouncementsScreen> {
  bool _composing = false;
  bool _loading = true, _saving = false, _reloadRequired = false;
  String? _error;
  String _search = '';
  final TextEditingController _searchController = TextEditingController();
  AnnouncementDisplayStatus? _filter;
  String? _branchFilter;
  AnnouncementCategory? _categoryFilter;
  Map<String, ({String name, bool active})> _branches = {};
  AnnouncementAudience _audience = AnnouncementAudience.all;
  Set<String> _targets = {};
  AnnouncementCategory _category = AnnouncementCategory.general;
  AnnouncementPriority _priority = AnnouncementPriority.normal;
  bool _schedule = false;

  String _audienceLabel(AnnouncementAudience audience, Iterable<String> ids) {
    if (audience == AnnouncementAudience.all) return 'All branches';
    if (ids.isEmpty) return 'No branches selected';
    return ids
        .map((id) => _branches[id]?.name ?? 'Unavailable branch')
        .join(', ');
  }

  List<Announcement> _entries = [];
  Announcement? _editing;
  int _generation = 0;
  final _title = TextEditingController();
  final _body = TextEditingController();
  DateTime _from = DateTime.now();
  DateTime _to = DateTime.now().add(const Duration(days: 7));

  @override
  void initState() {
    super.initState();
    _load(openId: widget.initialAnnouncementId);
  }

  @override
  void didUpdateWidget(covariant AnnouncementsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final id = widget.initialAnnouncementId;
    if (id != null && id != oldWidget.initialAnnouncementId) {
      _load(openId: id);
    }
  }

  Future<void> _load({String? openId}) async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
      _entries = [];
      _composing = false;
      _editing = null;
      _reloadRequired = false;
    });
    try {
      final repository = context.read<ContentRepository>();
      final branches = await widget.loadBranches?.call() ?? _branches;
      if (!mounted || generation != _generation) return;
      final entries = <Announcement>[];
      final seen = <String>{};
      String? cursor;
      do {
        final page = await repository.loadAnnouncements(afterId: cursor);
        if (!mounted || generation != _generation) return;
        entries.addAll(page.items);
        cursor = page.nextCursor;
        if (cursor != null && !seen.add(cursor)) {
          throw StateError('Announcement pagination did not advance.');
        }
      } while (cursor != null);
      setState(() {
        _entries = entries;
        _branches = branches;
        if (_branchFilter != null &&
            _branchFilter!.isNotEmpty &&
            !_branches.containsKey(_branchFilter)) {
          _branchFilter = null;
        }
        _loading = false;
      });
      if (openId != null) {
        final entry = entries.where((item) => item.id == openId).firstOrNull;
        if (entry == null) {
          setState(() => _error = 'This announcement is no longer available.');
        } else {
          _open(entry);
        }
      }
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _loading = false;
        _entries = [];
        _error =
            'Could not load announcements. Check your authorization and retry.';
      });
    }
  }

  void _open([Announcement? entry]) => setState(() {
        _editing = entry;
        _composing = true;
        _reloadRequired = false;
        _error = null;
        _title.text = entry?.title ?? '';
        _body.text = entry?.body ?? '';
        _audience = entry?.audience ?? AnnouncementAudience.all;
        _targets = {...?entry?.targetBranchIds};
        _category = entry?.category ?? AnnouncementCategory.general;
        _priority = entry?.priority ?? AnnouncementPriority.normal;
        _schedule = entry?.validFrom.isAfter(DateTime.now()) ?? false;
        _from = entry?.validFrom ?? DateTime.now();
        _to = entry?.validTo ?? DateTime.now().add(const Duration(days: 7));
      });

  Future<bool> canLeave() async {
    if (_saving) return false;
    if (!_composing) return true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard announcement changes?'),
        content: const Text(
            'Any unsaved content, audience targets, or schedule settings will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (mounted && discard == true) {
      setState(() {
        _composing = false;
        _error = null;
      });
      return true;
    }
    return false;
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _myt(isFrom ? _from : _to),
      firstDate: DateTime(2000),
      lastDate: DateTime(9999),
    );
    if (picked != null && mounted && !_saving) {
      final midnight = DateTime.utc(picked.year, picked.month, picked.day)
          .subtract(const Duration(hours: 8));
      setState(() => isFrom ? _from = midnight : _to = midnight);
    }
  }

  Future<void> _save(AnnouncementStatus status,
      {Announcement? existing}) async {
    if (_saving || _reloadRequired) return;
    final published = status == AnnouncementStatus.published;
    final publishNow = published &&
        !_schedule &&
        (_editing?.status != AnnouncementStatus.published ||
            _editing?.displayStatusAt(DateTime.now()) ==
                AnnouncementDisplayStatus.expired);
    final entry = existing?.copyWith(status: status) ??
        (_editing ??
                Announcement(
                    id: '',
                    title: '',
                    body: '',
                    validFrom: _from,
                    validTo: _to))
            .copyWith(
                title: _title.text.trim(),
                body: _body.text.trim(),
                validFrom: publishNow ? DateTime.now() : _from,
                validTo: _to,
                status: status,
                audience: _audience,
                targetBranchIds: _audience == AnnouncementAudience.branches
                    ? _targets.toList()
                    : const [],
                category: _category,
                priority: _priority);
    try {
      entry.validate();
      if (existing == null &&
          published &&
          !entry.validTo.isAfter(DateTime.now())) {
        throw const FormatException('Choose an end date in the future.');
      }
    } on FormatException catch (e) {
      showToast(context, e.message);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await context.read<ContentRepository>().saveAnnouncement(entry);
      if (!mounted) return;
      showToast(
          context,
          status == AnnouncementStatus.published
              ? 'Announcement saved and published. Members can refresh Home.'
              : status == AnnouncementStatus.inactive
                  ? 'Announcement deactivated.'
                  : 'Draft saved.');
      await _load();
    } on AnnouncementConflict {
      if (mounted) {
        setState(() {
          _reloadRequired = true;
          _error =
              'This announcement changed or was removed. Discard and reload before saving.';
        });
      }
    } on AnnouncementSessionChanged {
      if (mounted) {
        setState(() {
          _reloadRequired = true;
          _error =
              'Your account or authorization changed. Sign in again before editing.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _reloadRequired = true;
          _error = 'Save was not verified. Discard and reload before retrying.';
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  IconData _categoryIcon(AnnouncementCategory category) => switch (category) {
        AnnouncementCategory.general => Icons.campaign_outlined,
        AnnouncementCategory.maintenance => Icons.construction_outlined,
        AnnouncementCategory.closure => Icons.door_front_door_outlined,
        AnnouncementCategory.promotion => Icons.local_offer_outlined,
        AnnouncementCategory.event => Icons.event_outlined,
        AnnouncementCategory.update => Icons.info_outline,
      };

  @override
  Widget build(BuildContext context) {
    if (_composing) {
      return _buildComposer(context);
    }
    return _buildManagementHub(context);
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 1. ANNOUNCEMENT MANAGEMENT HUB (Dashboard View)
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildManagementHub(BuildContext context) {
    final announcements = [..._entries]
      ..sort((a, b) => b.validFrom.compareTo(a.validFrom));
    final now = DateTime.now();
    int count(AnnouncementDisplayStatus status) =>
        announcements.where((a) => a.displayStatusAt(now) == status).length;

    final visible = announcements.where((a) {
      final statusMatch = _filter == null || a.displayStatusAt(now) == _filter;
      final audienceMatch = _branchFilter == null ||
          (_branchFilter == ''
              ? a.audience == AnnouncementAudience.all
              : a.targetBranchIds.contains(_branchFilter));
      final categoryMatch =
          _categoryFilter == null || a.category == _categoryFilter;
      final searchMatch = _search.isEmpty ||
          a.title.toLowerCase().contains(_search) ||
          a.body.toLowerCase().contains(_search);
      return statusMatch && audienceMatch && categoryMatch && searchMatch;
    }).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(32, 28, 32, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page Header
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Announcements',
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink,
                              fontSize: 26,
                            ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Create and publish updates across your gym locations.',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!_loading && _error == null)
                  FilledButton.icon(
                    onPressed: _saving ? null : () => _open(),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('New announcement'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),

            if (_loading) const LinearProgressIndicator(),

            if (!_loading && _error != null)
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.warning),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: AppColors.warning),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _error!,
                        style:
                            const TextStyle(color: AppColors.ink, fontSize: 14),
                      ),
                    ),
                    TextButton(
                      onPressed: _saving ? null : () => _load(),
                      child: Text(_reloadRequired
                          ? 'Discard and reload'
                          : 'Retry announcements'),
                    ),
                  ],
                ),
              ),

            if (!_loading && _error == null) ...[
              // KPI Cards Row
              LayoutBuilder(
                builder: (context, constraints) {
                  final kpis = [
                    (
                      label: 'Total announcements',
                      value: '${announcements.length}',
                      icon: Icons.campaign_outlined,
                      color: AppColors.primary,
                    ),
                    (
                      label: 'Active',
                      value: '${count(AnnouncementDisplayStatus.active)}',
                      icon: Icons.check_circle_outline_rounded,
                      color: AppColors.success,
                    ),
                    (
                      label: 'Scheduled',
                      value: '${count(AnnouncementDisplayStatus.scheduled)}',
                      icon: Icons.schedule_rounded,
                      color: AppColors.warning,
                    ),
                    (
                      label: 'Drafts',
                      value: '${count(AnnouncementDisplayStatus.draft)}',
                      icon: Icons.edit_note_rounded,
                      color: AppColors.inkSoft,
                    ),
                  ];

                  if (constraints.maxWidth >= 900) {
                    return Row(
                      children: [
                        for (int i = 0; i < kpis.length; i++) ...[
                          if (i > 0) const SizedBox(width: 16),
                          Expanded(
                            child: _KpiMetricCard(
                              icon: kpis[i].icon,
                              label: kpis[i].label,
                              value: kpis[i].value,
                              color: kpis[i].color,
                            ),
                          ),
                        ],
                      ],
                    );
                  } else if (constraints.maxWidth >= 540) {
                    return Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _KpiMetricCard(
                                icon: kpis[0].icon,
                                label: kpis[0].label,
                                value: kpis[0].value,
                                color: kpis[0].color,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _KpiMetricCard(
                                icon: kpis[1].icon,
                                label: kpis[1].label,
                                value: kpis[1].value,
                                color: kpis[1].color,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _KpiMetricCard(
                                icon: kpis[2].icon,
                                label: kpis[2].label,
                                value: kpis[2].value,
                                color: kpis[2].color,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _KpiMetricCard(
                                icon: kpis[3].icon,
                                label: kpis[3].label,
                                value: kpis[3].value,
                                color: kpis[3].color,
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  } else {
                    return Column(
                      children: [
                        for (final kpi in kpis) ...[
                          _KpiMetricCard(
                            icon: kpi.icon,
                            label: kpi.label,
                            value: kpi.value,
                            color: kpi.color,
                          ),
                          const SizedBox(height: 12),
                        ],
                      ],
                    );
                  }
                },
              ),
              const SizedBox(height: 24),

              // Unified Management Table Container
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.hairline),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Status Tabs Bar
                    _buildStatusTabs(announcements, now),
                    const Divider(height: 1, color: AppColors.hairline),

                    // Filter Toolbar
                    _buildFilterToolbar(context),
                    const Divider(height: 1, color: AppColors.hairline),

                    // Table Contents
                    if (announcements.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 48),
                        child: Center(
                          child: Text(
                            'No announcements yet. Create a draft to get started.',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.inkSoft,
                            ),
                          ),
                        ),
                      )
                    else if (visible.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 48),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.filter_list_off_rounded,
                                  size: 32, color: AppColors.inkSoft),
                              const SizedBox(height: 10),
                              const Text(
                                'No announcements match your filters.',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.ink,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Try clearing your search query or switching audience and status tabs.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.inkSoft,
                                ),
                              ),
                              const SizedBox(height: 14),
                              TextButton(
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _search = '';
                                    _filter = null;
                                    _branchFilter = null;
                                    _categoryFilter = null;
                                  });
                                },
                                child: const Text('Clear all filters'),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final wide = constraints.maxWidth >= 760;
                          return Column(
                            children: [
                              if (wide)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceAlt
                                        .withValues(alpha: 0.4),
                                  ),
                                  child: const Row(
                                    children: [
                                      Expanded(
                                        flex: 4,
                                        child: Text(
                                          'Announcement',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.inkSoft,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          'Audience',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.inkSoft,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          'Status',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.inkSoft,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 3,
                                        child: Text(
                                          'Display period',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.inkSoft,
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 56,
                                        child: Text(
                                          'Actions',
                                          textAlign: TextAlign.end,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.inkSoft,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              for (int i = 0; i < visible.length; i++) ...[
                                if (i > 0 || wide)
                                  const Divider(
                                      height: 1, color: AppColors.hairline),
                                _buildTableRow(visible[i], now, wide),
                              ],
                            ],
                          );
                        },
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Horizontal Status Tabs Bar
  Widget _buildStatusTabs(List<Announcement> announcements, DateTime now) {
    int countFor(AnnouncementDisplayStatus? status) {
      if (status == null) return announcements.length;
      return announcements
          .where((a) => a.displayStatusAt(now) == status)
          .length;
    }

    final tabs = <AnnouncementDisplayStatus?>[
      null,
      AnnouncementDisplayStatus.active,
      AnnouncementDisplayStatus.scheduled,
      AnnouncementDisplayStatus.draft,
      AnnouncementDisplayStatus.expired,
      AnnouncementDisplayStatus.deactivated,
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          for (final status in tabs)
            InkWell(
              onTap: () => setState(() => _filter = status),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: _filter == status
                          ? AppColors.primary
                          : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _label(status),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: _filter == status
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: _filter == status
                            ? AppColors.primary
                            : AppColors.inkSoft,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _filter == status
                            ? AppColors.primaryTint
                            : AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${countFor(status)}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _filter == status
                              ? AppColors.primary
                              : AppColors.inkSoft,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Filter Toolbar (Search + Audience Dropdown + Refresh Button)
  Widget _buildFilterToolbar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Search Input
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 260, maxWidth: 340),
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.hairline),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.search_rounded,
                          size: 18, color: AppColors.inkSoft),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: (v) =>
                              setState(() => _search = v.trim().toLowerCase()),
                          decoration: const InputDecoration(
                            hintText: 'Search by title or message',
                            hintStyle: TextStyle(
                              color: AppColors.inkSoft,
                              fontSize: 13,
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 10),
                            isDense: true,
                            filled: false,
                          ),
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.ink),
                        ),
                      ),
                      if (_search.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 16),
                          splashRadius: 14,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _search = '');
                          },
                        ),
                    ],
                  ),
                ),
              ),

              // Audience Dropdown Filter
              Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.hairline),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _branchFilter ?? '*',
                    icon: const Icon(Icons.arrow_drop_down_rounded,
                        color: AppColors.inkSoft),
                    style: const TextStyle(fontSize: 13, color: AppColors.ink),
                    onChanged: (value) => setState(
                        () => _branchFilter = value == '*' ? null : value),
                    items: [
                      const DropdownMenuItem(
                          value: '*', child: Text('All audiences')),
                      const DropdownMenuItem(
                          value: '', child: Text('Global only')),
                      for (final branch in _branches.entries)
                        DropdownMenuItem(
                            value: branch.key, child: Text(branch.value.name)),
                    ],
                  ),
                ),
              ),

              // Category Filter Dropdown
              Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.hairline),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<AnnouncementCategory?>(
                    value: _categoryFilter,
                    icon: const Icon(Icons.arrow_drop_down_rounded,
                        color: AppColors.inkSoft),
                    style: const TextStyle(fontSize: 13, color: AppColors.ink),
                    hint: const Text('All categories',
                        style:
                            TextStyle(fontSize: 13, color: AppColors.inkSoft)),
                    onChanged: (value) =>
                        setState(() => _categoryFilter = value),
                    items: [
                      const DropdownMenuItem(
                          value: null, child: Text('All categories')),
                      for (final category in AnnouncementCategory.values)
                        DropdownMenuItem(
                            value: category,
                            child: Text(category.name[0].toUpperCase() +
                                category.name.substring(1))),
                    ],
                  ),
                ),
              ),

              if (_search.isNotEmpty ||
                  _branchFilter != null ||
                  _categoryFilter != null ||
                  _filter != null)
                TextButton.icon(
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _search = '';
                      _filter = null;
                      _branchFilter = null;
                      _categoryFilter = null;
                    });
                  },
                  icon: const Icon(Icons.close_rounded, size: 14),
                  label: const Text('Reset', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.inkSoft,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          ),

          // Action Toolbar Right: Refresh Button
          IconButton(
            tooltip: 'Refresh announcements',
            onPressed: _saving || _loading ? null : () => _load(),
            icon: const Icon(Icons.refresh_rounded, size: 20),
            color: AppColors.inkSoft,
          ),
        ],
      ),
    );
  }

  // Table Row for an Announcement
  Widget _buildTableRow(Announcement entry, DateTime now, bool wide) {
    final status = entry.displayStatusAt(now);
    final audience = _audienceLabel(entry.audience, entry.targetBranchIds);
    final period = '${_fmt(entry.validFrom)} – ${_fmt(entry.validTo)} MYT';

    final categoryColor = switch (entry.category) {
      AnnouncementCategory.maintenance => AppColors.warning,
      AnnouncementCategory.closure => AppColors.danger,
      AnnouncementCategory.promotion => AppColors.primary,
      AnnouncementCategory.event => AppColors.success,
      _ => AppColors.primary,
    };

    final heading = Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: categoryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(_categoryIcon(entry.category),
              size: 18, color: categoryColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      entry.title.isEmpty ? 'Untitled draft' : entry.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  if (entry.priority == AnnouncementPriority.important) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Important',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.warning,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                entry.body,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.inkSoft,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    final actions = PopupMenuButton<String>(
      tooltip: 'Announcement actions',
      enabled: !_saving && !_reloadRequired,
      icon: const Icon(Icons.more_vert_rounded,
          size: 18, color: AppColors.inkSoft),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      onSelected: (action) {
        switch (action) {
          case 'View':
            showDialog<void>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(entry.title),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(audience,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.ink)),
                      const SizedBox(height: 4),
                      Text(period,
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.inkSoft)),
                      const SizedBox(height: 14),
                      SelectableText(entry.body),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            );
          case 'Deactivate':
            _save(AnnouncementStatus.inactive, existing: entry);
          default:
            _open(entry);
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'View', child: Text('View')),
        const PopupMenuItem(value: 'Edit', child: Text('Edit')),
        if (status == AnnouncementDisplayStatus.draft)
          const PopupMenuItem(value: 'Publish', child: Text('Publish')),
        if (status == AnnouncementDisplayStatus.active ||
            status == AnnouncementDisplayStatus.scheduled)
          const PopupMenuItem(value: 'Deactivate', child: Text('Deactivate')),
        if (status == AnnouncementDisplayStatus.expired ||
            status == AnnouncementDisplayStatus.deactivated)
          const PopupMenuItem(value: 'Republish', child: Text('Republish')),
      ],
    );

    final badge = Align(
      alignment: Alignment.centerLeft,
      child: statusPill(_label(status)),
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: wide
          ? Row(
              children: [
                Expanded(
                  flex: 4,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: heading,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Tooltip(
                    message: audience,
                    child: Text(
                      audience,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(fontSize: 13, color: AppColors.ink),
                    ),
                  ),
                ),
                Expanded(flex: 2, child: badge),
                Expanded(
                  flex: 3,
                  child: Text(
                    period,
                    style:
                        const TextStyle(fontSize: 13, color: AppColors.inkSoft),
                  ),
                ),
                SizedBox(
                  width: 56,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: actions,
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: heading),
                    actions,
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        audience,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink),
                      ),
                    ),
                    badge,
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  period,
                  style:
                      const TextStyle(fontSize: 12, color: AppColors.inkSoft),
                ),
              ],
            ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 2. ANNOUNCEMENT COMPOSER (Creation & Editing View)
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildComposer(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(32, 28, 32, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Composer Header
            Row(
              children: [
                TextButton.icon(
                  onPressed: _saving ? null : canLeave,
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: const Text('Back to Announcements'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.inkSoft,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _editing == null
                          ? 'New announcement'
                          : 'Edit announcement',
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: AppColors.ink,
                                fontSize: 26,
                              ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Draft, target, and schedule announcements for gym members.',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.inkSoft,
                      ),
                    ),
                  ],
                ),
                if (_editing != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.hairline),
                    ),
                    child: Text(
                      'Editing: ${_editing!.title.isEmpty ? 'Untitled' : _editing!.title}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.inkSoft,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),

            // Two-column Composer Layout
            LayoutBuilder(
              builder: (context, constraints) {
                final formCards = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Card 1: Message Content
                    _buildMessageContentCard(context),
                    const SizedBox(height: 20),

                    // Card 2: Target Audience
                    _buildTargetAudienceCard(context),
                    const SizedBox(height: 20),

                    // Card 3: Publishing Schedule
                    _buildPublishingScheduleCard(context),
                  ],
                );

                final previewCards = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Right Card 1: Mobile App Preview
                    _buildMemberAppPreviewCard(context),
                    const SizedBox(height: 20),

                    // Right Card 2: Publication Summary
                    _buildPublicationSummaryCard(context),
                  ],
                );

                if (constraints.maxWidth < 960) {
                  return Column(
                    children: [
                      formCards,
                      const SizedBox(height: 24),
                      previewCards,
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 65, child: formCards),
                    const SizedBox(width: 24),
                    Expanded(flex: 35, child: previewCards),
                  ],
                );
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildStickyFooter(context),
    );
  }

  // Composer Left Card 1: Message Content
  Widget _buildMessageContentCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primaryTint,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.article_outlined,
                    size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Message content',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    Text(
                      'Compose the announcement headline and body.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.inkSoft,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 28, color: AppColors.hairline),

          // Title field
          const Text(
            'Announcement title',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _title,
            onChanged: (_) => setState(() {}),
            enabled: !_saving && !_reloadRequired,
            maxLength: 120,
            style: const TextStyle(fontSize: 14, color: AppColors.ink),
            decoration: InputDecoration(
              hintText: 'e.g. Public holiday operating hours',
              hintStyle:
                  const TextStyle(color: AppColors.inkSoft, fontSize: 14),
              filled: true,
              fillColor: AppColors.surface,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.hairline),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.hairline),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    const BorderSide(color: AppColors.primary, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Message body field
          const Text(
            'Message',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _body,
            onChanged: (_) => setState(() {}),
            enabled: !_saving && !_reloadRequired,
            maxLength: 4000,
            maxLines: 4,
            style: const TextStyle(fontSize: 14, color: AppColors.ink),
            decoration: InputDecoration(
              hintText: 'What do members need to know?',
              hintStyle:
                  const TextStyle(color: AppColors.inkSoft, fontSize: 14),
              filled: true,
              fillColor: AppColors.surface,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.hairline),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.hairline),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    const BorderSide(color: AppColors.primary, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Category & Priority row
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Category',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.hairline),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<AnnouncementCategory>(
                          isExpanded: true,
                          value: _category,
                          onChanged: _saving
                              ? null
                              : (value) => setState(() => _category = value!),
                          items: [
                            for (final category in AnnouncementCategory.values)
                              DropdownMenuItem(
                                value: category,
                                child: Text('Category · ${category.name}'),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Priority',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.hairline),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<AnnouncementPriority>(
                          isExpanded: true,
                          value: _priority,
                          onChanged: _saving
                              ? null
                              : (value) => setState(() => _priority = value!),
                          items: [
                            for (final priority in AnnouncementPriority.values)
                              DropdownMenuItem(
                                value: priority,
                                child: Text('Priority · ${priority.name}'),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Composer Left Card 2: Target Audience
  Widget _buildTargetAudienceCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primaryTint,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.hub_outlined,
                    size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Target audience',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    Text(
                      'Choose whether to broadcast to all gym locations or specific branches.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.inkSoft,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 28, color: AppColors.hairline),

          // Audience selection cards
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _saving
                      ? null
                      : () =>
                          setState(() => _audience = AnnouncementAudience.all),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _audience == AnnouncementAudience.all
                          ? AppColors.primaryTint
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _audience == AnnouncementAudience.all
                            ? AppColors.primary
                            : AppColors.hairline,
                        width:
                            _audience == AnnouncementAudience.all ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Radio<AnnouncementAudience>(
                          value: AnnouncementAudience.all,
                          groupValue: _audience,
                          activeColor: AppColors.primary,
                          onChanged: _saving
                              ? null
                              : (v) => setState(() => _audience = v!),
                        ),
                        const SizedBox(width: 4),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'All branches',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.ink,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Visible to members across all active and future gym locations.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.inkSoft,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: InkWell(
                  onTap: _saving
                      ? null
                      : () => setState(
                          () => _audience = AnnouncementAudience.branches),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _audience == AnnouncementAudience.branches
                          ? AppColors.primaryTint
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _audience == AnnouncementAudience.branches
                            ? AppColors.primary
                            : AppColors.hairline,
                        width: _audience == AnnouncementAudience.branches
                            ? 1.5
                            : 1.0,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Radio<AnnouncementAudience>(
                          value: AnnouncementAudience.branches,
                          groupValue: _audience,
                          activeColor: AppColors.primary,
                          onChanged: _saving
                              ? null
                              : (v) => setState(() => _audience = v!),
                        ),
                        const SizedBox(width: 4),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Specific branches',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.ink,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Target selected gym branches only (maximum 8 branches).',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.inkSoft,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Specific branches list
          if (_audience == AnnouncementAudience.branches) ...[
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.hairline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Select branches to broadcast:',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                      Text(
                        '${_targets.length} selected (max 8)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _targets.length > 8
                              ? AppColors.danger
                              : AppColors.inkSoft,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final id in {..._branches.keys, ..._targets})
                        if (_branches[id]?.active == true ||
                            _targets.contains(id))
                          FilterChip(
                            selectedColor: AppColors.primaryTint,
                            checkmarkColor: AppColors.primary,
                            selected: _targets.contains(id),
                            label: Text(_branches[id]?.active == true
                                ? _branches[id]!.name
                                : '${_branches[id]?.name ?? 'Unavailable branch'} (inactive)'),
                            labelStyle: TextStyle(
                              fontSize: 13,
                              fontWeight: _targets.contains(id)
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: _targets.contains(id)
                                  ? AppColors.primary
                                  : AppColors.ink,
                            ),
                            side: BorderSide(
                              color: _targets.contains(id)
                                  ? AppColors.primary
                                  : AppColors.hairline,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            onSelected: _saving
                                ? null
                                : (selected) => setState(() {
                                      if (selected) {
                                        _targets.add(id);
                                      } else {
                                        _targets.remove(id);
                                      }
                                    }),
                          ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Composer Left Card 3: Publishing Schedule
  Widget _buildPublishingScheduleCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primaryTint,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.schedule_rounded,
                    size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Publishing schedule',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    Text(
                      'Set publication timing and active visibility period.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.inkSoft,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 28, color: AppColors.hairline),

          // Schedule choice chips
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap:
                      _saving ? null : () => setState(() => _schedule = false),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: !_schedule
                          ? AppColors.primaryTint
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color:
                            !_schedule ? AppColors.primary : AppColors.hairline,
                        width: !_schedule ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        Radio<bool>(
                          value: false,
                          groupValue: _schedule,
                          activeColor: AppColors.primary,
                          onChanged: _saving
                              ? null
                              : (v) => setState(() => _schedule = v!),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _editing?.status == AnnouncementStatus.published &&
                                    _editing!.isActive
                                ? 'Keep start date'
                                : 'Publish now',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: InkWell(
                  onTap:
                      _saving ? null : () => setState(() => _schedule = true),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color:
                          _schedule ? AppColors.primaryTint : AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color:
                            _schedule ? AppColors.primary : AppColors.hairline,
                        width: _schedule ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        Radio<bool>(
                          value: true,
                          groupValue: _schedule,
                          activeColor: AppColors.primary,
                          onChanged: _saving
                              ? null
                              : (v) => setState(() => _schedule = v!),
                        ),
                        const SizedBox(width: 6),
                        const Expanded(
                          child: Text(
                            'Schedule publication',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Date buttons
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Start date (valid from)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.inkSoft,
                      ),
                    ),
                    const SizedBox(height: 6),
                    OutlinedButton.icon(
                      onPressed: _saving || _reloadRequired || !_schedule
                          ? null
                          : () => _pickDate(true),
                      icon: const Icon(Icons.calendar_today_outlined, size: 16),
                      label: Text('From ${_fmt(_from)}'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.ink,
                        disabledForegroundColor: AppColors.inkSoft,
                        side: const BorderSide(color: AppColors.hairline),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        alignment: Alignment.centerLeft,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'End date (valid to - exclusive)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.inkSoft,
                      ),
                    ),
                    const SizedBox(height: 6),
                    OutlinedButton.icon(
                      onPressed: _saving || _reloadRequired
                          ? null
                          : () => _pickDate(false),
                      icon: const Icon(Icons.event_outlined, size: 16),
                      label: Text('Until ${_fmt(_to)}'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.ink,
                        side: const BorderSide(color: AppColors.hairline),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        alignment: Alignment.centerLeft,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Malaysia Time helper note
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.hairline),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded,
                    size: 18, color: AppColors.inkSoft),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Announcements appear in the app during the display period. The end date is exclusive. Dates use Malaysia Time (GMT+8).',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.ink.withValues(alpha: 0.85),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Composer Right Card 1: Member App Mobile Preview
  Widget _buildMemberAppPreviewCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primaryTint,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.smartphone_rounded,
                    size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Member app preview',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    Text(
                      'Live simulation of member mobile card',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.inkSoft,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24, color: AppColors.hairline),

          // Phone Device Frame
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.hairline, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Simulated Phone Status Notch
                      Container(
                        color: AppColors.bg,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '9:41',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink,
                              ),
                            ),
                            Row(
                              children: [
                                Icon(Icons.wifi_rounded,
                                    size: 12, color: AppColors.ink),
                                SizedBox(width: 4),
                                Icon(Icons.battery_full_rounded,
                                    size: 14, color: AppColors.ink),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Screen Canvas wrapped in RepaintBoundary for test capture
                      RepaintBoundary(
                        key: const Key('announcement-mobile-preview'),
                        child: Container(
                          color: AppColors.bg,
                          padding: const EdgeInsets.fromLTRB(14, 6, 14, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Announcements',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                              ),
                              const SizedBox(height: 8),

                              // Real Member AnnouncementCard
                              AnnouncementCard(
                                title: _title.text.trim().isEmpty
                                    ? 'Announcement title'
                                    : _title.text,
                                message: _body.text.trim().isEmpty
                                    ? 'Announcement message'
                                    : _body.text,
                                caption:
                                    '${_audienceLabel(_audience, _targets)} · ${_fmt(_from)}',
                                icon: _categoryIcon(_category),
                                important:
                                    _priority == AnnouncementPriority.important,
                                warmAccent: _category ==
                                        AnnouncementCategory.maintenance ||
                                    _category == AnnouncementCategory.closure,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Composer Right Card 2: Publication Summary
  Widget _buildPublicationSummaryCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Publication summary',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Authoritative publishing configuration.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.inkSoft,
            ),
          ),
          const Divider(height: 24, color: AppColors.hairline),
          _SummaryRow(
            label: 'Audience',
            value: _audience == AnnouncementAudience.all
                ? 'All branches'
                : '${_targets.length} selected branch${_targets.length == 1 ? '' : 'es'}',
            icon: Icons.hub_outlined,
          ),
          const SizedBox(height: 10),
          _SummaryRow(
            label: 'Channel',
            value: 'Delivery in the Member App',
            icon: Icons.smartphone_rounded,
          ),
          const SizedBox(height: 10),
          _SummaryRow(
            label: 'Display period',
            value: '${_fmt(_from)} – ${_fmt(_to)} MYT',
            icon: Icons.date_range_rounded,
          ),
          const SizedBox(height: 10),
          _SummaryRow(
            label: 'Expected state',
            value: _editing?.isActive == true
                ? 'Active'
                : _schedule
                    ? 'Scheduled on publish'
                    : 'Active on publish',
            icon: Icons.check_circle_outline_rounded,
            valueColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  // Composer Sticky Footer Action Bar
  Widget _buildStickyFooter(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.hairline),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton(
            onPressed: _saving ? null : canLeave,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.inkSoft,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            ),
            child: const Text('Cancel'),
          ),
          Row(
            children: [
              OutlinedButton(
                onPressed: _saving || _reloadRequired
                    ? null
                    : () => _save(AnnouncementStatus.draft),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.ink,
                  side: const BorderSide(color: AppColors.hairline),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
                child: const Text('Save draft'),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: _saving || _reloadRequired
                    ? null
                    : () => _save(AnnouncementStatus.published),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                child: Text(_saving
                    ? 'Saving…'
                    : _editing?.isActive == true
                        ? 'Save changes'
                        : _schedule
                            ? 'Schedule announcement'
                            : 'Publish announcement'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COMPONENT WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _KpiMetricCard extends StatelessWidget {
  const _KpiMetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 84,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.inkSoft,
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

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    required this.icon,
    this.valueColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.inkSoft),
        const SizedBox(width: 8),
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.inkSoft,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: valueColor ?? AppColors.ink,
            ),
          ),
        ),
      ],
    );
  }
}
