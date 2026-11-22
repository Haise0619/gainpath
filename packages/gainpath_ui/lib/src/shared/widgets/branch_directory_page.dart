import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import '../../tokens/app_theme.dart';
import 'admin_dialogs.dart';
import 'branch_activity_page.dart';
import 'branch_map.dart';
import 'gym_details_screen.dart';

part 'branch_admin_directory.dart';
part 'branch_admin_editor.dart';

typedef BranchRequest = Future<Map<String, dynamic>> Function(
    Map<String, Object?> input);

class BranchDirectoryPage extends StatefulWidget {
  const BranchDirectoryPage({
    super.key,
    required this.request,
    required this.openDirections,
    this.admin = false,
    this.adminVisible = true,
    this.onSelected,
    this.locate,
    this.scanVisit,
    this.pickCover,
    this.initialDetails,
    this.onOpenReports,
    this.onOpenCalendar,
    this.onOpenCoaches,
    this.adminRoute = const BranchAdminRoute(),
    this.onAdminNavigate,
    this.onEditorLeaveCheckChanged,
    this.adminOperation,
  });

  final BranchRequest request;
  final Future<bool> Function(Uri) openDirections;
  final bool admin, adminVisible;
  final ValueChanged<String>? onSelected;
  final Future<({double latitude, double longitude})> Function()? locate;
  final Future<String?> Function(BuildContext context)? scanVisit;
  final Future<String?> Function()? pickCover;
  final Map<String, dynamic>? initialDetails;
  final ValueChanged<String>? onOpenReports;
  final ValueChanged<String>? onOpenCalendar;
  final ValueChanged<String>? onOpenCoaches;
  final BranchAdminRoute adminRoute;
  final void Function(BranchAdminRoute route, {required bool replace})?
      onAdminNavigate;
  final void Function(BranchAdminRoute, Future<bool> Function()?)?
      onEditorLeaveCheckChanged;
  final Widget Function(BranchAdminRoute route)? adminOperation;

  @override
  State<BranchDirectoryPage> createState() => _BranchDirectoryPageState();
}

class _BranchDirectoryPageState extends State<BranchDirectoryPage> {
  List<Map<String, dynamic>> _branches = [];
  String? _home, _next;
  String _query = '';
  final _adminSearch = TextEditingController();
  int _mapFocusRequest = 0;
  String _statusFilter = 'all';
  bool _busy = false, _failed = false;
  Future<void>? _directoryLoad;
  bool _showMap = false, _locating = false;
  LatLng? _location;
  String? _selection, _mapSelection;
  BranchAdminRoute _localAdminRoute = const BranchAdminRoute();

  BranchAdminRoute get _adminRoute =>
      widget.onAdminNavigate == null ? _localAdminRoute : widget.adminRoute;

  void _navigate(BranchAdminRoute route, {bool replace = false}) {
    final callback = widget.onAdminNavigate;
    if (callback == null) {
      setState(() => _localAdminRoute = route);
    } else {
      callback(route, replace: replace);
    }
  }

  Future<void> _useLocation() async {
    setState(() => _locating = true);
    try {
      final point = await widget.locate!();
      if (mounted) {
        setState(() => _location = LatLng(point.latitude, point.longitude));
      }
    } on StateError catch (error) {
      if (mounted) _notice(error.message);
    } catch (_) {
      if (mounted) {
        _notice('Location is unavailable. You can still browse branches.');
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadDirectory();
    final details = widget.initialDetails;
    if (details != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _details(details);
      });
    }
  }

  @override
  void dispose() {
    _adminSearch.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant BranchDirectoryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.admin && oldWidget.adminRoute.id != widget.adminRoute.id) {
      _resolveRouteBranch();
    }
  }

  Future<void> _loadDirectory() async {
    await _load();
    await _resolveRouteBranch();
  }

  Future<void> _resolveRouteBranch() async {
    if (!mounted || !widget.admin) return;
    final id = _adminRoute.id;
    if (id == null) return;
    await _directoryLoad;
    final seen = <String>{};
    while (mounted &&
        _adminRoute.id == id &&
        !_failed &&
        _next != null &&
        !_branches.any((branch) => branch['branchId'] == id) &&
        seen.add(_next!)) {
      await _load(more: true);
    }
  }

  Future<void> _load({bool more = false}) =>
      _directoryLoad ??= _readDirectory(after: more ? _next : null)
          .whenComplete(() => _directoryLoad = null);

  Future<void> _readDirectory({String? after}) async {
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      final result = await widget.request({
        'action': 'list',
        if (after != null) 'afterId': after,
      });
      if (!mounted) return;
      final branches = (result['records'] as List)
          .map((value) => Map<String, dynamic>.from(value as Map));
      final next = result['nextAfterId'] as String?;
      setState(() {
        _branches = [if (after != null) ..._branches, ...branches];
        _home = result['homeBranchId'] as String?;
        _selection = result['selectedBranchId'] as String?;
        _next = after != null && next != null && next.compareTo(after) <= 0
            ? null
            : next;
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _details(Map<String, dynamic> branch) async {
    final id = branch['branchId'] as String;
    if (widget.admin) {
      _navigate(BranchAdminRoute(BranchAdminSection.overview, id));
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => GymDetailsScreen(
          branch: branch,
          isHome: _home == id,
          isSelected: _selection == id,
          openDirections: widget.openDirections,
          onSelectGym: () async {
            try {
              await widget.request({'action': 'setSelected', 'branchId': id});
              if (mounted) {
                setState(() => _selection = id);
                widget.onSelected?.call(id);
                _notice('Selected as current workout gym.');
              }
            } catch (_) {
              if (mounted) _notice('Could not select this branch.');
            }
          },
          onSetHome: () async {
            try {
              await widget.request({'action': 'setHome', 'branchId': id});
              if (mounted) {
                await _load();
                _notice('Home branch updated.');
              }
            } catch (_) {
              if (mounted) _notice('Could not update the home branch.');
            }
          },
          onCheckIn: widget.scanVisit != null ? _checkIn : null,
          onOpenEquipment: () => _activity(branch: branch, visits: false),
        ),
      ),
    );
  }

  String _destination(Map<String, dynamic> branch) {
    final point = branchMapPoint(branch);
    return point == null
        ? _branchAddress(branch)
        : '${point.latitude},${point.longitude}';
  }

  Future<void> _directions(Map<String, dynamic> branch) async {
    try {
      final opened = await widget.openDirections(
        Uri.https('www.google.com', '/maps/dir/', {
          'api': '1',
          'destination': _destination(branch),
          'travelmode': 'driving',
          'dir_action': 'navigate',
        }),
      );
      if (!opened && mounted) _notice('Could not open directions.');
    } catch (_) {
      if (mounted) _notice('Could not open directions.');
    }
  }

  void _notice(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _activity(
          {Map<String, dynamic>? branch, required bool visits}) =>
      Navigator.of(context).push<void>(MaterialPageRoute(
          builder: (_) => BranchActivityPage(
                title: visits
                    ? 'Gym visits'
                    : '${branch?['displayName']} equipment',
                request: widget.request,
                branchId: branch?['branchId'] as String?,
                visits: visits,
                admin: widget.admin,
              )));

  Future<void> _checkIn() async {
    final code = await widget.scanVisit!(context);
    if (!mounted || code == null) return;
    final match =
        RegExp(r'^gainpath-visit:([A-Za-z0-9_-]{1,128}):([A-Za-z0-9_-]{32})$')
            .firstMatch(code);
    if (match == null) {
      _notice('This is not a GainPath gym visit code.');
      return;
    }
    try {
      final result = await widget.request(
          {'action': 'checkIn', 'branchId': match[1], 'token': match[2]});
      if (mounted) {
        _notice(result['duplicate'] == true
            ? 'Visit already recorded.'
            : 'Gym check-in successful.');
      }
    } catch (_) {
      if (mounted) {
        _notice(
            'Check-in unavailable. Check your membership or ask for a fresh code.');
      }
    }
  }

  Widget _adminPage(List<Map<String, dynamic>> visible) {
    final route = _adminRoute;
    return IndexedStack(
      sizing: StackFit.expand,
      index: route.section == BranchAdminSection.directory ? 0 : 1,
      children: [
        _AdminBranchDirectory(
          branches: _branches,
          visible: visible,
          search: _adminSearch,
          mapFocusRequest: _mapFocusRequest,
          homeId: _home,
          statusFilter: _statusFilter,
          showMap: _showMap,
          renderMap: widget.adminVisible &&
              route.section == BranchAdminSection.directory,
          mapSelection: _mapSelection,
          loading: _busy,
          failed: _failed,
          hasMore: _next != null,
          onAdd: () =>
              _navigate(const BranchAdminRoute(BranchAdminSection.add)),
          onRefresh: _loadDirectory,
          onQuery: (value) => setState(() => _query = value),
          onStatus: (value) => setState(() => _statusFilter = value),
          onView: (visible) => setState(() => _showMap = visible),
          onSelectMarker: (branch) => setState(() {
            _mapSelection = branch['branchId'] as String;
            _mapFocusRequest++;
          }),
          onManage: _details,
          onMore: () => _load(more: true),
          openAttribution: widget.openDirections,
        ),
        if (route.section != BranchAdminSection.directory)
          KeyedSubtree(key: ValueKey(route), child: _branchSubpage(route)),
      ],
    );
  }

  Widget _branchSubpage(BranchAdminRoute route) {
    final id = route.id;
    final branch = _branches.where((row) => row['branchId'] == id).firstOrNull;
    const directory = BranchAdminRoute();
    final overview = id == null
        ? directory
        : BranchAdminRoute(BranchAdminSection.overview, id);
    if (route.section == BranchAdminSection.add ||
        (route.section == BranchAdminSection.edit && branch != null)) {
      return _AdminBranchEditor(
        branch: branch,
        request: widget.request,
        pickCover: widget.pickCover,
        onSaved: () {
          _navigate(overview, replace: true);
          _notice(id == null ? 'Branch added.' : 'Branch saved.');
          _loadDirectory();
        },
        onCancel: () => _navigate(overview, replace: true),
        onLeaveCheckChanged: (check) =>
            widget.onEditorLeaveCheckChanged?.call(route, check),
      );
    }
    if (branch == null || id == null) {
      return ListView(padding: _branchPadding, children: [
        Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _navigate(directory),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back to branches'),
            )),
        const SizedBox(height: 12),
        if (_busy || (!_failed && _next != null))
          const LinearProgressIndicator()
        else ...[
          Text(_failed
              ? 'Could not load the branch.'
              : 'This branch is unavailable.'),
          if (_failed)
            Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton(
                  onPressed: _loadDirectory,
                  child: const Text('Retry'),
                )),
        ],
      ]);
    }
    final tabs = [
      BranchAdminSection.overview,
      BranchAdminSection.equipment,
      BranchAdminSection.visits,
      if (widget.adminOperation != null) ...[
        BranchAdminSection.members,
        BranchAdminSection.bookings,
      ],
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: _branchPadding.copyWith(bottom: 12, top: 12),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _navigate(directory),
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Back to branches'),
              )),
          const SizedBox(height: 4),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 10,
            children: [
              Text(_branchName(branch),
                  style: Theme.of(context).textTheme.headlineMedium),
              FilledButton.icon(
                onPressed: () =>
                    _navigate(BranchAdminRoute(BranchAdminSection.edit, id)),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Edit Branch'),
                style: FilledButton.styleFrom(minimumSize: const Size(0, 42)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 4, children: [
            for (final section in tabs)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(BranchAdminRoute(section, id).label),
                  selected: route.section == section,
                  selectedColor: AppColors.primaryTint,
                  checkmarkColor: AppColors.primaryDark,
                  onSelected: (selected) {
                    if (selected) _navigate(BranchAdminRoute(section, id));
                  },
                ),
              ),
            if (widget.onOpenCoaches != null)
              TextButton(
                  onPressed: () => widget.onOpenCoaches!(id),
                  child: const Text('Coaches')),
            if (widget.onOpenCalendar != null)
              TextButton.icon(
                  key: const ValueKey('branch-operations-calendar'),
                  onPressed: () => widget.onOpenCalendar!(id),
                  icon: const Icon(Icons.calendar_month_outlined, size: 16),
                  label: const Text('Operations Calendar')),
            if (widget.onOpenReports != null)
              TextButton(
                  onPressed: () => widget.onOpenReports!(id),
                  child: const Text('Reports')),
          ]),
        ]),
      ),
      Expanded(
        child: switch (route.section) {
          BranchAdminSection.equipment ||
          BranchAdminSection.visits =>
            BranchActivityPage(
              title: route.label,
              branchId: id,
              admin: true,
              embedded: true,
              canIssueVisitCode: branch['status'] == 'active',
              visits: route.section == BranchAdminSection.visits,
              request: widget.request,
            ),
          BranchAdminSection.members ||
          BranchAdminSection.bookings =>
            widget.adminOperation?.call(route) ??
                const Center(child: Text('Section unavailable.')),
          _ => _AdminBranchOverview(
              branch: branch,
              request: widget.request,
              home: id == _home,
              onDirections: _destination(branch).isEmpty
                  ? null
                  : () => _directions(branch),
            ),
        },
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.toLowerCase().trim();
    final visible = _branches
        .where((branch) =>
            (_statusFilter == 'all' || branch['status'] == _statusFilter) &&
            '${branch['displayName']} ${branch['address'] ?? ''}'
                .toLowerCase()
                .contains(query))
        .toList();
    if (widget.admin) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: _adminPage(visible),
      );
    }
    final location = _location;
    if (location != null) {
      double distance(Map<String, dynamic> branch) =>
          branchDistanceKm(branch, location) ?? double.infinity;
      visible.sort((a, b) {
        final order = distance(a).compareTo(distance(b));
        return order != 0
            ? order
            : (a['branchId'] as String).compareTo(b['branchId'] as String);
      });
    }
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Explore Gyms',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
                letterSpacing: -0.3,
              ),
            ),
            Text(
              'Find your next place to train.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: AppColors.inkSoft,
              ),
            ),
          ],
        ),
        actions: [
          if (widget.scanVisit != null)
            IconButton(
              tooltip: 'Gym check-in',
              icon: const Icon(Icons.qr_code_scanner_rounded, size: 22),
              color: AppColors.primary,
              onPressed: _checkIn,
            ),
          IconButton(
            tooltip: 'My gym visits',
            icon: const Icon(Icons.history_rounded, size: 22),
            color: AppColors.ink,
            onPressed: () => _activity(visits: true),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _showMap
          ? Stack(
              children: [
                Positioned.fill(
                  child: BranchMap(
                    key: ValueKey((
                      location,
                      visible.map((b) => b['branchId']).join(',')
                    )),
                    branches: visible,
                    location: location,
                    selectedId: _mapSelection ?? _selection,
                    onBranch: (b) =>
                        setState(() => _mapSelection = b['branchId'] as String),
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 16,
                  right: 16,
                  child: SafeArea(
                    bottom: false,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.search,
                              size: 20, color: AppColors.inkSoft),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              onChanged: (value) =>
                                  setState(() => _query = value),
                              decoration: const InputDecoration(
                                hintText: 'Search gyms by name or area...',
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding:
                                    EdgeInsets.symmetric(vertical: 8),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (widget.locate != null)
                            IconButton(
                              tooltip: _locating ? 'Locating…' : 'Near me',
                              icon: Icon(
                                Icons.near_me_outlined,
                                size: 18,
                                color: location != null
                                    ? AppColors.primary
                                    : AppColors.inkSoft,
                              ),
                              onPressed: _locating ? null : _useLocation,
                            ),
                          Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _segmentButton(
                                  icon: Icons.format_list_bulleted_rounded,
                                  label: 'List',
                                  isSelected: false,
                                  onTap: () => setState(() => _showMap = false),
                                ),
                                _segmentButton(
                                  icon: Icons.map_outlined,
                                  label: 'Map',
                                  isSelected: true,
                                  onTap: () {},
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (visible.isNotEmpty)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: SafeArea(
                      top: false,
                      child: _GymMapPreviewCard(
                        branch: visible
                                .where((b) => b['branchId'] == _mapSelection)
                                .firstOrNull ??
                            visible.first,
                        isHome: (_mapSelection ??
                                visible.first['branchId'] as String) ==
                            _home,
                        isSelected: (_mapSelection ??
                                visible.first['branchId'] as String) ==
                            _selection,
                        distanceKm: location == null
                            ? null
                            : branchDistanceKm(
                                visible
                                        .where((b) =>
                                            b['branchId'] == _mapSelection)
                                        .firstOrNull ??
                                    visible.first,
                                location,
                              ),
                        onTap: () => _details(visible
                                .where((b) => b['branchId'] == _mapSelection)
                                .firstOrNull ??
                            visible.first),
                        onDirections: () => _directions(visible
                                .where((b) => b['branchId'] == _mapSelection)
                                .firstOrNull ??
                            visible.first),
                      ),
                    ),
                  ),
              ],
            )
          : RefreshIndicator(
              onRefresh: () => _load(),
              color: AppColors.primary,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: [
                  TextField(
                    onChanged: (value) => setState(() => _query = value),
                    decoration: InputDecoration(
                      hintText: 'Search gyms by name or area...',
                      prefixIcon: const Icon(Icons.search,
                          size: 20, color: AppColors.inkSoft),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppColors.hairline),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppColors.hairline),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                            color: AppColors.primary, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Compact horizontal discovery toolbar
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      if (widget.locate != null)
                        InkWell(
                          onTap: _locating ? null : _useLocation,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 5),
                            decoration: BoxDecoration(
                              color: location != null
                                  ? AppColors.primaryTint
                                  : const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: location != null
                                    ? AppColors.primary.withValues(alpha: 0.25)
                                    : Colors.transparent,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.near_me_outlined,
                                  size: 14,
                                  color: location != null
                                      ? AppColors.primary
                                      : AppColors.inkSoft,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _locating ? 'Finding location…' : 'Near me',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: location != null
                                        ? AppColors.primary
                                        : AppColors.ink,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        const SizedBox.shrink(),
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _segmentButton(
                              icon: Icons.format_list_bulleted_rounded,
                              label: 'List',
                              isSelected: true,
                              onTap: () {},
                            ),
                            _segmentButton(
                              icon: Icons.map_outlined,
                              label: 'Map',
                              isSelected: false,
                              onTap: () => setState(() => _showMap = true),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Compact result header
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'All gyms',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.inkSoft,
                            letterSpacing: 0.1,
                          ),
                        ),
                        Text(
                          '${visible.length} ${visible.length == 1 ? "location" : "locations"}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.inkSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (location != null) ...[
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Icon(Icons.near_me_outlined,
                              size: 13, color: AppColors.primary),
                          SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              'Approximate straight-line distance · sorted',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 11, color: AppColors.inkSoft),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (_busy) const LinearProgressIndicator(),
                  if (_failed) ...[
                    const SizedBox(height: 20),
                    Center(
                      child: Column(
                        children: [
                          const Text(
                              'Branches could not be loaded. Pull down to retry.'),
                          const SizedBox(height: 8),
                          OutlinedButton(
                            onPressed: _load,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (!_busy && !_failed && visible.isEmpty) ...[
                    const SizedBox(height: 40),
                    const Center(
                      child: Text(
                        'No matching branches.',
                        style:
                            TextStyle(color: AppColors.inkSoft, fontSize: 14),
                      ),
                    ),
                  ],
                  for (final branch in visible)
                    _GymCard(
                      branch: branch,
                      isHome: branch['branchId'] == _home,
                      isSelected: branch['branchId'] == _selection,
                      distanceKm: location == null
                          ? null
                          : branchDistanceKm(branch, location),
                      onTap: () => _details(branch),
                      onDirections: () => _directions(branch),
                    ),
                  if (_next != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Center(
                        child: OutlinedButton(
                          onPressed: _busy ? null : () => _load(more: true),
                          child: const Text('Load more'),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _segmentButton({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? AppColors.primary : AppColors.inkSoft,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppColors.primary : AppColors.inkSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GymCard extends StatelessWidget {
  const _GymCard({
    required this.branch,
    required this.isHome,
    required this.isSelected,
    required this.distanceKm,
    required this.onTap,
    required this.onDirections,
  });

  final Map<String, dynamic> branch;
  final bool isHome;
  final bool isSelected;
  final double? distanceKm;
  final VoidCallback onTap;
  final VoidCallback onDirections;

  @override
  Widget build(BuildContext context) {
    final name = branch['displayName'] as String? ?? 'Branch';
    final address = _branchAddress(branch);
    final coverUrl = branch['coverUrl'] as String?;
    final hours = branch['openingHours'] as List?;
    final statusInfo = branchCardOpeningStatus(hours);

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.35)
              : AppColors.hairline,
          width: 1.0,
        ),
      ),
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Clean landscape gym cover - no badges on top
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: SizedBox(
                height: 130,
                child: coverUrl != null && coverUrl.isNotEmpty
                    ? Image.network(
                        coverUrl,
                        webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _cardCoverPlaceholder(),
                      )
                    : _cardCoverPlaceholder(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Gym name and indicators
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                          letterSpacing: -0.2,
                        ),
                      ),
                      if (isSelected)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primaryTint,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.25),
                              width: 0.8,
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle_outline_rounded,
                                  size: 13, color: AppColors.primary),
                              SizedBox(width: 4),
                              Text(
                                'Current gym',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (isHome)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: AppColors.hairline,
                              width: 0.8,
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.home_outlined,
                                  size: 13, color: AppColors.inkSoft),
                              SizedBox(width: 4),
                              Text(
                                'Home gym',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.inkSoft,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Opening status + distance
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: statusInfo.isOpen
                              ? AppColors.success
                              : (statusInfo.isAvailable
                                  ? const Color(0xFFEF4444)
                                  : const Color(0xFF9CA3AF)),
                          shape: BoxShape.circle,
                        ),
                      ),
                      Text(
                        statusInfo.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: statusInfo.isOpen
                              ? AppColors.inkSoft
                              : (statusInfo.isAvailable
                                  ? AppColors.inkSoft
                                  : const Color(0xFF9CA3AF)),
                        ),
                      ),
                      if (distanceKm != null) ...[
                        const Text('•',
                            style: TextStyle(
                                fontSize: 12, color: Color(0xFF9CA3AF))),
                        Text(
                          '${distanceKm!.toStringAsFixed(1)} km away',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.inkSoft,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (address.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Icon(Icons.location_on_outlined,
                              size: 14, color: Color(0xFF9CA3AF)),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            address,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.inkSoft,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  const Divider(
                      height: 1, thickness: 1, color: AppColors.hairline),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      InkWell(
                        onTap: onDirections,
                        borderRadius: BorderRadius.circular(8),
                        child: const Padding(
                          padding:
                              EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.directions_outlined,
                                  size: 16, color: AppColors.inkSoft),
                              SizedBox(width: 6),
                              Text(
                                'Directions',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.inkSoft,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: onTap,
                        borderRadius: BorderRadius.circular(8),
                        child: const Padding(
                          padding:
                              EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'View gym',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(Icons.arrow_forward_rounded,
                                  size: 15, color: AppColors.primary),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardCoverPlaceholder() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryDark, AppColors.primary],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.fitness_center_rounded,
          size: 40,
          color: Colors.white.withValues(alpha: 0.2),
        ),
      ),
    );
  }
}

class _GymMapPreviewCard extends StatelessWidget {
  const _GymMapPreviewCard({
    required this.branch,
    required this.isHome,
    required this.isSelected,
    required this.distanceKm,
    required this.onTap,
    required this.onDirections,
  });

  final Map<String, dynamic> branch;
  final bool isHome;
  final bool isSelected;
  final double? distanceKm;
  final VoidCallback onTap;
  final VoidCallback onDirections;

  @override
  Widget build(BuildContext context) {
    final name = branch['displayName'] as String? ?? 'Branch';
    final address = _branchAddress(branch);
    final coverUrl = branch['coverUrl'] as String?;
    final hours = branch['openingHours'] as List?;
    final statusInfo = branchCardOpeningStatus(hours);

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      elevation: 6,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.hairline),
      ),
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 72,
                      height: 72,
                      child: coverUrl != null && coverUrl.isNotEmpty
                          ? Image.network(
                              coverUrl,
                              webHtmlElementStrategy:
                                  WebHtmlElementStrategy.fallback,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _thumbPlaceholder(),
                            )
                          : _thumbPlaceholder(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: statusInfo.isOpen
                                        ? AppColors.success
                                        : (statusInfo.isAvailable
                                            ? const Color(0xFFEF4444)
                                            : const Color(0xFF9CA3AF)),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  statusInfo.label,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: statusInfo.isOpen
                                        ? AppColors.inkSoft
                                        : (statusInfo.isAvailable
                                            ? AppColors.inkSoft
                                            : const Color(0xFF9CA3AF)),
                                  ),
                                ),
                              ],
                            ),
                            if (isSelected)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryTint,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                      color: AppColors.primary
                                          .withValues(alpha: 0.25),
                                      width: 0.6),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.check_circle_outline_rounded,
                                        size: 11, color: AppColors.primary),
                                    SizedBox(width: 3),
                                    Text(
                                      'Current gym',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (isHome)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF3F4F6),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                      color: AppColors.hairline, width: 0.6),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.home_outlined,
                                        size: 11, color: AppColors.inkSoft),
                                    SizedBox(width: 3),
                                    Text(
                                      'Home gym',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.inkSoft,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                        if (address.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            address,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.inkSoft,
                            ),
                          ),
                        ],
                        if (distanceKm != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            '${distanceKm!.toStringAsFixed(1)} km away',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: AppColors.ink,
                        side: const BorderSide(color: AppColors.hairline),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: onDirections,
                      icon: const Icon(Icons.directions_outlined,
                          size: 15, color: AppColors.inkSoft),
                      label: const Text('Directions',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: onTap,
                      icon: const Icon(Icons.arrow_forward_rounded, size: 15),
                      label: const Text('View gym',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _thumbPlaceholder() {
    return Container(
      color: AppColors.primaryTint,
      child: const Center(
        child: Icon(Icons.fitness_center_rounded,
            size: 24, color: AppColors.primary),
      ),
    );
  }
}

const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

String _dayLabel(Object? value) {
  if (value is! Map) return 'Unavailable';
  if (value['closed'] == true) return 'Closed';
  if (value['allDay'] == true) return 'Open 24 hours';
  return '${value['open']}–${value['close']}';
}

({String label, bool isOpen, bool isAvailable}) branchCardOpeningStatus(
    List? hours) {
  if (hours == null || hours.length != 7) {
    return (
      label: 'Opening hours unavailable',
      isOpen: false,
      isAvailable: false
    );
  }
  final local = DateTime.now().toUtc().add(const Duration(hours: 8));
  final today = hours[local.weekday - 1];
  final yesterday = hours[(local.weekday + 5) % 7];
  final minute = local.hour * 60 + local.minute;

  int? parse(Object? value) {
    if (value is! String ||
        !RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(value)) {
      return null;
    }
    return int.parse(value.substring(0, 2)) * 60 +
        int.parse(value.substring(3));
  }

  if (hours.any((day) =>
      day is! Map ||
      (day['closed'] != true &&
          day['allDay'] != true &&
          (parse(day['open']) == null ||
              parse(day['close']) == null ||
              day['open'] == day['close'])))) {
    return (
      label: 'Opening hours unavailable',
      isOpen: false,
      isAvailable: false
    );
  }

  bool open(Object? value, {required bool previous}) {
    if (value is! Map || value['closed'] == true) return false;
    if (value['allDay'] == true) return !previous;
    final start = parse(value['open']), end = parse(value['close']);
    if (start == null || end == null) return false;
    return previous
        ? start > end && minute < end
        : minute >= start && (start > end || minute < end);
  }

  if (today is Map && today['allDay'] == true) {
    return (label: 'Open 24 hours', isOpen: true, isAvailable: true);
  }

  final isOpenNow =
      open(today, previous: false) || open(yesterday, previous: true);
  if (isOpenNow) {
    return (label: 'Open now', isOpen: true, isAvailable: true);
  } else {
    return (label: 'Closed', isOpen: false, isAvailable: true);
  }
}

String branchOpeningStatus(List hours) {
  if (hours.length != 7) return 'Opening hours unavailable';
  final local = DateTime.now().toUtc().add(const Duration(hours: 8));
  final today = hours[local.weekday - 1];
  final yesterday = hours[(local.weekday + 5) % 7];
  final minute = local.hour * 60 + local.minute;
  int? parse(Object? value) {
    if (value is! String ||
        !RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(value)) {
      return null;
    }
    return int.parse(value.substring(0, 2)) * 60 +
        int.parse(value.substring(3));
  }

  if (hours.any((day) =>
      day is! Map ||
      (day['closed'] != true &&
          day['allDay'] != true &&
          (parse(day['open']) == null ||
              parse(day['close']) == null ||
              day['open'] == day['close'])))) {
    return 'Opening hours unavailable';
  }

  bool open(Object? value, {required bool previous}) {
    if (value is! Map || value['closed'] == true) return false;
    if (value['allDay'] == true) return !previous;
    final start = parse(value['open']), end = parse(value['close']);
    if (start == null || end == null) return false;
    return previous
        ? start > end && minute < end
        : minute >= start && (start > end || minute < end);
  }

  return open(today, previous: false) || open(yesterday, previous: true)
      ? 'Open now · MYT'
      : 'Closed now · MYT';
}
