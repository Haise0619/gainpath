import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';

const _categories = ['Yoga', 'HIIT', 'Strength', 'Dance', 'Pilates', 'Other'];
const _levels = ['All levels', 'Beginner', 'Intermediate', 'Advanced'];
const _eligibility = ['Paid Members', 'Premium Only'];
const _coverLimit = 5 * 1024 * 1024;

String _adminClassError(Object error) {
  if (error is FirebaseFunctionsException) {
    return classError(
        (error.message ?? 'Could not complete this request. Try again.')
            .replaceFirst(RegExp(r'\s+\[[45]\d\d\]$'), ''));
  }
  return classError(error);
}

class GroupClassesAdminPage extends StatefulWidget {
  const GroupClassesAdminPage({super.key, required this.call, this.pickCover});
  final ClassCall call;
  final Future<XFile?> Function()? pickCover;

  @override
  State<GroupClassesAdminPage> createState() => _GroupClassesAdminPageState();
}

class _GroupClassesAdminPageState extends State<GroupClassesAdminPage> {
  List<Map<String, dynamic>> _rows = [];
  String? _branch, _category, _status, _error;
  String _search = '';
  String _activeTab = 'All'; // All | Upcoming | Past | Drafts
  bool _loading = false;
  bool _showBuilder = false;
  Map<String, dynamic>? _builderRow;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.call('list', {});
      final rows = classRows(result['classes'])
        ..sort((a, b) =>
            (b['startAtMillis'] as int).compareTo(a['startAtMillis'] as int));
      if (mounted) setState(() => _rows = rows);
    } catch (error) {
      if (mounted) setState(() => _error = _adminClassError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _details(String id) async {
    await openGroupClassAdminDetails(
      context,
      widget.call,
      id,
      onEdit: (row) {
        setState(() {
          _showBuilder = true;
          _builderRow = row;
        });
      },
    );
    if (mounted) await _load();
  }

  void _create() {
    setState(() {
      _showBuilder = true;
      _builderRow = null;
    });
  }

  Future<void> _closeBuilder([bool reload = false]) async {
    setState(() {
      _showBuilder = false;
      _builderRow = null;
    });
    if (reload && mounted) {
      await _load();
    }
  }

  bool _matchesTab(Map<String, dynamic> row, int now) {
    final state = row['state'] as String? ?? 'Published';
    final status = row['status'] as String? ?? 'Open';
    final startAt = (row['startAtMillis'] as num?)?.toInt() ?? 0;

    switch (_activeTab) {
      case 'Upcoming':
        return state != 'Draft' &&
            status != 'Cancelled' &&
            status != 'Completed' &&
            startAt > now;
      case 'Past':
        return status == 'Completed' ||
            (startAt <= now && status != 'Cancelled' && state != 'Draft');
      case 'Drafts':
        return state == 'Draft';
      case 'All':
      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showBuilder) {
      return _ClassEditor(
        call: widget.call,
        pickCover: widget.pickCover,
        row: _builderRow,
        onDone: (saved) => _closeBuilder(saved),
      );
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final query = _search.trim().toLowerCase();

    final filtered = _rows.where((row) {
      if (!_matchesTab(row, now)) return false;
      if (_branch != null && row['branchName'] != _branch) return false;
      if (_category != null && row['category'] != _category) return false;
      if (_status != null && row['status'] != _status) return false;
      if (query.isNotEmpty) {
        final text =
            '${row['title']} ${row['instructor']} ${row['venue']} ${row['branchName']}'
                .toLowerCase();
        if (!text.contains(query)) return false;
      }
      return true;
    }).toList();

    int count(String status) =>
        _rows.where((row) => row['status'] == status).length;
    int draftCount() => _rows.where((row) => row['state'] == 'Draft').length;

    final hasActiveFilters = _branch != null ||
        _category != null ||
        _status != null ||
        query.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FC),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 960;

          return RefreshIndicator(
            onRefresh: _load,
            color: AppColors.primary,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 32 : 16,
                vertical: 24,
              ),
              children: [
                // Top Header Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Group Classes',
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.ink,
                                  letterSpacing: -0.5,
                                ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Schedule classes and manage participants across branches.',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.inkSoft,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Refresh classes',
                          onPressed: _loading ? null : _load,
                          icon: const Icon(Icons.refresh_rounded),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 1,
                          ),
                          onPressed: _create,
                          icon: const Icon(Icons.add_rounded, size: 20),
                          label: const Text(
                            'Create class',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Operational Statistics (KPI Cards)
                _buildMetricsGrid([
                  (
                    'Total classes',
                    '${_rows.length}',
                    Icons.groups_rounded,
                    AppColors.primary,
                    AppColors.primaryTint
                  ),
                  (
                    'Open registration',
                    '${count('Open')}',
                    Icons.check_circle_outline_rounded,
                    const Color(0xFF16A34A),
                    const Color(0xFFF0FDF4)
                  ),
                  (
                    'Fully booked',
                    '${count('Full')}',
                    Icons.people_alt_rounded,
                    const Color(0xFFD97706),
                    const Color(0xFFFFFBEB)
                  ),
                  (
                    'Completed',
                    '${count('Completed')}',
                    Icons.task_alt_rounded,
                    const Color(0xFF475569),
                    const Color(0xFFF1F5F9)
                  ),
                  (
                    'Drafts',
                    '${draftCount()}',
                    Icons.edit_note_rounded,
                    const Color(0xFF7C3AED),
                    const Color(0xFFF5F3FF)
                  ),
                ]),
                const SizedBox(height: 20),

                // Navigation Tabs & Search/Filter Bar
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.hairline),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x06000000),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Sub-navigation tabs: All | Upcoming | Past | Drafts
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final tab in [
                              'All',
                              'Upcoming',
                              'Past',
                              'Drafts'
                            ])
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label:
                                      Text(tab == 'All' ? 'All Classes' : tab),
                                  selected: _activeTab == tab,
                                  selectedColor: AppColors.primaryTint,
                                  labelStyle: TextStyle(
                                    fontSize: 13,
                                    fontWeight: _activeTab == tab
                                        ? FontWeight.w700
                                        : FontWeight.w600,
                                    color: _activeTab == tab
                                        ? AppColors.primary
                                        : AppColors.ink,
                                  ),
                                  onSelected: (_) =>
                                      setState(() => _activeTab = tab),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const Divider(height: 24),

                      // Filters row
                      Wrap(
                        spacing: 12,
                        runSpacing: 10,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          // Search field
                          SizedBox(
                            width: isDesktop ? 260 : double.infinity,
                            height: 40,
                            child: TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText:
                                    'Search by title, instructor, venue...',
                                hintStyle: const TextStyle(
                                    fontSize: 13, color: AppColors.inkSoft),
                                prefixIcon: const Icon(Icons.search_rounded,
                                    size: 18, color: AppColors.inkSoft),
                                suffixIcon: _search.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear_rounded,
                                            size: 16),
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() => _search = '');
                                        },
                                      )
                                    : null,
                                contentPadding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                      color: AppColors.hairline),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                      color: AppColors.hairline),
                                ),
                              ),
                              style: const TextStyle(fontSize: 13),
                              onChanged: (v) => setState(() => _search = v),
                            ),
                          ),

                          classFilter(
                            'Branch',
                            _branch,
                            _rows
                                .map(
                                    (row) => row['branchName'] as String? ?? '')
                                .where((s) => s.isNotEmpty),
                            (x) => setState(() => _branch = x),
                          ),
                          classFilter(
                            'Category',
                            _category,
                            _categories,
                            (x) => setState(() => _category = x),
                          ),
                          classFilter(
                            'Status',
                            _status,
                            const [
                              'Draft',
                              'Scheduled',
                              'Open',
                              'Full',
                              'Closed',
                              'In progress',
                              'Completed',
                              'Cancelled',
                            ],
                            (x) => setState(() => _status = x),
                          ),

                          if (hasActiveFilters)
                            TextButton.icon(
                              onPressed: () => setState(() {
                                _branch = null;
                                _category = null;
                                _status = null;
                                _search = '';
                                _searchController.clear();
                              }),
                              icon: const Icon(Icons.refresh_rounded, size: 16),
                              label: const Text('Reset filters'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                if (_loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child:
                          CircularProgressIndicator(color: AppColors.primary),
                    ),
                  ),

                if (_error != null) _ClassError(_error!),

                // Empty States
                if (!_loading && _error == null && filtered.isEmpty) ...[
                  if (_rows.isEmpty)
                    // State 1: No classes created at all
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 48),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.hairline),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppColors.primaryTint,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.groups_rounded,
                              size: 48,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'No group classes yet',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Create your first group class to start scheduling studio sessions and taking member bookings.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.inkSoft,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 20),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: _create,
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('Create class'),
                          ),
                        ],
                      ),
                    )
                  else
                    // State 2: No classes match current filters
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 40),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.hairline),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: const BoxDecoration(
                              color: Color(0xFFF1F5F9),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.filter_alt_off_rounded,
                              size: 40,
                              color: AppColors.inkSoft,
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'No classes match the current filters.',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Try adjusting your search keywords, branch selection, or status filters.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13.5,
                              color: AppColors.inkSoft,
                            ),
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: () => setState(() {
                              _branch = null;
                              _category = null;
                              _status = null;
                              _search = '';
                              _searchController.clear();
                              _activeTab = 'All';
                            }),
                            icon: const Icon(Icons.refresh_rounded, size: 16),
                            label: const Text('Clear all filters'),
                          ),
                        ],
                      ),
                    ),
                ],

                // Class Grid List
                if (!_loading && filtered.isNotEmpty)
                  LayoutBuilder(
                    builder: (_, constraints) {
                      final columns = constraints.maxWidth >= 1300
                          ? 3
                          : (constraints.maxWidth >= 760 ? 2 : 1);
                      final cardWidth =
                          (constraints.maxWidth - (columns - 1) * 16) / columns;

                      return Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          for (final row in filtered)
                            SizedBox(
                              width: cardWidth,
                              child: GroupClassCard(
                                row: row,
                                showAdminActions: true,
                                onOpen: () => _details(row['id'] as String),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMetricsGrid(
      List<(String, String, IconData, Color, Color)> metrics) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth >= 1100
            ? (constraints.maxWidth - 4 * 12) / 5
            : (constraints.maxWidth >= 600
                ? (constraints.maxWidth - 2 * 12) / 3
                : (constraints.maxWidth - 12) / 2);

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final metric in metrics)
              Container(
                width: cardWidth,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.hairline),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x06000000),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: metric.$5,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(metric.$3, size: 22, color: metric.$4),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            metric.$2,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: metric.$4,
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            metric.$1,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.inkSoft,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

Future<void> openGroupClassAdminDetails(
        BuildContext context, ClassCall call, String id,
        {ValueChanged<Map<String, dynamic>>? onEdit}) =>
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close class details',
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, __, ___) => Align(
        alignment: Alignment.centerRight,
        child: SizedBox(
          width: 720,
          height: double.infinity,
          child: _AdminClassDetail(call: call, id: id, onEdit: onEdit),
        ),
      ),
      transitionBuilder: (_, animation, __, child) => SlideTransition(
        position: Tween(begin: const Offset(1, 0), end: Offset.zero)
            .animate(animation),
        child: child,
      ),
    );

class _AdminClassDetail extends StatefulWidget {
  const _AdminClassDetail({
    required this.call,
    required this.id,
    this.onEdit,
  });
  final ClassCall call;
  final String id;
  final ValueChanged<Map<String, dynamic>>? onEdit;

  @override
  State<_AdminClassDetail> createState() => _AdminClassDetailState();
}

class _AdminClassDetailState extends State<_AdminClassDetail> {
  Map<String, dynamic>? _row;
  List<Map<String, dynamic>> _participants = [];
  bool _busy = false;
  String? _error;
  String _activeSection =
      'All'; // 'All' | 'Overview' | 'Participants' | 'Attendance'

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load(
      [String? action, Map<String, dynamic> input = const {}]) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (action != null) {
        await widget.call(
            action, {'id': widget.id, 'requestId': classRequestId(), ...input});
      }
      final data = await widget.call('detail', {'id': widget.id});
      if (mounted) {
        setState(() {
          _row = Map<String, dynamic>.from(data['item'] as Map);
          _participants = classRows(data['participants']);
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = _adminClassError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm(String title, String text) async =>
      await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: Text(title),
          content: Text(text),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Go back'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(dialog, true),
              child: const Text('Confirm'),
            ),
          ],
        ),
      ) ==
      true;

  Future<void> _edit() async {
    if (widget.onEdit != null && _row != null) {
      final row = _row!;
      Navigator.pop(context);
      widget.onEdit!(row);
      return;
    }
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog.fullscreen(
        child: _ClassEditor(call: widget.call, row: _row),
      ),
    );
    if (result == true && mounted) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final row = _row;
    final isCompleted = row?['status'] == 'Completed';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FC),
      appBar: AppBar(
        title: const Text('Class details'),
        centerTitle: false,
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 1,
        leading: IconButton(
          tooltip: 'Close',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close_rounded),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _busy ? null : () => _load(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(bottom: BorderSide(color: AppColors.hairline)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _buildSectionTab(
                      'All', 'All Sections', Icons.view_agenda_outlined),
                  _buildSectionTab(
                      'Overview', 'Overview', Icons.info_outline_rounded),
                  _buildSectionTab(
                    'Participants',
                    'Participants (${_participants.where((p) => p['status'] == 'Registered').length})',
                    Icons.people_outline_rounded,
                  ),
                  _buildSectionTab(
                      'Attendance', 'Attendance', Icons.fact_check_outlined),
                ],
              ),
            ),
          ),
        ),
      ),
      body: _busy && row == null
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_busy) const LinearProgressIndicator(),
                  if (_error != null) _ClassError(_error!),
                  if (row != null) ...[
                    if (_activeSection == 'All' ||
                        _activeSection == 'Overview') ...[
                      _buildOverviewSection(row),
                      if (_activeSection == 'All') const SizedBox(height: 24),
                    ],
                    if (_activeSection == 'All' ||
                        _activeSection == 'Participants') ...[
                      _buildParticipantsSection(row),
                      if (_activeSection == 'All') const SizedBox(height: 24),
                    ],
                    if (_activeSection == 'All' ||
                        _activeSection == 'Attendance') ...[
                      _buildAttendanceSection(row, isCompleted),
                    ],
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTab(String key, String label, IconData icon) {
    final selected = _activeSection == key;
    return InkWell(
      onTap: () => setState(() => _activeSection = key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? AppColors.primary : Colors.transparent,
              width: 2.5,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: selected ? AppColors.primary : AppColors.inkSoft,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color: selected ? AppColors.primary : AppColors.inkSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewSection(Map<String, dynamic> row) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.info_outline_rounded,
                size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              'Overview',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GroupClassCard(row: row),
        const SizedBox(height: 16),

        // Admin Lifecycle Actions
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.hairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Class Lifecycle Actions',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _busy ? null : _edit,
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Edit class'),
                  ),
                  if (row['state'] == 'Draft')
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _busy ? null : () => _load('publish'),
                      icon: const Icon(Icons.publish_rounded, size: 16),
                      label: const Text('Publish Class'),
                    ),
                  if (row['state'] == 'Published' && row['status'] == 'Open')
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFD97706),
                        side: const BorderSide(color: Color(0xFFFDE68A)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _busy ? null : () => _load('close'),
                      icon: const Icon(Icons.lock_clock_outlined, size: 16),
                      label: const Text('Close Registration'),
                    ),
                  if (!['Cancelled', 'Completed', 'In progress']
                      .contains(row['status']))
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFE11D48),
                        side: const BorderSide(color: Color(0xFFFECDD3)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _busy
                          ? null
                          : () async {
                              if (await _confirm('Cancel class?',
                                      'Registered members will be notified and their spots released.') &&
                                  mounted) {
                                await _load('cancel', {'confirmChanges': true});
                              }
                            },
                      icon: const Icon(Icons.cancel_outlined, size: 16),
                      label: const Text('Cancel class'),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Description & Venue
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.hairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Class Details & Venue',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${row['description']}',
                style: const TextStyle(
                  fontSize: 13.5,
                  color: AppColors.inkSoft,
                  height: 1.45,
                ),
              ),
              const Divider(height: 24),
              Row(
                children: [
                  const Icon(Icons.place_rounded,
                      size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    '${row['venue']} · ${row['branchName']}',
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Instructor Details
        GroupClassInstructor(
          key: ValueKey(row['coachId']),
          row: row,
          call: widget.call,
        ),
      ],
    );
  }

  Widget _buildParticipantsSection(Map<String, dynamic> row) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.people_outline_rounded,
                        size: 18, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Participants',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${row['activeCount']} / ${row['capacity']} registered · ${row['cancellationCount']} cancellations',
                  style:
                      const TextStyle(fontSize: 12.5, color: AppColors.inkSoft),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (_participants.isEmpty)
          Container(
            padding: const EdgeInsets.all(28),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.hairline),
            ),
            child: const Column(
              children: [
                Icon(Icons.people_outline_rounded,
                    size: 36, color: AppColors.inkSoft),
                SizedBox(height: 8),
                Text(
                  'No registrations yet.',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.inkSoft,
                  ),
                ),
              ],
            ),
          ),
        for (final p in _participants)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.hairline),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primaryTint,
                  foregroundColor: AppColors.primary,
                  radius: 18,
                  child: Text(
                    (p['name'] as String? ?? '?')
                        .trim()
                        .characters
                        .first
                        .toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${p['name']}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        p['status'] == 'Cancelled' &&
                                p['cancelledAtMillis'] != null
                            ? 'Cancelled · ${classDate(p['cancelledAtMillis'])}'
                            : '${p['status']}',
                        style: TextStyle(
                          fontSize: 12,
                          color: p['status'] == 'Cancelled'
                              ? const Color(0xFFE11D48)
                              : (p['status'] == 'Registered'
                                  ? const Color(0xFF16A34A)
                                  : AppColors.inkSoft),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if ((p['cancellations'] as List?)?.isNotEmpty == true)
                        ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          title: const Text('Cancellation history',
                              style: TextStyle(fontSize: 12)),
                          children: [
                            for (final entry in p['cancellations'] as List)
                              ListTile(
                                dense: true,
                                title: Text(classDate(entry['atMillis'])),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
                if (p['status'] == 'Registered' && row['status'] != 'Cancelled')
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFE11D48),
                    ),
                    onPressed: _busy
                        ? null
                        : () async {
                            if (await _confirm('Cancel this registration?',
                                    'The member will be notified.') &&
                                mounted) {
                              await _load('removeParticipant',
                                  {'memberId': p['memberId']});
                            }
                          },
                    icon: const Icon(Icons.person_remove_rounded, size: 16),
                    label: const Text('Cancel registration'),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildAttendanceSection(Map<String, dynamic> row, bool isCompleted) {
    final registeredParticipants =
        _participants.where((p) => p['status'] != 'Cancelled').toList();
    final attendedCount = row['attendedCount'] as int? ?? 0;
    final absentCount = row['absentCount'] as int? ?? 0;
    final markedTotal = attendedCount + absentCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.fact_check_outlined,
                size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              'Attendance',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (!isCompleted)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    color: Color(0xFFD97706), size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Attendance marking opens after the class ends. You can review registered participants under the Participants section.',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF92400E),
                    ),
                  ),
                ),
              ],
            ),
          )
        else ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.hairline),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Attendance Summary',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$attendedCount attended · $absentCount absent · $markedTotal marked',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primaryTint,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    markedTotal == 0
                        ? 'Not marked'
                        : '${(100 * attendedCount / markedTotal).toStringAsFixed(1)}%',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Mark Attendance',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 10),
          if (registeredParticipants.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.hairline),
              ),
              child: const Text('No participants enrolled to mark attendance.'),
            ),
          for (final p in registeredParticipants)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.hairline),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${p['name']}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Current: ${p['status']}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: p['status'] == 'Attended'
                                ? const Color(0xFF16A34A)
                                : (p['status'] == 'Absent'
                                    ? const Color(0xFFE11D48)
                                    : AppColors.inkSoft),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final status in ['Attended', 'Absent'])
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: p['status'] == status
                                ? (status == 'Attended'
                                    ? const Color(0xFF16A34A)
                                    : const Color(0xFFE11D48))
                                : Colors.white,
                            foregroundColor: p['status'] == status
                                ? Colors.white
                                : (status == 'Attended'
                                    ? const Color(0xFF16A34A)
                                    : const Color(0xFFE11D48)),
                            elevation: p['status'] == status ? 1 : 0,
                            side: BorderSide(
                              color: status == 'Attended'
                                  ? const Color(0xFF16A34A)
                                  : const Color(0xFFE11D48),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: _busy || p['status'] == status
                              ? null
                              : () => _load('attendance', {
                                    'memberId': p['memberId'],
                                    'status': status,
                                  }),
                          child: Text(
                            status,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

/// 3-Step Dedicated In-Page Class Builder
class _ClassEditor extends StatefulWidget {
  const _ClassEditor({
    required this.call,
    this.pickCover,
    this.row,
    this.onDone,
  });
  final ClassCall call;
  final Future<XFile?> Function()? pickCover;
  final Map<String, dynamic>? row;
  final ValueChanged<bool>? onDone;

  @override
  State<_ClassEditor> createState() => _ClassEditorState();
}

class _ClassEditorState extends State<_ClassEditor> {
  final _form = GlobalKey<FormState>();
  final _scroll = ScrollController();
  int _currentStep =
      0; // 0: Details, 1: Schedule & Instructor, 2: Registration & Publish
  late final _id = widget.row?['id'] as String? ?? 'class-${classRequestId()}';

  bool get _isDraft => widget.row == null || widget.row?['state'] == 'Draft';

  void _exit([bool saved = false]) {
    if (widget.onDone != null) {
      widget.onDone!(saved);
    } else {
      Navigator.of(context).maybePop(saved);
    }
  }

  late final _fields = {
    for (final key in [
      'title',
      'description',
      'venue',
      'instructor',
      'capacity'
    ])
      key: TextEditingController(
          text:
              '${widget.row?[key] ?? (key == 'capacity' ? 16 : (key == 'venue' ? 'Studio A' : ''))}'),
  };

  static int _defaultStart() {
    final now = DateTime.now().toUtc().add(const Duration(days: 1));
    final snappedMinute = (now.minute / 30).ceil() * 30;
    return DateTime.utc(now.year, now.month, now.day, now.hour)
        .add(Duration(minutes: snappedMinute))
        .millisecondsSinceEpoch;
  }

  late final _times = {
    'startAtMillis': widget.row?['startAtMillis'] as int? ?? _defaultStart(),
    'endAtMillis':
        widget.row?['endAtMillis'] as int? ?? (_defaultStart() + 3600000),
    'openAtMillis': widget.row?['openAtMillis'] as int?,
    'closeAtMillis': widget.row?['closeAtMillis'] as int?,
  };

  late String _category =
      widget.row?['category'] as String? ?? _categories.first;
  late String _difficulty =
      widget.row?['difficulty'] as String? ?? _levels.first;
  late String _access = classEligibility(widget.row?['eligibility']);
  late String? _branch = widget.row?['branchId'] as String?;
  late String? _coach = widget.row?['coachId'] as String?;
  late String? _cover = widget.row?['coverUrl'] as String?;
  Uint8List? _coverPreview;
  ({Uint8List bytes, String contentType, String id})? _pendingCover;
  bool _uploadingCover = false;
  String? _coverError;
  bool _isExternalInstructor = false;

  List<Map<String, dynamic>> _branches = [], _coaches = [];
  bool _busy = false, _loading = true, _confirmed = false;
  bool _publishFailedAfterSave = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _isExternalInstructor = widget.row?['coachId'] == null &&
        (widget.row?['instructor'] as String?)?.isNotEmpty == true;
    _options();
  }

  Future<void> _options() async {
    try {
      final result = await widget.call('options', {});
      if (mounted) {
        setState(() {
          _branches = classRows(result['branches']);
          _coaches = classRows(result['coaches']);
          if (_branch == null && _branches.isNotEmpty) {
            _branch = _branches.first['id'] as String?;
          }
          if (_coach == null && !_isExternalInstructor && _coaches.isNotEmpty) {
            _coach = _coaches.first['id'] as String?;
          }
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = _adminClassError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDate(String key) async {
    final existing = _times[key];
    final now = DateTime.now().toUtc().add(const Duration(hours: 8));
    final value = existing == null ? now : classLocal(existing);
    final start = _times['startAtMillis']!;
    final localStart = classLocal(start);
    final changingEnd = key == 'endAtMillis';
    final date = changingEnd
        ? localStart
        : await showDatePicker(
            context: context,
            initialDate: DateTime(value.year, value.month, value.day),
            firstDate: DateTime(now.year - 1),
            lastDate: DateTime(now.year + 2),
          );
    if (!mounted || date == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: value.hour,
        minute: existing == null ? 0 : value.minute,
      ),
    );
    if (!mounted || time == null) return;

    const slot = Duration(minutes: 30);
    final roundedMinutes = ((time.hour * 60 + time.minute + 15) ~/ 30) * 30;
    final midnight = DateTime.utc(date.year, date.month, date.day)
        .subtract(const Duration(hours: 8));
    final tomorrow =
        midnight.add(const Duration(days: 1)).millisecondsSinceEpoch;
    var selected =
        midnight.add(Duration(minutes: roundedMinutes)).millisecondsSinceEpoch;
    if (changingEnd && roundedMinutes == 0) selected = tomorrow;
    if (key == 'startAtMillis' && selected == tomorrow) {
      selected = tomorrow - slot.inMilliseconds;
    }
    setState(() {
      _error = null;
      _publishFailedAfterSave = false;
      _times[key] = selected;
      if (key == 'startAtMillis') {
        final oldDuration = (_times['endAtMillis'] ?? start) - start;
        final duration = oldDuration >= slot.inMilliseconds &&
                oldDuration <= const Duration(hours: 4).inMilliseconds
            ? oldDuration
            : const Duration(hours: 1).inMilliseconds;
        _times['endAtMillis'] = min(selected + duration, tomorrow);
        final close = _times['closeAtMillis'];
        if (close != null &&
            (close == start - const Duration(hours: 2).inMilliseconds ||
                close <= DateTime.now().millisecondsSinceEpoch ||
                close > selected)) {
          _times['closeAtMillis'] = null;
        }
      }
    });
  }

  Future<void> _upload({bool retry = false}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _uploadingCover = true;
    });
    try {
      if (!retry) {
        final pickCover = widget.pickCover;
        final pick = await (pickCover != null
            ? pickCover()
            : openFile(acceptedTypeGroups: const [
                XTypeGroup(
                  label: 'Cover images',
                  extensions: ['png', 'jpg', 'jpeg', 'webp'],
                  mimeTypes: ['image/png', 'image/jpeg', 'image/webp'],
                ),
              ]));
        if (!mounted || pick == null) return;
        final length = await pick.length();
        if (length == 0 || length > _coverLimit) {
          throw const FormatException('Choose a cover image up to 5 MB.');
        }
        final bytes = await pick.readAsBytes();
        if (bytes.length > _coverLimit) {
          throw const FormatException('Choose a cover image up to 5 MB.');
        }
        final contentType = _coverContentType(bytes);
        try {
          final codec = await ui.instantiateImageCodec(bytes,
              targetWidth: 1200, allowUpscaling: false);
          try {
            final frame = await codec.getNextFrame();
            frame.image.dispose();
          } finally {
            codec.dispose();
          }
        } catch (_) {
          throw const FormatException('This image could not be opened.');
        }
        if (!mounted) return;
        final random = Random.secure();
        final id =
            List.generate(32, (_) => random.nextInt(16).toRadixString(16))
                .join();
        setState(() {
          _pendingCover = (bytes: bytes, contentType: contentType, id: id);
          _coverError = null;
        });
      }
      final pending = _pendingCover;
      if (pending == null) return;
      if (retry) setState(() => _coverError = null);
      final result = await widget.call('uploadCover', {
        'uploadId': pending.id,
        'contentType': pending.contentType,
        'dataBase64': base64Encode(pending.bytes),
      });
      final url = result['url'];
      if (url is! String || url.isEmpty) {
        throw const FormatException('The upload did not return an image link.');
      }
      if (mounted) {
        setState(() {
          _cover = url;
          _coverPreview = pending.bytes;
          _pendingCover = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _coverError = error is FormatException
            ? error.message
            : 'Could not upload cover. ${_adminClassError(error)}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _uploadingCover = false;
        });
      }
    }
  }

  String _coverContentType(Uint8List bytes) {
    bool starts(List<int> signature, [int offset = 0]) {
      if (bytes.length < offset + signature.length) return false;
      for (var i = 0; i < signature.length; i++) {
        if (bytes[offset + i] != signature[i]) return false;
      }
      return true;
    }

    if (starts([137, 80, 78, 71, 13, 10, 26, 10])) return 'image/png';
    if (starts([255, 216, 255])) return 'image/jpeg';
    if (starts([82, 73, 70, 70]) && starts([87, 69, 66, 80], 8)) {
      return 'image/webp';
    }
    throw const FormatException('Choose a PNG, JPG or WebP cover image.');
  }

  Uint8List? get _visibleCover => _pendingCover?.bytes ?? _coverPreview;

  Future<void> _save({bool publish = false}) async {
    if (_busy || _loading || (publish && !_isDraft)) return;
    if (_pendingCover != null) {
      setState(() {
        _currentStep = 0;
        _coverError = 'Retry or discard the cover before saving.';
      });
      return;
    }

    final start = _times['startAtMillis'];
    final end = _times['endAtMillis'];
    final now = DateTime.now().millisecondsSinceEpoch;
    final duration = start == null || end == null ? 0 : end - start;
    if (start == null ||
        end == null ||
        start <= now ||
        duration < const Duration(minutes: 30).inMilliseconds ||
        duration > const Duration(hours: 4).inMilliseconds ||
        classDate(start) != classDate(end - 1)) {
      _showValidation(1,
          'Choose a future class time lasting 30 minutes to 4 hours on the same Malaysia date.');
      return;
    }
    final open = _times['openAtMillis'] ?? now;
    final standardClose = start - const Duration(hours: 2).inMilliseconds;
    final close = _times['closeAtMillis'] ??
        (standardClose > max(now, open) ? standardClose : start);
    if (open >= close || close > start || (publish && close <= now)) {
      _showValidation(2,
          'Registration must open before it closes and close by the class start. To publish, choose a closing time that is still in the future.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _publishFailedAfterSave = false;
    });

    var draftSaved = false;
    try {
      final selectedCoach = _isExternalInstructor ? null : _coach;
      final instructorName = _isExternalInstructor
          ? _fields['instructor']!.text.trim()
          : (_coaches.firstWhere((c) => c['id'] == _coach,
                  orElse: () => {'name': ''})['name'] as String? ??
              '');

      await widget.call('save', {
        'id': _id,
        'requestId': classRequestId(),
        'confirmChanges': _confirmed,
        'item': {
          for (final entry in _fields.entries)
            entry.key: entry.key == 'capacity'
                ? int.tryParse(entry.value.text) ?? 16
                : entry.value.text.trim(),
          ..._times,
          'openAtMillis': open,
          'closeAtMillis': close,
          'branchId': _branch,
          'coachId': selectedCoach,
          'instructor': instructorName,
          'coverUrl': _cover,
          'category': _category,
          'difficulty': _difficulty,
          'eligibility': _access,
        },
      });
      draftSaved = true;

      if (publish) {
        await widget.call('publish', {
          'id': _id,
          'requestId': classRequestId(),
        });
      }

      if (mounted) _exit(true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _publishFailedAfterSave = publish && draftSaved;
          final message = _adminClassError(error);
          _error = _publishFailedAfterSave ? 'Draft saved. $message' : message;
        });
        if (_scroll.hasClients) _scroll.jumpTo(0);
      }
    }
  }

  void _showValidation(int step, String message) {
    setState(() {
      _currentStep = step;
      _error = message;
      _publishFailedAfterSave = false;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  @override
  void dispose() {
    _scroll.dispose();
    for (final controller in _fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Map<String, dynamic> _buildLivePreviewData() {
    final selectedBranch = _branches.firstWhere((b) => b['id'] == _branch,
        orElse: () => {'name': 'Select Branch'});
    final selectedCoach = _isExternalInstructor
        ? null
        : _coaches.firstWhere((c) => c['id'] == _coach,
            orElse: () => {'name': 'Instructor'});
    final instructor = _isExternalInstructor
        ? (_fields['instructor']!.text.trim().isEmpty
            ? 'External Instructor'
            : _fields['instructor']!.text.trim())
        : (selectedCoach?['name'] as String? ?? 'Instructor');

    return {
      'id': _id,
      'title': _fields['title']!.text.trim().isEmpty
          ? 'Class Title'
          : _fields['title']!.text.trim(),
      'category': _category,
      'difficulty': _difficulty,
      'eligibility': _access,
      'coverUrl': _cover,
      'branchName': selectedBranch['name'] ?? 'Branch',
      'venue': _fields['venue']!.text.trim().isEmpty
          ? 'Studio Venue'
          : _fields['venue']!.text.trim(),
      'instructor': instructor,
      'status': widget.row?['status'] ?? 'Draft',
      'capacity': int.tryParse(_fields['capacity']!.text) ?? 16,
      'activeCount': widget.row?['activeCount'] ?? 0,
      'startAtMillis': _times['startAtMillis'] ??
          DateTime.now()
              .toUtc()
              .add(const Duration(days: 1))
              .millisecondsSinceEpoch,
      'endAtMillis': _times['endAtMillis'] ??
          DateTime.now()
              .toUtc()
              .add(const Duration(days: 1, hours: 1))
              .millisecondsSinceEpoch,
    };
  }

  Widget _buildTopBreadcrumbBar(BuildContext context) {
    final isEdit = widget.row != null;
    final titleText = isEdit ? 'Edit Class' : 'Class Builder';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.hairline)),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Cancel',
            onPressed: _busy ? null : () => _exit(false),
            icon: const Icon(
              Icons.arrow_back_rounded,
              size: 20,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: _busy ? null : () => _exit(false),
                    borderRadius: BorderRadius.circular(6),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      child: Text(
                        'Home',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 2),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: AppColors.inkSoft,
                    ),
                  ),
                  InkWell(
                    onTap: _busy ? null : () => _exit(false),
                    borderRadius: BorderRadius.circular(6),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      child: Text(
                        'Group Classes',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 2),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: AppColors.inkSoft,
                    ),
                  ),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Text(
                      titleText,
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
          const SizedBox(width: 12),
          TextButton(
            onPressed: _busy ? null : () => _exit(false),
            child: const Text('Cancel'),
          ),
          const SizedBox(width: 8),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: _busy || _loading ? null : () => _save(),
            child: Text(_isDraft ? 'Save Draft' : 'Save changes'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final previewData = _buildLivePreviewData();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FC),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 960;

          return Column(
            children: [
              _buildTopBreadcrumbBar(context),

              // Wizard Step Indicator Header
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(bottom: BorderSide(color: AppColors.hairline)),
                ),
                child: Row(
                  children: [
                    _buildStepIndicator(0, '1. Class Details'),
                    _buildStepDivider(),
                    _buildStepIndicator(1, '2. Schedule & Coach'),
                    _buildStepDivider(),
                    _buildStepIndicator(2,
                        _isDraft ? '3. Capacity & Publish' : '3. Registration'),
                  ],
                ),
              ),

              if (_loading || _busy) const LinearProgressIndicator(),

              Expanded(
                child: Form(
                  key: _form,
                  child: SingleChildScrollView(
                    controller: _scroll,
                    padding: EdgeInsets.symmetric(
                      horizontal: isDesktop ? 32 : 16,
                      vertical: 24,
                    ),
                    child: isDesktop
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 6,
                                child: _buildCurrentStepContent(),
                              ),
                              const SizedBox(width: 28),
                              Expanded(
                                flex: 4,
                                child: _buildPreviewStickyPanel(previewData),
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildCurrentStepContent(),
                              const SizedBox(height: 24),
                              _buildPreviewStickyPanel(previewData),
                            ],
                          ),
                  ),
                ),
              ),

              // Bottom Step Navigation Bar
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(top: BorderSide(color: AppColors.hairline)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (_currentStep > 0)
                      OutlinedButton.icon(
                        onPressed:
                            _busy ? null : () => setState(() => _currentStep--),
                        icon: const Icon(Icons.arrow_back_rounded, size: 16),
                        label: const Text('Previous Step'),
                      )
                    else
                      const SizedBox.shrink(),
                    Row(
                      children: [
                        if (_currentStep < 2)
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: _busy
                                ? null
                                : () {
                                    if (_currentStep == 0 &&
                                        !_form.currentState!.validate()) {
                                      return;
                                    }
                                    setState(() => _currentStep++);
                                  },
                            icon: const Icon(Icons.arrow_forward_rounded,
                                size: 16),
                            label: const Text('Next Step'),
                          )
                        else if (_isDraft) ...[
                          OutlinedButton(
                            onPressed: _busy || _loading ? null : () => _save(),
                            child: const Text('Save Draft'),
                          ),
                          const SizedBox(width: 10),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF16A34A),
                              foregroundColor: Colors.white,
                            ),
                            onPressed: _busy || _loading
                                ? null
                                : () => _save(publish: true),
                            icon: const Icon(Icons.publish_rounded, size: 16),
                            label: const Text('Publish Class'),
                          ),
                        ] else
                          FilledButton(
                            onPressed: _busy || _loading ? null : () => _save(),
                            child: const Text('Save changes'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStepIndicator(int stepIndex, String title) {
    final isActive = _currentStep == stepIndex;
    final isDone = _currentStep > stepIndex;

    return InkWell(
      onTap: () => setState(() => _currentStep = stepIndex),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDone
                    ? const Color(0xFF16A34A)
                    : (isActive ? AppColors.primary : const Color(0xFFE2E8F0)),
              ),
              alignment: Alignment.center,
              child: isDone
                  ? const Icon(Icons.check_rounded,
                      size: 14, color: Colors.white)
                  : Text(
                      '${stepIndex + 1}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isActive ? Colors.white : AppColors.inkSoft,
                      ),
                    ),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                color: isActive ? AppColors.primary : AppColors.inkSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepDivider() => const Expanded(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Divider(color: AppColors.hairline),
        ),
      );

  Widget _buildCurrentStepContent() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) ...[
            _ClassError(_error!),
            if (_publishFailedAfterSave && _currentStep == 2)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () {
                    setState(() => _currentStep = 1);
                    if (_scroll.hasClients) _scroll.jumpTo(0);
                  },
                  child: const Text('Edit schedule'),
                ),
              ),
            const SizedBox(height: 12),
          ],
          if (_currentStep == 0) _buildStep1Details(),
          if (_currentStep == 1) _buildStep2Schedule(),
          if (_currentStep == 2) _buildStep3Registration(),
        ],
      ),
    );
  }

  Widget _buildStep1Details() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Step 1 — Class Details',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Define the core identity, discipline, and description of this group session.',
          style: TextStyle(fontSize: 13, color: AppColors.inkSoft),
        ),
        const SizedBox(height: 20),

        // Title
        TextFormField(
          controller: _fields['title'],
          decoration: const InputDecoration(
            labelText: 'Class Name *',
            hintText: 'e.g. Strength Lab, Sunday Reset Yoga',
          ),
          onChanged: (_) => setState(() {}),
          validator: (v) =>
              v?.trim().isEmpty == true ? 'Class name is required' : null,
        ),
        const SizedBox(height: 14),

        // Category & Difficulty Row
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Category *'),
                items: _categories
                    .map(
                        (cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                    .toList(),
                onChanged: (v) => setState(() => _category = v ?? _category),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _difficulty,
                decoration: const InputDecoration(labelText: 'Difficulty *'),
                items: _levels
                    .map(
                        (lvl) => DropdownMenuItem(value: lvl, child: Text(lvl)))
                    .toList(),
                onChanged: (v) =>
                    setState(() => _difficulty = v ?? _difficulty),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Description
        TextFormField(
          controller: _fields['description'],
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Description *',
            hintText:
                'Describe workout structure, equipment needed, and benefits...',
          ),
          onChanged: (_) => setState(() {}),
          validator: (v) =>
              v?.trim().isEmpty == true ? 'Description is required' : null,
        ),
        const SizedBox(height: 20),

        // Cover Image Upload
        const Text(
          'Cover Image',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 100,
                height: 70,
                child: GroupClassCover(url: _cover, bytes: _visibleCover),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _upload(),
                    icon: const Icon(Icons.upload_file_rounded, size: 18),
                    label: Text(_cover == null && _pendingCover == null
                        ? 'Upload Cover Photo'
                        : 'Replace Cover Photo'),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'PNG, JPG, or WEBP under 5MB. Aspect ratio ~16:9 recommended.',
                    style: TextStyle(fontSize: 11.5, color: AppColors.inkSoft),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (_uploadingCover ||
            _coverError != null ||
            _coverPreview != null) ...[
          const SizedBox(height: 10),
          Semantics(
            liveRegion: true,
            child: Text(
              _uploadingCover
                  ? (_pendingCover == null
                      ? 'Preparing cover…'
                      : 'Uploading cover…')
                  : _coverError ?? 'Cover uploaded',
              style: TextStyle(
                  color: _coverError != null && !_uploadingCover
                      ? Theme.of(context).colorScheme.error
                      : AppColors.inkSoft),
            ),
          ),
        ],
        if (_pendingCover != null && !_busy)
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                  onPressed: () => _upload(retry: true),
                  child: const Text('Retry upload')),
              TextButton(
                onPressed: () => setState(() {
                  _pendingCover = null;
                  _coverError = null;
                }),
                child: const Text('Discard selected cover'),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildStep2Schedule() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Step 2 — Schedule & Instructor',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Set location, timetable, and assign an internal coach or guest instructor.',
          style: TextStyle(fontSize: 13, color: AppColors.inkSoft),
        ),
        const SizedBox(height: 20),

        // Branch & Venue
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _branch,
                decoration: const InputDecoration(labelText: 'Branch *'),
                items: _branches
                    .map((b) => DropdownMenuItem(
                          value: b['id'] as String,
                          child: Text('${b['name']}'),
                        ))
                    .toList(),
                onChanged: (id) => setState(() => _branch = id),
                validator: (id) => id == null ? 'Select branch' : null,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: TextFormField(
                controller: _fields['venue'],
                decoration: const InputDecoration(
                  labelText: 'Venue / Studio *',
                  hintText: 'e.g. Studio A, Yoga Hall',
                ),
                onChanged: (_) => setState(() {}),
                validator: (v) =>
                    v?.trim().isEmpty == true ? 'Venue required' : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Date and Time selectors
        const Text(
          'Date & Session Time (MYT)',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.hairline),
          ),
          child: Column(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today_rounded,
                    color: AppColors.primary),
                title: const Text('Class Start Time (MYT)'),
                subtitle: Text(_times['startAtMillis'] == null
                    ? 'Select start date & time'
                    : '${classDate(_times['startAtMillis'])} · ${classTime(_times['startAtMillis'])} MYT'),
                trailing: const Icon(Icons.edit_calendar_outlined),
                onTap: () => _pickDate('startAtMillis'),
              ),
              const Divider(height: 1),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.schedule_rounded,
                    color: AppColors.primary),
                title: const Text('Class End Time (MYT)'),
                subtitle: Text(_times['endAtMillis'] == null
                    ? 'Select end time'
                    : '${classDate(_times['endAtMillis'])} · ${classTime(_times['endAtMillis'])} MYT'),
                trailing: const Icon(Icons.edit_calendar_outlined),
                onTap: () => _pickDate('endAtMillis'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Instructor assignment
        const Text(
          'Instructor Assignment',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        SegmentedButton<bool>(
          style: SegmentedButton.styleFrom(
            minimumSize: const Size(0, 44),
            visualDensity: VisualDensity.standard,
          ),
          segments: const [
            ButtonSegment(
              value: false,
              label: Text('Internal Coach'),
              icon: Icon(Icons.person_rounded, size: 16),
            ),
            ButtonSegment(
              value: true,
              label: Text('Guest Instructor'),
              icon: Icon(Icons.badge_rounded, size: 16),
            ),
          ],
          selected: {_isExternalInstructor},
          onSelectionChanged: (set) =>
              setState(() => _isExternalInstructor = set.first),
        ),
        const SizedBox(height: 16),
        if (!_isExternalInstructor)
          DropdownButtonFormField<String>(
            initialValue:
                _coaches.any((c) => c['id'] == _coach) ? _coach : null,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Assign Coach *'),
            items: _coaches
                .map((c) => DropdownMenuItem(
                      value: c['id'] as String,
                      child: Text(
                        '${c['name']} · ${c['specialty']}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ))
                .toList(),
            onChanged: (id) => setState(() => _coach = id),
            validator: (id) =>
                !_isExternalInstructor && id == null ? 'Select coach' : null,
          )
        else
          TextFormField(
            controller: _fields['instructor'],
            decoration: const InputDecoration(
              labelText: 'External Instructor Full Name *',
              hintText: 'e.g. Master Jin, Chloe Davis',
            ),
            onChanged: (_) => setState(() {}),
            validator: (v) => _isExternalInstructor && v?.trim().isEmpty == true
                ? 'Instructor name required'
                : null,
          ),
      ],
    );
  }

  Widget _buildStep3Registration() {
    final hasActiveCount = (widget.row?['activeCount'] as num? ?? 0) > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Step 3 — Registration & Capacity',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Configure capacity caps, membership eligibility, and registration timing.',
          style: TextStyle(fontSize: 13, color: AppColors.inkSoft),
        ),
        const SizedBox(height: 20),

        // Capacity
        TextFormField(
          controller: _fields['capacity'],
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Maximum Capacity (Participants 1–60) *',
            hintText: '16',
          ),
          onChanged: (_) => setState(() {}),
          validator: (v) {
            final parsed = int.tryParse(v ?? '');
            if (parsed == null || parsed < 1 || parsed > 60) {
              return 'Enter a capacity between 1 and 60';
            }
            return null;
          },
        ),
        const SizedBox(height: 14),

        // Eligibility
        DropdownButtonFormField<String>(
          initialValue: _access,
          decoration: const InputDecoration(
            labelText: 'Membership Eligibility *',
            helperText: 'Group classes require an active paid membership.',
            helperMaxLines: 2,
          ),
          items: _eligibility
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: (v) => setState(() => _access = v ?? _access),
        ),
        const SizedBox(height: 18),

        // Registration Window
        const Text(
          'Registration Window (Optional Customization)',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.hairline),
          ),
          child: Column(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.lock_open_rounded,
                    color: AppColors.inkSoft),
                title: const Text('Registration Opens'),
                subtitle: Text(_times['openAtMillis'] == null
                    ? 'Immediately upon publish'
                    : '${classDate(_times['openAtMillis'])} · ${classTime(_times['openAtMillis'])} MYT'),
                trailing: const Icon(Icons.edit_calendar_outlined),
                onTap: () => _pickDate('openAtMillis'),
              ),
              const Divider(height: 1),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.lock_clock_outlined,
                    color: AppColors.inkSoft),
                title: const Text('Registration Closes'),
                subtitle: Text(_times['closeAtMillis'] == null
                    ? '2 hours before class start'
                    : '${classDate(_times['closeAtMillis'])} · ${classTime(_times['closeAtMillis'])} MYT'),
                trailing: const Icon(Icons.edit_calendar_outlined),
                onTap: () => _pickDate('closeAtMillis'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        if (hasActiveCount)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _confirmed,
              title: const Text(
                'Confirm schedule or venue changes and notify registered members',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              onChanged: (v) => setState(() => _confirmed = v == true),
            ),
          ),
      ],
    );
  }

  Widget _buildPreviewStickyPanel(Map<String, dynamic> previewData) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.remove_red_eye_rounded,
                size: 16, color: AppColors.primary),
            const SizedBox(width: 6),
            Text(
              'Live Class Preview',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        GroupClassCard(row: previewData, coverBytes: _visibleCover),
      ],
    );
  }
}

class GroupClassAnalytics extends StatefulWidget {
  const GroupClassAnalytics({super.key, required this.call});
  final ClassCall call;

  @override
  State<GroupClassAnalytics> createState() => _GroupClassAnalyticsState();
}

class _GroupClassAnalyticsState extends State<GroupClassAnalytics> {
  List<Map<String, dynamic>>? _rows;
  String? _error, _branch;
  int _days = 30;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final now = DateTime.now().toUtc().add(const Duration(hours: 8));
      final tomorrow = DateTime.utc(now.year, now.month, now.day + 1)
          .subtract(const Duration(hours: 8));
      final result = await widget.call('analytics', {
        'startAtMillis':
            tomorrow.subtract(Duration(days: _days)).millisecondsSinceEpoch,
        'endAtMillis': tomorrow.millisecondsSinceEpoch,
      });
      if (mounted) setState(() => _rows = classRows(result['classes']));
    } catch (error) {
      if (mounted) setState(() => _error = classError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = _rows ?? [];
    final rows = all
        .where((row) => _branch == null || row['branchName'] == _branch)
        .toList();
    int sum(String field) => rows.fold(
        0, (total, row) => total + ((row[field] as num?)?.toInt() ?? 0));
    final attended = sum('attendedCount');
    final absent = sum('absentCount');
    final marked = attended + absent;

    final branches = <String, int>{};
    final popular = <String, int>{};
    for (final row in rows) {
      final branch = row['branchName'] as String? ?? 'Branch';
      final title = row['title'] as String? ?? 'Class';
      branches.update(branch, (count) => count + 1, ifAbsent: () => 1);
      final reg = (row['totalRegistrations'] as num?)?.toInt() ?? 0;
      popular.update(title, (count) => count + reg, ifAbsent: () => reg);
    }
    final top = popular.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FC),
      body: ListView(
        padding: const EdgeInsets.all(28),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Group Classes Analytics',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Monitor registration rates, attendance, and popular class formats.',
                    style: TextStyle(fontSize: 14, color: AppColors.inkSoft),
                  ),
                ],
              ),
              IconButton(
                tooltip: 'Refresh',
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final days in [7, 30, 90])
                ChoiceChip(
                  label: Text('Last $days days'),
                  selected: days == _days,
                  selectedColor: AppColors.primaryTint,
                  labelStyle: TextStyle(
                    fontWeight:
                        days == _days ? FontWeight.w700 : FontWeight.w500,
                    color: days == _days ? AppColors.primary : AppColors.ink,
                  ),
                  onSelected: (_) {
                    setState(() => _days = days);
                    _load();
                  },
                ),
              classFilter(
                'Branch',
                _branch,
                all.map((row) => row['branchName'] as String? ?? ''),
                (value) => setState(() => _branch = value),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null) _ClassError(_error!),
          if (_rows != null) ...[
            _metrics([
              ('Total Classes', '${rows.length}'),
              ('Total Registrations', '${sum('totalRegistrations')}'),
              (
                'Completed Classes',
                '${rows.where((r) => r['status'] == 'Completed').length}'
              ),
              (
                'Attendance Rate',
                marked == 0
                    ? '—'
                    : '${(100 * attended / marked).toStringAsFixed(1)}%'
              ),
              ('Cancellation Count', '${sum('cancellationCount')}'),
            ]),
            const SizedBox(height: 8),
            Text(
              '$attended attended · $marked attendance records marked',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.inkSoft,
              ),
            ),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 900;
                final branchCard = Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.hairline),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Branch Breakdown',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.ink,
                                ),
                      ),
                      const SizedBox(height: 12),
                      if (branches.isEmpty)
                        const Text('No classes in this date range.'),
                      for (final entry in branches.entries)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(entry.key,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primaryTint,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${entry.value} classes',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );

                final popularCard = Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.hairline),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Most Popular Classes',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.ink,
                                ),
                      ),
                      const SizedBox(height: 12),
                      if (top.isEmpty)
                        const Text('No registrations in this date range.'),
                      for (final entry in top.take(5))
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(entry.key,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${entry.value} registrations',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF16A34A),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );

                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: branchCard),
                      const SizedBox(width: 16),
                      Expanded(child: popularCard),
                    ],
                  );
                }
                return Column(
                  children: [
                    branchCard,
                    const SizedBox(height: 16),
                    popularCard,
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

Widget _metrics(List<(String, String)> metrics) => LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth >= 900
            ? (constraints.maxWidth - (metrics.length - 1) * 12) /
                metrics.length
            : 166.0;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final metric in metrics)
              SizedBox(
                width: cardWidth,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.hairline),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        metric.$2,
                        style: const TextStyle(
                          fontSize: 22,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        metric.$1,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.inkSoft,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );

class _ClassError extends StatelessWidget {
  const _ClassError(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.dangerTint,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFFECDD3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded,
                color: AppColors.danger, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  color: AppColors.danger,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
}
