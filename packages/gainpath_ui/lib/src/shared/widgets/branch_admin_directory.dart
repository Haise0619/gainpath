part of 'branch_directory_page.dart';

enum BranchAdminSection {
  directory,
  add,
  overview,
  edit,
  equipment,
  visits,
  members,
  bookings,
}

@immutable
class BranchAdminRoute {
  const BranchAdminRoute(
      [this.section = BranchAdminSection.directory, this.id]);
  final BranchAdminSection section;
  final String? id;

  static BranchAdminRoute parse(List<String> parts) {
    if (parts.isEmpty) return const BranchAdminRoute();
    if (parts.length == 1 && parts.first == 'add') {
      return const BranchAdminRoute(BranchAdminSection.add);
    }
    if (parts.length > 2 ||
        !RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(parts.first)) {
      return const BranchAdminRoute();
    }
    final section = parts.length == 1
        ? BranchAdminSection.overview
        : BranchAdminSection.values
            .where((section) =>
                section != BranchAdminSection.directory &&
                section != BranchAdminSection.add &&
                section.name == parts[1])
            .firstOrNull;
    return section == null
        ? const BranchAdminRoute()
        : BranchAdminRoute(section, parts.first);
  }

  List<String> get segments => switch (section) {
        BranchAdminSection.directory => [],
        BranchAdminSection.add => ['add'],
        BranchAdminSection.overview => [id!, 'overview'],
        _ => [id!, section.name],
      };

  String get label => switch (section) {
        BranchAdminSection.directory => 'Branches',
        BranchAdminSection.add => 'Add Branch',
        BranchAdminSection.overview => 'Overview',
        BranchAdminSection.edit => 'Edit Branch',
        BranchAdminSection.equipment => 'Equipment',
        BranchAdminSection.visits => 'Check-in & visits',
        BranchAdminSection.members => 'Members',
        BranchAdminSection.bookings => 'Bookings',
      };

  Uri get uri => Uri(pathSegments: ['', 'console', 'branches', ...segments]);

  @override
  bool operator ==(Object other) =>
      other is BranchAdminRoute && other.id == id && other.section == section;

  @override
  int get hashCode => Object.hash(section, id);
}

const _branchPadding = EdgeInsets.fromLTRB(28, 24, 28, 32);

String _branchName(Map<String, dynamic> branch) =>
    branch['displayName'] as String? ?? 'Branch';

String _branchAddress(Map<String, dynamic> branch) =>
    (branch['address'] as String?)?.trim() ?? '';

List<String> _branchFacilities(Map<String, dynamic> branch) =>
    (branch['facilities'] as List?)?.whereType<String>().toList() ?? [];

String _branchHours(Map<String, dynamic> branch) {
  final hours = branch['openingHours'];
  final zone = branch['timeZone'];
  if (hours is! List || (zone != null && zone != 'Asia/Kuala_Lumpur')) {
    return 'Opening hours unavailable';
  }
  return branchOpeningStatus(hours);
}

class _AdminBranchDirectory extends StatelessWidget {
  const _AdminBranchDirectory({
    required this.branches,
    required this.visible,
    required this.search,
    required this.mapFocusRequest,
    required this.homeId,
    required this.statusFilter,
    required this.showMap,
    required this.renderMap,
    required this.mapSelection,
    required this.loading,
    required this.failed,
    required this.hasMore,
    required this.onAdd,
    required this.onRefresh,
    required this.onQuery,
    required this.onStatus,
    required this.onView,
    required this.onSelectMarker,
    required this.onManage,
    required this.onMore,
    required this.openAttribution,
  });

  final List<Map<String, dynamic>> branches, visible;
  final TextEditingController search;
  final int mapFocusRequest;
  final Future<bool> Function(Uri) openAttribution;
  final String? homeId, mapSelection;
  final String statusFilter;
  final bool showMap, renderMap, loading, failed, hasMore;
  final VoidCallback onAdd, onRefresh, onMore;
  final ValueChanged<String> onQuery, onStatus;
  final ValueChanged<bool> onView;
  final ValueChanged<Map<String, dynamic>> onSelectMarker, onManage;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ListView(
      key: const PageStorageKey('admin-branch-directory'),
      padding: _branchPadding,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Branch Management', style: text.headlineMedium),
                const SizedBox(height: 4),
                const Text(
                    'Manage gym locations, facilities and branch operations.'),
              ],
            ),
            FilledButton.icon(
              onPressed: loading ? null : onAdd,
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text('Add Branch'),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 42)),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (branches.isNotEmpty || (!loading && !failed)) ...[
          Text(
              hasMore
                  ? 'Loaded branches'
                  : 'Branches available to this account',
              style: text.bodySmall),
          const SizedBox(height: 8),
          LayoutBuilder(builder: (context, box) {
            final columns = (box.maxWidth / 195).floor().clamp(1, 3);
            final width = (box.maxWidth - (columns - 1) * 12) / columns;
            return Wrap(spacing: 12, runSpacing: 12, children: [
              _BranchCount(width, 'Total branches', branches.length,
                  Icons.apartment_rounded),
              _BranchCount(
                  width,
                  'Active branches',
                  branches.where((b) => b['status'] == 'active').length,
                  Icons.check_circle_outline),
              _BranchCount(
                  width,
                  'Inactive branches',
                  branches.where((b) => b['status'] == 'inactive').length,
                  Icons.pause_circle_outline),
            ]);
          }),
          const SizedBox(height: 20),
        ],
        _BranchPanel(
          child: Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 338),
                child: TextField(
                  key: const ValueKey('admin-branch-search'),
                  controller: search,
                  onChanged: onQuery,
                  decoration: const InputDecoration(
                    labelText: 'Search branches',
                    prefixIcon: Icon(Icons.search),
                    filled: true,
                    fillColor: AppColors.surface,
                    isDense: true,
                  ),
                ),
              ),
              Wrap(spacing: 6, runSpacing: 4, children: [
                for (final filter in const {
                  'all': 'All',
                  'active': 'Active',
                  'inactive': 'Inactive'
                }.entries)
                  ChoiceChip(
                    label: Text(filter.value),
                    selected: statusFilter == filter.key,
                    selectedColor: AppColors.primaryTint,
                    checkmarkColor: AppColors.primaryDark,
                    labelStyle: TextStyle(
                      color: statusFilter == filter.key
                          ? AppColors.primaryDark
                          : AppColors.ink,
                    ),
                    side: BorderSide(
                      color: statusFilter == filter.key
                          ? AppColors.primarySoft
                          : AppColors.hairline,
                    ),
                    onSelected: (_) => onStatus(filter.key),
                  ),
              ]),
              SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                      value: false,
                      icon: Icon(Icons.grid_view_rounded),
                      label: Text('Grid')),
                  ButtonSegment(
                      value: true,
                      icon: Icon(Icons.map_outlined),
                      label: Text('Map')),
                ],
                selected: {showMap},
                onSelectionChanged: (selected) => onView(selected.single),
                style: SegmentedButton.styleFrom(
                  selectedBackgroundColor: AppColors.primaryTint,
                  selectedForegroundColor: AppColors.primaryDark,
                  side: const BorderSide(color: AppColors.hairline),
                ),
              ),
              IconButton.outlined(
                tooltip: 'Refresh branches',
                onPressed: loading ? null : onRefresh,
                icon: const Icon(Icons.refresh_rounded),
                style: IconButton.styleFrom(
                  side: const BorderSide(color: AppColors.hairline),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (loading) const LinearProgressIndicator(),
        if (failed)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text('Branches could not be loaded. Refresh to retry.'),
          ),
        if (!loading && !failed && visible.isEmpty)
          const _BranchPanel(child: Text('No matching branches.')),
        if (visible.isNotEmpty && !showMap) _grid(),
        if (visible.isNotEmpty && showMap && renderMap) _map(context),
        if (hasMore)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
                onPressed: loading ? null : onMore,
                child: const Text('Load more')),
          ),
      ],
    );
  }

  Widget _grid() => LayoutBuilder(builder: (context, box) {
        const gap = 18.0;
        final count = ((box.maxWidth + gap) / (300 + gap)).floor().clamp(1, 5);
        final width =
            ((box.maxWidth - (count - 1) * gap) / count).clamp(0.0, 360.0);
        return Column(
          children: [
            for (var i = 0; i < visible.length; i += count)
              Padding(
                padding: EdgeInsets.only(top: i == 0 ? 0 : gap),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var j = i;
                          j < i + count && j < visible.length;
                          j++) ...[
                        if (j > i) const SizedBox(width: gap),
                        SizedBox(
                          width: width,
                          child: _AdminBranchCard(
                            branch: visible[j],
                            home: visible[j]['branchId'] == homeId,
                            onManage: () => onManage(visible[j]),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        );
      });

  Widget _map(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final sideBySide = box.maxWidth >= 810;
        final height =
            (MediaQuery.sizeOf(context).height - 278).clamp(370.0, 620.0);
        final map = BranchMap(
          height: sideBySide ? height : 330,
          branches: visible,
          selectedId: mapSelection,
          focusSelected: true,
          focusRequestId: mapFocusRequest,
          onBranch: onSelectMarker,
          onManageBranch: onManage,
          onOpenAttribution: openAttribution,
        );
        final list = _BranchMapResults(
          branches: visible,
          selection: mapSelection,
          onSelect: onSelectMarker,
          onManage: onManage,
          height: sideBySide ? height : 290,
        );
        return sideBySide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 35, child: list),
                  const SizedBox(width: 16),
                  Expanded(flex: 65, child: map)
                ],
              )
            : Column(children: [map, const SizedBox(height: 12), list]);
      });
}

class _BranchCount extends StatelessWidget {
  const _BranchCount(this.width, this.label, this.count, this.icon);
  final double width;
  final String label;
  final int count;
  final IconData icon;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        child: _BranchPanel(
          child: Row(children: [
            DecoratedBox(
              decoration: BoxDecoration(
                  color: AppColors.primaryTint,
                  borderRadius: BorderRadius.circular(9)),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(icon, size: 20, color: AppColors.primaryDark),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$count', style: Theme.of(context).textTheme.titleLarge),
                  Text(label, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ]),
        ),
      );
}

class _BranchPanel extends StatelessWidget {
  const _BranchPanel(
      {required this.child, this.padding = const EdgeInsets.all(16)});
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.hairline),
        ),
        child: child,
      );
}

class _BranchCover extends StatelessWidget {
  const _BranchCover({required this.branch});
  final Map<String, dynamic> branch;

  @override
  Widget build(BuildContext context) {
    final url = branch['coverUrl'];
    const fallback = ColoredBox(
      color: AppColors.surfaceAlt,
      child: Center(
          child: Icon(Icons.apartment_rounded,
              color: AppColors.inkSoft,
              size: 32,
              semanticLabel: 'No branch cover')),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(9),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: url is String && url.isNotEmpty
            ? Image.network(
                key: ValueKey((branch['branchId'], url)),
                url,
                webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                fit: BoxFit.cover,
                loadingBuilder: (context, image, progress) => progress == null
                    ? image
                    : const ColoredBox(
                        color: AppColors.surfaceAlt,
                        child: Center(
                            child: SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              semanticsLabel: 'Loading branch cover'),
                        )),
                      ),
                errorBuilder: (_, __, ___) => fallback,
              )
            : fallback,
      ),
    );
  }
}

String? _branchStatus(Map<String, dynamic> branch) =>
    switch (branch['status']) {
      'active' => 'Active',
      'inactive' => 'Inactive',
      _ => null,
    };

class _BranchStatus extends StatelessWidget {
  const _BranchStatus({required this.branch});
  final Map<String, dynamic> branch;

  @override
  Widget build(BuildContext context) {
    final status = _branchStatus(branch);
    final active = status == 'Active';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: active ? AppColors.successTint : AppColors.membershipFreeTint,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        child: Text(
          status ?? 'Status unavailable',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: active
                    ? const Color(0xFF166534)
                    : AppColors.membershipFreeInk,
              ),
        ),
      ),
    );
  }
}

class _AdminBranchCard extends StatelessWidget {
  const _AdminBranchCard(
      {required this.branch, required this.home, required this.onManage});
  final Map<String, dynamic> branch;
  final bool home;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final address = _branchAddress(branch);
    final facilities = _branchFacilities(branch);
    return _BranchPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _BranchCover(branch: branch),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 5,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _BranchStatus(branch: branch),
              if (home) Text('Home branch', style: text.bodySmall),
            ],
          ),
          const SizedBox(height: 8),
          Tooltip(
            message: _branchName(branch),
            child: Text(_branchName(branch),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: text.titleMedium),
          ),
          const SizedBox(height: 4),
          Text(address.isEmpty ? 'Address unavailable' : address,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: text.bodyMedium),
          const SizedBox(height: 10),
          Text(_branchHours(branch), style: text.bodySmall),
          if (facilities.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(facilities.join(' · '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: text.bodySmall),
          ],
          const Spacer(),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.hairline),
          const SizedBox(height: 10),
          Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton(
                onPressed: onManage,
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
                child: const Text('Manage Branch'),
              )),
        ],
      ),
    );
  }
}

class _BranchMapResults extends StatefulWidget {
  const _BranchMapResults(
      {required this.branches,
      required this.selection,
      required this.onSelect,
      required this.onManage,
      required this.height});
  final List<Map<String, dynamic>> branches;
  final String? selection;
  final ValueChanged<Map<String, dynamic>> onSelect, onManage;
  final double height;

  @override
  State<_BranchMapResults> createState() => _BranchMapResultsState();
}

class _BranchMapResultsState extends State<_BranchMapResults> {
  final _selectedKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _revealSelection();
  }

  @override
  void didUpdateWidget(covariant _BranchMapResults oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selection != oldWidget.selection) _revealSelection();
  }

  void _revealSelection() {
    if (widget.selection == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final row = _selectedKey.currentContext;
      final render = row?.findRenderObject();
      if (row != null && render != null) {
        // Reveal the result inside its panel without moving the outer page.
        Scrollable.of(row).position.ensureVisible(render, alignment: .5);
      }
    });
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        height: widget.height,
        child: _BranchPanel(
          padding: const EdgeInsets.all(12),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 2, 4, 9),
              child: Text('${widget.branches.length} branch results',
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            Expanded(
                child: SingleChildScrollView(
              primary: false,
              child: Column(children: [
                for (final branch in widget.branches)
                  Padding(
                    key: widget.selection == branch['branchId']
                        ? _selectedKey
                        : ValueKey(branch['branchId']),
                    padding: const EdgeInsets.only(bottom: 6),
                    child: ListTile(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      selected: widget.selection == branch['branchId'],
                      selectedTileColor: AppColors.primaryTint,
                      title: Text(_branchName(branch),
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                          [
                            if (_branchAddress(branch).isNotEmpty)
                              _branchAddress(branch),
                            if (_branchStatus(branch) case final String status)
                              status,
                            if (branchMapPoint(branch) == null)
                              'Location unavailable',
                          ].join(' · '),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis),
                      onTap: () => widget.onSelect(branch),
                      trailing: IconButton(
                        tooltip: 'Manage ${_branchName(branch)}',
                        onPressed: () => widget.onManage(branch),
                        icon: const Icon(Icons.chevron_right_rounded),
                      ),
                    ),
                  ),
              ]),
            )),
          ]),
        ),
      );
}

class _AdminBranchOverview extends StatefulWidget {
  const _AdminBranchOverview({
    required this.branch,
    required this.request,
    required this.home,
    required this.onDirections,
  });
  final Map<String, dynamic> branch;
  final BranchRequest request;
  final bool home;
  final VoidCallback? onDirections;

  @override
  State<_AdminBranchOverview> createState() => _AdminBranchOverviewState();
}

class _AdminBranchOverviewState extends State<_AdminBranchOverview> {
  late final _stats = Future<Map<String, dynamic>>.sync(() => widget.request(
      {'action': 'branchStats', 'branchId': widget.branch['branchId']}));

  @override
  Widget build(BuildContext context) {
    final branch = widget.branch;
    final text = Theme.of(context).textTheme;
    final address = _branchAddress(branch);
    final facilities = _branchFacilities(branch);
    final hours = branch['openingHours'];
    final point = branchMapPoint(branch);
    final readableHours = _branchHours(branch);
    return ListView(
      padding: _branchPadding.copyWith(top: 4),
      children: [
        LayoutBuilder(builder: (context, box) {
          final media = _BranchPanel(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _BranchCover(branch: branch),
              const SizedBox(height: 12),
              Text('Location', style: text.titleMedium),
              const SizedBox(height: 4),
              Text(address.isEmpty ? 'Address unavailable' : address),
              if ([
                for (final field in ['city', 'state', 'postalCode', 'country'])
                  if (branch[field] case final String value
                      when value.isNotEmpty)
                    value,
              ].join(' · ')
                  case final String locality when locality.isNotEmpty)
                Text(locality),
              const SizedBox(height: 4),
              Text(
                  point == null
                      ? 'Map location unavailable'
                      : '${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}',
                  style: text.bodySmall),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 6, children: [
                if (widget.onDirections != null)
                  OutlinedButton(
                      onPressed: widget.onDirections,
                      child: const Text('Get directions')),
                if (address.isNotEmpty)
                  TextButton(
                      onPressed: () =>
                          Clipboard.setData(ClipboardData(text: address)),
                      child: const Text('Copy address')),
              ]),
            ],
          ));
          final details =
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _BranchPanel(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _BranchStatus(branch: branch),
                    if (widget.home) const Text('Home branch'),
                    Text('ID: ${branch['branchId']}'),
                  ],
                ),
                for (final field in [
                  'description',
                  'contactPhone',
                  'contactEmail'
                ])
                  if (branch[field] case final String value
                      when value.isNotEmpty)
                    Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(value)),
                FutureBuilder<Map<String, dynamic>>(
                  future: _stats,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text('Branch totals unavailable.'));
                    }
                    final result = snapshot.data;
                    if (result == null) {
                      return const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: LinearProgressIndicator());
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Wrap(spacing: 12, runSpacing: 6, children: [
                        for (final metric in const {
                          'coaches': 'coach profiles',
                          'equipment': 'equipment units',
                          'bookings': 'bookings',
                          'visits': 'gym visits'
                        }.entries)
                          if (result[metric.key] case final num value)
                            Text('$value ${metric.value}'),
                      ]),
                    );
                  },
                ),
              ],
            )),
            const SizedBox(height: 14),
            _BranchPanel(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('Opening hours', style: text.titleMedium),
                  const SizedBox(height: 4),
                  Text(readableHours),
                  if (hours is List && hours.length == 7)
                    for (var i = 0; i < 7; i++)
                      Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: Text('${_days[i]}  ${_dayLabel(hours[i])}')),
                ])),
            const SizedBox(height: 14),
            _BranchPanel(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('Facilities', style: text.titleMedium),
                  const SizedBox(height: 6),
                  if (facilities.isEmpty)
                    const Text('No facilities listed.')
                  else
                    Wrap(spacing: 8, runSpacing: 6, children: [
                      for (final facility in facilities)
                        Chip(label: Text(facility)),
                    ]),
                ])),
          ]);
          return box.maxWidth >= 740
              ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(flex: 5, child: details),
                  const SizedBox(width: 16),
                  Expanded(flex: 4, child: media),
                ])
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [media, const SizedBox(height: 14), details]);
        }),
      ],
    );
  }
}
