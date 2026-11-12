import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../payment_review_repository.dart';

/// Workspace modes for financial operations.
enum PaymentsMode {
  transactions,
  refunds,
  reconciliation,
}

/// Professional financial operations console for GainPath Admin Web.
/// Separates routine Transactions, Refund Requests, and Reconciliation into
/// dedicated, desktop-optimized administration surfaces while maintaining a
/// single authoritative payment ledger.
class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({
    super.key,
    this.live = false,
    this.repository,
    this.isCurrent,
    this.mode = PaymentsMode.transactions,
    this.onNavigateMode,
    this.initialBookingId,
  });

  final bool live;
  final PaymentReviewRepository? repository;
  final bool Function()? isCurrent;
  final PaymentsMode mode;
  final ValueChanged<PaymentsMode>? onNavigateMode;
  final String? initialBookingId;

  @override
  State<PaymentsScreen> createState() => PaymentsScreenState();
}

/// Backward compatibility alias for existing test imports and routes.
typedef RefundsScreen = PaymentsScreen;
typedef RefundsScreenState = PaymentsScreenState;

class PaymentsScreenState extends State<PaymentsScreen> {
  late final PaymentReviewRepository? _repository = widget.repository ??
      (widget.live ? null : EmptyPaymentReviewRepository());
  PaymentsMode? _overrideMode;
  PaymentsMode get _mode => _overrideMode ?? widget.mode;
  PaymentReviewPage? _page;
  PaymentReviewDetail? _selected;
  String? _error;
  bool _loading = false;
  bool _processing = false;
  bool _showAllEvents = false;
  String _query = '';
  String _filter = 'All';
  final List<String?> _cursors = [null];
  int _pageIndex = 0;
  int _generation = 0;

  bool get _current => widget.isCurrent?.call() ?? !widget.live;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(PaymentsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode != widget.mode || _overrideMode != null) {
      setState(() {
        _overrideMode = null;
        _filter = 'All';
      });
    }
  }

  bool _valid(int generation) =>
      mounted && _current && generation == _generation;

  Future<void> _load() async {
    if (_repository == null || !_current) return;
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
      _page = null;
    });
    try {
      final page = await _repository.load(afterId: _cursors[_pageIndex]);
      if (_valid(generation)) {
        setState(() => _page = page);
        if (widget.initialBookingId != null && _selected == null) {
          final match = page.records
              .where((r) => r.id == widget.initialBookingId)
              .firstOrNull;
          if (match != null) {
            _open(match);
          }
        }
      }
    } catch (e) {
      if (_valid(generation)) setState(() => _error = _message(e));
    } finally {
      if (_valid(generation)) setState(() => _loading = false);
    }
  }

  Future<void> _open(PaymentReviewRecord record) async {
    if (_processing || _loading || !_current) return;
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
      _showAllEvents = false;
    });
    try {
      final detail = await _repository!.detail(record.id);
      if (_valid(generation)) setState(() => _selected = detail);
    } catch (e) {
      if (_valid(generation)) setState(() => _error = _message(e));
    } finally {
      if (_valid(generation)) setState(() => _loading = false);
    }
  }

  String _message(Object error) => error is PaymentReviewException
      ? error.toString()
      : 'Payment review could not be loaded. Refresh and try again.';

  void _switchMode(PaymentsMode newMode) {
    setState(() {
      _overrideMode = newMode;
      _filter = 'All';
    });
    widget.onNavigateMode?.call(newMode);
  }

  Future<void> _action(String action, String label, String consequence,
      {bool reason = false, String? identifier}) async {
    if (_processing || _loading || !_current) return;
    final bookingId = _selected!.payment.id;
    setState(() => _processing = true);
    final values = await showDialog<(String, String)>(
        context: context,
        builder: (_) => _PaymentActionDialog(
            label: label,
            consequence: consequence,
            requireReason: reason,
            identifier: identifier));
    if (!mounted) return;
    if (values == null || !_current) {
      setState(() => _processing = false);
      return;
    }
    final generation = ++_generation;
    setState(() => _error = null);
    try {
      final detail = await _repository!.manage(bookingId, action,
          requestId:
              '$bookingId-$action-${DateTime.now().microsecondsSinceEpoch}',
          reason: reason ? values.$1 : null,
          billId: action == 'recover_bill' ? values.$2 : null,
          refundOrderId: action == 'recover_refund' ? values.$2 : null);
      if (!_valid(generation)) return;
      setState(() => _selected = detail);
      final page = await _repository.load(afterId: _cursors[_pageIndex]);
      if (_valid(generation)) setState(() => _page = page);
    } catch (e) {
      if (_valid(generation)) setState(() => _error = _message(e));
    } finally {
      if (_valid(generation)) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_current || _repository == null) {
      return const Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(
              child: Text('Payment review requires a current Admin session.')));
    }
    return Scaffold(
        backgroundColor: Colors.transparent,
        body: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                    constraints.maxWidth < 600 ? 16 : 28,
                    20,
                    constraints.maxWidth < 600 ? 16 : 28,
                    40),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _header(context),
                      ..._feedback(),
                      const SizedBox(height: 14),
                      if (constraints.maxWidth >= 1200 && _selected != null)
                        _masterDetailLayout(context, constraints)
                      else if (_selected != null)
                        ..._detail(context, _selected!)
                      else
                        ..._list(context, constraints),
                    ]))));
  }

  Widget _header(BuildContext context) {
    final title = switch (_mode) {
      PaymentsMode.transactions => 'Transactions',
      PaymentsMode.refunds => 'Refund Requests',
      PaymentsMode.reconciliation => 'Reconciliation',
    };
    final subtitle = switch (_mode) {
      PaymentsMode.transactions =>
        'Track membership and coaching payments across facilities.',
      PaymentsMode.refunds =>
        'Review, approve, and manage member refund requests with audit evidence.',
      PaymentsMode.reconciliation =>
        'Investigate uncertain bills and resolve payment exceptions safely.',
    };

    final records = _page?.records ?? [];
    final pendingRefunds = records
        .where((r) =>
            r.text('refundStatus') == 'pending_review' ||
            (r.needsReview && r.text('paymentStatus') == 'cleared'))
        .length;
    final reconciliationCount = records.where((r) => r.needsReview).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(title,
                          style: Theme.of(context).textTheme.headlineMedium),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          widget.live ? 'Sandbox Live' : 'Sandbox (Demo)',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
            OutlinedButton.icon(
              onPressed: _loading || _processing ? null : _load,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Refresh'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 38),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        // Sub-tabs segment row for instantaneous workflow switching
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _subTabButton(
                icon: Icons.receipt_long_rounded,
                label: 'Transactions',
                selected: _mode == PaymentsMode.transactions,
                onTap: () => _switchMode(PaymentsMode.transactions),
              ),
              const SizedBox(width: 8),
              _subTabButton(
                icon: Icons.assignment_return_rounded,
                label: 'Refund Requests',
                badgeCount: pendingRefunds,
                badgeColor: AppColors.danger,
                selected: _mode == PaymentsMode.refunds,
                onTap: () => _switchMode(PaymentsMode.refunds),
              ),
              const SizedBox(width: 8),
              _subTabButton(
                icon: Icons.troubleshoot_rounded,
                label: 'Reconciliation',
                badgeCount: reconciliationCount,
                badgeColor: const Color(0xFFE65100),
                selected: _mode == PaymentsMode.reconciliation,
                onTap: () => _switchMode(PaymentsMode.reconciliation),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _subTabButton({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
    int? badgeCount,
    Color? badgeColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.12)
              : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.hairline,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 16,
                color: selected ? AppColors.primary : AppColors.inkSoft),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? AppColors.primary : AppColors.ink,
              ),
            ),
            if (badgeCount != null && badgeCount > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: (badgeColor ?? AppColors.primary)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$badgeCount',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: badgeColor ?? AppColors.primary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _feedback() => [
        if (_loading || _processing)
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator()),
        if (_error != null)
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Semantics(
                  liveRegion: true,
                  child: Panel(
                      background: AppColors.dangerTint,
                      child: Text(_error!,
                          style: const TextStyle(color: AppColors.danger))))),
      ];

  List<PaymentReviewRecord> _filteredRecords(List<PaymentReviewRecord> records) {
    return records.where((r) {
      if (_mode == PaymentsMode.refunds && !r.isRefundCase) return false;
      if (_mode == PaymentsMode.reconciliation && !r.isReconciliationCase) {
        return false;
      }

      final query = _query.trim().toLowerCase();
      if (query.isNotEmpty) {
        final match =
            '${r.id} ${r.businessTitle} ${r.memberDisplay} ${r.text('memberId')} ${r.text('coachName')} ${r.text('branchName')} ${r.text('billId')} ${r.text('planName')}'
                .toLowerCase()
                .contains(query);
        if (!match) return false;
      }

      if (_filter == 'All') return true;

      if (_mode == PaymentsMode.transactions) {
        if (_filter == 'Membership') return r.isMembership;
        if (_filter == 'Coaching') return !r.isMembership;
        if (_filter == 'Paid & verified') {
          return r.text('paymentStatus') == 'cleared';
        }
        if (_filter == 'Pending payment') {
          return r.text('paymentStatus') == 'pending';
        }
      } else if (_mode == PaymentsMode.refunds) {
        if (_filter == 'Pending Review') {
          return r.text('refundStatus') == 'pending_review' ||
              (r.needsReview && r.text('paymentStatus') == 'cleared');
        }
        if (_filter == 'Approved') return r.text('refundStatus') == 'approved';
        if (_filter == 'Processing / Completed') {
          return ['processing', 'completed'].contains(r.text('refundStatus'));
        }
        if (_filter == 'Declined') return r.text('refundStatus') == 'rejected';
      } else if (_mode == PaymentsMode.reconciliation) {
        if (_filter == 'Fulfillment Review') {
          return r.text('fulfilmentStatus') == 'reconciliation_required';
        }
        if (_filter == 'Uncertain Bills') {
          return r.text('resolutionReason') == 'bill_creation_uncertain' ||
              r.text('refundStatus') == 'uncertain';
        }
      }

      // Backward compatibility filters
      if (_filter == 'Reconciliation') return r.needsReview;
      if (_filter == 'Refunds') return r.isRefundCase;
      if (_filter == 'Pending payment') {
        return r.text('paymentStatus') == 'pending';
      }

      return true;
    }).toList();
  }

  List<Widget> _list(BuildContext context, BoxConstraints constraints) {
    final records = _page?.records ?? [];
    final visible = _filteredRecords(records);
    final isUnconnected =
        _page == null || _repository is EmptyPaymentReviewRepository;

    return [
      _buildMetricsStrip(context, records, isUnconnected),
      const SizedBox(height: 6),
      Text(
        'Operational queue metrics reflect the currently loaded batch (${records.length} records). For whole-facility 30-day revenue analytics and CSV export, see Reports.',
        style: const TextStyle(color: AppColors.inkSoft, fontSize: 11.5),
      ),
      const SizedBox(height: 14),
      _buildSearchAndFilters(records),
      const SizedBox(height: 12),
      if (!_loading && _error == null && visible.isEmpty)
        Panel(
            child: Text(records.isEmpty
                ? 'No payments on this page.'
                : 'No transactions match this page’s search and filter.'))
      else if (constraints.maxWidth >= 768)
        _buildDesktopTable(context, visible)
      else
        _buildResponsiveCards(context, visible),
      const SizedBox(height: 14),
      _buildPagination(),
    ];
  }

  Widget _buildMetricsStrip(
      BuildContext context, List<PaymentReviewRecord> records, bool isUnconnected) {
    final clearedAmount = records
        .where((r) => r.text('paymentStatus') == 'cleared')
        .fold<int>(0, (sum, r) => sum + r.amountMinor);
    final totalVolume = records.fold<int>(0, (sum, r) => sum + r.amountMinor);
    final pendingCheckoutCount =
        records.where((r) => r.text('paymentStatus') == 'pending').length;
    final reconciliationCount = records.where((r) => r.needsReview).length;
    final pendingRefundsCount = records
        .where((r) =>
            r.text('refundStatus') == 'pending_review' ||
            (r.needsReview && r.text('paymentStatus') == 'cleared'))
        .length;
    final approvedRefundsCount =
        records.where((r) => r.text('refundStatus') == 'approved').length;
    final completedRefundsCount =
        records.where((r) => r.text('refundStatus') == 'completed').length;
    final rejectedRefundsCount =
        records.where((r) => r.text('refundStatus') == 'rejected').length;
    final activationReviewCount = records
        .where((r) => r.text('fulfilmentStatus') == 'reconciliation_required')
        .length;
    final uncertainBillsCount = records
        .where((r) =>
            r.text('resolutionReason') == 'bill_creation_uncertain' ||
            r.text('refundStatus') == 'uncertain')
        .length;
    final resolvedCount = records
        .where((r) =>
            r.text('paymentStatus') == 'cleared' &&
            r.text('fulfilmentStatus') == 'confirmed')
        .length;

    return LayoutBuilder(builder: (context, metricConstraints) {
      final isNarrow = metricConstraints.maxWidth < 740;
      final tileWidth = isNarrow
          ? (metricConstraints.maxWidth < 420
              ? metricConstraints.maxWidth
              : (metricConstraints.maxWidth - 10) / 2)
          : (metricConstraints.maxWidth - 30) / 4;

      if (_mode == PaymentsMode.refunds) {
        return Wrap(spacing: 10, runSpacing: 10, children: [
          SizedBox(
              width: tileWidth,
              child: StatTile(
                  isUnconnected ? '—' : '$pendingRefundsCount',
                  'Pending refund review · loaded queue',
                  valueColor: pendingRefundsCount > 0 ? AppColors.danger : null,
                  compact: true)),
          SizedBox(
              width: tileWidth,
              child: StatTile(
                  isUnconnected ? '—' : '$approvedRefundsCount',
                  'Approved · pending execution',
                  valueColor: AppColors.primary,
                  compact: true)),
          SizedBox(
              width: tileWidth,
              child: StatTile(
                  isUnconnected ? '—' : '$completedRefundsCount',
                  'Completed refunds · loaded queue',
                  compact: true)),
          SizedBox(
              width: tileWidth,
              child: StatTile(
                  isUnconnected ? '—' : '$rejectedRefundsCount',
                  'Declined requests · loaded queue',
                  compact: true)),
        ]);
      }

      if (_mode == PaymentsMode.reconciliation) {
        return Wrap(spacing: 10, runSpacing: 10, children: [
          SizedBox(
              width: tileWidth,
              child: StatTile(
                  isUnconnected ? '—' : '$reconciliationCount',
                  'Total exceptions · loaded queue',
                  valueColor:
                      reconciliationCount > 0 ? const Color(0xFFE65100) : null,
                  compact: true)),
          SizedBox(
              width: tileWidth,
              child: StatTile(
                  isUnconnected ? '—' : '$activationReviewCount',
                  'Fulfillment review · loaded queue',
                  compact: true)),
          SizedBox(
              width: tileWidth,
              child: StatTile(
                  isUnconnected ? '—' : '$uncertainBillsCount',
                  'Uncertain provider bills',
                  compact: true)),
          SizedBox(
              width: tileWidth,
              child: StatTile(
                  isUnconnected ? '—' : '$resolvedCount',
                  'Verified / Settled · loaded queue',
                  valueColor: const Color(0xFF2E7D32),
                  compact: true)),
        ]);
      }

      // Default: Transactions mode
      return Wrap(spacing: 10, runSpacing: 10, children: [
        SizedBox(
            width: tileWidth,
            child: StatTile(
                isUnconnected
                    ? '—'
                    : 'RM ${(clearedAmount / 100).toStringAsFixed(2)}',
                'Confirmed payments · loaded queue',
                valueColor: AppColors.primary,
                compact: true)),
        SizedBox(
            width: tileWidth,
            child: StatTile(
                isUnconnected
                    ? '—'
                    : 'RM ${(totalVolume / 100).toStringAsFixed(2)}',
                'Total volume · loaded queue',
                compact: true)),
        SizedBox(
            width: tileWidth,
            child: StatTile(
                isUnconnected ? '—' : '$pendingCheckoutCount',
                'Pending checkout · loaded queue',
                compact: true)),
        SizedBox(
            width: tileWidth,
            child: StatTile(
                isUnconnected ? '—' : '$reconciliationCount',
                'Operational exceptions · loaded queue',
                valueColor:
                    reconciliationCount > 0 ? const Color(0xFFE65100) : null,
                compact: true)),
      ]);
    });
  }

  Widget _buildSearchAndFilters(List<PaymentReviewRecord> records) {
    List<String> filters;
    if (_mode == PaymentsMode.refunds) {
      filters = [
        'All',
        'Pending Review',
        'Approved',
        'Processing / Completed',
        'Declined'
      ];
    } else if (_mode == PaymentsMode.reconciliation) {
      filters = [
        'All',
        'Fulfillment Review',
        'Uncertain Bills',
      ];
    } else {
      filters = [
        'All',
        'Membership',
        'Coaching',
        'Paid & verified',
        'Pending payment',
      ];
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
            onChanged: (value) => setState(() => _query = value),
            decoration: const InputDecoration(
                labelText: 'Search records',
                hintText: 'Transaction, member, coach, branch or bill ID',
                prefixIcon: Icon(Icons.search_rounded))),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final filter in filters)
            ChoiceChip(
                label: Text(filter),
                selected: _filter == filter,
                selectedColor: AppColors.primary,
                onSelected: (_) => setState(() => _filter = filter)),
        ]),
      ],
    );
  }

  Widget _buildDesktopTable(
      BuildContext context, List<PaymentReviewRecord> visible) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Table Header
          Container(
            color: AppColors.surfaceAlt,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: Text('Transaction / Title',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.inkSoft)),
                ),
                Expanded(
                  flex: 3,
                  child: Text('Member',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.inkSoft)),
                ),
                Expanded(
                  flex: 2,
                  child: Text('Amount',
                      textAlign: TextAlign.right,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.inkSoft)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  flex: 3,
                  child: Text(
                      _mode == PaymentsMode.refunds
                          ? 'Refund Status'
                          : _mode == PaymentsMode.reconciliation
                              ? 'Exception Issue'
                              : 'Payment Status',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.inkSoft)),
                ),
                Expanded(
                  flex: 3,
                  child: Text('Date / Time',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.inkSoft)),
                ),
                SizedBox(
                  width: 90,
                  child: Text('Action',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.inkSoft)),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.hairline),
          // Table Rows
          for (var i = 0; i < visible.length; i++) ...[
            _tableRow(context, visible[i]),
            if (i < visible.length - 1)
              const Divider(height: 1, color: AppColors.hairline),
          ],
        ],
      ),
    );
  }

  Widget _tableRow(BuildContext context, PaymentReviewRecord r) {
    final isSelected = _selected?.payment.id == r.id;
    return InkWell(
      onTap: _loading || _processing ? null : () => _open(r),
      child: Container(
        color: isSelected ? AppColors.primary.withValues(alpha: 0.08) : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Transaction / Title
            Expanded(
              flex: 4,
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: r.isMembership
                          ? const Color(0xFFF3E5F5)
                          : const Color(0xFFE3F2FD),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      r.isMembership
                          ? Icons.badge_outlined
                          : Icons.fitness_center_rounded,
                      color: r.isMembership
                          ? const Color(0xFF7B1FA2)
                          : const Color(0xFF1976D2),
                      size: 17,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.businessTitle,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                r.id,
                                style: const TextStyle(
                                    fontSize: 11, color: AppColors.inkSoft),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            InkWell(
                              onTap: () => Clipboard.setData(
                                  ClipboardData(text: r.id)),
                              child: const Icon(Icons.copy_rounded,
                                  size: 12, color: AppColors.inkSoft),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Member
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.memberDisplay,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w500)),
                  Text(
                    r.isMembership ? r.text('kind') : r.text('coachName'),
                    style:
                        const TextStyle(fontSize: 11, color: AppColors.inkSoft),
                  ),
                ],
              ),
            ),
            // Amount
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(r.amount,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700)),
                  if (r.hasPremiumVoucher)
                    const Text('Voucher applied',
                        style: TextStyle(
                            fontSize: 10.5,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const SizedBox(width: 14),
            // Status Badges
            Expanded(
              flex: 3,
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  if (_mode == PaymentsMode.refunds)
                    _badge(
                        r.refundLifecycleLabel ?? 'Pending Review',
                        AppColors.danger,
                        AppColors.dangerTint)
                  else if (_mode == PaymentsMode.reconciliation)
                    _badge(r.reconciliationCategory, const Color(0xFFE65100),
                        const Color(0xFFFFF3E0))
                  else ...[
                    _badge(
                        r.paymentLifecycleLabel,
                        r.text('paymentStatus') == 'cleared'
                            ? const Color(0xFF2E7D32)
                            : const Color(0xFF1565C0),
                        r.text('paymentStatus') == 'cleared'
                            ? const Color(0xFFE8F5E9)
                            : const Color(0xFFE3F2FD)),
                    if (r.text('fulfilmentStatus') != 'confirmed')
                      _badge(r.fulfillmentLifecycleLabel,
                          const Color(0xFFE65100), const Color(0xFFFFF3E0)),
                  ],
                ],
              ),
            ),
            // Date / Schedule
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.isMembership ? r.formattedDate : r.sessionSchedule,
                    style: const TextStyle(fontSize: 12, color: AppColors.ink),
                  ),
                  if (!r.isMembership)
                    Text('Recorded: ${r.formattedDate}',
                        style: const TextStyle(
                            fontSize: 10.5, color: AppColors.inkSoft)),
                ],
              ),
            ),
            // Action
            SizedBox(
              width: 90,
              child: OutlinedButton(
                onPressed: _loading || _processing ? null : () => _open(r),
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  minimumSize: const Size(0, 32),
                ),
                child: Text(
                  _mode == PaymentsMode.refunds
                      ? 'Review'
                      : _mode == PaymentsMode.reconciliation
                          ? 'Investigate'
                          : 'Details',
                  style: const TextStyle(fontSize: 11.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResponsiveCards(
      BuildContext context, List<PaymentReviewRecord> visible) {
    return Column(
      children: [
        for (final record in visible)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Panel(
              onTap: _loading || _processing ? null : () => _open(record),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: record.isMembership
                              ? const Color(0xFFF3E5F5)
                              : const Color(0xFFE3F2FD),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          record.isMembership
                              ? Icons.badge_outlined
                              : Icons.fitness_center_rounded,
                          color: record.isMembership
                              ? const Color(0xFF7B1FA2)
                              : const Color(0xFF1976D2),
                          size: 19,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(record.businessTitle,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14)),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                      color: AppColors.surfaceAlt,
                                      borderRadius: BorderRadius.circular(4)),
                                  child: Text(
                                    record.isMembership
                                        ? 'Membership'
                                        : 'Coaching',
                                    style: const TextStyle(
                                        fontSize: 10.5,
                                        color: AppColors.inkSoft,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Wrap(
                              spacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  record.id,
                                  style: const TextStyle(
                                      fontSize: 12, color: AppColors.inkSoft),
                                ),
                                const Text('·',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.inkSoft)),
                                Text(
                                  record.memberDisplay,
                                  style: const TextStyle(
                                      fontSize: 12, color: AppColors.inkSoft),
                                ),
                              ],
                            ),
                            Text(
                              record.isMembership
                                  ? '${record.text('planName')} · Organization-wide'
                                  : record.sessionSchedule,
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.ink),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(record.amount,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 15)),
                          if (record.hasPremiumVoucher)
                            const Text('Voucher applied',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, runSpacing: 4, children: [
                    _badge(
                        record.paymentLifecycleLabel,
                        record.text('paymentStatus') == 'cleared'
                            ? const Color(0xFF2E7D32)
                            : const Color(0xFF1565C0),
                        record.text('paymentStatus') == 'cleared'
                            ? const Color(0xFFE8F5E9)
                            : const Color(0xFFE3F2FD)),
                    _badge(
                        record.fulfillmentLifecycleLabel,
                        record.text('fulfilmentStatus') == 'confirmed'
                            ? AppColors.ink
                            : const Color(0xFFE65100),
                        record.text('fulfilmentStatus') == 'confirmed'
                            ? AppColors.surfaceAlt
                            : const Color(0xFFFFF3E0)),
                    if (record.refundLifecycleLabel != null)
                      _badge(record.refundLifecycleLabel!, AppColors.danger,
                          AppColors.dangerTint),
                  ]),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPagination() {
    return Wrap(
      spacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        OutlinedButton(
            onPressed: _pageIndex == 0 || _loading || _processing
                ? null
                : () {
                    setState(() => _pageIndex--);
                    _load();
                  },
            child: const Text('Previous')),
        Text('Page ${_pageIndex + 1} · search and counts apply to this page'),
        OutlinedButton(
            onPressed: _page?.nextAfterId == null || _loading || _processing
                ? null
                : () {
                    final next = _page!.nextAfterId;
                    setState(() {
                      if (_cursors.length > _pageIndex + 1) {
                        _cursors.removeRange(_pageIndex + 1, _cursors.length);
                      }
                      _cursors.add(next);
                      _pageIndex++;
                    });
                    _load();
                  },
            child: const Text('Next')),
      ],
    );
  }

  Widget _masterDetailLayout(
      BuildContext context, BoxConstraints constraints) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _list(context, constraints),
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          flex: 5,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.hairline),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Financial Detail',
                        style: Theme.of(context).textTheme.titleMedium),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => setState(() => _selected = null),
                      tooltip: 'Close details',
                    ),
                  ],
                ),
                const Divider(height: 20),
                ..._detailContent(context, _selected!),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _detail(BuildContext context, PaymentReviewDetail detail) {
    final r = detail.payment;
    final backLabel = switch (_mode) {
      PaymentsMode.transactions => 'Transactions',
      PaymentsMode.refunds => 'Refund Requests',
      PaymentsMode.reconciliation => 'Reconciliation',
    };

    return [
      Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
        TextButton.icon(
            onPressed: _processing || _loading
                ? null
                : () => setState(() {
                      _selected = null;
                      _error = null;
                    }),
            icon: const Icon(Icons.arrow_back_rounded, size: 16),
            label: Text('Back to $backLabel')),
        const SizedBox(width: 8),
        Text('· ${r.businessTitle} (${r.id})',
            style: const TextStyle(fontWeight: FontWeight.w600)),
      ]),
      const SizedBox(height: 14),
      ..._detailContent(context, detail),
      const SizedBox(height: 16),
      OutlinedButton.icon(
          onPressed: _processing || _loading ? null : () => _open(r),
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Refresh payment')),
    ];
  }

  List<Widget> _detailContent(
      BuildContext context, PaymentReviewDetail detail) {
    final r = detail.payment;
    final events = detail.events;
    final visibleEvents = _showAllEvents ? events : events.take(5).toList();

    return [
      // Cross-Navigation Banner
      _buildCrossNavigationBanner(r),
      const SizedBox(height: 12),
      // Summary Card
      Panel(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.businessTitle,
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 2),
                      Wrap(
                        spacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text('ID: ${r.id}',
                              style: const TextStyle(
                                  color: AppColors.inkSoft, fontSize: 12)),
                          InkWell(
                            onTap: () => Clipboard.setData(
                                ClipboardData(text: r.id)),
                            child: const Icon(Icons.copy_rounded,
                                size: 13, color: AppColors.inkSoft),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Text(r.amount,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 20)),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(spacing: 6, runSpacing: 4, children: [
              _badge(
                  r.paymentLifecycleLabel,
                  r.text('paymentStatus') == 'cleared'
                      ? const Color(0xFF2E7D32)
                      : const Color(0xFF1565C0),
                  r.text('paymentStatus') == 'cleared'
                      ? const Color(0xFFE8F5E9)
                      : const Color(0xFFE3F2FD)),
              _badge(
                  r.fulfillmentLifecycleLabel,
                  r.text('fulfilmentStatus') == 'confirmed'
                      ? AppColors.ink
                      : const Color(0xFFE65100),
                  r.text('fulfilmentStatus') == 'confirmed'
                      ? AppColors.surfaceAlt
                      : const Color(0xFFFFF3E0)),
              if (r.refundLifecycleLabel != null)
                _badge(r.refundLifecycleLabel!, AppColors.danger,
                    AppColors.dangerTint),
            ]),
            const SizedBox(height: 10),
            Text(r.refundExplanation,
                style:
                    const TextStyle(fontSize: 12.5, color: AppColors.inkSoft)),
          ])),
      const SizedBox(height: 16),
      const Eyebrow('Payment & Financial Breakdown'),
      Panel(
          child: Column(children: [
        DetailRow('Member ID', r.text('memberId')),
        if (r.text('memberDisplayName').isNotEmpty)
          DetailRow('Member', r.text('memberDisplayName')),
        const Divider(height: 20),
        DetailRow(r.isMembership ? 'Membership plan' : 'Booked session',
            r.isMembership ? r.text('planName') : r.sessionSchedule),
        if (r.text('bookingStatus').isNotEmpty)
          DetailRow('Booking status', _label(r.text('bookingStatus'))),
        if (r.text('cancellationReason').isNotEmpty)
          DetailRow('Cancellation reason', r.text('cancellationReason')),
        if (r.data['cancelledAtMillis'] != null)
          DetailRow('Cancelled', _time(r.data['cancelledAtMillis'])),
        const Divider(height: 20),
        DetailRow('Payment type',
            r.isMembership ? r.text('kind') : 'CoachingBooking'),
        if (r.hasPremiumVoucher) ...[
          const Divider(height: 20),
          DetailRow('Original booking fee', r.originalAmount),
          DetailRow('Premium voucher discount', r.voucherDiscount),
          DetailRow(
              r.text('paymentStatus') == 'cleared'
                  ? 'Amount collected'
                  : 'Checkout amount',
              r.amount),
          DetailRow('Voucher finance', r.voucherFinanceReference),
          const SizedBox(height: 4),
          const Text(
              'Refund review uses the amount collected. Voucher reinstatement is unavailable.',
              style: TextStyle(fontSize: 11, color: AppColors.inkSoft)),
        ],
        const Divider(height: 20),
        DetailRow('Created date', r.formattedDate),
        DetailRow('Last updated', _time(r.data['updatedAtMillis'])),
        if (r.data['reviewedAtMillis'] != null)
          DetailRow('Admin decision', _time(r.data['reviewedAtMillis'])),
        if (r.data['refundReservedAtMillis'] != null)
          DetailRow('Refund attempted', _time(r.data['refundReservedAtMillis'])),
        if (r.text('refundReference').isNotEmpty)
          DetailRow('Refund reference', r.text('refundReference')),
        if (r.text('refundProviderStatus').isNotEmpty)
          DetailRow('Provider status', r.text('refundProviderStatus')),
        const Divider(height: 20),
        if (!r.isMembership)
          DetailRow('Coach / branch',
              '${r.text('coachName')} / ${r.text('branchName')}'),
        if (r.isMembership) DetailRow('Scope', 'Organization-wide'),
        if (r.text('refundReason').isNotEmpty)
          DetailRow('Member reason', r.text('refundReason')),
        if (r.text('refundNotes').isNotEmpty)
          DetailRow('Member notes', r.text('refundNotes')),
        const Divider(height: 20),
        DetailRow(
            'Provider bill ID',
            r.text('billId').isEmpty
                ? 'Unknown — recovery required'
                : r.text('billId')),
        const Divider(height: 20),
        DetailRow(
            'Payment Order ID',
            r.text('refundOrderId').isEmpty
                ? 'None recorded'
                : r.text('refundOrderId')),
        const Divider(height: 20),
        DetailRow(
            'Resolution reason',
            r.text('resolutionReason').isEmpty
                ? 'None recorded'
                : r.text('resolutionReason')),
        if (r.text('reviewReason').isNotEmpty) ...[
          const Divider(height: 20),
          DetailRow('Review note', r.text('reviewReason'))
        ],
      ])),
      const SizedBox(height: 16),
      // Safe Action Buttons
      Wrap(spacing: 10, runSpacing: 10, children: [
        if (r.text('billId').isNotEmpty)
          _button(
              'Verify payment',
              () => _action('verify', 'Verify payment',
                  'Read provider status and reconcile this payment. This does not create another bill.')),
        if (r.text('billId').isEmpty && r.text('paymentStatus') == 'pending')
          _button(
              'Recover bill',
              () => _action('recover_bill', 'Recover bill',
                  'Attach an existing provider bill only after the server verifies its transaction reference, collection and amount. This never creates another bill.',
                  reason: true, identifier: 'Provider bill ID')),
        if (r.canDecide) ...[
          if (r.text('refundStatus') != 'approved')
            _button(
                'Approve refund',
                () => _action('approve_refund', 'Approve refund',
                    'Record approval for this paid reconciliation case. Approval alone does not issue a refund or change membership access.',
                    reason: true)),
          _button(
              'Reject refund',
              () => _action('reject_refund', 'Reject refund',
                  'Record rejection and its reason. The paid booking remains in reconciliation for follow-up.',
                  reason: true)),
        ],
        if (r.text('refundStatus') == 'approved' &&
            detail.refundExecutionAvailable)
          _button(
              'Execute sandbox refund',
              () => _action('execute_refund', 'Execute sandbox refund',
                  'Create a Sandbox Payment Order using dummy-bank details. This simulates a refund and never moves real money. Do not repeat while the outcome is uncertain.',
                  reason: true)),
        if (['processing', 'uncertain'].contains(r.text('refundStatus'))) ...[
          if (r.text('refundOrderId').isNotEmpty)
            _button(
                'Check refund status',
                () => _action('check_refund', 'Check refund status',
                    'Read the existing Payment Order status without creating another refund.')),
          if (r.text('refundOrderId').isEmpty)
            _button(
                'Recover Payment Order',
                () => _action('recover_refund', 'Recover Payment Order',
                    'Attach an existing Sandbox Payment Order. The server verifies the collection, refund reference, full amount and dummy destination before checking status.',
                    reason: true, identifier: 'Provider Payment Order ID')),
        ],
      ]),
      if (!detail.refundExecutionAvailable)
        const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
                'Sandbox refund execution is not configured. Approval records a decision only.',
                style: TextStyle(fontSize: 11.5, color: AppColors.inkSoft))),
      const SizedBox(height: 20),
      // Audit Timeline
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Eyebrow('Payment audit history'),
          if (events.length > 5)
            TextButton(
              onPressed: () =>
                  setState(() => _showAllEvents = !_showAllEvents),
              child: Text(_showAllEvents
                  ? 'Show recent 5'
                  : 'View all (${events.length})'),
            ),
        ],
      ),
      Panel(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            if (events.isEmpty)
              const Text('No payment events recorded.')
            else
              for (var i = 0; i < visibleEvents.length; i++)
                _timelineEvent(visibleEvents[i], i == visibleEvents.length - 1),
          ])),
    ];
  }

  Widget _buildCrossNavigationBanner(PaymentReviewRecord r) {
    if (_mode == PaymentsMode.transactions) {
      if (r.isRefundCase) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFFBE9E7),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFFFCCBC)),
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Icon(Icons.assignment_return_rounded,
                      color: AppColors.danger, size: 18),
                  Text(
                    'Linked refund case: ${r.refundLifecycleLabel ?? 'Pending Review'}',
                    style: const TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: () => _switchMode(PaymentsMode.refunds),
                icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                label: const Text('View in Refund Requests',
                    style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        );
      }
      if (r.isReconciliationCase) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3E0),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFFFE0B2)),
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Icon(Icons.troubleshoot_rounded,
                      color: Color(0xFFE65100), size: 18),
                  Text(
                    'Operational exception: ${r.reconciliationCategory}',
                    style: const TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: () => _switchMode(PaymentsMode.reconciliation),
                icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                label: const Text('Investigate in Reconciliation',
                    style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        );
      }
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.hairline),
        ),
        child: Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.spaceBetween,
          children: [
            const Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Icon(Icons.receipt_long_rounded,
                    color: AppColors.primary, size: 18),
                Text(
                  'Original authoritative payment ledger record',
                  style:
                      TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            TextButton.icon(
              onPressed: () => _switchMode(PaymentsMode.transactions),
              icon: const Icon(Icons.arrow_forward_rounded, size: 14),
              label: const Text('View in Transactions',
                  style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _timelineEvent(Map<String, dynamic> event, bool isLast) {
    final name = (event['event'] ?? 'Payment event').toString();
    final isDanger = name.contains('refund') || name.contains('failed');
    final isSuccess = name.contains('settled') ||
        name.contains('cleared') ||
        name.contains('confirmed');
    final dotColor = isDanger
        ? AppColors.danger
        : isSuccess
            ? const Color(0xFF2E7D32)
            : AppColors.primary;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dotColor,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: AppColors.hairline,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name.replaceAll('_', ' '),
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Text(_time(event['atMillis']),
                      style: const TextStyle(
                          color: AppColors.inkSoft, fontSize: 11)),
                  if (event['actorId'] != null)
                    Text('Actor: ${event['actorId']}',
                        style: const TextStyle(
                            color: AppColors.inkSoft, fontSize: 11)),
                  if (event['reason'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text('Reason: ${event['reason']}',
                          style: const TextStyle(
                              color: AppColors.ink, fontSize: 12)),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(String label, Color textColor, Color bgColor) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: bgColor, borderRadius: BorderRadius.circular(6)),
        child: Text(label,
            style: TextStyle(
                color: textColor, fontSize: 11, fontWeight: FontWeight.w600)),
      );

  String _label(String value) => value
      .split('_')
      .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');

  Widget _button(String label, VoidCallback onPressed) => OutlinedButton(
      onPressed: _processing || _loading ? null : onPressed,
      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 42)),
      child: Text(label));

  String _time(dynamic millis) => millis is num && millis > 0
      ? DateTime.fromMillisecondsSinceEpoch(millis.toInt()).toLocal().toString()
      : 'Time unavailable';
}

class _PaymentActionDialog extends StatefulWidget {
  const _PaymentActionDialog(
      {required this.label,
      required this.consequence,
      required this.requireReason,
      this.identifier});
  final String label, consequence;
  final bool requireReason;
  final String? identifier;
  @override
  State<_PaymentActionDialog> createState() => _PaymentActionDialogState();
}

class _PaymentActionDialogState extends State<_PaymentActionDialog> {
  final _form = GlobalKey<FormState>();
  final _reason = TextEditingController();
  final _identifier = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    _identifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.label),
        content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
                child: Form(
                    key: _form,
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.consequence),
                          if (widget.identifier != null) ...[
                            const SizedBox(height: 16),
                            TextFormField(
                                controller: _identifier,
                                decoration: InputDecoration(
                                    labelText: widget.identifier),
                                validator: (v) => v == null || v.trim().isEmpty
                                    ? 'Provider ID is required.'
                                    : null)
                          ],
                          if (widget.requireReason) ...[
                            const SizedBox(height: 16),
                            TextFormField(
                                controller: _reason,
                                minLines: 2,
                                maxLines: 4,
                                maxLength: 500,
                                decoration: const InputDecoration(
                                    labelText: 'Admin reason',
                                    helperText:
                                        'Saved in the payment audit history.'),
                                validator: (v) => v == null || v.trim().isEmpty
                                    ? 'A reason is required.'
                                    : v.trim().length < 5
                                        ? 'Enter at least 5 characters.'
                                        : null)
                          ],
                        ])))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () {
                if (_form.currentState!.validate()) {
                  Navigator.pop(
                      context, (_reason.text.trim(), _identifier.text.trim()));
                }
              },
              child: const Text('Confirm'))
        ],
      );
}
