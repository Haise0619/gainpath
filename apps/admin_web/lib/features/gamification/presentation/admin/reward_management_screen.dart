import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/gamification.dart';
import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_domain/workout.dart'
    show EquipmentImage, EquipmentImagePicker;
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../reward_fulfilment_repository.dart';
import 'reward_fulfilment_panel.dart';

String _requestId() =>
    'reward_${DateTime.now().microsecondsSinceEpoch}_${List.generate(16, (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0')).join()}';

enum _EligibilityFilter {
  all('All Rewards'),
  regular('Regular Rewards'),
  premium('Premium Exclusive');

  const _EligibilityFilter(this.label);
  final String label;

  bool includes(PublishedReward item) => switch (this) {
        all => true,
        regular => !item.premiumOnly,
        premium => item.premiumOnly,
      };
}

const _regularEligibility = 'Basic & Premium';
const _premiumEligibility = 'Premium Exclusive';

class RewardManagementScreen extends StatefulWidget {
  const RewardManagementScreen({
    super.key,
    required this.repository,
    this.fulfilmentRepository,
    this.onVerify,
    this.sessionChanges,
    this.initialTab = 'shop',
  });

  final RewardManagementRepository repository;
  final RewardFulfilmentRepository? fulfilmentRepository;
  final VoidCallback? onVerify;
  final Stream<Object?>? sessionChanges;
  final String initialTab;

  @override
  State<RewardManagementScreen> createState() => _RewardManagementScreenState();
}

class _RewardManagementScreenState extends State<RewardManagementScreen> {
  RewardShopAdministration? _shop;
  PublishedReward? _editing;
  String? _newId, _error;
  bool _busy = false, _loading = false;
  late String _activeTab =
      widget.initialTab == 'vouchers' ? 'vouchers' : 'shop';

  // Search & Filter state
  final _searchController = TextEditingController();
  String _searchQuery = '';
  _EligibilityFilter _eligibility = _EligibilityFilter.all;
  String _categoryFilter = 'All';
  String _visibilityFilter = 'all'; // 'all', 'active', 'removed'
  String _stockFilter = 'all'; // 'all', 'in_stock', 'low_stock', 'out_of_stock'
  String _sortBy =
      'name_asc'; // 'name_asc', 'name_desc', 'points_asc', 'points_desc', 'stock_desc'
  String _viewMode = 'grid'; // 'grid', 'list'

  int _generation = 0;
  final _retireIds = <String, String>{};

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
    final generation = ++_generation;
    final repository = widget.repository;
    if (!repository.current) return;
    setState(() {
      _loading = true;
      _shop = null;
      _error = null;
    });
    try {
      final shop = await repository.shopOverview();
      if (!mounted ||
          generation != _generation ||
          !identical(repository, widget.repository) ||
          !repository.current) {
        return;
      }
      setState(() => _shop = shop);
    } catch (_) {
      if (mounted && generation == _generation && repository.current) {
        setState(() =>
            _error = 'Could not load rewards. Check Admin access and retry.');
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  void didUpdateWidget(RewardManagementScreen old) {
    super.didUpdateWidget(old);
    if (old.repository != widget.repository || !widget.repository.current) {
      _generation++;
      _shop = null;
      _editing = null;
      _newId = null;
      _eligibility = _EligibilityFilter.all;
      _categoryFilter = 'All';
      _visibilityFilter = 'all';
      _stockFilter = 'all';
      _sortBy = 'name_asc';
      _busy = false;
      _error = null;
      _retireIds.clear();
      _loading = false;
      if (widget.repository.current) _load();
    }
  }

  void _open([PublishedReward? item]) {
    if (!widget.repository.current) return;
    try {
      final id = item == null ? widget.repository.newItemId() : null;
      setState(() {
        _editing = item;
        _newId = id;
        _error = null;
      });
    } catch (_) {
      setState(() =>
          _error = 'Check Admin access and refresh before editing rewards.');
    }
  }

  void _close() {
    setState(() {
      _editing = null;
      _newId = null;
    });
    _load();
  }

  Future<void> _remove(PublishedReward item) async {
    if (_busy || !widget.repository.current) return;
    final generation = _generation;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.retireReward(
          itemId: item.itemId,
          requestId: _retireIds.putIfAbsent(
              '${item.itemId}:${item.revision}', _requestId),
          baseItemRevision: item.revision);
      if (mounted && generation == _generation && widget.repository.current) {
        setState(() => _busy = false);
        await _load();
      }
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(
            () => _error = 'Removal not confirmed. Retry or refresh the shop.');
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  List<PublishedReward> _getFilteredAndSortedRewards(
      List<PublishedReward> items) {
    var filtered = items.where((item) {
      // 1. Eligibility Filter
      if (!_eligibility.includes(item)) return false;

      // 2. Category Filter
      if (_categoryFilter != 'All' && item.category != _categoryFilter) {
        return false;
      }

      // 3. Visibility Filter
      if (_visibilityFilter == 'active' && !item.active) return false;
      if (_visibilityFilter == 'removed' && item.active) return false;

      // 4. Stock Filter
      if (_stockFilter == 'in_stock' && item.stock <= 10) return false;
      if (_stockFilter == 'low_stock' && (item.stock == 0 || item.stock > 10)) {
        return false;
      }
      if (_stockFilter == 'out_of_stock' && item.stock > 0) return false;

      // 5. Search Query
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final match = item.title.toLowerCase().contains(q) ||
            item.category.toLowerCase().contains(q) ||
            item.description.toLowerCase().contains(q) ||
            item.conditions.toLowerCase().contains(q);
        if (!match) return false;
      }

      return true;
    }).toList();

    // Sorting
    filtered.sort((a, b) {
      switch (_sortBy) {
        case 'name_desc':
          return b.title.toLowerCase().compareTo(a.title.toLowerCase());
        case 'points_asc':
          return a.pointCost.compareTo(b.pointCost);
        case 'points_desc':
          return b.pointCost.compareTo(a.pointCost);
        case 'stock_desc':
          return b.stock.compareTo(a.stock);
        case 'name_asc':
        default:
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      }
    });

    return filtered;
  }

  Widget _buildTabs() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.hairline)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTabItem(
              id: 'shop',
              label: 'Reward shop',
              icon: Icons.storefront_outlined,
            ),
            _buildTabItem(
              id: 'vouchers',
              label: 'Voucher collection',
              icon: Icons.qr_code_scanner,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabItem({
    required String id,
    required String label,
    required IconData icon,
  }) {
    final active = _activeTab == id;
    return InkWell(
      onTap: () => setState(() => _activeTab = id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: active ? AppColors.primary : Colors.transparent,
              width: 2.5,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: active ? AppColors.primary : AppColors.inkSoft,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active ? AppColors.primary : AppColors.inkSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbar(BuildContext context, List<PublishedReward> allItems) {
    final activeCount = allItems.where((e) => e.active).length;
    final categories = [
      'All',
      ...{for (final item in allItems) item.category}
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.hairline),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final summaryText = Text(
            '$activeCount in shop · ${allItems.length} rewards',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.inkSoft,
            ),
          );

          final searchField = SizedBox(
            width: 240,
            height: 38,
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v.trim()),
              style: const TextStyle(fontSize: 13, color: AppColors.ink),
              decoration: InputDecoration(
                hintText: 'Search rewards...',
                hintStyle:
                    const TextStyle(fontSize: 13, color: AppColors.inkSoft),
                prefixIcon: const Icon(Icons.search,
                    size: 18, color: AppColors.inkSoft),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear,
                            size: 16, color: AppColors.inkSoft),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                filled: true,
                fillColor: AppColors.surfaceAlt,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
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
                isDense: true,
                icon:
                    const Icon(Icons.arrow_drop_down, color: AppColors.inkSoft),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
                      value: 'points_asc', child: Text('Points (Low–High)')),
                  DropdownMenuItem(
                      value: 'points_desc', child: Text('Points (High–Low)')),
                  DropdownMenuItem(
                      value: 'stock_desc', child: Text('Stock (High–Low)')),
                ],
                onChanged: (v) => setState(() => _sortBy = v ?? 'name_asc'),
              ),
            ),
          );

          final viewModeToggle = Container(
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.all(3),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () => setState(() => _viewMode = 'grid'),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _viewMode == 'grid'
                          ? Colors.white
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: _viewMode == 'grid'
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              )
                            ]
                          : null,
                    ),
                    child: Icon(
                      Icons.grid_view_rounded,
                      size: 16,
                      color: _viewMode == 'grid'
                          ? AppColors.primary
                          : AppColors.inkSoft,
                    ),
                  ),
                ),
                InkWell(
                  onTap: () => setState(() => _viewMode = 'list'),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _viewMode == 'list'
                          ? Colors.white
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: _viewMode == 'list'
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              )
                            ]
                          : null,
                    ),
                    child: Icon(
                      Icons.view_list_rounded,
                      size: 16,
                      color: _viewMode == 'list'
                          ? AppColors.primary
                          : AppColors.inkSoft,
                    ),
                  ),
                ),
              ],
            ),
          );

          final refreshBtn = IconButton(
            tooltip: 'Refresh rewards',
            onPressed: _busy || _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded, size: 20),
            color: AppColors.ink,
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    summaryText,
                    const SizedBox(width: 24),
                    searchField,
                    const SizedBox(width: 10),
                    sortDropdown,
                    const SizedBox(width: 10),
                    viewModeToggle,
                    const SizedBox(width: 8),
                    refreshBtn,
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, color: AppColors.hairline),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 220),
                      child: DropdownButtonFormField<_EligibilityFilter>(
                        key: const ValueKey('reward-eligibility-filter'),
                        initialValue: _eligibility,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Member eligibility',
                          isDense: true,
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: _EligibilityFilter.values
                            .map((filter) => DropdownMenuItem(
                                value: filter, child: Text(filter.label)))
                            .toList(),
                        onChanged: _busy
                            ? null
                            : (filter) {
                                if (filter != null) {
                                  setState(() => _eligibility = filter);
                                }
                              },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      height: 38,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.hairline),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _categoryFilter,
                          isDense: true,
                          icon: const Icon(Icons.arrow_drop_down,
                              color: AppColors.inkSoft),
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.ink,
                                  ),
                          items: categories
                              .map((c) => DropdownMenuItem(
                                  value: c,
                                  child:
                                      Text(c == 'All' ? 'All categories' : c)))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _categoryFilter = v ?? 'All'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      height: 38,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.hairline),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _visibilityFilter,
                          isDense: true,
                          icon: const Icon(Icons.arrow_drop_down,
                              color: AppColors.inkSoft),
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.ink,
                                  ),
                          items: const [
                            DropdownMenuItem(
                                value: 'all', child: Text('All visibility')),
                            DropdownMenuItem(
                                value: 'active', child: Text('In shop')),
                            DropdownMenuItem(
                                value: 'removed', child: Text('Removed')),
                          ],
                          onChanged: (v) =>
                              setState(() => _visibilityFilter = v ?? 'all'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      height: 38,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.hairline),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _stockFilter,
                          isDense: true,
                          icon: const Icon(Icons.arrow_drop_down,
                              color: AppColors.inkSoft),
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.ink,
                                  ),
                          items: const [
                            DropdownMenuItem(
                                value: 'all', child: Text('All stock')),
                            DropdownMenuItem(
                                value: 'in_stock',
                                child: Text('In stock (>10)')),
                            DropdownMenuItem(
                                value: 'low_stock',
                                child: Text('Low stock (≤10)')),
                            DropdownMenuItem(
                                value: 'out_of_stock',
                                child: Text('Out of stock')),
                          ],
                          onChanged: (v) =>
                              setState(() => _stockFilter = v ?? 'all'),
                        ),
                      ),
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

  Widget _rewardCard(BuildContext context, PublishedReward item) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.hairline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Product Image Container (BoxFit.contain, neutral clean background)
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Stack(
              children: [
                _cover(item.imageUrl, height: 165),
                // Top-left Badges
                Positioned(
                  top: 10,
                  left: 10,
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.hairline),
                        ),
                        child: Text(
                          item.category,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: item.premiumOnly
                              ? AppColors.primaryTint
                              : AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(6),
                          border: item.premiumOnly
                              ? Border.all(color: AppColors.primarySoft)
                              : null,
                        ),
                        child: Text(
                          item.premiumOnly
                              ? _premiumEligibility
                              : _regularEligibility,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: item.premiumOnly
                                ? AppColors.primaryDark
                                : AppColors.ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Top-right Shop Status
                Positioned(
                  top: 10,
                  right: 10,
                  child: statusPill(item.active ? 'In shop' : 'Removed'),
                ),
              ],
            ),
          ),

          // 2. Card Content
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),

                // Points cost with coin/star badge
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primaryTint,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.stars_rounded,
                              size: 14, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Text(
                            '${item.pointCost} points',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Stock Operational Metric
                    Text(
                      '${item.stock} in stock',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: item.stock <= 10
                            ? AppColors.warning
                            : AppColors.inkSoft,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Validity days
                Text(
                  'Valid ${item.validityDays} days after redemption',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.inkSoft,
                  ),
                ),
                const SizedBox(height: 14),

                // Card Footer Actions
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _busy ? null : () => _open(item),
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('Edit reward'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.ink,
                        side: const BorderSide(color: AppColors.hairline),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    if (item.active)
                      TextButton(
                        onPressed: _busy ? null : () => _remove(item),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.danger,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                        ),
                        child: const Text('Remove from shop'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListView(List<PublishedReward> items) {
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: const Row(
              children: [
                Expanded(
                  flex: 4,
                  child: Text(
                    'REWARD',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.inkSoft,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'ELIGIBILITY',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.inkSoft,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'POINTS COST',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.inkSoft,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'STOCK',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.inkSoft,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'VALIDITY',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.inkSoft,
                      letterSpacing: 0.5,
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
                      color: AppColors.inkSoft,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'ACTIONS',
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.inkSoft,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.hairline),

          // Table Rows
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: AppColors.hairline),
            itemBuilder: (context, index) {
              final item = items[index];
              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    // Reward Name & Thumbnail
                    Expanded(
                      flex: 4,
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: 48,
                              height: 48,
                              child: _cover(item.imageUrl, height: 48),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title,
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.ink,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  item.category,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: AppColors.inkSoft,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Eligibility
                    Expanded(
                      flex: 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: item.premiumOnly
                              ? AppColors.primaryTint
                              : AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(6),
                          border: item.premiumOnly
                              ? Border.all(color: AppColors.primarySoft)
                              : null,
                        ),
                        child: Text(
                          item.premiumOnly
                              ? _premiumEligibility
                              : _regularEligibility,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: item.premiumOnly
                                ? AppColors.primaryDark
                                : AppColors.ink,
                          ),
                        ),
                      ),
                    ),

                    // Points Cost
                    Expanded(
                      flex: 2,
                      child: Text(
                        '${item.pointCost} points',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),

                    // Stock
                    Expanded(
                      flex: 2,
                      child: Text(
                        '${item.stock} in stock',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: item.stock <= 10
                              ? AppColors.warning
                              : AppColors.inkSoft,
                        ),
                      ),
                    ),

                    // Validity
                    Expanded(
                      flex: 2,
                      child: Text(
                        '${item.validityDays} days',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.inkSoft,
                        ),
                      ),
                    ),

                    // Status
                    Expanded(
                      flex: 2,
                      child: statusPill(item.active ? 'In shop' : 'Removed'),
                    ),

                    // Actions
                    Expanded(
                      flex: 2,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            tooltip: 'Edit reward',
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            color: AppColors.ink,
                            onPressed: _busy ? null : () => _open(item),
                          ),
                          if (item.active)
                            IconButton(
                              tooltip: 'Remove from shop',
                              icon: const Icon(Icons.remove_circle_outline,
                                  size: 18),
                              color: AppColors.danger,
                              onPressed: _busy ? null : () => _remove(item),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildVoucherCollectionTab(BuildContext context) {
    RewardFulfilmentRepository? repo = widget.fulfilmentRepository;
    if (repo == null) {
      try {
        final source = context.read<AdminMemberDirectoryRepository?>();
        if (source is RewardFulfilmentRepository) {
          repo = source as RewardFulfilmentRepository;
        }
      } catch (_) {}
    }

    if (repo == null || !repo.current) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.hairline),
        ),
        child: const Text('Reward fulfilment unavailable for this session.'),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.hairline),
      ),
      child: RewardFulfilmentPanel(repository: repo),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.repository.current) {
      return const Center(
          child: Text('Reward management unavailable for this session.'));
    }

    if (_newId != null || _editing != null) {
      return RewardEditorPage(
        key: ValueKey(_newId ?? _editing!.itemId),
        repository: widget.repository,
        itemId: _newId ?? _editing!.itemId,
        existing: _editing,
        onDone: _close,
      );
    }

    final allItems = _shop?.items ?? <PublishedReward>[];
    final visibleRewards = _getFilteredAndSortedRewards(allItems);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Breadcrumbs
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: const [
                  Text('Home',
                      style: TextStyle(fontSize: 13, color: AppColors.inkSoft)),
                  SizedBox(width: 6),
                  Icon(Icons.chevron_right_rounded,
                      size: 16, color: AppColors.inkSoft),
                  SizedBox(width: 6),
                  Text('Governance',
                      style: TextStyle(fontSize: 13, color: AppColors.inkSoft)),
                  SizedBox(width: 6),
                  Icon(Icons.chevron_right_rounded,
                      size: 16, color: AppColors.inkSoft),
                  SizedBox(width: 6),
                  Text('Reward Catalog',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink)),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 2. Page Header & Actions
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 720;
                final titleColumn = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Reward Catalog',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Manage rewards, member eligibility and voucher collection.',
                      style: TextStyle(
                        fontSize: 13.5,
                        color: AppColors.inkSoft,
                      ),
                    ),
                  ],
                );

                final actionButtons = Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    if (widget.onVerify != null ||
                        widget.fulfilmentRepository != null)
                      OutlinedButton.icon(
                        onPressed: () {
                          if (widget.onVerify != null) {
                            widget.onVerify!();
                          }
                          setState(() => _activeTab = 'vouchers');
                        },
                        icon: const Icon(Icons.qr_code_scanner, size: 18),
                        label: const Text('Verify reward voucher'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.ink,
                          side: const BorderSide(color: AppColors.hairline),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    FilledButton.icon(
                      onPressed: _busy || _loading || _shop == null
                          ? null
                          : () => _open(),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add reward'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                );

                return isWide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: titleColumn),
                          const SizedBox(width: 16),
                          actionButtons,
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          titleColumn,
                          const SizedBox(height: 14),
                          actionButtons,
                        ],
                      );
              },
            ),
            const SizedBox(height: 20),

            // 3. Sub-Navigation Tabs
            _buildTabs(),
            const SizedBox(height: 20),

            // 4. Progress bar if loading
            if (_loading) const LinearProgressIndicator(),

            // 5. Tab Content Body
            if (_activeTab == 'shop') ...[
              // Sub-header for test finders
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primaryTint,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.redeem_rounded,
                        color: AppColors.primary, size: 20),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Rewards',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const Text(
                        'Manage items in your Member shop.',
                        style:
                            TextStyle(fontSize: 13, color: AppColors.inkSoft),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Toolbar (white container with search, filters, sort, view toggle, refresh)
              _buildToolbar(context, allItems),
              const SizedBox(height: 18),

              // Error Banner
              if (_error != null)
                Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_error!,
                          style: const TextStyle(color: AppColors.danger)),
                      TextButton(
                        onPressed: _busy || _loading ? null : _load,
                        child: const Text('Retry rewards'),
                      ),
                    ],
                  ),
                ),

              // Empty State (Zero Rewards)
              if (_shop != null && _shop!.items.isEmpty)
                Panel(
                  child: SizedBox(
                    width: double.infinity,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 36, horizontal: 12),
                      child: Column(
                        children: [
                          const Icon(Icons.redeem_outlined,
                              color: AppColors.primary, size: 56),
                          const SizedBox(height: 16),
                          Text('No rewards yet',
                              style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 8),
                          const Text(
                            'Select Add reward to create your first Member reward.',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Empty Filter Results State
              if (_shop?.items.isNotEmpty == true && visibleRewards.isEmpty)
                const Panel(
                  child: Text('No rewards match this eligibility filter.'),
                ),

              // Rewards Grid or List View
              if (visibleRewards.isNotEmpty)
                _viewMode == 'grid'
                    ? LayoutBuilder(
                        builder: (context, c) {
                          final columns = c.maxWidth >= 1200
                              ? 3
                              : c.maxWidth >= 720
                                  ? 2
                                  : 1;
                          final cardWidth =
                              (c.maxWidth - (columns - 1) * 20) / columns;
                          return Wrap(
                            spacing: 20,
                            runSpacing: 20,
                            children: [
                              for (final item in visibleRewards)
                                SizedBox(
                                  width: cardWidth,
                                  child: _rewardCard(context, item),
                                ),
                            ],
                          );
                        },
                      )
                    : _buildListView(visibleRewards),
            ] else if (_activeTab == 'vouchers') ...[
              _buildVoucherCollectionTab(context),
            ],
          ],
        ),
      ),
    );
  }
}

Widget _cover(String url, {double height = 150}) => Container(
      height: height,
      width: double.infinity,
      color: AppColors.surfaceAlt,
      child: url.isEmpty
          ? const Icon(Icons.redeem_outlined,
              color: AppColors.primary, size: 56)
          : Image.network(
              url,
              fit: BoxFit.contain,
              webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.redeem_outlined,
                color: AppColors.primary,
                size: 56,
              ),
            ),
    );

class RewardEditorPage extends StatefulWidget {
  const RewardEditorPage({
    super.key,
    required this.repository,
    required this.itemId,
    required this.onDone,
    this.existing,
  });

  final RewardManagementRepository repository;
  final String itemId;
  final PublishedReward? existing;
  final VoidCallback onDone;

  @override
  State<RewardEditorPage> createState() => _RewardEditorPageState();
}

class _RewardEditorPageState extends State<RewardEditorPage> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.existing?.title ?? '');
  late final _description =
      TextEditingController(text: widget.existing?.description ?? '');
  late final _image =
      TextEditingController(text: widget.existing?.imageUrl ?? '');
  late final _cost =
      TextEditingController(text: widget.existing?.pointCost.toString() ?? '');
  late final _stock =
      TextEditingController(text: widget.existing == null ? '' : '0');
  late final _days = TextEditingController(
      text: widget.existing?.validityDays.toString() ?? '');
  late final _conditions =
      TextEditingController(text: widget.existing?.conditions ?? '');
  late final _instructions = TextEditingController(
      text: widget.existing?.collectionInstructions ?? '');
  late String _category = widget.existing?.category ?? 'Merchandise';
  late bool _premiumOnly = widget.existing?.premiumOnly ?? false;
  String? _signature, _request, _error;
  EquipmentImage? _selectedCover;
  Uint8List? _coverBytes;
  String? _uploadedCoverUrl;
  int _coverGeneration = 0;
  bool _busy = false;

  Future<void> _pickCover() async {
    if (_busy || !widget.repository.current) return;
    try {
      final image = await context.read<EquipmentImagePicker>().pick();
      if (!mounted || !widget.repository.current || image == null) return;
      setState(() {
        _selectedCover = image;
        _coverBytes = image.copyBytes();
        _uploadedCoverUrl = null;
        _coverGeneration++;
        _image.clear();
        _error = null;
      });
    } catch (_) {
      if (mounted && widget.repository.current) {
        setState(() =>
            _error = 'Choose a JPG, PNG or WebP image no larger than 5 MB.');
      }
    }
  }

  @override
  void dispose() {
    for (final c in [
      _title,
      _description,
      _image,
      _cost,
      _stock,
      _days,
      _conditions,
      _instructions
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy ||
        !widget.repository.current ||
        !_form.currentState!.validate()) {
      return;
    }
    final values = [
      _title.text.trim(),
      _description.text.trim(),
      _category,
      _image.text.trim(),
      _cost.text.trim(),
      _stock.text.trim(),
      _days.text.trim(),
      _conditions.text.trim(),
      _instructions.text.trim()
    ];
    final premiumOnly = _premiumOnly;
    final signature = jsonEncode([...values, _coverGeneration, premiumOnly]);
    if (_signature != signature) {
      _signature = signature;
      _request = _requestId();
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      var imageUrl = values[3];
      if (_selectedCover != null) {
        final media = widget.repository;
        if (media is! RewardMediaRepository) {
          throw StateError('Reward cover upload unavailable');
        }
        _uploadedCoverUrl ??= await (media as RewardMediaRepository)
            .uploadRewardCover(_selectedCover!);
        if (!mounted || !widget.repository.current) return;
        imageUrl = _uploadedCoverUrl!;
      }
      await widget.repository.saveReward(
          requestId: _request!,
          itemId: widget.itemId,
          baseItemRevision: widget.existing?.revision ?? 0,
          title: values[0],
          description: values[1],
          category: values[2],
          imageUrl: imageUrl,
          pointCost: int.parse(values[4]),
          stockToAdd: int.parse(values[5]),
          validityDays: int.parse(values[6]),
          conditions: values[7],
          collectionInstructions: values[8],
          premiumOnly: premiumOnly);
      if (mounted && widget.repository.current) widget.onDone();
    } on RewardMediaUploadFailed catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on RewardCatalogSessionChanged {
      if (mounted) {
        setState(() => _error =
            'Your Admin session changed. Sign in again before saving.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Save not confirmed. Retry unchanged fields, or return and refresh if another Admin changed the reward.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _text(TextEditingController c, String label,
          {int max = 2000, int lines = 1, bool required = false}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: c,
          enabled: !_busy,
          maxLength: max,
          maxLines: lines,
          decoration: InputDecoration(
            labelText: label,
            isDense: true,
          ),
          validator: (v) =>
              required && (v == null || v.trim().isEmpty) ? 'Required' : null,
        ),
      );

  Widget _number(TextEditingController c, String label,
          {int max = 100000000}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: c,
          enabled: !_busy,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: label,
            isDense: true,
          ),
          validator: (v) {
            final n = int.tryParse(v?.trim() ?? '');
            return n == null || n < (c == _stock ? 0 : 1) || n > max
                ? 'Enter a whole number from ${c == _stock ? 0 : 1} to $max'
                : null;
          },
        ),
      );

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.inkSoft,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
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
          subtitle: 'Name and classify your reward item.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _text(_title, 'Title', max: 120, required: true),
              _text(_description, 'Description', lines: 3),
              DropdownButtonFormField<String>(
                initialValue: _category,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  isDense: true,
                ),
                items: {
                  ...RewardCatalogDraft.categories,
                  if (_category.isNotEmpty) _category,
                }
                    .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                    .toList(),
                onChanged: _busy ? null : (v) => setState(() => _category = v!),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 2. Redemption & Inventory Card
        _cardContainer(
          title: 'Redemption & inventory',
          subtitle:
              'Configure points requirements, stock delta, and validity rules.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _number(_cost, 'Points cost'),
              _number(
                _stock,
                widget.existing == null ? 'Initial stock' : 'Additional stock',
              ),
              if (widget.existing != null) ...[
                Text(
                  '${widget.existing!.stock} currently in stock. Enter 0 to keep the remaining stock unchanged.',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.inkSoft,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              _number(
                _days,
                'Validity after redemption (days)',
                max: 365,
              ),
              _text(_conditions, 'Conditions', lines: 3, required: true),
              _text(_instructions, 'Collection instructions',
                  lines: 3, required: true),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 3. Membership Eligibility Card
        _cardContainer(
          title: 'Membership eligibility',
          subtitle: 'Specify which membership tiers can redeem this reward.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<bool>(
                key: const ValueKey('reward-member-eligibility'),
                initialValue: _premiumOnly,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Member Eligibility',
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(
                      value: false, child: Text(_regularEligibility)),
                  DropdownMenuItem(
                      value: true, child: Text(_premiumEligibility)),
                ],
                onChanged: _busy
                    ? null
                    : (value) {
                        if (value != null) {
                          setState(() => _premiumOnly = value);
                        }
                      },
              ),
              const SizedBox(height: 8),
              const Text(
                'Premium-exclusive rewards require an active Premium membership.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppColors.inkSoft,
                ),
              ),
              if (widget.existing?.active == true &&
                  widget.existing!.premiumOnly != _premiumOnly) ...[
                const SizedBox(height: 6),
                const Text(
                  'This change applies to future redemptions. Existing vouchers retain their terms.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.warning,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRightColumn(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Reward Image Card
        _cardContainer(
          title: 'Reward image',
          subtitle: 'Upload a product photograph or digital badge.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Eyebrow('Reward cover'),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: _coverBytes != null
                    ? Container(
                        height: 200,
                        width: double.infinity,
                        color: AppColors.surfaceAlt,
                        child: Image.memory(
                          _coverBytes!,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Center(
                            child: Text('Image preview unavailable'),
                          ),
                        ),
                      )
                    : _cover(_image.text, height: 200),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed:
                        _busy || widget.repository is! RewardMediaRepository
                            ? null
                            : _pickCover,
                    icon: const Icon(Icons.upload_outlined, size: 16),
                    label: Text(
                      _selectedCover != null || _image.text.isNotEmpty
                          ? 'Change cover'
                          : 'Choose cover image',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.ink,
                      side: const BorderSide(color: AppColors.hairline),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  if (_selectedCover != null || _image.text.isNotEmpty)
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                                _selectedCover = null;
                                _coverBytes = null;
                                _uploadedCoverUrl = null;
                                _coverGeneration++;
                                _image.clear();
                              }),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.danger,
                      ),
                      child: const Text('Remove cover'),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'JPG, PNG or WebP · up to 5 MB. Your selected image uploads when you save.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.inkSoft,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 2. Shop Visibility & Lifecycle Card
        _cardContainer(
          title: 'Shop visibility & lifecycle',
          subtitle: 'Operational policies governing redemption and vouchers.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              statusPill(widget.existing == null
                  ? 'Draft'
                  : widget.existing!.active
                      ? 'In shop'
                      : 'Removed'),
              const SizedBox(height: 10),
              const Text(
                'Unused expired rewards keep their points spent. Removing a reward from the shop preserves issued vouchers.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppColors.inkSoft,
                  height: 1.45,
                ),
              ),
              if (widget.existing?.active == false) ...[
                const SizedBox(height: 8),
                const Text(
                  'Saving returns this reward to the shop. Existing vouchers keep their original terms.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_error != null) ...[
            Text(_error!, style: const TextStyle(color: AppColors.danger)),
            const SizedBox(height: 12),
          ],
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              OutlinedButton(
                onPressed: _busy ? null : widget.onDone,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.ink,
                  side: const BorderSide(color: AppColors.hairline),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: _busy ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(
                  _busy
                      ? 'Saving…'
                      : widget.existing == null
                          ? 'Create reward'
                          : 'Save changes',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.repository.current) {
      return const Center(
          child: Text('Reward management unavailable for this session.'));
    }

    final isEdit = widget.existing != null;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 40),
        child: Align(
          alignment: Alignment.topLeft,
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Breadcrumbs & Back Navigation
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      TextButton.icon(
                        onPressed: _busy ? null : widget.onDone,
                        icon: const Icon(Icons.arrow_back, size: 16),
                        label: const Text('Reward Catalog'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          padding: EdgeInsets.zero,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.chevron_right_rounded,
                          size: 16, color: AppColors.inkSoft),
                      const SizedBox(width: 6),
                      Text(
                        isEdit ? 'Edit reward' : 'Add reward',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                        ),
                      ),
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
                            isEdit ? 'Edit reward' : 'Add reward',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isEdit
                                ? 'Update reward information, point costs, inventory, and membership eligibility.'
                                : 'Create a new reward item for members to redeem with their earned points.',
                            style: const TextStyle(
                              fontSize: 13.5,
                              color: AppColors.inkSoft,
                            ),
                          ),
                          if (widget.existing?.active == false) ...[
                            const SizedBox(height: 6),
                            const Text(
                              'Saving returns this reward to the shop. Existing vouchers keep their original terms.',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: AppColors.success,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Responsive Two-Column Layout (Shopify Polaris style)
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isDesktop = constraints.maxWidth >= 900;
                    if (isDesktop) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 65,
                            child: _buildLeftColumn(context),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            flex: 35,
                            child: _buildRightColumn(context),
                          ),
                        ],
                      );
                    } else {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildLeftColumn(context),
                          const SizedBox(height: 16),
                          _buildRightColumn(context),
                        ],
                      );
                    }
                  },
                ),
                const SizedBox(height: 24),

                // Sticky Bottom Action Bar
                _buildBottomActions(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
