import 'dart:math' as math;
import 'confirm_content_removal.dart';
import 'routine_cover_field.dart';
import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../../../navigation/admin_breadcrumb.dart';
import 'equipment_catalog_screen.dart' show EditableStringList;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/workout.dart';

/// Refined Fitness Placeholder for Routine Templates with no cover image.
class _FitnessPlaceholder extends StatelessWidget {
  final String level;

  const _FitnessPlaceholder({this.level = 'Beginner'});

  Color get _accentColor {
    switch (level.toLowerCase()) {
      case 'beginner':
        return AppColors.success;
      case 'advanced':
        return AppColors.danger;
      default:
        return AppColors.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmall = constraints.maxHeight < 80;
        final iconSize = isSmall ? 20.0 : 32.0;

        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.surfaceAlt,
                AppColors.primaryTint.withValues(alpha: 0.65),
              ],
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (!isSmall)
                Positioned(
                  right: -20,
                  bottom: -20,
                  child: Icon(
                    Icons.fitness_center_rounded,
                    size: 110,
                    color: AppColors.primary.withValues(alpha: 0.05),
                  ),
                ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: iconSize * 1.5,
                    height: iconSize * 1.5,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _accentColor.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.06),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.fitness_center_rounded,
                      size: iconSize,
                      color: AppColors.primary,
                    ),
                  ),
                  if (!isSmall) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.surface.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'ROUTINE BLUEPRINT',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: AppColors.inkSoft.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

Widget _networkHero(String url,
    {BoxFit fit = BoxFit.cover, String level = 'Beginner'}) {
  if (url.trim().isEmpty) {
    return _FitnessPlaceholder(level: level);
  }
  return Image.network(
    url,
    fit: fit,
    webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
    loadingBuilder: (context, child, progress) =>
        progress == null ? child : Container(color: AppColors.surfaceAlt),
    errorBuilder: (context, error, stack) => _FitnessPlaceholder(level: level),
  );
}

Widget _buildDifficultyChip(String level) {
  final (Color bg, Color text) = switch (level.toLowerCase()) {
    'beginner' => (AppColors.successTint, AppColors.success),
    'advanced' => (AppColors.dangerTint, AppColors.danger),
    _ => (const Color(0xFFFEF3C7), AppColors.warning),
  };
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      level,
      style: TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        color: text,
      ),
    ),
  );
}

Widget _buildTrackingModeBadge(ExerciseExecutionMode? mode) {
  final (Color bg, Color text, IconData icon, String label) = switch (mode) {
    ExerciseExecutionMode.aiTracked => (
      AppColors.primaryTint,
      AppColors.primary,
      Icons.auto_awesome_rounded,
      'AI Tracked'
    ),
    ExerciseExecutionMode.videoGuidedTimed => (
      AppColors.infoTint,
      AppColors.info,
      Icons.smart_display_rounded,
      'Video Timed'
    ),
    _ => (
      AppColors.surfaceAlt,
      AppColors.inkSoft,
      Icons.assignment_outlined,
      'Self-reported'
    ),
  };
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(4),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: text),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: text,
          ),
        ),
      ],
    ),
  );
}

/// AD-M11.4 — Manage Routine Templates.
/// Professional, responsive Routine Template Library Dashboard inspired by
/// Notion Gallery, TeamBuildr Training Library, and Shopify Polaris.
class RoutineTemplatesScreen extends StatefulWidget {
  const RoutineTemplatesScreen(
      {super.key, this.allowRemoval = true, this.initialDraft});
  final RoutineBlueprint? initialDraft;
  final bool allowRemoval;

  @override
  State<RoutineTemplatesScreen> createState() => _RoutineTemplatesScreenState();
}

class _RoutineTemplatesScreenState extends State<RoutineTemplatesScreen> {
  String? _expandedId;
  RoutineBlueprint? _editing;
  bool _creating = false;
  bool _removing = false;
  String? _publishingId;
  late Future<List<RoutineBlueprint>> _templatesFuture;

  // Search, Filter, Sort, View, Drawer state
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedDifficulty = 'All';
  String _selectedSort = 'Name (A–Z)';
  bool _isGridView = true;
  RoutineBlueprint? _drawerTemplate;

  @override
  void initState() {
    super.initState();
    _creating = widget.initialDraft != null;
    _templatesFuture = context.read<RoutineTemplateRepository>().load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openCreate() => setState(() {
        _drawerTemplate = null;
        _creating = true;
      });

  void _openEdit(RoutineBlueprint t) => setState(() {
        _drawerTemplate = null;
        _editing = t;
      });

  void _closeForm() => setState(() {
        _creating = false;
        _editing = null;
        _templatesFuture = context.read<RoutineTemplateRepository>().load();
      });

  Future<void> _remove(RoutineBlueprint item) async {
    if (_removing || _publishingId != null || !widget.allowRemoval) return;
    final repository = context.read<RoutineTemplateRepository>();
    if (repository is! RoutineArchivingRepository) return;
    setState(() => _removing = true);
    try {
      final confirmed = await confirmContentRemoval(context,
          title: item.name,
          detail:
              'This archives the template. Published Member routines and workout history are preserved.');
      if (!confirmed || !mounted || !widget.allowRemoval) {
        return;
      }
      await (repository as RoutineArchivingRepository).archive(item);
      if (!mounted) return;
      setState(() {
        if (_drawerTemplate?.id == item.id) _drawerTemplate = null;
        _templatesFuture = repository.load();
      });
      showToast(context, 'Template removed.');
    } catch (_) {
      if (mounted) {
        showToast(context, 'Removal was not verified. Reload before retrying.');
      }
    } finally {
      if (mounted) setState(() => _removing = false);
    }
  }

  Future<void> _publish(RoutineBlueprint blueprint) async {
    if (_publishingId != null || _removing) return;
    final firebaseCatalog =
        context.read<TutorialRepository>().requiresCatalogSelection;
    setState(() => _publishingId = blueprint.id);
    try {
      await context.read<RoutineTemplateRepository>().publish(blueprint.id);
      if (mounted) {
        showToast(
            context,
            firebaseCatalog
                ? 'Routine published. Members can pull to refresh Home or refresh Workout.'
                : 'Routine published to members.');
      }
    } catch (_) {
      if (mounted) {
        showToast(context,
            'Publication was not verified. Reload and check the Member catalog before retrying.');
      }
    } finally {
      if (mounted) setState(() => _publishingId = null);
    }
  }

  List<RoutineBlueprint> _getFilteredAndSorted(List<RoutineBlueprint> source) {
    var list = source.where((t) {
      if (_selectedDifficulty != 'All' &&
          t.level.toLowerCase() != _selectedDifficulty.toLowerCase()) {
        return false;
      }
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.trim().toLowerCase();
        final matchName = t.name.toLowerCase().contains(q);
        final matchGoal = t.goal.toLowerCase().contains(q);
        final matchTags = t.tags.any((tag) => tag.toLowerCase().contains(q));
        final matchEq =
            t.equipmentNeeded.any((eq) => eq.toLowerCase().contains(q));
        if (!matchName && !matchGoal && !matchTags && !matchEq) return false;
      }
      return true;
    }).toList();

    switch (_selectedSort) {
      case 'Name (A–Z)':
        list.sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      case 'Name (Z–A)':
        list.sort(
            (a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
      case 'Days (Most–Least)':
        list.sort((a, b) => b.days.length.compareTo(a.days.length));
      case 'Days (Least–Most)':
        list.sort((a, b) => a.days.length.compareTo(b.days.length));
      case 'Duration (Longest)':
        list.sort(
            (a, b) => b.sessionDurationMin.compareTo(a.sessionDurationMin));
      case 'Duration (Shortest)':
        list.sort(
            (a, b) => a.sessionDurationMin.compareTo(b.sessionDurationMin));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    if (_creating || _editing != null) {
      return _TemplateFormPage(
          existing: _editing,
          initialDraft: widget.initialDraft,
          onDone: _closeForm);
    }

    return FutureBuilder<List<RoutineBlueprint>>(
      future: _templatesFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Could not load routine templates.'),
            const SizedBox(height: 12),
            TextButton(
                onPressed: () => setState(() => _templatesFuture =
                    context.read<RoutineTemplateRepository>().load()),
                child: const Text('Retry')),
          ]));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final templates = snapshot.data!;
        final filtered = _getFilteredAndSorted(templates);
        final totalAssigned =
            templates.fold<int>(0, (sum, t) => sum + t.assignedMembers);

        final totalCount = templates.length;
        final beginnerCount = templates
            .where((t) => t.level.toLowerCase() == 'beginner')
            .length;
        final intermediateCount = templates
            .where((t) => t.level.toLowerCase() == 'intermediate')
            .length;
        final advancedCount = templates
            .where((t) => t.level.toLowerCase() == 'advanced')
            .length;

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              // Main content scroll view
              Positioned.fill(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(28, 24, 28, 48),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1680),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. Page Header with Title, Description, and Actions
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Routine Templates',
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.ink,
                                          ),
                                    ),
                                    const SizedBox(height: 6),
                                    const Text(
                                      'Author, organize, and assign workout blueprints across training splits and fitness levels.',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: AppColors.inkSoft,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              IconButton(
                                tooltip: 'Reload templates',
                                icon: const Icon(Icons.refresh),
                                onPressed: _removing
                                    ? null
                                    : () => setState(() => _templatesFuture =
                                        context
                                            .read<RoutineTemplateRepository>()
                                            .load()),
                              ),
                              const SizedBox(width: 8),
                              FilledButton.icon(
                                onPressed: _removing ? null : _openCreate,
                                icon: const Icon(Icons.add_rounded, size: 18),
                                label: const Text('New template'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 18),

                          // 2. Metrics Summary Pill Bar
                          Wrap(
                            spacing: 12,
                            runSpacing: 10,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppColors.hairline),
                                ),
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(
                                      '$totalCount templates',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.ink,
                                      ),
                                    ),
                                    _metricDivider(),
                                    _metricDot(AppColors.success),
                                    Text(
                                      '$beginnerCount Beginner',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.ink,
                                      ),
                                    ),
                                    _metricDivider(),
                                    _metricDot(AppColors.warning),
                                    Text(
                                      '$intermediateCount Intermediate',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.ink,
                                      ),
                                    ),
                                    _metricDivider(),
                                    _metricDot(AppColors.danger),
                                    Text(
                                      '$advancedCount Advanced',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.ink,
                                      ),
                                    ),
                                    if (totalAssigned > 0) ...[
                                      _metricDivider(),
                                      const Icon(Icons.people_outline_rounded,
                                          size: 15, color: AppColors.inkSoft),
                                      Text(
                                        '$totalAssigned following',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.inkSoft,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),

                          // 3. Search, Filter, Sort, and View Switcher Toolbar
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            alignment: WrapAlignment.spaceBetween,
                            children: [
                              // Search and Filter Pills
                              Wrap(
                                spacing: 10,
                                runSpacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  // Search Field
                                  SizedBox(
                                    width: 280,
                                    height: 38,
                                    child: TextField(
                                      controller: _searchController,
                                      onChanged: (val) =>
                                          setState(() => _searchQuery = val),
                                      style: const TextStyle(fontSize: 13),
                                      decoration: InputDecoration(
                                        hintText: 'Search templates by name…',
                                        hintStyle: const TextStyle(
                                            color: AppColors.inkSoft,
                                            fontSize: 13),
                                        prefixIcon: const Icon(
                                            Icons.search_rounded,
                                            size: 18,
                                            color: AppColors.inkSoft),
                                        suffixIcon: _searchQuery.isNotEmpty
                                            ? IconButton(
                                                icon: const Icon(
                                                    Icons.close_rounded,
                                                    size: 16),
                                                onPressed: () {
                                                  _searchController.clear();
                                                  setState(
                                                      () => _searchQuery = '');
                                                },
                                              )
                                            : null,
                                        contentPadding: EdgeInsets.zero,
                                        filled: true,
                                        fillColor: AppColors.surface,
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          borderSide: const BorderSide(
                                              color: AppColors.hairline),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          borderSide: const BorderSide(
                                              color: AppColors.primary,
                                              width: 1.5),
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Difficulty Filter Chips
                                  ...[
                                    ('All', totalCount),
                                    ('Beginner', beginnerCount),
                                    ('Intermediate', intermediateCount),
                                    ('Advanced', advancedCount),
                                  ].map((filter) {
                                    final isSelected =
                                        _selectedDifficulty == filter.$1;
                                    return InkWell(
                                      onTap: () => setState(() =>
                                          _selectedDifficulty = filter.$1),
                                      borderRadius: BorderRadius.circular(8),
                                      child: AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 150),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? AppColors.primary
                                              : AppColors.surface,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                            color: isSelected
                                                ? AppColors.primary
                                                : AppColors.hairline,
                                          ),
                                        ),
                                        child: Text(
                                          '${filter.$1} (${filter.$2})',
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: isSelected
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                            color: isSelected
                                                ? Colors.white
                                                : AppColors.ink,
                                          ),
                                        ),
                                      ),
                                    );
                                  }),
                                ],
                              ),

                              // Sort & View Toggle
                              Wrap(
                                spacing: 10,
                                runSpacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  // Sort Dropdown
                                  Container(
                                    height: 38,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10),
                                    decoration: BoxDecoration(
                                      color: AppColors.surface,
                                      borderRadius: BorderRadius.circular(8),
                                      border:
                                          Border.all(color: AppColors.hairline),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: _selectedSort,
                                        icon: const Icon(Icons.arrow_drop_down,
                                            color: AppColors.inkSoft),
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.ink,
                                        ),
                                        items: [
                                          'Name (A–Z)',
                                          'Name (Z–A)',
                                          'Days (Most–Least)',
                                          'Days (Least–Most)',
                                          'Duration (Longest)',
                                          'Duration (Shortest)',
                                        ]
                                            .map((s) => DropdownMenuItem(
                                                value: s, child: Text(s)))
                                            .toList(),
                                        onChanged: (val) {
                                          if (val != null) {
                                            setState(
                                                () => _selectedSort = val);
                                          }
                                        },
                                      ),
                                    ),
                                  ),

                                  // Grid / List View Toggle
                                  Container(
                                    height: 38,
                                    padding: const EdgeInsets.all(3),
                                    decoration: BoxDecoration(
                                      color: AppColors.surface,
                                      borderRadius: BorderRadius.circular(8),
                                      border:
                                          Border.all(color: AppColors.hairline),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        InkWell(
                                          onTap: () => setState(
                                              () => _isGridView = true),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: _isGridView
                                                  ? AppColors.primaryTint
                                                  : Colors.transparent,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Icon(
                                              Icons.grid_view_rounded,
                                              size: 18,
                                              color: _isGridView
                                                  ? AppColors.primary
                                                  : AppColors.inkSoft,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 2),
                                        InkWell(
                                          onTap: () => setState(
                                              () => _isGridView = false),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: !_isGridView
                                                  ? AppColors.primaryTint
                                                  : Colors.transparent,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Icon(
                                              Icons.view_list_rounded,
                                              size: 18,
                                              color: !_isGridView
                                                  ? AppColors.primary
                                                  : AppColors.inkSoft,
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

                          const SizedBox(height: 24),

                          // 4. Content Area: Grid View or List View or Empty State
                          if (filtered.isEmpty)
                            _buildEmptyState()
                          else if (_isGridView)
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final width = constraints.maxWidth;
                                final int columns;
                                if (width >= 1480) {
                                  columns = 4;
                                } else if (width >= 1100) {
                                  columns = 3;
                                } else if (width >= 680) {
                                  columns = 2;
                                } else {
                                  columns = 1;
                                }
                                const double spacing = 18;
                                final double cardWidth = (width -
                                        (columns - 1) * spacing) /
                                    columns;

                                return Wrap(
                                  spacing: spacing,
                                  runSpacing: 20,
                                  children: filtered.map((t) {
                                    return SizedBox(
                                      width: cardWidth,
                                      child: _RoutineGridCard(
                                        template: t,
                                        showRemoval: widget.allowRemoval,
                                        expanded: _expandedId == t.id,
                                        onToggle: () => setState(() =>
                                            _expandedId = _expandedId == t.id
                                                ? null
                                                : t.id),
                                        onPreview: () => setState(
                                            () => _drawerTemplate = t),
                                        onEdit: () => _openEdit(t),
                                        onRemove: widget.allowRemoval &&
                                                context.read<
                                                        RoutineTemplateRepository>()
                                                    is RoutineArchivingRepository &&
                                                !_removing &&
                                                _publishingId == null
                                            ? () => _remove(t)
                                            : null,
                                        onPublish: () => _publish(t),
                                        publishing: _publishingId == t.id,
                                      ),
                                    );
                                  }).toList(),
                                );
                              },
                            )
                          else
                            Column(
                              children: filtered.map((t) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _TemplateCard(
                                    showRemoval: widget.allowRemoval,
                                    template: t,
                                    expanded: _expandedId == t.id,
                                    onToggle: () => setState(() =>
                                        _expandedId =
                                            _expandedId == t.id ? null : t.id),
                                    onPreview: () =>
                                        setState(() => _drawerTemplate = t),
                                    onRemove: widget.allowRemoval &&
                                            context.read<
                                                    RoutineTemplateRepository>()
                                                is RoutineArchivingRepository &&
                                            !_removing &&
                                            _publishingId == null
                                        ? () => _remove(t)
                                        : null,
                                    onEdit: () => _openEdit(t),
                                    onPublish: () => _publish(t),
                                    publishing: _publishingId == t.id,
                                    firebaseCatalog: context
                                        .read<TutorialRepository>()
                                        .requiresCatalogSelection,
                                  ),
                                );
                              }).toList(),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // 5. Sliding Detail Drawer & Scrim Backdrop
              if (_drawerTemplate != null) ...[
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () => setState(() => _drawerTemplate = null),
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.32),
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  bottom: 0,
                  right: 0,
                  width:
                      math.min(520, MediaQuery.of(context).size.width * 0.92),
                  child: Material(
                    elevation: 16,
                    color: AppColors.surface,
                    child: _RoutineDetailDrawerContent(
                      template: _drawerTemplate!,
                      showRemoval: widget.allowRemoval,
                      onClose: () => setState(() => _drawerTemplate = null),
                      onEdit: () {
                        final t = _drawerTemplate!;
                        setState(() => _drawerTemplate = null);
                        _openEdit(t);
                      },
                      onPublish: () => _publish(_drawerTemplate!),
                      onRemove: widget.allowRemoval &&
                              context.read<RoutineTemplateRepository>()
                                  is RoutineArchivingRepository &&
                              !_removing &&
                              _publishingId == null
                          ? () {
                              final t = _drawerTemplate!;
                              setState(() => _drawerTemplate = null);
                              _remove(t);
                            }
                          : null,
                      publishing: _publishingId == _drawerTemplate!.id,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 24),
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
              color: AppColors.surfaceAlt,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.search_off_rounded,
                size: 32, color: AppColors.inkSoft),
          ),
          const SizedBox(height: 16),
          const Text(
            'No routine templates found',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Try adjusting your search query or difficulty filter.',
            style: TextStyle(fontSize: 13, color: AppColors.inkSoft),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () {
              _searchController.clear();
              setState(() {
                _searchQuery = '';
                _selectedDifficulty = 'All';
              });
            },
            child: const Text('Clear filters'),
          ),
        ],
      ),
    );
  }

  static Widget _metricDot(Color color) {
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  static Widget _metricDivider() {
    return Container(
      width: 1,
      height: 12,
      color: AppColors.hairline,
      margin: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}

/// Responsive, modern 16:9 Routine Card inspired by Notion Gallery & TeamBuildr.
class _RoutineGridCard extends StatefulWidget {
  final RoutineBlueprint template;
  final bool showRemoval;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onPreview;
  final VoidCallback onEdit;
  final VoidCallback? onRemove;
  final VoidCallback onPublish;
  final bool publishing;

  const _RoutineGridCard({
    required this.template,
    required this.showRemoval,
    required this.expanded,
    required this.onToggle,
    required this.onPreview,
    required this.onEdit,
    this.onRemove,
    required this.onPublish,
    required this.publishing,
  });

  @override
  State<_RoutineGridCard> createState() => _RoutineGridCardState();
}

class _RoutineGridCardState extends State<_RoutineGridCard> {
  bool _isHovered = false;

  int get _totalExercises => widget.template.days
      .fold<int>(0, (sum, day) => sum + day.exercises.length);

  @override
  Widget build(BuildContext context) {
    final t = widget.template;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onToggle,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isHovered
                  ? AppColors.primary.withValues(alpha: 0.45)
                  : AppColors.hairline,
              width: _isHovered ? 1.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: _isHovered
                    ? AppColors.primary.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.03),
                blurRadius: _isHovered ? 14 : 8,
                offset: _isHovered ? const Offset(0, 4) : const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top: 16:9 Routine Cover Image
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _networkHero(t.imageUrl, level: t.level),
                      // Top Left: Difficulty Chip
                      Positioned(
                        top: 10,
                        left: 10,
                        child: _buildDifficultyChip(t.level),
                      ),
                      // Top Right: Split Tag & Delete
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${t.days.length}-day split',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            if (widget.showRemoval) ...[
                              const SizedBox(width: 6),
                              Container(
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  tooltip: 'Remove template',
                                  icon: const Icon(Icons.delete_outline,
                                      size: 15, color: Colors.white),
                                  onPressed:
                                      t.readOnly ? null : widget.onRemove,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Body Content
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Routine Title
                      Text(
                        t.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),

                      // Goal / Description
                      Text(
                        t.goal.isNotEmpty
                            ? t.goal
                            : 'GainPath progressive athletic training blueprint.',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.inkSoft,
                          height: 1.35,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),

                      // Specs Row (Exercises, Duration, Following)
                      Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.fitness_center_outlined,
                                  size: 14, color: AppColors.inkSoft),
                              const SizedBox(width: 4),
                              Text(
                                '$_totalExercises exercises',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.ink,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.schedule_rounded,
                                  size: 14, color: AppColors.inkSoft),
                              const SizedBox(width: 4),
                              Text(
                                '${t.sessionDurationMin} min',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.ink,
                                ),
                              ),
                            ],
                          ),
                          if (t.assignedMembers > 0)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.people_outline_rounded,
                                    size: 14, color: AppColors.inkSoft),
                                const SizedBox(width: 4),
                                Text(
                                  '${t.assignedMembers} following',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.inkSoft,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),

                      // Tags preview
                      if (t.tags.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            ...t.tags.take(2).map((tag) => Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceAlt,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    tag,
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.inkSoft,
                                    ),
                                  ),
                                )),
                            if (t.tags.length > 2)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceAlt,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '+${t.tags.length - 2}',
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.inkSoft,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 14),
                      const Divider(height: 1, color: AppColors.hairline),
                      const SizedBox(height: 10),

                      // Footer Actions: Preview, Edit, More Menu
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: widget.onPreview,
                              icon: const Icon(Icons.visibility_outlined,
                                  size: 15),
                              label: const Text('Preview'),
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                side:
                                    const BorderSide(color: AppColors.hairline),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            tooltip: 'Edit template',
                            onPressed: t.readOnly ? null : widget.onEdit,
                          ),
                          PopupMenuButton<String>(
                            tooltip: 'More actions',
                            icon: const Icon(Icons.more_vert_rounded, size: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'publish',
                                enabled: !widget.publishing && !t.readOnly,
                                child: Row(
                                  children: [
                                    const Icon(Icons.publish_rounded,
                                        size: 16, color: AppColors.ink),
                                    const SizedBox(width: 8),
                                    Text(widget.publishing
                                        ? 'Publishing…'
                                        : 'Publish to members'),
                                  ],
                                ),
                              ),
                              if (widget.showRemoval)
                                PopupMenuItem(
                                  value: 'remove',
                                  enabled: !t.readOnly,
                                  child: const Row(
                                    children: [
                                      Icon(Icons.delete_outline,
                                          size: 16, color: AppColors.danger),
                                      SizedBox(width: 8),
                                      Text('Remove template',
                                          style: TextStyle(
                                              color: AppColors.danger)),
                                    ],
                                  ),
                                ),
                            ],
                            onSelected: (action) {
                              if (action == 'publish') {
                                widget.onPublish();
                              } else if (action == 'remove' &&
                                  widget.onRemove != null) {
                                widget.onRemove!();
                              }
                            },
                          ),
                        ],
                      ),

                      // Inline Day Breakdown & Publish
                      AnimatedSize(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOut,
                        child: widget.expanded
                            ? Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    const Divider(
                                        height: 1, color: AppColors.hairline),
                                    const SizedBox(height: 10),
                                    ...t.days.map((d) => Padding(
                                          padding: const EdgeInsets.only(
                                              bottom: 8),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text('Day ${d.dayNumber}',
                                                  style: const TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color:
                                                          AppColors.primary)),
                                              const SizedBox(height: 4),
                                              ...d.exercises.map((e) => Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                            bottom: 2,
                                                            left: 4),
                                                    child: Row(
                                                      children: [
                                                        const Icon(
                                                            Icons.circle,
                                                            size: 4,
                                                            color: AppColors
                                                                .inkSoft),
                                                        const SizedBox(
                                                            width: 6),
                                                        Expanded(
                                                          child: Text(
                                                            '${e.exerciseName} · ${e.sets} × ${e.prescription is TimedPrescription ? '${(e.prescription as TimedPrescription).durationSeconds}s' : '${e.reps ?? 10} reps'}',
                                                            style:
                                                                const TextStyle(
                                                                    fontSize:
                                                                        12),
                                                          ),
                                                        ),
                                                        _buildTrackingModeBadge(
                                                            e.executionMode),
                                                      ],
                                                    ),
                                                  )),
                                            ],
                                          ),
                                        )),
                                    const SizedBox(height: 10),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: OutlinedButton.icon(
                                        onPressed:
                                            widget.publishing || t.readOnly
                                                ? null
                                                : widget.onPublish,
                                        icon: widget.publishing
                                            ? const SizedBox(
                                                width: 14,
                                                height: 14,
                                                child:
                                                    CircularProgressIndicator(
                                                        strokeWidth: 2))
                                            : const Icon(
                                                Icons.publish_rounded,
                                                size: 16),
                                        label: Text(widget.publishing
                                            ? 'Publishing…'
                                            : 'Publish'),
                                        style: OutlinedButton.styleFrom(
                                          padding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 12, vertical: 8),
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8)),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : const SizedBox(width: double.infinity),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact List View Row & expandable breakdown.
class _TemplateCard extends StatelessWidget {
  final bool showRemoval;
  final RoutineBlueprint template;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onPreview;
  final VoidCallback onEdit;
  final VoidCallback? onRemove;
  final VoidCallback onPublish;
  final bool publishing;
  final bool firebaseCatalog;

  const _TemplateCard({
    required this.template,
    required this.expanded,
    required this.onToggle,
    required this.onPreview,
    required this.onEdit,
    this.showRemoval = true,
    this.onRemove,
    required this.onPublish,
    required this.publishing,
    required this.firebaseCatalog,
  });

  int get _totalExercises =>
      template.days.fold<int>(0, (sum, day) => sum + day.exercises.length);

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(
                children: [
                  // 16:9 Compact Thumbnail
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 90,
                      height: 52,
                      child: _networkHero(template.imageUrl,
                          level: template.level),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Routine Specs & Badges
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              template.name,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.ink,
                                  ),
                            ),
                            const SizedBox(width: 8),
                            _buildDifficultyChip(template.level),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          firebaseCatalog
                              ? '${template.days.length}-day split  ·  $_totalExercises exercises  ·  ${template.sessionDurationMin} min'
                              : '${template.days.length}-day split  ·  $_totalExercises exercises  ·  ${template.sessionDurationMin} min  ·  ${template.assignedMembers} following',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                fontSize: 12.5,
                                color: AppColors.inkSoft,
                              ),
                        ),
                      ],
                    ),
                  ),

                  // Actions
                  OutlinedButton.icon(
                    onPressed: onPreview,
                    icon: const Icon(Icons.visibility_outlined, size: 15),
                    label: const Text('Preview'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      side: const BorderSide(color: AppColors.hairline),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  if (showRemoval)
                    IconButton(
                      tooltip: 'Remove template',
                      onPressed: template.readOnly ? null : onRemove,
                      icon: const Icon(Icons.delete_outline, size: 18),
                    ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    tooltip: 'Edit template',
                    onPressed: template.readOnly ? null : onEdit,
                  ),
                  Icon(
                    expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: AppColors.inkSoft,
                  ),
                ],
              ),
            ),
          ),

          // Inline breakdown section
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            child: expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Divider(height: 20),
                        if (template.goal.isNotEmpty) ...[
                          Text(template.goal,
                              style: Theme.of(context).textTheme.bodyMedium),
                          const SizedBox(height: 10),
                        ],
                        if (template.tags.isNotEmpty) ...[
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: template.tags
                                .map((t) => Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                          color: AppColors.primaryTint,
                                          borderRadius:
                                              BorderRadius.circular(999)),
                                      child: Text(t,
                                          style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.primary)),
                                    ))
                                .toList(),
                          ),
                          const SizedBox(height: 10),
                        ],
                        ...template.days.map((d) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Day ${d.dayNumber}',
                                      style: const TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.primary)),
                                  const SizedBox(height: 4),
                                  ...d.exercises.map((e) => Padding(
                                        padding: const EdgeInsets.only(
                                            bottom: 3, left: 4),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.circle,
                                                size: 4,
                                                color: AppColors.inkSoft),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                  '${e.exerciseName}  ·  ${e.sets} × ${e.prescription is TimedPrescription ? '${(e.prescription as TimedPrescription).durationSeconds}s' : '${e.reps ?? 10} reps'}',
                                                  style: const TextStyle(
                                                      fontSize: 13)),
                                            ),
                                            _buildTrackingModeBadge(
                                                e.executionMode),
                                          ],
                                        ),
                                      )),
                                ],
                              ),
                            )),
                        Align(
                          alignment: Alignment.centerRight,
                          child: OutlinedButton.icon(
                            onPressed: publishing || template.readOnly
                                ? null
                                : onPublish,
                            icon: publishing
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))
                                : const Icon(Icons.publish_rounded, size: 17),
                            label: Text(publishing ? 'Publishing…' : 'Publish'),
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

/// Slide-in Detail Drawer Content on the right side.
class _RoutineDetailDrawerContent extends StatelessWidget {
  final RoutineBlueprint template;
  final bool showRemoval;
  final VoidCallback onClose;
  final VoidCallback onEdit;
  final VoidCallback onPublish;
  final VoidCallback? onRemove;
  final bool publishing;

  const _RoutineDetailDrawerContent({
    required this.template,
    required this.showRemoval,
    required this.onClose,
    required this.onEdit,
    required this.onPublish,
    this.onRemove,
    required this.publishing,
  });

  int get _totalExercises =>
      template.days.fold<int>(0, (sum, day) => sum + day.exercises.length);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Drawer Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.hairline)),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: onClose,
                tooltip: 'Close details',
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Routine Overview',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 19),
                tooltip: 'Edit template',
                onPressed: template.readOnly ? null : onEdit,
              ),
              if (showRemoval)
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      size: 19, color: AppColors.danger),
                  tooltip: 'Remove template',
                  onPressed: template.readOnly ? null : onRemove,
                ),
            ],
          ),
        ),

        // Scrollable Drawer Body
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 16:9 Hero Image
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: _networkHero(template.imageUrl,
                        level: template.level),
                  ),
                ),
                const SizedBox(height: 18),

                // Name & Badges
                Text(
                  template.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 10),

                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _buildDifficultyChip(template.level),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${template.days.length}-Day Split',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.inkSoft,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${template.sessionDurationMin} Min / Session',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.inkSoft,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Goal description
                if (template.goal.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.flag_outlined,
                            size: 16, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            template.goal,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.ink,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // 4-Card Metrics Grid
                Row(
                  children: [
                    Expanded(
                      child: _metricCard(
                        'Training Split',
                        '${template.days.length} Days',
                        Icons.calendar_view_week_rounded,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _metricCard(
                        'Session Length',
                        '${template.sessionDurationMin} min',
                        Icons.timer_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _metricCard(
                        'Exercises',
                        '$_totalExercises movements',
                        Icons.fitness_center_rounded,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _metricCard(
                        'Members',
                        '${template.assignedMembers} active',
                        Icons.groups_outlined,
                      ),
                    ),
                  ],
                ),

                // Tags & Equipment
                if (template.tags.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Tags',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.inkSoft,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: template.tags.map((tag) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primaryTint,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          tag,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],

                if (template.equipmentNeeded.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  const Text(
                    'Equipment Needed',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.inkSoft,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: template.equipmentNeeded.map((eq) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          eq,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],

                const SizedBox(height: 22),
                const Divider(height: 1, color: AppColors.hairline),
                const SizedBox(height: 18),

                // Daily Structure
                const Text(
                  'Daily Workout Structure',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 12),

                ...template.days.map((day) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.hairline),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Day ${day.dayNumber}',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${day.exercises.length} exercises',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.inkSoft,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ...day.exercises.map((e) {
                          final String prescriptionText;
                          if (e.prescription is TimedPrescription) {
                            final tp = e.prescription as TimedPrescription;
                            prescriptionText =
                                '${e.sets} sets × ${tp.durationSeconds}s · ${tp.restSeconds}s rest';
                          } else {
                            prescriptionText =
                                '${e.sets} sets × ${e.reps ?? 10} reps · ${e.prescription?.restSeconds ?? 60}s rest';
                          }

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                const Icon(Icons.radio_button_checked_rounded,
                                    size: 14, color: AppColors.primary),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        e.exerciseName,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.ink,
                                        ),
                                      ),
                                      Text(
                                        prescriptionText,
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          color: AppColors.inkSoft,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                _buildTrackingModeBadge(e.executionMode),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),

        // Sticky Footer
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.hairline)),
          ),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: template.readOnly ? null : onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Edit blueprint'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed:
                    publishing || template.readOnly ? null : onPublish,
                icon: publishing
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.publish_rounded, size: 16),
                label: Text(publishing ? 'Publishing…' : 'Publish'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _metricCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: AppColors.inkSoft),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.inkSoft,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExerciseDraft {
  static int _serial = 0;
  final String entryId;
  ExerciseExecutionMode? mode;
  int? sourceRevision;
  final TextEditingController rest;
  final TextEditingController name;
  final TextEditingController sets;
  final TextEditingController reps;
  String? selectedExerciseId;
  _ExerciseDraft(
      {String name = '',
      String sets = '3',
      String reps = '10',
      String rest = '60',
      String? entryId,
      this.mode,
      this.sourceRevision,
      this.selectedExerciseId})
      : entryId = entryId ??
            'entry-${DateTime.now().microsecondsSinceEpoch}-${_serial++}',
        rest = TextEditingController(text: rest),
        name = TextEditingController(text: name),
        sets = TextEditingController(text: sets),
        reps = TextEditingController(text: reps);

  void dispose() {
    name.dispose();
    sets.dispose();
    reps.dispose();
    rest.dispose();
  }
}

class _DayDraft {
  final List<_ExerciseDraft> exercises;
  _DayDraft([List<_ExerciseDraft>? exercises])
      : exercises = exercises ?? [_ExerciseDraft()];

  void dispose() {
    for (final e in exercises) {
      e.dispose();
    }
  }
}

class _TemplateFormPage extends StatefulWidget {
  final RoutineBlueprint? initialDraft;
  final RoutineBlueprint? existing;
  final VoidCallback onDone;
  const _TemplateFormPage({this.existing, this.initialDraft, required this.onDone});

  @override
  State<_TemplateFormPage> createState() => _TemplateFormPageState();
}

class _TemplateFormPageState extends State<_TemplateFormPage> {
  late final RoutineBlueprint? _seed = widget.existing ?? widget.initialDraft;
  static const _levels = ['Beginner', 'Intermediate', 'Advanced'];
  static const _tagOptions = [
    'Fat loss',
    'Muscle gain',
    'General fitness',
    'Strength',
    'Mobility'
  ];

  late final _name = TextEditingController(text: _seed?.name ?? '')
    ..addListener(_repaint);
  late final _imageUrl = TextEditingController(text: _seed?.imageUrl ?? '')
    ..addListener(_repaint);
  late final _goal = TextEditingController(text: _seed?.goal ?? '');
  late final _duration =
      TextEditingController(text: '${_seed?.sessionDurationMin ?? 45}');
  late String _level = _seed?.level ?? _levels.first;
  late final Set<String> _tags = {...(_seed?.tags ?? const [])};
  late List<String> _equipmentNeeded = [
    ...(_seed?.equipmentNeeded ?? const [])
  ];
  late final List<_DayDraft> _days = _seed == null
      ? [_DayDraft()]
      : _seed.days
          .map((d) => _DayDraft(d.exercises
              .map((e) => _ExerciseDraft(
                  name: e.exerciseName,
                  sets: '${e.sets}',
                  reps:
                      '${e.prescription is TimedPrescription ? (e.prescription as TimedPrescription).durationSeconds : e.reps}',
                  rest: '${e.prescription?.restSeconds ?? 60}',
                  entryId: e.entryId.isEmpty ? null : e.entryId,
                  mode: e.executionMode,
                  sourceRevision: e.sourceCatalogRevision,
                  selectedExerciseId:
                      e.exerciseId.isEmpty ? null : e.exerciseId))
              .toList()))
          .toList();
  String? _error;
  EquipmentImage? _cover;
  String? _coverError;
  bool _pickingCover = false;

  Future<void> _chooseCover() async {
    if (_saving || _reloadRequired || _pickingCover) return;
    setState(() {
      _pickingCover = true;
      _coverError = null;
    });
    try {
      final selected = await context.read<EquipmentImagePicker>().pick();
      if (mounted && selected != null) setState(() => _cover = selected);
    } on FormatException catch (error) {
      if (mounted) setState(() => _coverError = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _coverError =
            'Could not open the image. Choose another JPG, PNG or WebP.');
      }
    } finally {
      if (mounted) setState(() => _pickingCover = false);
    }
  }

  List<TutorialVideo> _catalog = const [];
  bool _catalogLoading = false;
  bool _saving = false;
  bool _reloadRequired = false;
  bool get _usesCatalog =>
      context.read<TutorialRepository>().requiresCatalogSelection;

  bool get _isEdit => widget.existing != null;
  bool get _isV2 =>
      _usesCatalog &&
      (widget.existing == null ||
          widget.existing!.schemaVersion == 2 ||
          _upgradeLegacy);
  bool _upgradeLegacy = false;
  int _stage = 0;
  void _selectStage(int stage) {
    if (stage > 0 &&
        (_name.text.trim().isEmpty ||
            int.tryParse(_duration.text) == null ||
            int.parse(_duration.text) < 5 ||
            int.parse(_duration.text) > 240)) {
      setState(() {
        _stage = 0;
        _error = 'Give the routine a name and a duration of 5–240 minutes.';
      });
      return;
    }
    if (stage == 2) {
      for (final day in _days) {
        for (final row in day.exercises) {
          try {
            if (row.selectedExerciseId == null) {
              throw const FormatException('Select an exercise for every row.');
            }
            final sets = int.tryParse(row.sets.text),
                value = int.tryParse(row.reps.text),
                rest = int.tryParse(row.rest.text);
            if (sets == null || value == null || rest == null) {
              throw const FormatException('Use whole target values.');
            }
            final ExercisePrescription target =
                row.mode == ExerciseExecutionMode.videoGuidedTimed
                    ? TimedPrescription(
                        sets: sets, durationSeconds: value, restSeconds: rest)
                    : RepetitionPrescription(
                        sets: sets, repetitions: value, restSeconds: rest);
            target.validate();
          } on FormatException catch (error) {
            setState(() {
              _stage = 1;
              _error = error.message;
            });
            return;
          }
        }
      }
    }
    setState(() {
      _stage = stage;
      _error = null;
    });
  }

  ExerciseExecutionMode _catalogMode(TutorialVideo item) =>
      item.executionMode == ExerciseExecutionMode.videoGuidedTimed
          ? ExerciseExecutionMode.videoGuidedTimed
          : item.trackingCapability.hasPoseTracking
              ? ExerciseExecutionMode.aiTracked
              : ExerciseExecutionMode.legacyManual;

  void _copyDefaults(_ExerciseDraft row, TutorialVideo item) {
    row.selectedExerciseId = item.id;
    row.mode = _catalogMode(item);
    row.sourceRevision = item.editRevision;
    final defaults = item.defaultPrescription;
    row.sets.text = '${defaults?.sets ?? 3}';
    row.rest.text = '${defaults?.restSeconds ?? 60}';
    row.reps.text = defaults is TimedPrescription
        ? '${defaults.durationSeconds}'
        : '${defaults is RepetitionPrescription ? defaults.repetitions : 10}';
  }

  @override
  void initState() {
    super.initState();
    if (context.read<TutorialRepository>().requiresCatalogSelection) {
      _loadCatalog();
    }
  }

  Future<void> _loadCatalog() async {
    if (_saving || _reloadRequired) return;
    setState(() {
      _catalogLoading = true;
      _error = null;
    });
    try {
      final entries = await context.read<TutorialRepository>().load();
      if (mounted) {
        setState(() {
          _catalog = entries
              .where((entry) =>
                  !entry.archived && entry.status == TutorialStatus.active)
              .toList();
          final byId = {for (final entry in _catalog) entry.id: entry};
          for (final day in _days) {
            for (final row in day.exercises) {
              final item = byId[row.selectedExerciseId];
              if (item != null &&
                  row.mode == ExerciseExecutionMode.aiTracked &&
                  _catalogMode(item) == ExerciseExecutionMode.legacyManual) {
                row.mode = ExerciseExecutionMode.legacyManual;
              }
            }
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Could not load the exercise catalog. Reload exercises to retry.');
      }
    } finally {
      if (mounted) setState(() => _catalogLoading = false);
    }
  }

  void _repaint() => setState(() {});
  Future<void> _discard() async {
    if (_saving) return;
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
                title: const Text('Discard unsaved routine changes?'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialog, false),
                      child: const Text('Keep editing')),
                  TextButton(
                      onPressed: () => Navigator.pop(dialog, true),
                      child: const Text('Discard'))
                ]));
    if (confirmed == true && mounted) widget.onDone();
  }

  @override
  void dispose() {
    _name.dispose();
    _imageUrl.dispose();
    _goal.dispose();
    _duration.dispose();
    for (final d in _days) {
      d.dispose();
    }
    super.dispose();
  }

  void _addDay() => setState(() => _days.add(_DayDraft()));

  void _removeDay(int i) {
    setState(() {
      _days[i].dispose();
      _days.removeAt(i);
    });
  }

  void _addExercise(int dayIndex) =>
      setState(() => _days[dayIndex].exercises.add(_ExerciseDraft()));

  void _removeExercise(int dayIndex, int exIndex) {
    setState(() {
      _days[dayIndex].exercises[exIndex].dispose();
      _days[dayIndex].exercises.removeAt(exIndex);
    });
  }

  void _moveExercise(int dayIndex, int from, int to) {
    if (_saving || _reloadRequired) return;
    final exercises = _days[dayIndex].exercises;
    if (to < 0 || to >= exercises.length) return;
    setState(() => exercises.insert(to, exercises.removeAt(from)));
  }

  Future<void> _save() async {
    if (_saving || _reloadRequired || _catalogLoading || _pickingCover) return;
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Give the template a name.');
      return;
    }
    if (_usesCatalog && _name.text.trim().length > 120) {
      setState(() => _error = 'Routine names must be 120 characters or fewer.');
      return;
    }
    if (_days.isEmpty) {
      setState(() => _error = 'Add at least one day.');
      return;
    }
    if (_usesCatalog && _days.length > 14) {
      setState(() => _error = 'A routine can contain at most 14 days.');
      return;
    }
    final duration = int.tryParse(_duration.text.trim());
    if (_usesCatalog && (duration == null || duration < 5 || duration > 240)) {
      setState(() => _error = 'Session duration must be 5–240 whole minutes.');
      return;
    }
    final days = <RoutineDay>[];
    for (var i = 0; i < _days.length; i++) {
      if (_usesCatalog && _days[i].exercises.length > 20) {
        setState(
            () => _error = 'Day ${i + 1} can contain at most 20 exercises.');
        return;
      }
      final exercises = <RoutineExerciseRef>[];
      for (final ex in _days[i].exercises) {
        TutorialVideo? selected;
        if (_usesCatalog && ex.selectedExerciseId != null) {
          for (final entry in _catalog) {
            if (entry.id == ex.selectedExerciseId) selected = entry;
          }
        }
        if (_usesCatalog && selected == null) {
          setState(() => _error =
              'Day ${i + 1}: select an active exercise from the catalog.');
          return;
        }
        final mode = _isV2 ? _catalogMode(selected!) : null;
        final name = _usesCatalog ? selected!.title : ex.name.text.trim();
        if (name.isEmpty) continue;
        final sets = int.tryParse(ex.sets.text.trim());
        final reps = int.tryParse(ex.reps.text.trim());
        if (sets == null ||
            sets <= 0 ||
            reps == null ||
            reps <= 0 ||
            (_usesCatalog &&
                (sets > 50 ||
                    reps >
                        (mode == ExerciseExecutionMode.videoGuidedTimed
                            ? 3600
                            : 100)))) {
          setState(() => _error = _usesCatalog
              ? 'Day ${i + 1}: sets must be 1–50 and reps 1–100.'
              : 'Day ${i + 1}: sets and reps must be whole numbers greater than zero.');
          return;
        }
        ExercisePrescription? target;
        if (_isV2) {
          final rest = int.tryParse(ex.rest.text);
          if (rest == null) {
            setState(() => _error = 'Use whole rest seconds.');
            return;
          }
          target = mode == ExerciseExecutionMode.videoGuidedTimed
              ? TimedPrescription(
                  sets: sets, durationSeconds: reps, restSeconds: rest)
              : RepetitionPrescription(
                  sets: sets, repetitions: reps, restSeconds: rest);
          try {
            target.validate();
          } on FormatException catch (error) {
            setState(() => _error = error.message);
            return;
          }
        }
        exercises.add(RoutineExerciseRef(
            name, sets, target is TimedPrescription ? null : reps,
            exerciseId: selected?.id ?? '',
            entryId: ex.entryId,
            executionMode: mode,
            prescription: target,
            sourceCatalogRevision: ex.sourceRevision));
      }
      if (exercises.isEmpty) {
        setState(() => _error = 'Day ${i + 1} needs at least one exercise.');
        return;
      }
      days.add(RoutineDay(i + 1, exercises));
    }
    final sessionDuration = duration ?? 45;
    if (_usesCatalog &&
        days.fold<int>(0, (sum, day) => sum + day.exercises.length) > 50) {
      setState(() => _error = 'A routine can contain at most 50 exercises.');
      return;
    }

    final blueprint = RoutineBlueprint(
      id: widget.existing?.id ??
          (_usesCatalog ? '' : 'rt${DateTime.now().millisecondsSinceEpoch}'),
      editBaseline: widget.existing?.editBaseline,
      schemaVersion: _isV2 ? 2 : 1,
      name: _name.text.trim(),
      level: _level,
      assignedMembers: 0,
      days: days,
      goal: _goal.text.trim(),
      tags: _tags.toList(),
      sessionDurationMin: sessionDuration,
      equipmentNeeded: _equipmentNeeded,
      imageUrl: _imageUrl.text.trim(),
    );
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repository = context.read<RoutineTemplateRepository>();
      if (_cover != null) {
        if (repository is! RoutineCoverRepository) {
          throw const RoutineCoverUploadFailed();
        }
        await (repository as RoutineCoverRepository)
            .saveWithCover(blueprint, _cover!);
      } else {
        await repository.save(blueprint);
      }
    } on RoutineCoverUploadFailed {
      if (mounted) {
        setState(() => _error =
            'Could not upload the cover. Your changes are kept. Try saving again.');
      }
      return;
    } on RoutineEditConflict {
      if (mounted) {
        setState(() {
          _reloadRequired = true;
          _error = 'This routine changed. Discard and reload before saving.';
        });
      }
      return;
    } on RoutineEditAuthorizationChanged {
      if (mounted) {
        setState(() {
          _reloadRequired = true;
          _error = 'Your authorization changed. Sign in again.';
        });
      }
      return;
    } on FormatException {
      if (mounted) {
        setState(() => _error =
            'Check the routine fields and active catalog exercises before saving.');
      }
      return;
    } catch (_) {
      if (mounted) {
        setState(() {
          _reloadRequired = true;
          _error =
              'Could not verify the save. Discard and reload before retrying.';
        });
      }
      return;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    if (!mounted) return;
    showToast(
        context,
        _usesCatalog
            ? 'Blueprint saved. Publish it to update the Member catalog.'
            : _isEdit
                ? 'Template updated.'
                : 'Template created.');
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageBreadcrumb(crumbs: [
              PageCrumb('Routine Templates', _discard),
              PageCrumb(_isEdit ? 'Edit routine' : 'Create routine'),
            ]),
            const SizedBox(height: 6),
            if (_usesCatalog && widget.existing?.schemaVersion == 1)
              CheckboxListTile(
                  value: _upgradeLegacy,
                  title: const Text('Create an upgraded routine successor'),
                  subtitle: const Text(
                      'Keeps the original published routine and existing workout history.'),
                  onChanged: _saving
                      ? null
                      : (value) => setState(() {
                            _upgradeLegacy = value ?? false;
                            if (_upgradeLegacy) {
                              for (final day in _days) {
                                for (final row in day.exercises) {
                                  final item = _catalog
                                      .where(
                                          (e) => e.id == row.selectedExerciseId)
                                      .firstOrNull;
                                  row.mode = item == null
                                      ? ExerciseExecutionMode.legacyManual
                                      : _catalogMode(item);
                                }
                              }
                            }
                          })),
            Text(_isEdit ? 'Edit routine template' : 'Create routine template',
                style: Theme.of(context).textTheme.headlineMedium),
            Wrap(spacing: 8, children: [
              for (var i = 0; i < 3; i++)
                ChoiceChip(
                    label: Text(const ['Details', 'Structure', 'Review'][i]),
                    selected: _stage == i,
                    onSelected: (_) => _selectStage(i))
            ]),
            if (_stage == 2)
              Panel(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    const Text('Review effective workout targets'),
                    for (var d = 0; d < _days.length; d++) ...[
                      Text('Day ${d + 1}'),
                      for (final row in _days[d].exercises)
                        Text(
                            '${_catalog.where((e) => e.id == row.selectedExerciseId).firstOrNull?.title ?? row.name.text}: '
                            '${row.sets.text} sets × ${row.reps.text}${row.mode == ExerciseExecutionMode.videoGuidedTimed ? ' seconds' : ' reps'} · ${row.rest.text}s rest'),
                    ],
                    const Text(
                        'Save draft first. Publication is a separate action.'),
                  ])),
            const SizedBox(height: 4),
            Text(
                _usesCatalog
                    ? 'Save an organization routine blueprint, then publish it to the member workout catalog.'
                    : 'Coaches and members can be assigned this blueprint once it is saved.',
                style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 22),
            LayoutBuilder(builder: (context, constraints) {
              final wide = constraints.maxWidth >= 900;
              final form = _form(context);
              final summary = _summaryCard(context);
              return wide
                  ? IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 3, child: form),
                          const SizedBox(width: 20),
                          Expanded(flex: 2, child: summary),
                        ],
                      ),
                    )
                  : Column(
                      children: [form, const SizedBox(height: 20), summary]);
            }),
          ],
        ),
      ),
    );
  }

  Widget _form(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!_isV2 || _stage == 0) ...[
          const Eyebrow('Template details'),
          Panel(
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _name,
                        decoration: const InputDecoration(
                            labelText: 'Template name', isDense: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _level,
                        isExpanded: true,
                        decoration: const InputDecoration(
                            labelText: 'Level', isDense: true),
                        items: _levels
                            .map((l) =>
                                DropdownMenuItem(value: l, child: Text(l)))
                            .toList(),
                        onChanged: (v) => setState(() => _level = v ?? _level),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                RoutineCoverField(
                    cover: _cover,
                    savedUrl: _imageUrl.text,
                    busy: _pickingCover || (_saving && _cover != null),
                    error: _coverError,
                    onChoose: _reloadRequired ||
                            context.read<RoutineTemplateRepository>()
                                is! RoutineCoverRepository
                        ? null
                        : _chooseCover,
                    onRemove: () {
                      if (_saving || _reloadRequired) return;
                      setState(() {
                        _cover = null;
                        _imageUrl.clear();
                        _coverError = null;
                      });
                    }),
                const SizedBox(height: 12),
                TextField(
                  controller: _goal,
                  maxLines: 2,
                  decoration: const InputDecoration(
                      labelText: 'Goal / description', isDense: true),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _duration,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Est. session duration (minutes)',
                      isDense: true),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Tags',
                      style: Theme.of(context).textTheme.bodyMedium),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _tagOptions.map((t) {
                    final selected = _tags.contains(t);
                    return FilterChip(
                      label: Text(t),
                      selected: selected,
                      onSelected: (v) =>
                          setState(() => v ? _tags.add(t) : _tags.remove(t)),
                      backgroundColor: AppColors.surface,
                      selectedColor: AppColors.primaryTint,
                      labelStyle: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: selected ? AppColors.primary : AppColors.ink),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                          side: const BorderSide(color: AppColors.hairline)),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                EditableStringList(
                  label: 'Equipment needed',
                  items: _equipmentNeeded,
                  onChanged: (v) => _equipmentNeeded = v,
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 18),
        if (!_isV2 || _stage == 1) ...[
          const Eyebrow('Day-by-day structure'),
          ...List.generate(
              _days.length, (dayIndex) => _dayEditor(context, dayIndex)),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: OutlinedButton.icon(
              onPressed: _addDay,
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Add day'),
            ),
          ),
        ],
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(_error!,
                style:
                    const TextStyle(fontSize: 12.5, color: AppColors.danger)),
          ),
        if (_usesCatalog &&
            _catalog.isEmpty &&
            !_catalogLoading &&
            !_reloadRequired)
          TextButton(
              onPressed: _loadCatalog, child: const Text('Reload exercises')),
        if (_reloadRequired)
          TextButton(
              onPressed: widget.onDone,
              child: const Text('Discard and reload')),
        const SizedBox(height: 8),
        Row(
          children: [
            if (_isV2 && _stage < 2) ...[
              FilledButton(
                  onPressed: _saving ? null : () => _selectStage(_stage + 1),
                  child: const Text('Continue')),
              const SizedBox(width: 10),
            ],
            OutlinedButton(
                onPressed: _saving ? null : _discard,
                child: const Text('Cancel')),
            const SizedBox(width: 10),
            FilledButton(
                onPressed: _saving ||
                        _catalogLoading ||
                        _reloadRequired ||
                        _pickingCover
                    ? null
                    : _save,
                child: Text(_saving
                    ? 'Saving…'
                    : _isEdit
                        ? 'Save changes'
                        : 'Create template')),
          ],
        ),
      ],
    );
  }

  Widget _dayEditor(BuildContext context, int dayIndex) {
    final day = _days[dayIndex];
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Day ${dayIndex + 1}',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary)),
              ),
              if (_days.length > 1)
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded,
                      size: 17, color: AppColors.danger),
                  onPressed: () => _removeDay(dayIndex),
                  constraints:
                      const BoxConstraints(minWidth: 30, minHeight: 30),
                  padding: EdgeInsets.zero,
                ),
            ],
          ),
          ...List.generate(day.exercises.length, (exIndex) {
            final ex = day.exercises[exIndex];
            return Padding(
              key: ObjectKey(ex),
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: _usesCatalog
                              ? DropdownButtonFormField<String>(
                                  initialValue: _catalog.any((item) =>
                                          item.id == ex.selectedExerciseId)
                                      ? ex.selectedExerciseId
                                      : null,
                                  isExpanded: true,
                                  decoration: InputDecoration(
                                    hintText: _catalogLoading
                                        ? 'Loading exercises…'
                                        : _catalog.isEmpty
                                            ? 'Add an active exercise first'
                                            : 'Select exercise',
                                    isDense: true,
                                  ),
                                  items: _catalog
                                      .map((item) => DropdownMenuItem(
                                          value: item.id,
                                          child: Row(children: [
                                            Expanded(
                                                child: Text(item.title,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis)),
                                            const SizedBox(width: 8),
                                            Text(
                                                item.trackingCapability
                                                    .displayLabel,
                                                style: const TextStyle(
                                                    fontSize: 11,
                                                    color: AppColors.inkSoft)),
                                          ])))
                                      .toList(),
                                  onChanged: _catalogLoading || _catalog.isEmpty
                                      ? null
                                      : (id) => setState(() {
                                            final item = _catalog
                                                .firstWhere((e) => e.id == id);
                                            if (_isV2) {
                                              _copyDefaults(ex, item);
                                            } else {
                                              ex.selectedExerciseId = id;
                                            }
                                          }),
                                )
                              : TextField(
                                  controller: ex.name,
                                  decoration: const InputDecoration(
                                      hintText: 'Exercise name', isDense: true),
                                ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: ex.sets,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                                hintText: 'Sets', isDense: true),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: ex.reps,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                                hintText: ex.mode ==
                                        ExerciseExecutionMode.videoGuidedTimed
                                    ? 'Duration (seconds)'
                                    : 'Reps',
                                isDense: true),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 16),
                          onPressed: day.exercises.length > 1
                              ? () => _removeExercise(dayIndex, exIndex)
                              : null,
                          constraints:
                              const BoxConstraints(minWidth: 30, minHeight: 30),
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                    Wrap(spacing: 8, children: [
                      if (_isV2) ...[
                        SizedBox(
                            width: 140,
                            child: TextField(
                                controller: ex.rest,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                    labelText: 'Rest (seconds)'))),
                        Text(ex.mode == ExerciseExecutionMode.videoGuidedTimed
                            ? 'Video guided · Timer tracked'
                            : ex.mode == ExerciseExecutionMode.aiTracked
                                ? 'AI tracking'
                                : 'Self-reported sets'),
                        TextButton(
                            onPressed: ex.selectedExerciseId == null
                                ? null
                                : () => setState(() => _copyDefaults(
                                    ex,
                                    _catalog.firstWhere(
                                        (e) => e.id == ex.selectedExerciseId))),
                            child: const Text('Reset to exercise defaults')),
                      ],
                      TextButton.icon(
                          onPressed: exIndex == 0 || _saving || _reloadRequired
                              ? null
                              : () =>
                                  _moveExercise(dayIndex, exIndex, exIndex - 1),
                          icon: const Icon(Icons.arrow_upward, size: 16),
                          label: const Text('Move up')),
                      TextButton.icon(
                          onPressed: exIndex == day.exercises.length - 1 ||
                                  _saving ||
                                  _reloadRequired
                              ? null
                              : () =>
                                  _moveExercise(dayIndex, exIndex, exIndex + 1),
                          icon: const Icon(Icons.arrow_downward, size: 16),
                          label: const Text('Move down')),
                    ]),
                  ]),
            );
          }),
          TextButton.icon(
            onPressed: () => _addExercise(dayIndex),
            icon: const Icon(Icons.add_rounded, size: 15),
            label: const Text('Add exercise'),
            style: TextButton.styleFrom(
                padding: EdgeInsets.zero, minimumSize: const Size(0, 30)),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(BuildContext context) {
    final totalExercises =
        _days.fold<int>(0, (sum, d) => sum + d.exercises.length);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Eyebrow('Summary'),
        Panel(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: _cover == null
                        ? _networkHero(_imageUrl.text)
                        : Image.memory(_cover!.copyBytes(),
                            fit: BoxFit.cover,
                            gaplessPlayback: true,
                            semanticLabel: 'Selected routine cover',
                            errorBuilder: (_, __, ___) => const Center(
                                child: Icon(Icons.broken_image_outlined)))),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: _summaryDetails(context, totalExercises),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
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
                  _usesCatalog
                      ? 'Saving changes this blueprint only. Publish again after routine or catalog edits, then refresh Home or Workout in the Member app. Publication does not assign a workout or record activity.'
                      : 'Coaches see this in their routine picker as soon as it is saved — members already following an assigned routine are unaffected until reassigned.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _summaryDetails(BuildContext context, int totalExercises) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_name.text.isEmpty ? 'Untitled template' : _name.text,
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        DetailRow('Level', _level),
        const Divider(height: 20),
        DetailRow('Days', '${_days.length}'),
        const Divider(height: 20),
        DetailRow('Exercises', '$totalExercises total'),
        const Divider(height: 20),
        DetailRow('Session length',
            '${_duration.text.isEmpty ? '0' : _duration.text} min'),
        if (_tags.isNotEmpty) ...[
          const Divider(height: 20),
          DetailRow('Tags', _tags.join(', ')),
        ],
      ],
    );
  }
}
