import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/workout.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../../../navigation/admin_breadcrumb.dart';

/// Defensive network image loader: displays gym equipment with BoxFit.contain
/// inside a neutral padded container, falling back to a GainPath equipment icon.
Widget _networkHero(String url, {BoxFit fit = BoxFit.contain}) {
  final fallback = Container(
    color: AppColors.bg,
    child: const Center(
      child: Icon(
        Icons.fitness_center_rounded,
        size: 36,
        color: AppColors.primary,
      ),
    ),
  );

  if (url.trim().isEmpty) {
    return fallback;
  }

  return Image.network(
    url,
    fit: fit,
    webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
    loadingBuilder: (context, child, progress) =>
        progress == null ? child : Container(color: AppColors.surfaceAlt),
    errorBuilder: (context, error, stack) => fallback,
  );
}

/// Admin management view over `gymEquipment` — the catalogue
/// the member-facing equipment scanner matches against and browses.
class EquipmentCatalogScreen extends StatefulWidget {
  const EquipmentCatalogScreen({super.key});

  @override
  State<EquipmentCatalogScreen> createState() => _EquipmentCatalogScreenState();
}

class _EquipmentCatalogScreenState extends State<EquipmentCatalogScreen> {
  // Filters & View State
  String _category = 'All';
  String _statusFilter = 'all'; // 'all', 'published', 'hidden'
  String _query = '';
  String _sortBy = 'name_asc'; // 'name_asc', 'name_desc', 'category'
  String _viewMode = 'grid'; // 'grid', 'list'

  // Data & Lifecycle
  List<GymEquipment> _equipment = [];
  bool _loading = true, _saving = false, _reloadRequired = false;
  String? _error, _cursor;
  int _generation = 0;

  // Editor State
  GymEquipment? _editing;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool more = false}) async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
      _reloadRequired = false;
      if (!more) {
        _equipment = [];
        _cursor = null;
      }
    });
    try {
      final page = await context
          .read<EquipmentRepository>()
          .loadEquipment(afterId: more ? _cursor : null);
      if (!mounted || generation != _generation) return;
      setState(() {
        _equipment = [..._equipment, ...page.items];
        _cursor = page.nextCursor;
        _loading = false;
        if (_category != 'All' &&
            !_equipment.any((e) => e.category == _category)) {
          _category = 'All';
        }
      });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _loading = false;
        _equipment = [];
        _error = 'Could not load equipment. Check authorization and retry.';
      });
    }
  }

  void _edit([GymEquipment? equipment]) {
    setState(() {
      _editing = equipment ??
          GymEquipment(
            id: '',
            name: '',
            category: '',
            muscleGroup: '',
            imageUrl: '',
            description: '',
            howToUse: [],
            safetyTips: [],
            isActive: !context.read<EquipmentRepository>().isLive,
          );
    });
  }

  Future<void> _activate(GymEquipment equipment, bool active) async {
    if (_saving || _reloadRequired) return;
    setState(() => _saving = true);
    try {
      await context
          .read<EquipmentRepository>()
          .saveEquipment(equipment.copyWith(isActive: active));
      if (mounted) await _load();
    } catch (_) {
      if (mounted) {
        setState(() {
          _reloadRequired = true;
          _error =
              'Change was not verified or the record changed. Refresh the catalog before retrying.';
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_editing != null) {
      return _EquipmentEditor(
        existing: _editing!.id.isEmpty ? null : _editing,
        onCancel: () => setState(() => _editing = null),
        onSaved: () {
          setState(() => _editing = null);
          _load();
        },
        onReload: _load,
      );
    }

    final equipment = _equipment;
    final categories = [
      'All',
      ...{for (final e in equipment) e.category}
    ];

    // Filter and Sort
    var visible = equipment.where((e) {
      final matchesCategory = _category == 'All' || e.category == _category;
      final matchesStatus = _statusFilter == 'all' ||
          (_statusFilter == 'published' ? e.isActive : !e.isActive);
      final queryLower = _query.trim().toLowerCase();
      final matchesQuery = queryLower.isEmpty ||
          e.name.toLowerCase().contains(queryLower) ||
          e.category.toLowerCase().contains(queryLower) ||
          e.muscleGroup.toLowerCase().contains(queryLower);
      return matchesCategory && matchesStatus && matchesQuery;
    }).toList();

    visible.sort((a, b) {
      if (_sortBy == 'name_desc') {
        return b.name.toLowerCase().compareTo(a.name.toLowerCase());
      } else if (_sortBy == 'category') {
        final catComp = a.category.toLowerCase().compareTo(b.category.toLowerCase());
        return catComp != 0
            ? catComp
            : a.name.toLowerCase().compareTo(b.name.toLowerCase());
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    final activeCount = equipment.where((e) => e.isActive).length;
    final isMobile = MediaQuery.sizeOf(context).width < 600;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          isMobile ? 16 : 28,
          28,
          isMobile ? 16 : 28,
          40,
        ),
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
                    children: const [
                      Text(
                        'Equipment Catalog',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                          letterSpacing: -0.3,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Manage gym equipment, tutorials and member visibility.',
                        style: TextStyle(
                          fontSize: 13.5,
                          color: AppColors.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                FilledButton.icon(
                  onPressed: _loading || _saving || _error != null
                      ? null
                      : () => _edit(),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add equipment'),
                ),
              ],
            ),
            const SizedBox(height: 22),

            // Toolbar & Filter Controls
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.hairline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final summaryText = Text(
                        '$activeCount active, ${equipment.length} loaded for Member browsing',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.inkSoft,
                        ),
                      );

                      final searchField = SizedBox(
                        width: constraints.maxWidth < 600 ? double.infinity : 260,
                        child: TextField(
                          onChanged: (v) => setState(() => _query = v),
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: 'Search equipment...',
                            hintStyle: const TextStyle(
                              fontSize: 13,
                              color: AppColors.inkSoft,
                            ),
                            prefixIcon: const Icon(
                              Icons.search_rounded,
                              size: 18,
                              color: AppColors.inkSoft,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
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
                          ),
                        ),
                      );

                      final statusDropdown = Container(
                        height: 38,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.hairline),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _statusFilter,
                            icon: const Icon(Icons.arrow_drop_down,
                                color: AppColors.inkSoft),
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.ink,
                                ),
                            items: const [
                              DropdownMenuItem(
                                  value: 'all', child: Text('All status')),
                              DropdownMenuItem(
                                  value: 'published',
                                  child: Text('Published status')),
                              DropdownMenuItem(
                                  value: 'hidden',
                                  child: Text('Hidden status')),
                            ],
                            onChanged: (v) =>
                                setState(() => _statusFilter = v ?? 'all'),
                          ),
                        ),
                      );

                      final sortDropdown = Container(
                        height: 38,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.hairline),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _sortBy,
                            icon: const Icon(Icons.arrow_drop_down,
                                color: AppColors.inkSoft),
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.ink,
                                ),
                            items: const [
                              DropdownMenuItem(
                                  value: 'name_asc', child: Text('Name (A–Z)')),
                              DropdownMenuItem(
                                  value: 'name_desc', child: Text('Name (Z–A)')),
                              DropdownMenuItem(
                                  value: 'category', child: Text('Category')),
                            ],
                            onChanged: (v) =>
                                setState(() => _sortBy = v ?? 'name_asc'),
                          ),
                        ),
                      );

                      final viewToggle = Container(
                        decoration: BoxDecoration(
                          color: AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.hairline),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Grid view',
                              icon: Icon(
                                Icons.grid_view_rounded,
                                size: 18,
                                color: _viewMode == 'grid'
                                    ? AppColors.primary
                                    : AppColors.inkSoft,
                              ),
                              padding: const EdgeInsets.all(6),
                              constraints: const BoxConstraints(),
                              onPressed: () =>
                                  setState(() => _viewMode = 'grid'),
                            ),
                            IconButton(
                              tooltip: 'List view',
                              icon: Icon(
                                Icons.view_list_rounded,
                                size: 20,
                                color: _viewMode == 'list'
                                    ? AppColors.primary
                                    : AppColors.inkSoft,
                              ),
                              padding: const EdgeInsets.all(6),
                              constraints: const BoxConstraints(),
                              onPressed: () =>
                                  setState(() => _viewMode = 'list'),
                            ),
                          ],
                        ),
                      );

                      final refreshBtn = IconButton(
                        tooltip: 'Refresh equipment',
                        onPressed:
                            _loading || _saving ? null : () => _load(),
                        icon: const Icon(Icons.refresh_rounded, size: 20),
                        color: AppColors.ink,
                      );

                      if (constraints.maxWidth < 900) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(child: summaryText),
                                refreshBtn,
                              ],
                            ),
                            const SizedBox(height: 12),
                            searchField,
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                statusDropdown,
                                sortDropdown,
                                viewToggle,
                              ],
                            ),
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Expanded(child: summaryText),
                          searchField,
                          const SizedBox(width: 10),
                          statusDropdown,
                          const SizedBox(width: 10),
                          sortDropdown,
                          const SizedBox(width: 10),
                          viewToggle,
                          const SizedBox(width: 8),
                          refreshBtn,
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  const Divider(height: 1, color: AppColors.hairline),
                  const SizedBox(height: 14),

                  // Category Chips Row
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: categories.map((c) {
                      final selected = c == _category;
                      return ChoiceChip(
                        label: Text(c),
                        selected: selected,
                        onSelected: (_) => setState(() => _category = c),
                        backgroundColor: AppColors.surface,
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(
                          fontSize: 12.5,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                          color: selected ? Colors.white : AppColors.ink,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                            color: selected
                                ? AppColors.primary
                                : AppColors.hairline,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // States: Loading, Error, Empty, Content
            if (_loading) const LinearProgressIndicator(color: AppColors.primary),
            if (_error != null)
              Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_error!, style: const TextStyle(color: AppColors.danger)),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _loading || _saving ? null : () => _load(),
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Reload equipment'),
                    ),
                  ],
                ),
              ),

            if (!_loading && _error == null && visible.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.hairline),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(
                        color: AppColors.surfaceAlt,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.fitness_center_outlined,
                          size: 28,
                          color: AppColors.inkSoft,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No equipment matches these filters.',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Try adjusting your search query, category, or publication status.',
                      style: TextStyle(fontSize: 12.5, color: AppColors.inkSoft),
                    ),
                  ],
                ),
              )
            else if (_viewMode == 'grid')
              _buildGridView(visible)
            else
              _buildListView(visible),

            if (_cursor != null) ...[
              const SizedBox(height: 16),
              Center(
                child: OutlinedButton(
                  onPressed:
                      _loading || _saving ? null : () => _load(more: true),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.ink,
                    side: const BorderSide(color: AppColors.hairline),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Load more equipment'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGridView(List<GymEquipment> items) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Enforce 280-350px cards without stretching
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 360,
            mainAxisExtent: 405,
            crossAxisSpacing: 18,
            mainAxisSpacing: 18,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final e = items[index];
            return _buildEquipmentCard(e);
          },
        );
      },
    );
  }

  Widget _buildEquipmentCard(GymEquipment e) {
    final hasTutorial = e.tutorialVideoUrl.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.hairline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 16:9 Image Container with contain fit and badges
          Stack(
            children: [
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(11)),
                child: Container(
                  height: 180,
                  width: double.infinity,
                  color: AppColors.bg,
                  padding: const EdgeInsets.all(12),
                  child: _networkHero(e.imageUrl, fit: BoxFit.contain),
                ),
              ),
              // Category tag
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Text(
                    e.category,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                ),
              ),
              // Status Badge
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: e.isActive
                        ? AppColors.success.withValues(alpha: 0.12)
                        : AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: e.isActive
                          ? AppColors.success.withValues(alpha: 0.25)
                          : AppColors.hairline,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: e.isActive
                              ? AppColors.success
                              : AppColors.inkSoft,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        e.isActive ? 'Published' : 'Hidden',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: e.isActive
                              ? AppColors.success
                              : AppColors.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Card Body
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.accessibility_new_rounded,
                      size: 14,
                      color: AppColors.inkSoft,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        e.muscleGroup,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.inkSoft,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  e.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.inkSoft,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 10),
                if (hasTutorial)
                  Row(
                    children: const [
                      Icon(
                        Icons.play_circle_outline_rounded,
                        size: 14,
                        color: AppColors.primary,
                      ),
                      SizedBox(width: 5),
                      Text(
                        'Tutorial attached',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  )
                else
                  const SizedBox(height: 16),
              ],
            ),
          ),
          const Spacer(),
          const Divider(height: 1, color: AppColors.hairline),

          // Card Footer
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Switch with semantic label
                Semantics(
                  label: e.isActive
                      ? 'Published equipment'
                      : 'Hidden equipment',
                  child: Tooltip(
                    message: e.isActive
                        ? 'Published for member browsing'
                        : 'Hidden from members',
                    child: Switch(
                      value: e.isActive,
                      activeTrackColor: AppColors.primary,
                      onChanged: _saving || _reloadRequired
                          ? null
                          : (v) => _activate(e, v),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Edit equipment',
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  color: AppColors.ink,
                  onPressed: _saving || _reloadRequired ? null : () => _edit(e),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListView(List<GymEquipment> items) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: const BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: const Row(
              children: [
                Expanded(
                  flex: 4,
                  child: Text(
                    'EQUIPMENT',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: AppColors.inkSoft,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'CATEGORY',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: AppColors.inkSoft,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'MUSCLE GROUP',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: AppColors.inkSoft,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'TUTORIAL',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: AppColors.inkSoft,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'STATUS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: AppColors.inkSoft,
                    ),
                  ),
                ),
                SizedBox(
                  width: 50,
                  child: Center(
                    child: Text(
                      'ACTIONS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: AppColors.inkSoft,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Table Rows
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: AppColors.hairline),
            _buildListRow(items[i]),
          ],
        ],
      ),
    );
  }

  Widget _buildListRow(GymEquipment e) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          // Image + Name
          Expanded(
            flex: 4,
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 48,
                    height: 48,
                    color: AppColors.bg,
                    padding: const EdgeInsets.all(4),
                    child: _networkHero(e.imageUrl, fit: BoxFit.contain),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    e.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Category
          Expanded(
            flex: 2,
            child: Text(
              e.category,
              style: const TextStyle(fontSize: 13, color: AppColors.ink),
            ),
          ),

          // Muscle Group
          Expanded(
            flex: 2,
            child: Text(
              e.muscleGroup,
              style: const TextStyle(fontSize: 13, color: AppColors.inkSoft),
            ),
          ),

          // Tutorial
          Expanded(
            flex: 2,
            child: e.tutorialVideoUrl.isNotEmpty
                ? Row(
                    children: const [
                      Icon(Icons.check_circle_outline_rounded,
                          size: 15, color: AppColors.success),
                      SizedBox(width: 4),
                      Text('Video',
                          style: TextStyle(
                              fontSize: 12.5, color: AppColors.ink)),
                    ],
                  )
                : const Text('—',
                    style: TextStyle(color: AppColors.inkSoft)),
          ),

          // Status & Switch
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Switch(
                  value: e.isActive,
                  activeTrackColor: AppColors.primary,
                  onChanged: _saving || _reloadRequired
                      ? null
                      : (v) => _activate(e, v),
                ),
                const SizedBox(width: 4),
                Text(
                  e.isActive ? 'Published' : 'Hidden',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: e.isActive
                        ? AppColors.success
                        : AppColors.inkSoft,
                  ),
                ),
              ],
            ),
          ),

          // Actions
          SizedBox(
            width: 50,
            child: Center(
              child: IconButton(
                tooltip: 'Edit equipment',
                icon: const Icon(Icons.edit_outlined, size: 18),
                color: AppColors.ink,
                onPressed:
                    _saving || _reloadRequired ? null : () => _edit(e),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-page Equipment Content Editor embedded directly in the Admin shell.
class _EquipmentEditor extends StatefulWidget {
  final GymEquipment? existing;
  final VoidCallback onCancel;
  final VoidCallback onSaved;
  final Future<void> Function() onReload;

  const _EquipmentEditor({
    this.existing,
    required this.onCancel,
    required this.onSaved,
    required this.onReload,
  });

  @override
  State<_EquipmentEditor> createState() => _EquipmentEditorState();
}

class _EquipmentEditorState extends State<_EquipmentEditor> {
  bool _saving = false, _reloadRequired = false;
  bool _picking = false;
  EquipmentImage? _selectedImage;
  String? _imageError;
  EquipmentVideo? _selectedVideo;
  bool _pickingVideo = false, _removeVideo = false;
  double? _videoProgress;
  String? _videoError;
  String? _error;

  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _category =
      TextEditingController(text: widget.existing?.category ?? '');
  late final _muscleGroup =
      TextEditingController(text: widget.existing?.muscleGroup ?? '');
  late final _imageUrl =
      TextEditingController(text: widget.existing?.imageUrl ?? '');
  late final _description =
      TextEditingController(text: widget.existing?.description ?? '');
  late List<String> _howToUse = [...(widget.existing?.howToUse ?? const [])];
  late List<String> _safetyTips = [
    ...(widget.existing?.safetyTips ?? const [])
  ];

  bool get _isEdit => widget.existing != null;
  bool get _busy => _saving || _picking || _pickingVideo;

  @override
  void dispose() {
    _name.dispose();
    _category.dispose();
    _muscleGroup.dispose();
    _imageUrl.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _chooseImage() async {
    if (_busy || _reloadRequired) return;
    setState(() {
      _picking = true;
      _imageError = null;
    });
    try {
      final image = await context.read<EquipmentImagePicker>().pick();
      if (mounted && image != null) setState(() => _selectedImage = image);
    } on FormatException catch (e) {
      if (mounted) setState(() => _imageError = e.message);
    } catch (_) {
      if (mounted) {
        setState(
            () => _imageError = 'Could not select an image. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _chooseVideo() async {
    if (_busy || _reloadRequired) return;
    setState(() {
      _pickingVideo = true;
      _videoError = null;
    });
    try {
      final video = await context.read<EquipmentVideoPicker>().pick();
      if (mounted && video != null) {
        setState(() {
          _selectedVideo = video;
          _removeVideo = false;
        });
      }
    } on FormatException catch (e) {
      if (mounted) setState(() => _videoError = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _videoError = 'Could not select a video. Try again.');
      }
    } finally {
      if (mounted) setState(() => _pickingVideo = false);
    }
  }

  Future<void> _save() async {
    if (_busy || _reloadRequired) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final repository = context.read<EquipmentRepository>();
    final entry = widget.existing?.copyWith() ??
        GymEquipment(
            id: '',
            name: '',
            category: '',
            muscleGroup: '',
            imageUrl: '',
            description: '',
            howToUse: [],
            safetyTips: [],
            isActive: !repository.isLive);
    entry
      ..name = _name.text.trim()
      ..category = _category.text.trim()
      ..muscleGroup = _muscleGroup.text.trim()
      ..tutorialVideoUrl =
          _removeVideo ? '' : (widget.existing?.tutorialVideoUrl ?? '')
      ..imageUrl = _imageUrl.text.trim()
      ..description = _description.text.trim()
      ..howToUse = List.of(_howToUse)
      ..safetyTips = List.of(_safetyTips);
    try {
      entry.validate();
    } on FormatException catch (e) {
      setState(() => _error = e.message);
      return;
    }
    setState(() => _saving = true);
    try {
      await repository.saveEquipment(
        entry,
        image: _selectedImage,
        video: _selectedVideo,
        onVideoProgress: (value) {
          if (mounted) setState(() => _videoProgress = value);
        },
      );
      if (mounted) widget.onSaved();
    } on EquipmentVideoUploadFailed {
      if (mounted) {
        setState(() => _error =
            'Video upload failed. Equipment was not saved. Check your connection and retry.');
      }
    } on EquipmentImageUploadFailed {
      if (mounted) {
        setState(() => _error =
            'Image upload failed. Equipment was not saved. Check your connection and authorization, then retry.');
      }
    } on EquipmentConflict {
      if (mounted) {
        setState(() {
          _reloadRequired = true;
          _error =
              'Equipment changed or was removed. Discard and reload before saving.';
        });
      }
    } on EquipmentSessionChanged {
      if (mounted) {
        setState(() {
          _reloadRequired = true;
          _error =
              'Account or authorization changed. Sign in again before editing.';
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

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 600;

    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            isMobile ? 16 : 28,
            24,
            isMobile ? 16 : 28,
            40,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Breadcrumbs
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: PageBreadcrumb(
                    crumbs: [
                      PageCrumb('Equipment Catalog', () {
                        if (!_busy) widget.onCancel();
                      }),
                      PageCrumb(_isEdit ? 'Edit equipment' : 'Add equipment'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Editor Header
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isEdit ? 'Edit equipment' : 'Add equipment',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            context.read<EquipmentRepository>().isLive
                                ? 'Organization equipment information. New items start hidden; activation enables Member browsing. Optional tutorials appear on Equipment Details.'
                                : 'Author equipment catalog details, usage guidance, and safety precautions.',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.inkSoft,
                            ),
                          ),
                          if (_isEdit) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceAlt,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'ID: ${widget.existing!.id}  ·  Revision ${widget.existing!.revision}',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.inkSoft,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Error and Reload Banners
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: AppColors.danger.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded,
                              color: AppColors.danger, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.danger,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          if (_reloadRequired)
                            TextButton(
                              onPressed: () {
                                widget.onCancel();
                                widget.onReload();
                              },
                              child: const Text('Discard and reload'),
                            ),
                        ],
                      ),
                    ),
                  ),

                // Two-Column Layout (approx 65% / 35%)
                LayoutBuilder(
                  builder: (context, constraints) {
                    final leftColumn = _buildLeftColumn(context);
                    final rightColumn = _buildRightColumn(context);

                    if (constraints.maxWidth >= 900) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 13, child: leftColumn),
                          const SizedBox(width: 24),
                          Expanded(flex: 7, child: rightColumn),
                        ],
                      );
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        leftColumn,
                        const SizedBox(height: 24),
                        rightColumn,
                      ],
                    );
                  },
                ),
                const SizedBox(height: 32),

                // Sticky Footer Action Bar
                _buildStickyFooter(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLeftColumn(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Basic Information Card
        _cardContainer(
          title: 'Basic information',
          subtitle: 'Identify the machine and specify its primary muscle group.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // In tests, find.byType(TextFormField) expects:
              // at(0): Name
              // at(1): Category
              // at(2): Muscle group
              // at(3): Description
              TextFormField(
                controller: _name,
                enabled: !_busy && !_reloadRequired,
                decoration: InputDecoration(
                  labelText: 'Name',
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _category,
                      enabled: !_busy && !_reloadRequired,
                      decoration: InputDecoration(
                        labelText: 'Category',
                        isDense: true,
                        hintText: 'e.g. Strength, Cardio',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: TextFormField(
                      controller: _muscleGroup,
                      enabled: !_busy && !_reloadRequired,
                      decoration: InputDecoration(
                        labelText: 'Muscle group',
                        isDense: true,
                        hintText: 'e.g. Legs, Chest, Back',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _description,
                enabled: !_busy && !_reloadRequired,
                minLines: 3,
                maxLines: 6,
                decoration: InputDecoration(
                  labelText: 'Description',
                  isDense: true,
                  alignLabelWithHint: true,
                  hintText:
                      'Describe the equipment, its setup, and target workout benefits...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              if (!context.read<EquipmentRepository>().isLive) ...[
                const SizedBox(height: 14),
                TextFormField(
                  controller: _imageUrl,
                  enabled: !_busy && !_reloadRequired,
                  decoration: InputDecoration(
                    labelText: 'Image URL',
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  validator: (v) => null,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),

        // 2. How to Use Card
        _cardContainer(
          title: 'How to use',
          subtitle:
              'Step-by-step instructions for members adjusting and operating the machine.',
          child: IgnorePointer(
            ignoring: _busy || _reloadRequired,
            child: EditableStringList(
              label: 'How to use',
              items: _howToUse,
              onChanged: (v) => _howToUse = v,
            ),
          ),
        ),
        const SizedBox(height: 20),

        // 3. Safety Tips Card
        _cardContainer(
          title: 'Safety precautions',
          subtitle:
              'Guidance on machine lockouts, weight limits, and injury prevention.',
          child: IgnorePointer(
            ignoring: _busy || _reloadRequired,
            child: EditableStringList(
              label: 'Safety tips',
              items: _safetyTips,
              onChanged: (v) => _safetyTips = v,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRightColumn(BuildContext context) {
    final isLive = context.read<EquipmentRepository>().isLive;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Equipment Image Card
        if (isLive) ...[
          _cardContainer(
            title: 'Equipment image',
            subtitle: 'Upload a clear photo of the gym equipment.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    height: 160,
                    width: double.infinity,
                    color: AppColors.bg,
                    padding: const EdgeInsets.all(8),
                    child: _selectedImage != null
                        ? (kIsWeb
                            ? Image.network(
                                'data:${_selectedImage!.contentType};base64,${base64Encode(_selectedImage!.bytes)}',
                                key: const ValueKey(
                                    'equipment-selected-image-preview'),
                                webHtmlElementStrategy:
                                    WebHtmlElementStrategy.prefer,
                                fit: BoxFit.contain,
                              )
                            : Image.memory(
                                _selectedImage!.bytes,
                                key: const ValueKey(
                                    'equipment-selected-image-preview'),
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => const Icon(
                                    Icons.broken_image_outlined),
                              ))
                        : _imageUrl.text.isNotEmpty
                            ? _networkHero(_imageUrl.text, fit: BoxFit.contain)
                            : const Center(
                                child: Icon(
                                  Icons.add_photo_alternate_outlined,
                                  size: 40,
                                  color: AppColors.inkSoft,
                                ),
                              ),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed:
                          _busy || _reloadRequired ? null : _chooseImage,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.ink,
                        side: const BorderSide(color: AppColors.hairline),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(Icons.upload_file_outlined, size: 16),
                      label: Text(_picking ? 'Opening…' : 'Choose image'),
                    ),
                    if (_selectedImage != null)
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => setState(() => _selectedImage = null),
                        child: const Text('Discard selected image'),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'JPG, PNG or WebP · up to 5 MB. Uploaded when you save.',
                  style: TextStyle(fontSize: 11.5, color: AppColors.inkSoft),
                ),
                if (_imageError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        _imageError!,
                        key: const ValueKey('equipment-image-error'),
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.danger,
                        ),
                      ),
                    ),
                  ),
                if (_selectedImage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        _isEdit
                            ? 'New image selected. Save changes to apply it.'
                            : 'Image selected. Save to upload it.',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.success,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],

        // 2. Tutorial Video Card (Optional)
        _cardContainer(
          title: 'Tutorial video (optional)',
          subtitle:
              'Attach a demonstration video that appears on the mobile equipment details page.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'MP4 · up to 100 MB. Use H.264 video with AAC audio for device compatibility. Uploaded when you save.',
                style: TextStyle(fontSize: 12, color: AppColors.inkSoft, height: 1.4),
              ),
              const SizedBox(height: 12),
              if (_selectedVideo != null)
                Semantics(
                  liveRegion: true,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryTint.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.videocam_rounded,
                            size: 18, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Selected: ${_selectedVideo!.name} (${(_selectedVideo!.bytes.length / 1048576).toStringAsFixed(1)} MB). Save to apply.',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else if (_removeVideo)
                const Text(
                  'Tutorial will be removed when you save.',
                  style: TextStyle(fontSize: 12, color: AppColors.danger),
                )
              else if (widget.existing?.tutorialVideoUrl.isNotEmpty == true)
                Row(
                  children: const [
                    Icon(Icons.check_circle_rounded,
                        size: 16, color: AppColors.success),
                    SizedBox(width: 6),
                    Text(
                      'A tutorial video is attached.',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _busy || _reloadRequired ? null : _chooseVideo,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.ink,
                      side: const BorderSide(color: AppColors.hairline),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.video_library_outlined, size: 16),
                    label: Text(_pickingVideo
                        ? 'Opening video…'
                        : 'Choose tutorial video'),
                  ),
                  if (_selectedVideo != null ||
                      (!_removeVideo &&
                          widget.existing?.tutorialVideoUrl.isNotEmpty == true))
                    TextButton(
                      onPressed: _busy || _reloadRequired
                          ? null
                          : () => setState(() {
                                _selectedVideo = null;
                                _removeVideo = true;
                              }),
                      child: const Text('Remove tutorial'),
                    ),
                  if (_removeVideo &&
                      widget.existing?.tutorialVideoUrl.isNotEmpty == true)
                    TextButton(
                      onPressed: _busy || _reloadRequired
                          ? null
                          : () => setState(() => _removeVideo = false),
                      child: const Text('Undo removal'),
                    ),
                ],
              ),
              if (_videoError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      _videoError!,
                      style: const TextStyle(fontSize: 12, color: AppColors.danger),
                    ),
                  ),
                ),
              if (_saving && _selectedVideo != null) ...[
                const SizedBox(height: 12),
                LinearProgressIndicator(value: _videoProgress),
                const SizedBox(height: 4),
                Text(
                  _videoProgress == null
                      ? 'Preparing video upload…'
                      : 'Uploading tutorial: ${(_videoProgress! * 100).round()}%',
                  style: const TextStyle(fontSize: 11.5, color: AppColors.inkSoft),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),

        // 3. Member Visibility Card
        _cardContainer(
          title: 'Member visibility',
          subtitle: 'Control whether members can browse or scan this equipment.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: (widget.existing?.isActive ?? false)
                          ? AppColors.success.withValues(alpha: 0.12)
                          : AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      (widget.existing?.isActive ?? false)
                          ? 'Published'
                          : 'Hidden',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: (widget.existing?.isActive ?? false)
                            ? AppColors.success
                            : AppColors.inkSoft,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                _isEdit
                    ? (widget.existing!.isActive
                        ? 'This machine is active on the gym floor and visible to members in the Equipment Catalog and camera recognition matcher.'
                        : 'This machine is hidden from members. It will not appear in the mobile catalog or camera recognition pool.')
                    : 'New equipment starts hidden by default. Once saved, you can activate it from the Equipment Catalog to make it available for member scanning.',
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.inkSoft,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStickyFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton(
            onPressed: _busy ? null : widget.onCancel,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.ink,
              side: const BorderSide(color: AppColors.hairline),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: const Text('Cancel'),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: _busy || _reloadRequired ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              _saving
                  ? (_selectedImage == null ? 'Saving…' : 'Uploading and saving…')
                  : _isEdit
                      ? 'Save changes'
                      : 'Add equipment',
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardContainer({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.inkSoft,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

/// A repeatable list of short text lines (used for equipment "how to
/// use"/"safety tips" steps, and reusable anywhere else a form needs a
/// growable list of strings) with inline add/remove — exported for routine templates.
class EditableStringList extends StatefulWidget {
  final String label;
  final List<String> items;
  final ValueChanged<List<String>> onChanged;
  const EditableStringList({
    super.key,
    required this.label,
    required this.items,
    required this.onChanged,
  });

  @override
  State<EditableStringList> createState() => _EditableStringListState();
}

class _EditableStringListState extends State<EditableStringList> {
  late final List<TextEditingController> _controllers =
      widget.items.map((s) => TextEditingController(text: s)).toList();

  void _notify() => widget.onChanged(_controllers.map((c) => c.text).toList());

  void _add() {
    setState(() => _controllers.add(TextEditingController()));
    _notify();
  }

  void _remove(int i) {
    setState(() {
      _controllers[i].dispose();
      _controllers.removeAt(i);
    });
    _notify();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.label,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: _controllers.length >= 10 ? null : _add,
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Add line'),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 32),
                foregroundColor: AppColors.primary,
              ),
            ),
          ],
        ),
        if (_controllers.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No items added yet. Click "Add line" to create step 1.',
              style: TextStyle(
                fontSize: 12.5,
                color: AppColors.inkSoft.withValues(alpha: 0.8),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ...List.generate(_controllers.length, (i) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: AppColors.primaryTint,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _controllers[i],
                    onChanged: (_) => _notify(),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'Step ${i + 1}',
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.hairline),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.hairline),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: 'Remove',
                  icon: const Icon(Icons.close_rounded, size: 16),
                  onPressed: () => _remove(i),
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                  padding: EdgeInsets.zero,
                  color: AppColors.inkSoft,
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
