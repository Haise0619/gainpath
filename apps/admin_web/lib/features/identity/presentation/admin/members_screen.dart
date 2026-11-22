import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import 'member_provision_page.dart';
import 'member_details_dialog.dart';
import 'user_action_dialogs.dart';

const _pageSize = 24;

/// Deterministic, pastel-toned initials avatar with high-contrast text.
const _avatarPalette = [
  (Color(0xFFEDE9FE), Color(0xFF6D28D9)), // Violet / Purple
  (Color(0xFFDBEAFE), Color(0xFF1D4ED8)), // Blue
  (Color(0xFFD1FAE5), Color(0xFF047857)), // Emerald
  (Color(0xFFFEF3C7), Color(0xFFB45309)), // Amber
  (Color(0xFFFFE4E6), Color(0xFFBE123C)), // Rose
  (Color(0xFFE0E7FF), Color(0xFF4338CA)), // Indigo
];

class _InitialsAvatar extends StatelessWidget {
  const _InitialsAvatar({required this.name, this.size = 38.0});

  final String name;
  final double size;

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    final first = parts.first[0];
    final last = parts.length > 1 && parts.last.isNotEmpty ? parts.last[0] : '';
    return (first + last).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final palette = _avatarPalette[name.hashCode.abs() % _avatarPalette.length];
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: palette.$1,
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(
          color: palette.$2.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Text(
        _initials,
        style: TextStyle(
          fontSize: size * 0.38,
          fontWeight: FontWeight.w700,
          color: palette.$2,
          letterSpacing: -0.3,
        ),
      ),
    );
  }
}

/// Redesigned premium GainPath Member Management Screen.
///
/// Features responsive summary KPI cards, an integrated Member Directory
/// card with clean search, segmented status filters, SaaS data table,
/// and smooth pagination while maintaining complete backward compatibility.
class MembersScreen extends StatefulWidget {
  const MembersScreen(
      {super.key,
      this.live = false,
      this.branchId,
      this.branchRequest,
      this.memberSetup,
      this.addingMember = false,
      this.provisionBranchId,
      this.onOpenAddMember,
      this.onCloseAddMember,
      this.onProvisionLeaveCheckChanged});

  final bool live;
  final String? branchId;
  final BranchRequest? branchRequest;
  final MemberSetupRequest? memberSetup;
  final bool addingMember;
  final String? provisionBranchId;
  final VoidCallback? onOpenAddMember;
  final Future<void> Function()? onCloseAddMember;
  final ValueChanged<Future<bool> Function()?>? onProvisionLeaveCheckChanged;

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  final _searchController = TextEditingController();
  String _status = 'All';
  String _query = '';
  String? _homeFilter, _membershipFilter;
  Map<String, Map<String, dynamic>> _memberDescriptions = {};
  List<MemberBranch> _branches = [];
  final _resending = <String>{};
  bool _standaloneProvisioning = false;
  int _page = 0;

  // Live state
  List<AdminMemberRecord> _liveItems = [];
  final _liveCursors = <String?>[null];
  String? _liveNext;
  String? _liveError;
  bool _liveLoading = true;
  int _liveGeneration = 0;
  Timer? _liveDebounce;

  @override
  void initState() {
    super.initState();
    if (widget.live) {
      _loadLive();
      if (_canProvision) {
        unawaited(_loadBranches().then<void>((_) {}, onError: (Object _) {}));
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _liveDebounce?.cancel();
    _liveGeneration++;
    super.dispose();
  }

  Future<void> _loadLive() async {
    _liveDebounce?.cancel();
    final generation = ++_liveGeneration;
    setState(() {
      _liveLoading = true;
      _liveError = null;
      _liveItems = [];
      _liveNext = null;
    });
    try {
      final request = widget.branchRequest;
      final directory = context.read<AdminMemberDirectoryRepository>();
      final setup = widget.memberSetup;
      final rawStatus =
          _status == 'Pending setup' || (_status == 'Active' && setup != null)
              ? 'All'
              : _status;
      var cursor = _liveCursors.last;
      while (true) {
        final result = widget.branchId != null && request != null
            ? await _loadBranch(request, cursor, rawStatus)
            : await directory.loadPage(
                query: _query, status: rawStatus, afterId: cursor);
        if (!mounted || generation != _liveGeneration) return;
        final ids = result.items
            .where((member) => member.source == 'existing')
            .map((member) => member.id)
            .toList();
        var descriptions = <String, Map<String, dynamic>>{};
        if (setup != null && ids.isNotEmpty) {
          try {
            final response = await setup({
              'schemaVersion': 1,
              'action': 'describe',
              'memberIds': ids,
            });
            descriptions = {
              for (final row in response['members'] as List)
                row['memberId'] as String:
                    Map<String, dynamic>.from(row as Map),
            };
          } catch (_) {
            // The existing directory stays usable during a scoped callable outage.
            if (_homeFilter != null ||
                _membershipFilter != null ||
                _status == 'Pending setup') {
              rethrow;
            }
          }
        }
        if (!mounted || generation != _liveGeneration) return;
        final items = result.items.where((member) {
          final meta = descriptions[member.id];
          final account = meta?['accountStatus'] ?? member.status;
          return (_homeFilter == null ||
                  meta?['homeBranchId'] == _homeFilter) &&
              (_membershipFilter == null ||
                  meta?['membership'] == _membershipFilter) &&
              (_status != 'Pending setup' || account == 'pendingSetup') &&
              (_status != 'Active' || account == 'active');
        }).toList();
        if (items.isNotEmpty || result.nextCursor == null) {
          setState(() {
            _liveItems = items;
            _memberDescriptions = descriptions;
            _liveNext = result.nextCursor;
            _liveLoading = false;
          });
          break;
        }
        if (cursor == result.nextCursor) {
          throw StateError('Invalid directory cursor.');
        }
        cursor = result.nextCursor;
      }
    } catch (_) {
      if (!mounted || generation != _liveGeneration) return;
      setState(() {
        _liveLoading = false;
        _liveError =
            'Could not load members. Check your Admin access and retry.';
      });
    }
  }

  Future<AdminMemberPage> _loadBranch(
      BranchRequest request, String? cursor, String status) async {
    final response = await request({
      'action': 'branchMembers',
      'branchId': widget.branchId,
      'query': _query,
      'status': status,
      if (cursor != null) 'afterId': cursor,
    });
    return AdminMemberPage(
      (response['records'] as List)
          .map((row) => AdminMemberRecord(
                id: row['id'] as String,
                name: row['name'] as String,
                email: row['email'] as String,
                status: row['status'] as String,
              ))
          .toList(),
      nextCursor: response['nextAfterId'] as String?,
    );
  }

  bool get _canProvision =>
      widget.live && widget.memberSetup != null && widget.branchRequest != null;

  Future<List<MemberBranch>> _loadBranches() async {
    final request = widget.branchRequest!;
    final choices = <MemberBranch>[];
    String? cursor;
    do {
      final response = await request(
          {'action': 'list', if (cursor != null) 'afterId': cursor});
      for (final row in response['records'] as List) {
        final id = row['branchId'];
        final label = row['displayName'];
        if (id is String && label is String && label.trim().isNotEmpty) {
          choices.add((id: id, name: label, active: row['status'] == 'active'));
        }
      }
      final next = response['nextAfterId'] as String?;
      if (next != null && next == cursor) {
        throw StateError('Invalid branch cursor.');
      }
      cursor = next;
    } while (cursor != null);
    if (mounted) setState(() => _branches = choices);
    return choices;
  }

  void _reloadFirstPage() {
    _liveCursors
      ..clear()
      ..add(null);
    unawaited(_loadLive());
  }

  Future<void> _viewMember(String memberId) {
    final repository = context.read<AdminMemberDirectoryRepository>();
    return showDialog<void>(
      context: context,
      builder: (_) =>
          MemberDetailsDialog(memberId: memberId, repository: repository),
    );
  }

  void _addMember() {
    final open = widget.onOpenAddMember;
    if (open != null) {
      open();
    } else {
      setState(() => _standaloneProvisioning = true);
    }
  }

  Future<void> _closeProvisioning(String? memberId) async {
    if (widget.onCloseAddMember case final close?) {
      await close();
    } else {
      setState(() => _standaloneProvisioning = false);
    }
    if (mounted && memberId != null) await _viewMember(memberId);
  }

  Future<void> _resendSetup(String id) async {
    if (!_resending.add(id)) return;
    setState(() {});
    String message;
    try {
      final result = await widget.memberSetup!({
        'schemaVersion': 1,
        'action': 'resend',
        'memberId': id,
      });
      message = switch (result['delivery']) {
        'sent' => 'Brevo accepted the setup email for delivery.',
        'rate_limited' => 'Wait before sending another setup email.',
        'failed' => 'The setup email could not be sent.',
        _ => 'No new setup email was submitted.',
      };
      if (result['accountStatus'] == 'complete') {
        message = 'Account setup is already complete.';
      }
    } catch (_) {
      message = 'Could not confirm the setup email. Try again later.';
    } finally {
      if (mounted) setState(() => _resending.remove(id));
    }
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void _onSearch(String value) {
    if (widget.live) {
      _liveDebounce?.cancel();
      _liveGeneration++;
      setState(() {
        _query = value;
        _liveCursors
          ..clear()
          ..add(null);
        _liveItems = [];
        _liveNext = null;
        _liveLoading = true;
        _liveError = null;
      });
      _liveDebounce = Timer(const Duration(milliseconds: 300), _loadLive);
    } else {
      setState(() {
        _query = value;
        _page = 0;
      });
    }
  }

  void _onStatus(String s) {
    if (widget.live) {
      _liveDebounce?.cancel();
      setState(() {
        _status = s;
        _liveCursors
          ..clear()
          ..add(null);
      });
      _loadLive();
    } else {
      setState(() {
        _status = s;
        _page = 0;
      });
    }
  }

  void _refresh() => setState(() {});

  void _clearFilters() {
    _searchController.clear();
    _homeFilter = null;
    _membershipFilter = null;
    _onSearch('');
    _onStatus('All');
  }

  List<UserAccount> get _members => context
      .read<UserAccountRepository>()
      .users
      .where((u) => u.role == 'Member')
      .toList();

  @override
  Widget build(BuildContext context) {
    if (_canProvision && (widget.addingMember || _standaloneProvisioning)) {
      return MemberProvisionPage(
        key: ValueKey(widget.provisionBranchId ?? widget.branchId),
        request: widget.memberSetup!,
        homeBranchId: widget.provisionBranchId ?? widget.branchId,
        loadBranches: _loadBranches,
        onCreated: _reloadFirstPage,
        onClose: _closeProvisioning,
        onLeaveCheckChanged: widget.onProvisionLeaveCheckChanged,
      );
    }
    final all = widget.live ? const <UserAccount>[] : _members;
    final activeCount = widget.live
        ? _liveItems
            .where((u) =>
                (_memberDescriptions[u.id]?['accountStatus'] ?? u.status) ==
                'active')
            .length
        : all.where((u) => u.status == AccountStatus.active).length;
    final suspendedCount = widget.live
        ? _liveItems.where((u) => u.status == 'suspended').length
        : all.where((u) => u.status == AccountStatus.suspended).length;

    final filtered = widget.live
        ? const <UserAccount>[]
        : all.where((u) {
            final matchesStatus = _status == 'All' || u.status.label == _status;
            final matchesQuery = _query.isEmpty ||
                u.name.toLowerCase().contains(_query.toLowerCase()) ||
                u.email.toLowerCase().contains(_query.toLowerCase());
            return matchesStatus && matchesQuery;
          }).toList();

    final pageCount = (filtered.length / _pageSize).ceil().clamp(1, 1 << 30);
    final page = _page.clamp(0, pageCount - 1);
    final start = page * _pageSize;
    final pageItems = filtered.skip(start).take(_pageSize).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FC),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final isNarrow = width < 768;
          final double hPadding =
              isNarrow ? 18.0 : (width >= 1200 ? 36.0 : 24.0);
          final double vPadding = isNarrow ? 20.0 : 28.0;

          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: hPadding,
              vertical: vPadding,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1320),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Page Header with Breadcrumb and Title
                    _buildHeader(context),
                    const SizedBox(height: 24),

                    // 2. Summary KPI Cards
                    _buildSummaryCards(
                      width: width,
                      totalCount: widget.live ? _liveItems.length : all.length,
                      activeCount: activeCount,
                      suspendedCount: suspendedCount,
                    ),
                    const SizedBox(height: 24),

                    // 3. Member Directory Card (Toolbar + Table + Pagination)
                    _buildDirectoryCard(
                      context: context,
                      allCount: all.length,
                      filteredCount: filtered.length,
                      page: page,
                      pageCount: pageCount,
                      start: start,
                      pageItems: pageItems,
                      isNarrow: isNarrow,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main Title & Read-Only Badge
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            Text(
              'Members',
              style: GoogleFonts.poppins(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF242038),
                letterSpacing: -0.4,
              ),
            ),
            if (_canProvision)
              FilledButton.icon(
                  key: const ValueKey('add-member'),
                  onPressed: _addMember,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Member'))
            else if (widget.live)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEE8FC),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFDDD2F9)),
                ),
                child: Text(
                  'Organization membership records · Read-only directory',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF5633B9),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          widget.live
              ? 'Browse and review member accounts in your organization.'
              : "View and manage your fitness center's member directory.",
          style: GoogleFonts.inter(
            fontSize: 13.5,
            color: const Color(0xFF807895),
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCards({
    required double width,
    required int totalCount,
    required int activeCount,
    required int suspendedCount,
  }) {
    final card1 = _SummaryCard(
      icon: Icons.groups_rounded,
      label: widget.live ? 'Members on page' : 'Total members',
      value: '$totalCount',
      accentColor: const Color(0xFF6737CA),
      bgColor: const Color(0xFFF3E8FF),
    );

    final card2 = _SummaryCard(
      icon: Icons.check_circle_outline_rounded,
      label: widget.live ? 'Active on page' : 'Active',
      value: '$activeCount',
      accentColor: const Color(0xFF15854C),
      bgColor: const Color(0xFFE4F7EB),
    );

    final card3 = _SummaryCard(
      icon: Icons.block_rounded,
      label: widget.live ? 'Suspended on page' : 'Suspended',
      value: '$suspendedCount',
      accentColor: const Color(0xFFC44343),
      bgColor: const Color(0xFFFDECEC),
    );

    if (width >= 960) {
      return Row(
        children: [
          Expanded(child: card1),
          const SizedBox(width: 16),
          Expanded(child: card2),
          const SizedBox(width: 16),
          Expanded(child: card3),
        ],
      );
    }

    if (width >= 600) {
      return Wrap(
        spacing: 14,
        runSpacing: 14,
        children: [
          SizedBox(width: (width - 64) / 2, child: card1),
          SizedBox(width: (width - 64) / 2, child: card2),
          SizedBox(width: (width - 64) / 2, child: card3),
        ],
      );
    }

    return Column(
      children: [
        card1,
        const SizedBox(height: 12),
        card2,
        const SizedBox(height: 12),
        card3,
      ],
    );
  }

  Widget _buildDirectoryCard({
    required BuildContext context,
    required int allCount,
    required int filteredCount,
    required int page,
    required int pageCount,
    required int start,
    required List<UserAccount> pageItems,
    required bool isNarrow,
  }) {
    final int resultCount = widget.live ? _liveItems.length : filteredCount;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE9E6F2), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08190F2E),
            blurRadius: 16,
            spreadRadius: 0,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Directory Header with Card Title & Count Badge
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
            child: Row(
              children: [
                Text(
                  'Member Directory',
                  style: GoogleFonts.poppins(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF242038),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1EDFB),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    widget.live
                        ? '$resultCount members on page'
                        : '$resultCount members',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF6737CA),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. Search & Filter Toolbar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: _buildToolbar(isNarrow),
          ),

          // 3. Main Data Content (Table or States)
          const Divider(height: 1, color: Color(0xFFEEEAF4)),
          if (widget.live && _liveLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Color(0xFF6737CA),
                  ),
                ),
              ),
            )
          else if (widget.live && _liveError != null)
            _buildErrorState()
          else if (widget.live && _liveItems.isEmpty)
            _buildEmptyState()
          else if (!widget.live && pageItems.isEmpty)
            _buildEmptyState()
          else
            _buildMemberTable(context, pageItems),

          // 4. Pagination Footer
          const Divider(height: 1, color: Color(0xFFEEEAF4)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: _buildPaginationFooter(
              context: context,
              allCount: allCount,
              filteredCount: filteredCount,
              page: page,
              pageCount: pageCount,
              start: start,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar(bool isNarrow) {
    final searchInput = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearch,
        style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF242038)),
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Search members by name or email...',
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    _searchController.clear();
                    _onSearch('');
                  },
                ),
          hintStyle: GoogleFonts.inter(
            fontSize: 13.5,
            color: const Color(0xFF807895),
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            size: 20,
            color: Color(0xFF807895),
          ),
          filled: true,
          fillColor: const Color(0xFFF8F7FC),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE9E6F2)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF6737CA), width: 1.5),
          ),
        ),
      ),
    );

    final statusFilters = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        'All',
        'Active',
        'Suspended',
        if (_canProvision) 'Pending setup'
      ].map((s) {
        final selected = s == _status;
        return Padding(
          padding: const EdgeInsets.only(left: 6),
          child: InkWell(
            onTap: () => _onStatus(s),
            borderRadius: BorderRadius.circular(20),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFF6737CA)
                    : const Color(0xFFF8F7FC),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected
                      ? const Color(0xFF6737CA)
                      : const Color(0xFFE9E6F2),
                ),
              ),
              child: Text(
                s,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? Colors.white : const Color(0xFF242038),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );

    final refreshButton = widget.live
        ? IconButton(
            tooltip: 'Refresh members',
            onPressed: _liveLoading
                ? null
                : () {
                    _liveCursors
                      ..clear()
                      ..add(null);
                    _loadLive();
                  },
            icon: const Icon(
              Icons.refresh_rounded,
              color: Color(0xFF6737CA),
              size: 21,
            ),
          )
        : const SizedBox.shrink();

    if (isNarrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          searchInput,
          if (_canProvision) _directoryFilters(),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                statusFilters,
                if (widget.live) ...[
                  const SizedBox(width: 8),
                  refreshButton,
                ],
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(child: searchInput),
          const SizedBox(width: 12),
          statusFilters,
          if (widget.live) ...[const SizedBox(width: 8), refreshButton],
        ]),
        if (_canProvision) _directoryFilters(),
      ],
    );
  }

  Widget _directoryFilters() => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Wrap(spacing: 12, runSpacing: 8, children: [
          if (widget.branchId == null && _branches.isNotEmpty)
            DropdownButton<String>(
              value: _homeFilter ?? '',
              items: [
                const DropdownMenuItem(
                    value: '', child: Text('All home branches')),
                for (final branch in _branches)
                  DropdownMenuItem(value: branch.id, child: Text(branch.name)),
              ],
              onChanged: (value) {
                setState(() => _homeFilter = value == '' ? null : value);
                _reloadFirstPage();
              },
            ),
          DropdownButton<String>(
            value: _membershipFilter ?? '',
            items: const [
              DropdownMenuItem(value: '', child: Text('All memberships')),
              DropdownMenuItem(value: 'free', child: Text('Free')),
              DropdownMenuItem(value: 'basic', child: Text('Basic')),
              DropdownMenuItem(value: 'premium', child: Text('Premium')),
            ],
            onChanged: (value) {
              setState(() => _membershipFilter = value == '' ? null : value);
              _reloadFirstPage();
            },
          ),
        ]),
      );

  Widget _buildMemberTable(BuildContext context, List<UserAccount> pageItems) {
    return Column(
      children: [
        // Table Header
        Container(
          color: const Color(0xFFF8F7FC),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              Expanded(
                flex: 5,
                child: Text(
                  'MEMBER',
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF807895),
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              SizedBox(
                width: 140,
                child: Text(
                  'STATUS',
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF807895),
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              SizedBox(
                width: 80,
                child: Text(
                  'ACTIONS',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF807895),
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFFEEEAF4)),

        // Table Rows
        if (widget.live)
          for (var i = 0; i < _liveItems.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: Color(0xFFEEEAF4)),
            _MemberTableRow.member(
              _liveItems[i],
              description: _memberDescriptions[_liveItems[i].id],
              onManage: () => _viewMember(_liveItems[i].id),
              onResend:
                  _memberDescriptions[_liveItems[i].id]?['canResend'] == true &&
                          !_resending.contains(_liveItems[i].id)
                      ? () => _resendSetup(_liveItems[i].id)
                      : null,
            ),
          ]
        else
          for (var i = 0; i < pageItems.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: Color(0xFFEEEAF4)),
            _MemberTableRow(
              user: pageItems[i],
              onManage: () => _manage(context, pageItems[i]),
            ),
          ],
      ],
    );
  }

  Widget _buildEmptyState() {
    final String message = _liveNext != null
        ? 'No matches in this batch. Continue to search more members.'
        : (_query.isNotEmpty || _status != 'All')
            ? 'No members match that search.'
            : 'No members found.';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 56),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: const Color(0xFFF3E8FF),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.people_outline_rounded,
                color: Color(0xFF6737CA),
                size: 28,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF242038),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Try adjusting your keywords or clearing the status filter.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFF807895),
              ),
            ),
            if (_query.isNotEmpty || _status != 'All') ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _clearFilters,
                icon: const Icon(Icons.clear_rounded, size: 16),
                label: const Text('Clear filters'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF6737CA),
                  side: const BorderSide(color: Color(0xFFDDD2F9)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFFFDECEC),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: Color(0xFFC44343),
                size: 26,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              _liveError ?? 'Could not load members.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF242038),
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _loadLive,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Retry'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF6737CA),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaginationFooter({
    required BuildContext context,
    required int allCount,
    required int filteredCount,
    required int page,
    required int pageCount,
    required int start,
  }) {
    if (widget.live) {
      return Wrap(
        spacing: 16,
        runSpacing: 10,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            'Page ${_liveCursors.length} · ${_liveItems.length} matching members',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF807895),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton.icon(
                onPressed: _liveLoading || _liveCursors.length == 1
                    ? null
                    : () {
                        _liveCursors.removeLast();
                        _loadLive();
                      },
                icon: const Icon(Icons.chevron_left_rounded, size: 18),
                label: const Text('Previous'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF6737CA),
                  side: const BorderSide(color: Color(0xFFE9E6F2)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _liveLoading || _liveNext == null
                    ? null
                    : () {
                        _liveCursors.add(_liveNext);
                        _loadLive();
                      },
                label: Text(
                  _query.isNotEmpty || _status != 'All'
                      ? 'Continue search'
                      : 'Next',
                ),
                icon: const Icon(Icons.chevron_right_rounded, size: 18),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF6737CA),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    return Row(
      children: [
        Text(
          '$filteredCount of $allCount members',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF807895),
          ),
        ),
        const Spacer(),
        if (pageCount > 1)
          _Pagination(
            page: page,
            pageCount: pageCount,
            onSelect: (p) => setState(() => _page = p),
          ),
      ],
    );
  }

  void _manage(BuildContext context, UserAccount user) {
    showRecordActionsDialog(
      context,
      title: user.name,
      subtitle: user.email,
      actions: [
        RecordActionItem(
          icon: Icons.lock_reset_rounded,
          color: const Color(0xFF6737CA),
          label: 'Reset password',
          onTap: () {
            Navigator.pop(context);
            resetPasswordFlow(context, user);
          },
        ),
        RecordActionItem(
          icon: Icons.block_rounded,
          color: const Color(0xFFC44343),
          label: user.status == AccountStatus.suspended
              ? 'Lift suspension'
              : 'Suspend account',
          onTap: () {
            Navigator.pop(context);
            if (user.status == AccountStatus.suspended) {
              liftSuspensionFlow(context, user, _refresh);
            } else {
              suspendMemberFlow(context, user, _refresh);
            }
          },
        ),
      ],
    );
  }
}

/// Elevated KPI Summary Card.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.accentColor,
    required this.bgColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accentColor;
  final Color bgColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE9E6F2), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06190F2E),
            blurRadius: 14,
            spreadRadius: 0,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF807895),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF242038),
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accentColor, size: 22),
          ),
        ],
      ),
    );
  }
}

/// Polished SaaS Member Table Row.
class _MemberTableRow extends StatelessWidget {
  _MemberTableRow({required UserAccount user, this.onManage})
      : description = null,
        onResend = null,
        name = user.name,
        email = user.email,
        statusLabel = user.status.label,
        readOnly = false;

  _MemberTableRow.member(AdminMemberRecord member,
      {this.onManage, this.onResend, this.description})
      : name = member.name,
        email = member.email,
        statusLabel = switch (description?['accountStatus']) {
          'pendingSetup' => 'Pending setup',
          'disabled' => 'Disabled',
          'unknown' => 'Unknown',
          _ => member.statusLabel,
        },
        readOnly = true;

  final String name;
  final String email;
  final String statusLabel;
  final VoidCallback? onManage, onResend;
  final Map<String, dynamic>? description;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onManage,
        hoverColor: const Color(0xFFFAF8FF),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          child: Row(
            children: [
              // Member Column (Avatar + Name + Email)
              Expanded(
                flex: 5,
                child: Row(
                  children: [
                    _InitialsAvatar(name: name, size: 38),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF242038),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            email,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              color: const Color(0xFF807895),
                            ),
                          ),
                          if (description != null)
                            Text(
                              [
                                if (description!['branchName']
                                    case final String name)
                                  name,
                                if (description!['membership']
                                    case final String tier)
                                  '${tier[0].toUpperCase()}${tier.substring(1)} membership',
                              ].join(' · '),
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          if (onResend != null)
                            TextButton(
                              onPressed: onResend,
                              child: const Text('Resend Setup Email'),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Status Column (Semantic badge with dot)
              SizedBox(
                width: 140,
                child: _buildSemanticStatusBadge(statusLabel),
              ),

              // Actions Column
              SizedBox(
                width: 80,
                child: Align(
                  alignment: Alignment.center,
                  child: onManage == null
                      ? const SizedBox.shrink()
                      : Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F7FC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE9E6F2)),
                          ),
                          child: IconButton(
                            tooltip: readOnly ? 'View details for $name' : null,
                            icon: Icon(
                              readOnly
                                  ? Icons.visibility_outlined
                                  : Icons.more_vert_rounded,
                              size: 18,
                              color: const Color(0xFF6737CA),
                            ),
                            onPressed: onManage,
                            padding: EdgeInsets.zero,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSemanticStatusBadge(String status) {
    final (textColor, bgColor) = switch (status.toLowerCase()) {
      'active' => (const Color(0xFF15854C), const Color(0xFFE4F7EB)),
      'suspended' || 'disabled' => (
          const Color(0xFFC44343),
          const Color(0xFFFDECEC)
        ),
      'pending setup' => (const Color(0xFF8B410A), const Color(0xFFFFE9D3)),
      _ => (AppColors.inkSoft, AppColors.surfaceAlt),
    };

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: textColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              status,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact Pagination widget.
class _Pagination extends StatelessWidget {
  const _Pagination({
    required this.page,
    required this.pageCount,
    required this.onSelect,
  });

  final int page;
  final int pageCount;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _pageButton(
          context,
          icon: Icons.chevron_left_rounded,
          onTap: page > 0 ? () => onSelect(page - 1) : null,
        ),
        ...List.generate(pageCount, (i) => i)
            .map((i) => _numberButton(context, i)),
        _pageButton(
          context,
          icon: Icons.chevron_right_rounded,
          onTap: page < pageCount - 1 ? () => onSelect(page + 1) : null,
        ),
      ],
    );
  }

  Widget _numberButton(BuildContext context, int i) {
    final selected = i == page;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: selected ? const Color(0xFF6737CA) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => onSelect(i),
          child: SizedBox(
            width: 32,
            height: 32,
            child: Center(
              child: Text(
                '${i + 1}',
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : const Color(0xFF807895),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _pageButton(
    BuildContext context, {
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return IconButton(
      icon: Icon(
        icon,
        size: 19,
        color:
            onTap == null ? const Color(0xFFCDD3E1) : const Color(0xFF6737CA),
      ),
      onPressed: onTap,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      padding: EdgeInsets.zero,
    );
  }
}
