import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gainpath_domain/workout.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'exercise_video_preview.dart';

/// Presentation for catalog lifecycle; repositories own transitions and checks.
/// Modern, compact Exercise Library Dashboard inspired by Shopify Polaris & Contentful CMS.
class ExerciseCatalogList extends StatefulWidget {
  const ExerciseCatalogList({
    super.key,
    required this.tutorials,
    required this.catalogOnly,
    required this.filter,
    required this.onFilter,
    required this.onReload,
    required this.onAdd,
    required this.onEdit,
    this.onDelete,
    this.onStatusChange,
    this.busy = false,
    this.error,
  });

  final List<TutorialVideo> tutorials;
  final bool catalogOnly, busy;
  final ExerciseCatalogStatus? filter;
  final String? error;
  final void Function(ExerciseCatalogStatus?) onFilter;
  final VoidCallback onReload, onAdd;
  final void Function(TutorialVideo) onEdit;
  final void Function(TutorialVideo)? onDelete;
  final void Function(TutorialVideo, ExerciseCatalogStatus)? onStatusChange;

  bool get blocked => busy || error != null;

  @override
  State<ExerciseCatalogList> createState() => _ExerciseCatalogListState();
}

class _ExerciseCatalogListState extends State<ExerciseCatalogList> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'All';
  String _selectedTrackingMode = 'All';
  String _selectedSort = 'Name (A–Z)';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  int _count(ExerciseCatalogStatus status) =>
      widget.tutorials.where((t) => t.catalogStatus == status).length;

  int get _totalCount => widget.tutorials.length;
  int get _activeCount => _count(ExerciseCatalogStatus.active);
  int get _inactiveCount => _count(ExerciseCatalogStatus.inactive);
  int get _archivedCount => _count(ExerciseCatalogStatus.archived);

  List<String> get _categories {
    final set = widget.tutorials
        .map((t) => t.category.trim())
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return ['All', ...set];
  }

  List<TutorialVideo> _getFilteredAndSorted() {
    var list = widget.tutorials.where((t) {
      if (widget.filter != null && t.catalogStatus != widget.filter) {
        return false;
      }
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.trim().toLowerCase();
        final matchTitle = t.title.toLowerCase().contains(q);
        final matchCat = t.category.toLowerCase().contains(q);
        final matchId = t.id.toLowerCase().contains(q);
        if (!matchTitle && !matchCat && !matchId) return false;
      }
      if (_selectedCategory != 'All' && t.category != _selectedCategory) {
        return false;
      }
      if (_selectedTrackingMode == 'AI Tracked') {
        if (!t.trackingCapability.hasPoseTracking) return false;
      } else if (_selectedTrackingMode == 'Video Timed') {
        if (t.executionMode != ExerciseExecutionMode.videoGuidedTimed) {
          return false;
        }
      } else if (_selectedTrackingMode == 'Guided Only') {
        if (t.trackingCapability.hasPoseTracking ||
            t.executionMode == ExerciseExecutionMode.videoGuidedTimed) {
          return false;
        }
      }
      return true;
    }).toList();

    switch (_selectedSort) {
      case 'Name (A–Z)':
        list.sort((a, b) =>
            a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case 'Name (Z–A)':
        list.sort((a, b) =>
            b.title.toLowerCase().compareTo(a.title.toLowerCase()));
        break;
      case 'Category':
        list.sort((a, b) {
          final catComp =
              a.category.toLowerCase().compareTo(b.category.toLowerCase());
          return catComp != 0
              ? catComp
              : a.title.toLowerCase().compareTo(b.title.toLowerCase());
        });
        break;
    }
    return list;
  }

  bool get _hasActiveLocalFilters =>
      _searchQuery.isNotEmpty ||
      _selectedCategory != 'All' ||
      _selectedTrackingMode != 'All';

  void _resetLocalFilters() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _selectedCategory = 'All';
      _selectedTrackingMode = 'All';
    });
  }

  void _resetAllFilters() {
    setState(() {
      _resetLocalFilters();
      widget.onFilter(null);
    });
  }

  void _openPreview(BuildContext context, TutorialVideo item) {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(item.title),
        content: SizedBox(
          width: 640,
          child: ExerciseVideoPreview(url: item.videoUrl),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows = _getFilteredAndSorted();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Page Header
          if (widget.catalogOnly) ...[
            Text(
              'Exercise Catalog',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Build routines with AI-tracked and video-guided timed exercises. Tracking availability is checked by the system.',
              style: TextStyle(fontSize: 14, color: AppColors.inkSoft),
            ),
            const SizedBox(height: 18),
          ],

          // Stats & Action Bar (Responsive Wrap)
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              // Summary Metrics Pill
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.hairline),
                ),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _metricDot(AppColors.success),
                    Text(
                      '$_activeCount active',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                    _metricDivider(),
                    _metricDot(AppColors.warning),
                    Text(
                      '$_inactiveCount inactive',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                    _metricDivider(),
                    _metricDot(AppColors.inkSoft),
                    Text(
                      '$_archivedCount archived',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                  ],
                ),
              ),

              // Action Buttons
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  IconButton(
                    tooltip: 'Reload catalog',
                    icon: const Icon(Icons.refresh_rounded),
                    onPressed: widget.busy ? null : widget.onReload,
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: const BorderSide(color: AppColors.hairline),
                      ),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: widget.blocked ? null : widget.onAdd,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: Text(
                      widget.catalogOnly ? 'Add exercise' : 'Add tutorial',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Error Notification
          if (widget.error != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.dangerTint,
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded,
                      color: AppColors.danger, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.error!,
                      style: const TextStyle(
                        color: AppColors.danger,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: widget.onReload,
                    child: const Text('Reload',
                        style: TextStyle(
                            color: AppColors.danger,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Content Library Card
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.hairline),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x06190F2E),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Tab Bar & Filter Controls
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status ChoiceChips
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _filterTabChip(
                            label: 'All',
                            count: _totalCount,
                            selected: widget.filter == null,
                            onSelected: widget.busy
                                ? null
                                : (_) => widget.onFilter(null),
                          ),
                          _filterTabChip(
                            label: 'Active',
                            count: _activeCount,
                            selected:
                                widget.filter == ExerciseCatalogStatus.active,
                            onSelected: widget.busy
                                ? null
                                : (_) => widget
                                    .onFilter(ExerciseCatalogStatus.active),
                          ),
                          _filterTabChip(
                            label: 'Inactive',
                            count: _inactiveCount,
                            selected:
                                widget.filter == ExerciseCatalogStatus.inactive,
                            onSelected: widget.busy
                                ? null
                                : (_) => widget
                                    .onFilter(ExerciseCatalogStatus.inactive),
                          ),
                          _filterTabChip(
                            label: 'Archived',
                            count: _archivedCount,
                            selected:
                                widget.filter == ExerciseCatalogStatus.archived,
                            onSelected: widget.busy
                                ? null
                                : (_) => widget
                                    .onFilter(ExerciseCatalogStatus.archived),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Search & Dropdown Filters Bar
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          // Search Box
                          ConstrainedBox(
                            constraints: const BoxConstraints(
                                maxWidth: 280, minWidth: 160),
                            child: SizedBox(
                              height: 38,
                              child: TextField(
                              controller: _searchController,
                              onChanged: (val) =>
                                  setState(() => _searchQuery = val),
                              style: const TextStyle(fontSize: 13),
                              decoration: InputDecoration(
                                hintText:
                                    'Search by name, category, or ID…',
                                hintStyle: const TextStyle(
                                    fontSize: 12.5, color: AppColors.inkSoft),
                                prefixIcon: const Icon(Icons.search_rounded,
                                    size: 18, color: AppColors.inkSoft),
                                suffixIcon: _searchQuery.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear_rounded,
                                            size: 16),
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() => _searchQuery = '');
                                        },
                                      )
                                    : null,
                                contentPadding:
                                    const EdgeInsets.symmetric(vertical: 0),
                                filled: true,
                                fillColor:
                                    AppColors.surfaceAlt.withValues(alpha: 0.5),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide:
                                      const BorderSide(color: AppColors.hairline),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide:
                                      const BorderSide(color: AppColors.hairline),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide:
                                      const BorderSide(color: AppColors.primary),
                                ),
                              ),
                            ),
                          ),
                        ),

                          // Category Dropdown
                          _dropdownContainer(
                            icon: Icons.category_outlined,
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedCategory,
                                isDense: true,
                                style: const TextStyle(
                                    fontSize: 12.5,
                                    color: AppColors.ink,
                                    fontWeight: FontWeight.w500),
                                items: _categories
                                    .map((cat) => DropdownMenuItem(
                                          value: cat,
                                          child: Text(cat == 'All'
                                              ? 'All Categories'
                                              : cat),
                                        ))
                                    .toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _selectedCategory = val);
                                  }
                                },
                              ),
                            ),
                          ),

                          // Tracking Mode Dropdown
                          _dropdownContainer(
                            icon: Icons.tune_rounded,
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedTrackingMode,
                                isDense: true,
                                style: const TextStyle(
                                    fontSize: 12.5,
                                    color: AppColors.ink,
                                    fontWeight: FontWeight.w500),
                                items: const [
                                  DropdownMenuItem(
                                      value: 'All',
                                      child: Text('All Tracking Modes')),
                                  DropdownMenuItem(
                                      value: 'AI Tracked',
                                      child: Text('AI Tracked')),
                                  DropdownMenuItem(
                                      value: 'Video Timed',
                                      child: Text('Video Timed')),
                                  DropdownMenuItem(
                                      value: 'Guided Only',
                                      child: Text('Guided Only')),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(
                                        () => _selectedTrackingMode = val);
                                  }
                                },
                              ),
                            ),
                          ),

                          // Sort Dropdown
                          _dropdownContainer(
                            icon: Icons.sort_rounded,
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedSort,
                                isDense: true,
                                style: const TextStyle(
                                    fontSize: 12.5,
                                    color: AppColors.ink,
                                    fontWeight: FontWeight.w500),
                                items: const [
                                  DropdownMenuItem(
                                      value: 'Name (A–Z)',
                                      child: Text('Sort: A–Z')),
                                  DropdownMenuItem(
                                      value: 'Name (Z–A)',
                                      child: Text('Sort: Z–A')),
                                  DropdownMenuItem(
                                      value: 'Category',
                                      child: Text('Sort: Category')),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _selectedSort = val);
                                  }
                                },
                              ),
                            ),
                          ),

                          // Reset filters button
                          if (_hasActiveLocalFilters)
                            TextButton.icon(
                              onPressed: _resetLocalFilters,
                              icon: const Icon(Icons.clear_all_rounded,
                                  size: 16),
                              label: const Text('Reset',
                                  style: TextStyle(fontSize: 12)),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.inkSoft,
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                const Divider(
                    height: 1, thickness: 1, color: AppColors.hairline),

                // Table View
                if (rows.isEmpty)
                  _emptyState()
                else
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isDesktop = constraints.maxWidth >= 768;
                      if (!isDesktop) return _buildMobileList(context, rows);
                      final tableWidth = math.max(constraints.maxWidth, 980.0);
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: tableWidth,
                          child: _buildDesktopTable(context, rows),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopTable(BuildContext context, List<TutorialVideo> rows) {
    return Column(
      children: [
        // Table Header
        Container(
          color: AppColors.surfaceAlt.withValues(alpha: 0.6),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          child: const Row(
            children: [
              Expanded(
                flex: 4,
                child: Text(
                  'EXERCISE',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: AppColors.inkSoft,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'TRACKING MODE',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: AppColors.inkSoft,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'PRESCRIPTION',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: AppColors.inkSoft,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'MEDIA',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: AppColors.inkSoft,
                  ),
                ),
              ),
              Expanded(
                flex: 1,
                child: Text(
                  'STATUS',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: AppColors.inkSoft,
                  ),
                ),
              ),
              SizedBox(
                width: 180,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'ACTIONS',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: AppColors.inkSoft,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, thickness: 1, color: AppColors.hairline),

        // Table Rows
        Column(
          children: [
            for (int i = 0; i < rows.length; i++) ...[
              if (i > 0)
                const Divider(
                    height: 1, thickness: 1, color: AppColors.hairline),
              _buildTableRow(context, rows[i]),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildTableRow(BuildContext context, TutorialVideo item) {
    return Container(
      key: ValueKey('exercise-row-${item.id}'),
      color: Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      constraints: const BoxConstraints(minHeight: 80),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 1. Exercise Column (Thumbnail + Title + Category + ID)
          Expanded(
            flex: 4,
            child: InkWell(
              onTap: widget.blocked || item.archived
                  ? null
                  : () => widget.onEdit(item),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    // 56px Thumbnail
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceAlt,
                          border: Border.all(color: AppColors.hairline),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: item.thumbnailUrl.isEmpty
                            ? const Center(
                                child: Icon(
                                  Icons.fitness_center_rounded,
                                  color: AppColors.primary,
                                  size: 24,
                                ),
                              )
                            : Image.network(
                                item.thumbnailUrl,
                                fit: BoxFit.cover,
                                webHtmlElementStrategy:
                                    WebHtmlElementStrategy.prefer,
                                errorBuilder: (_, __, ___) => const Center(
                                  child: Icon(
                                    Icons.fitness_center_rounded,
                                    color: AppColors.primary,
                                    size: 24,
                                  ),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Title, Category & ID
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            item.title,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.ink,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                item.category,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: AppColors.inkSoft,
                                ),
                              ),
                              _copyIdPill(item.id),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 2. Tracking Mode Column
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _trackingModeBadge(item),
            ),
          ),

          // 3. Prescription Column
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _prescriptionText(item),
            ),
          ),

          // 4. Media Column
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _mediaBadge(item),
            ),
          ),

          // 5. Status Column
          Expanded(
            flex: 1,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _statusBadge(item),
            ),
          ),

          // 6. Actions Column
          SizedBox(
            width: 180,
            child: Align(
              alignment: Alignment.centerRight,
              child: _rowActions(context, item),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileList(BuildContext context, List<TutorialVideo> rows) {
    return Column(
      children: [
        for (int i = 0; i < rows.length; i++) ...[
          if (i > 0)
            const Divider(height: 1, thickness: 1, color: AppColors.hairline),
          _buildMobileRow(context, rows[i]),
        ],
      ],
    );
  }

  Widget _buildMobileRow(BuildContext context, TutorialVideo item) {
    return Padding(
      key: ValueKey('exercise-row-${item.id}'),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: widget.blocked || item.archived
                ? null
                : () => widget.onEdit(item),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      border: Border.all(color: AppColors.hairline),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: item.thumbnailUrl.isEmpty
                        ? const Center(
                            child: Icon(Icons.fitness_center_rounded,
                                color: AppColors.primary, size: 24))
                        : Image.network(
                            item.thumbnailUrl,
                            fit: BoxFit.cover,
                            webHtmlElementStrategy:
                                WebHtmlElementStrategy.prefer,
                            errorBuilder: (_, __, ___) => const Center(
                              child: Icon(Icons.fitness_center_rounded,
                                  color: AppColors.primary, size: 24),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.title,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.ink)),
                      const SizedBox(height: 3),
                      Text('${item.category} · ${item.id}',
                          style: const TextStyle(
                              fontSize: 12.5, color: AppColors.inkSoft)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _statusBadge(item),
              _trackingModeBadge(item),
              _mediaBadge(item),
              _prescriptionText(item),
            ],
          ),
          const SizedBox(height: 10),
          _rowActions(context, item, isMobile: true),
        ],
      ),
    );
  }

  Widget _copyIdPill(String id) {
    final short = id.length > 12 ? '${id.substring(0, 10)}…' : id;
    return Tooltip(
      message: 'ID: $id\nClick to copy',
      child: InkWell(
        onTap: () {
          Clipboard.setData(ClipboardData(text: id));
          showToast(context, 'Copied ID: $id');
        },
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: AppColors.hairline),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.copy_rounded,
                    size: 10, color: AppColors.inkSoft),
                const SizedBox(width: 4),
                Text(
                  short,
                  style: const TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: AppColors.inkSoft,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _trackingModeBadge(TutorialVideo item) {
    if (item.trackingCapability.hasPoseTracking) {
      // Soft purple badge
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF3E8FF),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFDDD6FE)),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.auto_awesome_rounded,
                  size: 13, color: Color(0xFF6D28D9)),
              const SizedBox(width: 5),
              Text(
                item.trackingCapability.displayLabel,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6D28D9),
                ),
              ),
            ],
          ),
        ),
      );
    } else if (item.executionMode == ExerciseExecutionMode.videoGuidedTimed) {
      // Soft blue badge
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFBFDBFE)),
        ),
        child: const FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.timer_outlined, size: 13, color: Color(0xFF1D4ED8)),
              SizedBox(width: 5),
              Text(
                'Video guided · Timer',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1D4ED8),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      // Neutral gray badge
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.play_lesson_outlined,
                  size: 13, color: Color(0xFF4B5563)),
              const SizedBox(width: 5),
              Text(
                item.trackingCapability.displayLabel,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF4B5563),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _prescriptionText(TutorialVideo item) {
    String text;
    Color color = AppColors.ink;
    if (item.defaultPrescription case final TimedPrescription target) {
      text =
          '${target.sets} sets × ${target.durationSeconds}s · ${target.restSeconds}s rest';
    } else if (item.defaultPrescription
        case final RepetitionPrescription target) {
      text =
          '${target.sets} sets × ${target.repetitions} reps · ${target.restSeconds}s rest';
    } else {
      text = widget.catalogOnly ? '—' : '${item.durationMin} min';
      color = AppColors.inkSoft;
    }
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: TextStyle(fontSize: 12.5, color: color),
      ),
    );
  }

  Widget _mediaBadge(TutorialVideo item) {
    if (item.executionMode == ExerciseExecutionMode.videoGuidedTimed) {
      final verified = item.mediaValidation != null;
      return FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              verified
                  ? Icons.check_circle_outline_rounded
                  : Icons.warning_amber_rounded,
              size: 14,
              color: verified ? AppColors.success : AppColors.warning,
            ),
            const SizedBox(width: 4),
            Text(
              verified ? 'Media verified' : 'Media needs verification',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: verified ? AppColors.success : AppColors.warning,
              ),
            ),
          ],
        ),
      );
    }
    if (item.videoUrl.trim().isNotEmpty) {
      return const FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.videocam_outlined, size: 14, color: AppColors.primary),
            SizedBox(width: 4),
            Text('Video linked',
                style: TextStyle(fontSize: 12, color: AppColors.inkSoft)),
          ],
        ),
      );
    }
    return const Text('No media',
        style: TextStyle(fontSize: 12, color: AppColors.inkSoft));
  }

  Widget _statusBadge(TutorialVideo item) {
    if (item.archived) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(6),
        ),
        child: const FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.archive_outlined, size: 12, color: AppColors.inkSoft),
              SizedBox(width: 4),
              Text(
                'Archived',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.inkSoft,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final active = widget.catalogOnly
        ? item.catalogStatus == ExerciseCatalogStatus.active
        : item.status == TutorialStatus.active;

    final color = active ? AppColors.success : AppColors.warning;
    final bg = active ? AppColors.successTint : AppColors.accentTint;
    final label = active ? 'Active' : 'Inactive';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.circle, size: 6.5, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rowActions(BuildContext context, TutorialVideo item,
      {bool isMobile = false}) {
    final actions = <Widget>[
      // Video Preview Icon Button
      if (item.videoUrl.trim().isNotEmpty)
        IconButton(
          tooltip: 'Preview tutorial video',
          icon: const Icon(Icons.play_circle_outline, size: 20),
          color: AppColors.primary,
          visualDensity: VisualDensity.compact,
          onPressed:
              widget.busy ? null : () => _openPreview(context, item),
        ),

      // Primary Action: Edit (or Restore if archived)
      if (!item.archived)
        OutlinedButton.icon(
          onPressed: widget.blocked ? null : () => widget.onEdit(item),
          icon: const Icon(Icons.edit_outlined, size: 14),
          label: const Text('Edit', style: TextStyle(fontSize: 12)),
          style: OutlinedButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            side: const BorderSide(color: AppColors.hairline),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        )
      else if (widget.onStatusChange != null)
        TextButton.icon(
          key: ValueKey('exercise-status-${item.id}'),
          onPressed: widget.blocked
              ? null
              : () => widget.onStatusChange!(
                  item, ExerciseCatalogStatus.inactive),
          icon: const Icon(Icons.unarchive_outlined, size: 15),
          label: const Text('Restore', style: TextStyle(fontSize: 12)),
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          ),
        ),

      // Secondary Actions More Menu
      if (widget.onStatusChange != null || widget.onDelete != null)
        PopupMenuButton<String>(
          key: ValueKey('exercise-more-${item.id}'),
          tooltip: 'More actions',
          enabled: !widget.blocked,
          icon: const Icon(Icons.more_horiz_rounded,
              size: 20, color: AppColors.inkSoft),
          onSelected: (action) {
            if (action == 'toggle_status' && widget.onStatusChange != null) {
              final next = item.catalogStatus == ExerciseCatalogStatus.active
                  ? ExerciseCatalogStatus.inactive
                  : ExerciseCatalogStatus.active;
              widget.onStatusChange!(item, next);
            } else if (action == 'restore' &&
                widget.onStatusChange != null) {
              widget.onStatusChange!(item, ExerciseCatalogStatus.inactive);
            } else if (action == 'copy_id') {
              Clipboard.setData(ClipboardData(text: item.id));
              showToast(context, 'Copied ID: ${item.id}');
            } else if (action == 'delete' && widget.onDelete != null) {
              widget.onDelete!(item);
            }
          },
          itemBuilder: (context) => [
            if (!item.archived && widget.onStatusChange != null)
              PopupMenuItem(
                key: ValueKey('exercise-status-${item.id}'),
                value: 'toggle_status',
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        item.catalogStatus == ExerciseCatalogStatus.active
                            ? Icons.pause_circle_outline
                            : Icons.check_circle_outline,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(item.catalogStatus == ExerciseCatalogStatus.active
                          ? 'Deactivate'
                          : 'Activate'),
                    ],
                  ),
                ),
              ),
            PopupMenuItem(
              value: 'copy_id',
              child: const FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.copy_rounded, size: 16),
                    SizedBox(width: 8),
                    Text('Copy Exercise ID'),
                  ],
                ),
              ),
            ),
            if (!item.archived && widget.onDelete != null)
              PopupMenuItem(
                key: ValueKey('exercise-delete-${item.id}'),
                value: 'delete',
                child: const Tooltip(
                  message: 'Delete exercise',
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.delete_outline,
                            size: 16, color: AppColors.danger),
                        SizedBox(width: 8),
                        Text('Delete exercise',
                            style: TextStyle(color: AppColors.danger)),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
    ];

    if (isMobile) {
      return Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: actions,
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: actions,
    );
  }

  Widget _emptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppColors.surfaceAlt,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.fitness_center_rounded,
                size: 36,
                color: AppColors.inkSoft.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'No exercises found',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'No exercises match the selected filters or search keyword.',
              style: TextStyle(fontSize: 13, color: AppColors.inkSoft),
            ),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: _resetAllFilters,
              child: const Text('Reset all filters'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterTabChip({
    required String label,
    required int count,
    required bool selected,
    required void Function(bool)? onSelected,
  }) {
    return ChoiceChip(
      selected: selected,
      onSelected: onSelected,
      showCheckmark: false,
      backgroundColor: AppColors.surface,
      selectedColor: AppColors.primaryTint,
      side: BorderSide(
        color: selected ? AppColors.primary : AppColors.hairline,
        width: selected ? 1.5 : 1,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      label: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? AppColors.primary : AppColors.ink,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primary.withValues(alpha: 0.15)
                    : AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: selected ? AppColors.primary : AppColors.inkSoft,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dropdownContainer({required IconData icon, required Widget child}) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.hairline),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppColors.inkSoft),
            const SizedBox(width: 6),
            child,
          ],
        ),
      ),
    );
  }

  Widget _metricDot(Color color) => Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle));

  Widget _metricDivider() => Container(
        height: 12,
        width: 1,
        color: AppColors.hairline,
        margin: const EdgeInsets.symmetric(horizontal: 8),
      );
}
