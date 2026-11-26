import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../tokens/app_theme.dart';

typedef SupportRequestCall = Future<Map<String, dynamic>> Function(
    String action, Map<String, dynamic> input);

class SupportRequestsPage extends StatefulWidget {
  const SupportRequestsPage({
    super.key,
    required this.call,
    this.admin = false,
    this.openReference,
  });

  final SupportRequestCall call;
  final bool admin;
  final void Function(String kind, String id)? openReference;

  static Widget adminThread({
    required String id,
    required SupportRequestCall call,
    void Function(String kind, String id)? openReference,
  }) =>
      Builder(
        builder: (context) => _SupportThread(
          id: id,
          admin: true,
          call: call,
          openReference: openReference,
          onBack: () => Navigator.of(context).pop(),
        ),
      );

  @override
  State<SupportRequestsPage> createState() => _SupportRequestsPageState();
}

class _SupportRequestsPageState extends State<SupportRequestsPage> {
  List<Map<String, dynamic>> _tickets = [];
  String? _nextId;
  bool _loading = false;
  bool _failed = false;
  String? _status;
  String _searchQuery = '';
  final _searchController = TextEditingController();
  String? _selectedTicketId;

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

  Future<void> _load({bool more = false}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final result = await widget.call('list', {
        if (more) 'afterId': _nextId,
      });
      if (!mounted) return;
      final next = _maps(result['tickets']);
      final byId = {
        if (more)
          for (final ticket in _tickets) ticket['id']: ticket,
        for (final ticket in next) ticket['id']: ticket,
      };
      setState(() {
        _tickets = byId.values.toList();
        _nextId = result['nextId'] as String?;
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(String id) async {
    if (widget.admin) {
      setState(() => _selectedTicketId = id);
    } else {
      await Navigator.of(context).push<void>(MaterialPageRoute(
        builder: (_) => _SupportThread(
          id: id,
          admin: false,
          call: widget.call,
          openReference: widget.openReference,
        ),
      ));
      if (mounted) await _load();
    }
  }

  Future<void> _create() async {
    final id = await Navigator.of(context).push<String>(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _NewSupportRequest(call: widget.call),
    ));
    if (id != null && mounted) await _open(id);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.admin && _selectedTicketId != null) {
      return _SupportThread(
        id: _selectedTicketId!,
        admin: true,
        call: widget.call,
        openReference: widget.openReference,
        onBack: () {
          setState(() => _selectedTicketId = null);
          _load();
        },
      );
    }
    final query = _searchQuery.trim().toLowerCase();
    final rows = _tickets.where((ticket) {
      if (_status != null && ticket['status'] != _status) return false;
      if (query.isNotEmpty) {
        final title = (ticket['title'] as String? ?? '').toLowerCase();
        final member = (ticket['memberName'] as String? ?? '').toLowerCase();
        final category = (ticket['category'] as String? ?? '').toLowerCase();
        if (!title.contains(query) &&
            !member.contains(query) &&
            !category.contains(query)) {
          return false;
        }
      }
      return true;
    }).toList()
      ..sort((a, b) {
        if (widget.admin) {
          final priority = (a['status'] == 'Open' ? 0 : 1)
              .compareTo(b['status'] == 'Open' ? 0 : 1);
          if (priority != 0) return priority;
        }
        return (b['updatedAtMillis'] as int)
            .compareTo(a['updatedAtMillis'] as int);
      });

    return widget.admin ? _buildAdminQueue(rows) : _buildMemberHome(rows);
  }

  Widget _buildMemberHome(List<Map<String, dynamic>> rows) {
    final body = RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          // Header action banner
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF7C3AED), Color(0xFF5B21B6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.support_agent_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Need Help?',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Have an issue with membership, bookings, or payments? We are here to assist.',
                            style: TextStyle(
                              color: Color(0xFFE9D5FF),
                              fontSize: 13,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primaryDark,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    onPressed: _create,
                    icon: const Icon(Icons.add_rounded, size: 20),
                    label: const Text('Submit a request'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Section header with live count
          Row(
            children: [
              Text(
                'My requests',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                      fontSize: 18,
                    ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primaryTint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${rows.length}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const Spacer(),
              if (_loading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 12),

          if (_failed)
            const _RequestError(
                'Could not load support requests. Tap refresh to try again.'),

          if (!_loading && !_failed && rows.isEmpty)
            Container(
              margin: const EdgeInsets.symmetric(vertical: 24),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.hairline),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.inbox_outlined,
                      color: AppColors.inkSoft,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No support requests yet',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Any questions or issues you submit will appear here with full ticket history.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.inkSoft,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),

          for (final row in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Material(
                color: AppColors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: AppColors.hairline),
                ),
                child: InkWell(
                  onTap: () => _open(row['id'] as String),
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _CategoryPill(category: row['category'] as String),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                _StatusBadge(
                                  status: row['status'] as String,
                                  isMemberView: true,
                                ),
                                if (row['unread'] == true)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEE2E2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'New reply',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.danger,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          row['title'] as String,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                            letterSpacing: -0.1,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(
                              Icons.access_time_rounded,
                              size: 13,
                              color: AppColors.inkSoft,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                _date(row['updatedAtMillis']),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.inkSoft,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              size: 18,
                              color: AppColors.inkSoft,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          if (_nextId != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: OutlinedButton(
                  onPressed: _loading ? null : () => _load(more: true),
                  child: const Text('Load more requests'),
                ),
              ),
            ),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FC),
      appBar: AppBar(
        title: const Text('Help & Support'),
        centerTitle: false,
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 1,
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            tooltip: 'Refresh requests',
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: body,
    );
  }

  Widget _buildAdminQueue(List<Map<String, dynamic>> rows) {
    final statusCounts = <String, int>{
      'All': _tickets.length,
      'Open': _tickets.where((t) => t['status'] == 'Open').length,
      'Waiting for member':
          _tickets.where((t) => t['status'] == 'Waiting for member').length,
      'Resolved': _tickets.where((t) => t['status'] == 'Resolved').length,
    };

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
                // Admin Header
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Support Requests',
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
                            'Review, triage, and reply to member support inquiries.',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.inkSoft,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _loading ? null : _load,
                      tooltip: 'Refresh requests',
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Toolbar Card: Filter chips + Search input + Record count
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.hairline),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          // Status Filter Tabs
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final tab in [
                                'All',
                                'Open',
                                'Waiting for member',
                                'Resolved'
                              ]) ...[
                                _FilterChip(
                                  label: tab,
                                  count: statusCounts[tab] ?? 0,
                                  selected: (_status == null && tab == 'All') ||
                                      _status == tab,
                                  onSelected: () => setState(() =>
                                      _status = tab == 'All' ? null : tab),
                                ),
                              ],
                            ],
                          ),
                          // Search field
                          SizedBox(
                            width: isDesktop ? 300 : double.infinity,
                            height: 40,
                            child: TextField(
                              controller: _searchController,
                              onChanged: (val) =>
                                  setState(() => _searchQuery = val),
                              style: const TextStyle(fontSize: 13),
                              decoration: InputDecoration(
                                hintText: 'Search by subject or member...',
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
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                filled: true,
                                fillColor: const Color(0xFFF8F7FC),
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
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                      color: AppColors.primary),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Text(
                            'Showing ${rows.length} of ${_tickets.length} requests',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.inkSoft,
                            ),
                          ),
                          if (_searchQuery.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceAlt,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Filtered: "$_searchQuery"',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                if (_loading) const LinearProgressIndicator(),
                if (_failed)
                  const _RequestError(
                      'Could not load support requests. Refresh to try again.'),

                if (!_loading && !_failed && rows.isEmpty)
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 32),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 48),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.hairline),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: const BoxDecoration(
                            color: AppColors.surfaceAlt,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.support_agent_outlined,
                            color: AppColors.inkSoft,
                            size: 28,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isNotEmpty || _status != null
                              ? 'No matching support requests'
                              : 'No support requests in queue',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _searchQuery.isNotEmpty || _status != null
                              ? 'Try adjusting your search query or filter selection.'
                              : 'When members submit support tickets, they will appear in this workspace.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.inkSoft,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Support Queue Cards
                for (final row in rows)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Material(
                      color: AppColors.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: row['unread'] == true
                              ? AppColors.primarySoft.withValues(alpha: 0.5)
                              : AppColors.hairline,
                          width: row['unread'] == true ? 1.5 : 1.0,
                        ),
                      ),
                      child: InkWell(
                        onTap: () => _open(row['id'] as String),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Unread dot indicator
                              if (row['unread'] == true) ...[
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 12),
                              ],
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        _CategoryPill(
                                            category:
                                                row['category'] as String),
                                        const SizedBox(width: 8),
                                        _StatusBadge(
                                          status: row['status'] as String,
                                          isMemberView: false,
                                        ),
                                        if (row['unread'] == true) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppColors.primaryTint,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: const Text(
                                              'Unread update',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.primary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      row['title'] as String,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.ink,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 12,
                                      runSpacing: 4,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        if ((row['memberName'] as String? ?? '')
                                            .isNotEmpty)
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.person_outline,
                                                  size: 14,
                                                  color: AppColors.inkSoft),
                                              const SizedBox(width: 4),
                                              Text(
                                                row['memberName'] as String,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors.inkSoft,
                                                ),
                                              ),
                                            ],
                                          ),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                                Icons.access_time_rounded,
                                                size: 14,
                                                color: AppColors.inkSoft),
                                            const SizedBox(width: 4),
                                            Text(
                                              _date(row['updatedAtMillis']),
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: AppColors.inkSoft,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 10),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: () => _open(row['id'] as String),
                                icon: const Icon(Icons.open_in_new_rounded,
                                    size: 16),
                                label: const Text('View'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                if (_nextId != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: OutlinedButton(
                        onPressed: _loading ? null : () => _load(more: true),
                        child: const Text('Load more requests'),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onSelected,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : const Color(0xFFF1EEF8),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? Colors.white : AppColors.ink,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: selected
                    ? Colors.white.withValues(alpha: 0.25)
                    : AppColors.hairline,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : AppColors.inkSoft,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({required this.category});
  final String category;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Text(
        category,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.inkSoft,
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.status,
    required this.isMemberView,
  });

  final String status;
  final bool isMemberView;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color border;
    Color text;
    String label;
    IconData icon;

    if (status == 'Waiting for member') {
      bg = const Color(0xFFFFFBEB);
      border = const Color(0xFFFDE68A);
      text = const Color(0xFFB45309);
      label = isMemberView ? 'Your reply needed' : 'Waiting for member';
      icon = Icons.hourglass_top_rounded;
    } else if (status == 'Resolved') {
      bg = const Color(0xFFF0FDF4);
      border = const Color(0xFFBBF7D0);
      text = const Color(0xFF16A34A);
      label = 'Resolved';
      icon = Icons.check_circle_outline_rounded;
    } else {
      bg = const Color(0xFFF5F0FF);
      border = const Color(0xFFDDD6FE);
      text = AppColors.primary;
      label = 'Open';
      icon = Icons.pending_actions_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: text),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NewSupportRequest extends StatefulWidget {
  const _NewSupportRequest({required this.call});
  final SupportRequestCall call;

  @override
  State<_NewSupportRequest> createState() => _NewSupportRequestState();
}

class _NewSupportRequestState extends State<_NewSupportRequest> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _requestId = _newRequestId();
  String _category = 'Other';
  Map<String, dynamic>? _reference;
  List<Map<String, dynamic>> _references = [];
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadReferences();
  }

  Future<void> _loadReferences() async {
    try {
      final result = await widget.call('references', {});
      if (mounted) setState(() => _references = _maps(result['references']));
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Linked records could not be loaded. You can still submit a request.');
      }
    }
  }

  Future<void> _submit() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final result = await widget.call('create', {
        'requestId': _requestId,
        'title': _title.text.trim(),
        'body': _body.text.trim(),
        'category': _category,
        if (_reference != null)
          'reference': {'kind': _reference!['kind'], 'id': _reference!['id']},
      });
      if (mounted) Navigator.pop(context, result['id'] as String);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not submit your request. Please try again.';
        });
      }
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F7FC),
        appBar: AppBar(
          title: const Text('New support request'),
          centerTitle: false,
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.ink,
          elevation: 0,
          scrolledUnderElevation: 1,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: _saving ? null : () => Navigator.pop(context),
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: const Border(top: BorderSide(color: AppColors.hairline)),
              boxShadow: [
                BoxShadow(
                  color: AppColors.ink.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onPressed: _saving ? null : _submit,
                child: Text(_saving ? 'Submitting…' : 'Submit'),
              ),
            ),
          ),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: Form(
                  key: _form,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.hairline),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.ink.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'How can we help?',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Select an appropriate category and describe your inquiry in detail so we can assist you quickly.',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.inkSoft,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Category Dropdown
                        const Text(
                          'CATEGORY',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.inkSoft,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          initialValue: _category,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFFFBF9FF),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  const BorderSide(color: AppColors.hairline),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  const BorderSide(color: AppColors.hairline),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  const BorderSide(color: AppColors.primary),
                            ),
                          ),
                          items: [
                            for (final label in [
                              'Membership',
                              'Coach Booking',
                              'Payment & Refund',
                              'App Issue',
                              'Other'
                            ])
                              DropdownMenuItem(
                                  value: label, child: Text(label)),
                          ],
                          onChanged: _saving
                              ? null
                              : (value) => setState(() => _category = value!),
                        ),
                        const SizedBox(height: 16),

                        // Subject TextFormField (Index 0)
                        const Text(
                          'SUBJECT',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.inkSoft,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _title,
                          enabled: !_saving,
                          maxLength: 120,
                          decoration: InputDecoration(
                            labelText: 'Subject',
                            hintText: 'Brief summary of the issue',
                            filled: true,
                            fillColor: const Color(0xFFFBF9FF),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  const BorderSide(color: AppColors.hairline),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  const BorderSide(color: AppColors.hairline),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  const BorderSide(color: AppColors.primary),
                            ),
                          ),
                          validator: _required,
                        ),
                        const SizedBox(height: 10),

                        // Description TextFormField (Index 1)
                        const Text(
                          'DESCRIPTION',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.inkSoft,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _body,
                          enabled: !_saving,
                          minLines: 4,
                          maxLines: 6,
                          maxLength: 4000,
                          decoration: InputDecoration(
                            labelText: 'Describe your question or request',
                            hintText:
                                'Please provide relevant details, steps taken, or dates...',
                            filled: true,
                            fillColor: const Color(0xFFFBF9FF),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  const BorderSide(color: AppColors.hairline),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  const BorderSide(color: AppColors.hairline),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  const BorderSide(color: AppColors.primary),
                            ),
                          ),
                          validator: _required,
                        ),

                        // Optional Reference Linking
                        if (_references.isNotEmpty &&
                            _category != 'App Issue' &&
                            _category != 'Other') ...[
                          const SizedBox(height: 10),
                          const Text(
                            'LINKED BOOKING OR PAYMENT (OPTIONAL)',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.inkSoft,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<Map<String, dynamic>>(
                            key: ValueKey(_category),
                            initialValue: _reference,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: 'Link a booking or payment (optional)',
                              filled: true,
                              fillColor: const Color(0xFFFBF9FF),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide:
                                    const BorderSide(color: AppColors.hairline),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide:
                                    const BorderSide(color: AppColors.hairline),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide:
                                    const BorderSide(color: AppColors.primary),
                              ),
                            ),
                            items: [
                              const DropdownMenuItem(
                                  value: null, child: Text('No linked record')),
                              for (final reference in _references)
                                DropdownMenuItem(
                                  value: reference,
                                  child: Text(
                                    '${reference['kind']} · ${reference['label']}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            onChanged: _saving
                                ? null
                                : (value) => setState(() => _reference = value),
                          ),
                        ],

                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          _RequestError(_error!),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SupportThread extends StatefulWidget {
  const _SupportThread({
    required this.id,
    required this.admin,
    required this.call,
    this.openReference,
    this.onBack,
  });

  final String id;
  final bool admin;
  final VoidCallback? onBack;
  final SupportRequestCall call;
  final void Function(String kind, String id)? openReference;

  @override
  State<_SupportThread> createState() => _SupportThreadState();
}

class _SupportThreadState extends State<_SupportThread> {
  final _reply = TextEditingController();
  String _replyId = _newRequestId();
  Map<String, dynamic>? _ticket;
  List<Map<String, dynamic>> _messages = [];
  String? _beforeId;
  String? _error;
  bool _busy = false;
  bool _waitForMember = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool older = false}) => _run(() async {
        await _read(older: older);
      });

  Future<void> _read({bool older = false}) async {
    final result = await widget.call('detail', {
      'ticketId': widget.id,
      if (older) 'beforeId': _beforeId,
    });
    if (!mounted) return;
    final page = _maps(result['messages']);
    setState(() {
      _ticket = Map<String, dynamic>.from(result['ticket'] as Map);
      _messages = [...page, if (older) ..._messages];
      _beforeId = result['beforeId'] as String?;
    });
  }

  Future<void> _run(Future<void> Function() work) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await work();
    } catch (_) {
      if (mounted) {
        setState(
            () => _error = 'Could not complete this action. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _write(String action) => _run(() async {
        final replying = action == 'reply';
        await widget.call(action, {
          'ticketId': widget.id,
          'requestId': replying ? _replyId : _newRequestId(),
          if (replying) 'body': _reply.text.trim(),
          if (replying && widget.admin) 'waitForMember': _waitForMember,
        });
        if (!mounted) return;
        if (replying) {
          _reply.clear();
          _replyId = _newRequestId();
        }
        await _read();
      });

  Future<void> _handleResolve() async {
    if (_reply.text.trim().isNotEmpty) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Discard unsent draft?'),
          content: const Text(
              'You have an unsent reply draft. Resolving this request now will close the ticket without sending your draft. Proceed?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Resolve anyway'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    await _write('resolve');
  }

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ticket = _ticket;
    final reference = ticket?['reference'];
    final resolved = ticket?['status'] == 'Resolved';

    if (widget.admin) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8F7FC),
        body: Column(
          children: [
            _buildBreadcrumbBar(ticket),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (ticket == null && _busy) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (constraints.maxWidth >= 960) {
                    return _buildAdminDesktopWorkspace(
                        ticket, reference, resolved, constraints);
                  }

                  return _buildMobileOrSingleColumnWorkspace(
                      ticket, reference, resolved);
                },
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FC),
      appBar: AppBar(
        title: const Text('Support request'),
        centerTitle: false,
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 1,
        actions: [
          IconButton(
            onPressed: _busy ? null : _load,
            tooltip: 'Refresh conversation',
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (ticket == null && _busy) {
            return const Center(child: CircularProgressIndicator());
          }
          return _buildMobileOrSingleColumnWorkspace(
              ticket, reference, resolved);
        },
      ),
    );
  }

  Widget _buildBreadcrumbBar(Map<String, dynamic>? ticket) {
    final title = ticket?['title'] as String? ??
        (widget.id.length > 8
            ? 'Request #${widget.id.substring(0, 8)}'
            : 'Request #${widget.id}');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.hairline)),
      ),
      child: Row(
        children: [
          if (widget.onBack != null) ...[
            BackButton(
              color: AppColors.ink,
              onPressed: widget.onBack,
            ),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: widget.onBack,
                    borderRadius: BorderRadius.circular(6),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
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
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: AppColors.inkSoft,
                    ),
                  ),
                  InkWell(
                    onTap: widget.onBack,
                    borderRadius: BorderRadius.circular(6),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      child: Text(
                        'Support Requests',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: AppColors.inkSoft,
                    ),
                  ),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    child: Text(
                      title,
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
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20),
            color: AppColors.ink,
            tooltip: 'Refresh conversation',
            onPressed: _busy ? null : _load,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }

  /// Desktop Admin Workspace (68% Main Conversation + 32% Information Sidebar)
  Widget _buildAdminDesktopWorkspace(
    Map<String, dynamic>? ticket,
    dynamic reference,
    bool resolved,
    BoxConstraints constraints,
  ) {
    return Column(
      children: [
        if (_busy) const LinearProgressIndicator(),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: _RequestError(_error!),
          ),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Main Conversation Column (~68%)
              Expanded(
                flex: 68,
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildTicketHeaderCard(ticket, reference),
                      const SizedBox(height: 20),
                      if (_beforeId != null)
                        Center(
                          child: TextButton.icon(
                            onPressed: _busy ? null : () => _load(older: true),
                            icon: const Icon(Icons.history_rounded, size: 16),
                            label: const Text('Load earlier messages'),
                          ),
                        ),
                      const SizedBox(height: 8),
                      _buildMessageTimeline(),
                      const SizedBox(height: 24),
                      _buildReplyComposer(resolved),
                    ],
                  ),
                ),
              ),

              // Vertical Divider
              Container(width: 1, color: AppColors.hairline),

              // Request Information Sidebar (~32%)
              Expanded(
                flex: 32,
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildSidebarCard(ticket, reference, resolved),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Compact / Single Column Workspace for Mobile Member or Compact Viewport
  Widget _buildMobileOrSingleColumnWorkspace(
    Map<String, dynamic>? ticket,
    dynamic reference,
    bool resolved,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_busy) const LinearProgressIndicator(),
          if (_error != null) _RequestError(_error!),
          _buildTicketHeaderCard(ticket, reference),
          const SizedBox(height: 14),
          if (_beforeId != null)
            Center(
              child: TextButton.icon(
                onPressed: _busy ? null : () => _load(older: true),
                icon: const Icon(Icons.history_rounded, size: 16),
                label: const Text('Load earlier messages'),
              ),
            ),
          const SizedBox(height: 4),
          _buildMessageTimeline(),
          const SizedBox(height: 14),
          _buildReplyComposer(resolved),
          if (widget.admin) ...[
            const SizedBox(height: 16),
            _buildSidebarCard(ticket, reference, resolved),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildTicketHeaderCard(
      Map<String, dynamic>? ticket, dynamic reference) {
    if (ticket == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  ticket['title'] as String,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                        letterSpacing: -0.3,
                      ),
                ),
              ),
              const SizedBox(width: 8),
              _StatusBadge(
                status: ticket['status'] as String,
                isMemberView: !widget.admin,
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Subtitle with Category and Status preserved for tests
          Text(
            '${ticket['category']} · ${ticket['status']}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.inkSoft,
            ),
          ),
          if (widget.admin &&
              (ticket['memberName'] as String? ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.person_rounded,
                    size: 14, color: AppColors.inkSoft),
                const SizedBox(width: 4),
                Text(
                  'Submitted by ${ticket['memberName']}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.inkSoft,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
          if (reference is Map) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.hairline),
              ),
              child: Row(
                children: [
                  const Icon(Icons.link_rounded,
                      size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Linked ${reference['kind']}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                        SelectableText(
                          reference['id'] as String,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.inkSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.openReference != null &&
                      reference['kind'] == 'Payment')
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => widget.openReference!(
                          reference['kind'] as String,
                          reference['id'] as String),
                      child: const Text('View payment',
                          style: TextStyle(fontSize: 12)),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMessageTimeline() {
    return Column(
      children: [
        for (final entry in _messages) ...[
          _buildMessageBubble(entry),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> entry) {
    final role = entry['role'] as String? ?? 'Member';
    final isAdminMsg = role == 'Admin';
    final isSystemNotice =
        (entry['body'] as String? ?? '').contains('marked as resolved') ||
            (entry['body'] as String? ?? '').contains('Request reopened');

    if (isSystemNotice) {
      return Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFF1EEF8),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.hairline),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.info_outline_rounded,
                  size: 14, color: AppColors.inkSoft),
              const SizedBox(width: 6),
              Text(
                '${entry['body']} · ${_date(entry['createdAtMillis'])}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.inkSoft,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Alignment: In admin view, Admin messages align Right, Member Left.
    // In member view, Member messages align Right, Admin Left.
    final alignRight = widget.admin ? isAdminMsg : !isAdminMsg;

    return Align(
      alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: alignRight ? const Color(0xFFF5F0FF) : AppColors.surface,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(alignRight ? 16 : 4),
              bottomRight: Radius.circular(alignRight ? 4 : 16),
            ),
            border: Border.all(
              color: alignRight ? const Color(0xFFDDD6FE) : AppColors.hairline,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.ink.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 10,
                        backgroundColor:
                            isAdminMsg ? AppColors.primary : AppColors.inkSoft,
                        child: Icon(
                          isAdminMsg
                              ? Icons.support_agent_rounded
                              : Icons.person_rounded,
                          size: 12,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isAdminMsg
                            ? 'GainPath Support'
                            : (widget.admin
                                ? (_ticket?['memberName'] as String? ??
                                    'Member')
                                : 'You'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isAdminMsg ? AppColors.primary : AppColors.ink,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    _date(entry['createdAtMillis']),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.inkSoft,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SelectableText(
                entry['body'] as String,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReplyComposer(bool resolved) {
    if (resolved) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFBBF7D0)),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle_rounded,
                color: AppColors.success, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'This support request has been marked as resolved and closed.',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF166534),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.reply_rounded,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                widget.admin ? 'Reply to Member' : 'Write a reply',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Single TextField in _SupportThread to satisfy tests and accessibility
          TextField(
            controller: _reply,
            enabled: !_busy,
            onChanged: (_) => setState(() {}),
            minLines: 3,
            maxLines: 6,
            maxLength: 4000,
            decoration: InputDecoration(
              labelText: 'Write a reply',
              hintText: widget.admin
                  ? 'Type your response to the member...'
                  : 'Add more details or reply to support...',
              filled: true,
              fillColor: const Color(0xFFFBF9FF),
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
                borderSide: const BorderSide(color: AppColors.primary),
              ),
            ),
          ),
          if (widget.admin) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(
                color: _waitForMember
                    ? const Color(0xFFFFFBEB)
                    : const Color(0xFFF8F7FC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _waitForMember
                      ? const Color(0xFFFDE68A)
                      : AppColors.hairline,
                ),
              ),
              child: CheckboxListTile(
                value: _waitForMember,
                contentPadding: EdgeInsets.zero,
                dense: true,
                activeColor: AppColors.primary,
                title: const Text(
                  'Waiting for member response',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                subtitle: const Text(
                  'Sets ticket status to "Waiting for member" upon sending reply',
                  style: TextStyle(fontSize: 11, color: AppColors.inkSoft),
                ),
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _waitForMember = value == true),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: _busy || _reply.text.trim().isEmpty
                    ? null
                    : () => _write('reply'),
                icon: const Icon(Icons.send_rounded, size: 16),
                label: const Text(
                  'Send reply',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarCard(
    Map<String, dynamic>? ticket,
    dynamic reference,
    bool resolved,
  ) {
    if (ticket == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Ticket Info Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.hairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Request Information',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 14),
              _SidebarDetailRow(
                label: 'Status',
                valueWidget: _StatusBadge(
                  status: ticket['status'] as String,
                  isMemberView: false,
                ),
              ),
              const SizedBox(height: 10),
              _SidebarDetailRow(
                label: 'Category',
                valueText: ticket['category'] as String,
              ),
              if ((ticket['memberName'] as String? ?? '').isNotEmpty) ...[
                const SizedBox(height: 10),
                _SidebarDetailRow(
                  label: 'Member',
                  valueText: ticket['memberName'] as String,
                ),
              ],
              const SizedBox(height: 10),
              _SidebarDetailRow(
                label: 'Created',
                valueText: _date(ticket['createdAtMillis']),
              ),
              const SizedBox(height: 10),
              _SidebarDetailRow(
                label: 'Last Update',
                valueText: _date(ticket['updatedAtMillis']),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Administrative Actions Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.hairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Administrative Actions',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 12),
              if (!resolved)
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    elevation: 1,
                    shadowColor:
                        const Color(0xFF16A34A).withValues(alpha: 0.35),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: _busy ? null : _handleResolve,
                  icon: const Icon(Icons.check_circle_rounded,
                      size: 18, color: Colors.white),
                  label: const Text(
                    'Mark as resolved',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: Colors.white,
                    ),
                  ),
                ),
              if (resolved)
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 1,
                    shadowColor:
                        AppColors.primary.withValues(alpha: 0.35),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: _busy ? null : () => _write('reopen'),
                  icon: const Icon(Icons.replay_rounded,
                      size: 18, color: Colors.white),
                  label: const Text(
                    'Reopen request',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Collapsible Technical Details
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.hairline),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              initiallyExpanded: false,
              tilePadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              title: const Text(
                'Technical Details',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.inkSoft,
                ),
              ),
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Request ID:',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.inkSoft,
                      ),
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      widget.id,
                      style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: widget.id));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Request ID copied to clipboard'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded, size: 14),
                      label: const Text(
                        'Copy Request ID',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SidebarDetailRow extends StatelessWidget {
  const _SidebarDetailRow({
    required this.label,
    this.valueText,
    this.valueWidget,
  });

  final String label;
  final String? valueText;
  final Widget? valueWidget;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.inkSoft,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: valueWidget ??
              Text(
                valueText ?? '-',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
        ),
      ],
    );
  }
}

class _RequestError extends StatelessWidget {
  const _RequestError(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFFCA5A5)),
          ),
          child: Row(
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: AppColors.danger, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: AppColors.danger,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

List<Map<String, dynamic>> _maps(Object? values) => (values as List)
    .map((row) => Map<String, dynamic>.from(row as Map))
    .toList();

String? _required(String? text) =>
    text == null || text.trim().isEmpty ? 'This field is required.' : null;

String _newRequestId() => DateTime.now().microsecondsSinceEpoch.toString();

String _date(Object? millis) {
  if (millis is! int) return '—';
  final date = DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true)
      .add(const Duration(hours: 8));
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(date.day)}/${two(date.month)}/${date.year} ${two(date.hour)}:${two(date.minute)} MYT';
}
