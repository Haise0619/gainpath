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
  PaymentReviewDetail? _reviewDetail;
  PaymentReviewDetail? _quickDrawerDetail;

  PaymentReviewDetail? get _selected => _reviewDetail ?? _quickDrawerDetail;

  bool _shouldOpenReviewPage(PaymentReviewRecord r) {
    return r.canDecide || r.isPendingRefundReview || r.canCloseRefund || r.isRefundCase;
  }

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

  final TextEditingController _searchController = TextEditingController();

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
        setState(() {
          _page = page;
          _loading = false;
        });
        if (widget.initialBookingId != null && _selected == null) {
          await _openId(widget.initialBookingId!);
        }
      }
    } catch (e) {
      if (_valid(generation)) {
        setState(() =>
            _error = 'Could not load the payments list. Refresh to try again.');
      }
    } finally {
      if (_valid(generation)) setState(() => _loading = false);
    }
  }

  Future<void> _open(PaymentReviewRecord record, {bool? forReview}) =>
      _openId(record.id, forReview: forReview);

  Future<void> _openId(String id, {bool? forReview}) async {
    if (_processing || _loading || !_current) return;
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
      _showAllEvents = false;
    });
    try {
      final detail = await _repository!.detail(id);
      if (_valid(generation)) {
        final shouldReview = forReview ??
            (_mode == PaymentsMode.refunds && _shouldOpenReviewPage(detail.payment));
        setState(() {
          if (shouldReview) {
            _reviewDetail = detail;
            _quickDrawerDetail = null;
          } else {
            _quickDrawerDetail = detail;
            _reviewDetail = null;
          }
        });
      }
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
      _error = null;
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
      setState(() {
        if (_reviewDetail != null) {
          _reviewDetail = detail;
        } else {
          _quickDrawerDetail = detail;
        }
      });
      try {
        final page = await _repository.load(afterId: _cursors[_pageIndex]);
        if (_valid(generation)) setState(() => _page = page);
      } catch (_) {
        if (_valid(generation)) {
          setState(() => _error =
              'The payment details were updated. Refresh to reload the payments list.');
        }
      }
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
        builder: (context, constraints) {
          if (_reviewDetail != null) {
            return _buildDedicatedReviewPage(
                context, constraints, _reviewDetail!);
          }

          final mainList = SingleChildScrollView(
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
                ..._list(context, constraints),
              ],
            ),
          );

          if (_quickDrawerDetail != null) {
            return Stack(
              children: [
                mainList,
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () => setState(() => _quickDrawerDetail = null),
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.35),
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  bottom: 0,
                  right: 0,
                  width:
                      constraints.maxWidth < 600 ? constraints.maxWidth : 540,
                  child: _buildQuickDrawer(
                      context, constraints, _quickDrawerDetail!),
                ),
              ],
            );
          }

          return mainList;
        },
      ),
    );
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
    final pendingRefunds = records.where((r) => r.isPendingRefundReview).length;
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
                  color:
                      (badgeColor ?? AppColors.primary).withValues(alpha: 0.15),
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

  List<PaymentReviewRecord> _filteredRecords(
      List<PaymentReviewRecord> records) {
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
          return r.isPendingRefundReview;
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

  Widget _buildMetricsStrip(BuildContext context,
      List<PaymentReviewRecord> records, bool isUnconnected) {
    final clearedAmount = records
        .where((r) => r.text('paymentStatus') == 'cleared')
        .fold<int>(0, (sum, r) => sum + r.amountMinor);
    final totalVolume = records.fold<int>(0, (sum, r) => sum + r.amountMinor);
    final pendingCheckoutCount =
        records.where((r) => r.text('paymentStatus') == 'pending').length;
    final reconciliationCount = records.where((r) => r.needsReview).length;
    final pendingRefundsCount =
        records.where((r) => r.isPendingRefundReview).length;
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
              child: StatTile(isUnconnected ? '—' : '$pendingRefundsCount',
                  'Pending refund review · loaded queue',
                  valueColor: pendingRefundsCount > 0 ? AppColors.danger : null,
                  compact: true)),
          SizedBox(
              width: tileWidth,
              child: StatTile(isUnconnected ? '—' : '$approvedRefundsCount',
                  'Approved · pending execution',
                  valueColor: AppColors.primary, compact: true)),
          SizedBox(
              width: tileWidth,
              child: StatTile(isUnconnected ? '—' : '$completedRefundsCount',
                  'Completed refunds · loaded queue',
                  compact: true)),
          SizedBox(
              width: tileWidth,
              child: StatTile(isUnconnected ? '—' : '$rejectedRefundsCount',
                  'Declined requests · loaded queue',
                  compact: true)),
        ]);
      }

      if (_mode == PaymentsMode.reconciliation) {
        return Wrap(spacing: 10, runSpacing: 10, children: [
          SizedBox(
              width: tileWidth,
              child: StatTile(isUnconnected ? '—' : '$reconciliationCount',
                  'Total exceptions · loaded queue',
                  valueColor:
                      reconciliationCount > 0 ? const Color(0xFFE65100) : null,
                  compact: true)),
          SizedBox(
              width: tileWidth,
              child: StatTile(isUnconnected ? '—' : '$activationReviewCount',
                  'Fulfillment review · loaded queue',
                  compact: true)),
          SizedBox(
              width: tileWidth,
              child: StatTile(isUnconnected ? '—' : '$uncertainBillsCount',
                  'Uncertain provider bills',
                  compact: true)),
          SizedBox(
              width: tileWidth,
              child: StatTile(isUnconnected ? '—' : '$resolvedCount',
                  'Verified / Settled · loaded queue',
                  valueColor: const Color(0xFF2E7D32), compact: true)),
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
            child: StatTile(isUnconnected ? '—' : '$pendingCheckoutCount',
                'Pending checkout · loaded queue',
                compact: true)),
        SizedBox(
            width: tileWidth,
            child: StatTile(isUnconnected ? '—' : '$reconciliationCount',
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
            controller: _searchController,
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
                  child: Text('Transaction',
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
                  child: Text('Created · MYT',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.inkSoft)),
                ),
                SizedBox(
                  width: 160,
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
    final isReviewable =
        r.canDecide || r.isPendingRefundReview || r.canCloseRefund;
    return InkWell(
      onTap: _loading || _processing
          ? null
          : () => _open(r,
              forReview: _mode == PaymentsMode.refunds ? isReviewable : false),
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
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Member
            Expanded(
              flex: 3,
              child: Text(r.memberDisplay,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500)),
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
                    _badge(r.refundLifecycleLabel ?? 'Pending Review',
                        AppColors.danger, AppColors.dangerTint)
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
              child: Text(r.formattedDate,
                  style: const TextStyle(fontSize: 12, color: AppColors.ink)),
            ),
            // Action
            SizedBox(
              width: 160,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (_mode == PaymentsMode.refunds) ...[
                    if (isReviewable) ...[
                      OutlinedButton(
                        onPressed: _loading || _processing
                            ? null
                            : () => _open(r, forReview: true),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          minimumSize: const Size(0, 30),
                          side: const BorderSide(color: AppColors.primary),
                        ),
                        child: const Text('Review',
                            style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary)),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.visibility_outlined, size: 16),
                        tooltip: 'Quick preview',
                        padding: EdgeInsets.zero,
                        style: IconButton.styleFrom(
                          minimumSize: const Size(26, 26),
                          padding: EdgeInsets.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        constraints: const BoxConstraints(
                            minWidth: 26, minHeight: 26),
                        onPressed: _loading || _processing
                            ? null
                            : () => _open(r, forReview: false),
                      ),
                    ] else ...[
                      OutlinedButton(
                        onPressed: _loading || _processing
                            ? null
                            : () => _open(r, forReview: false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          minimumSize: const Size(0, 30),
                        ),
                        child: const Text('View Details',
                            style: TextStyle(fontSize: 11.5)),
                      ),
                    ],
                  ] else ...[
                    OutlinedButton(
                      onPressed:
                          _loading || _processing ? null : () => _open(r),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        minimumSize: const Size(0, 32),
                      ),
                      child: Text(
                        _mode == PaymentsMode.reconciliation
                            ? 'Investigate'
                            : 'View',
                        style: const TextStyle(fontSize: 11.5),
                      ),
                    ),
                  ],
                ],
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
              onTap: _loading || _processing
                  ? null
                  : () => _open(record,
                      forReview: _mode == PaymentsMode.refunds
                          ? (record.canDecide ||
                              record.isPendingRefundReview ||
                              record.canCloseRefund)
                          : false),
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
                            Text(record.memberDisplay,
                                style: const TextStyle(
                                    fontSize: 12, color: AppColors.inkSoft)),
                            Text(
                              'Created · ${record.formattedDate} MYT',
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
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (_mode == PaymentsMode.refunds) ...[
                        if (record.canDecide ||
                            record.isPendingRefundReview ||
                            record.canCloseRefund) ...[
                          OutlinedButton(
                            onPressed: _loading || _processing
                                ? null
                                : () => _open(record, forReview: true),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              minimumSize: const Size(0, 30),
                              side: const BorderSide(color: AppColors.primary),
                            ),
                            child: const Text('Review',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary)),
                          ),
                          const SizedBox(width: 6),
                          IconButton(
                            icon: const Icon(Icons.visibility_outlined,
                                size: 16),
                            tooltip: 'Quick preview',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                                minWidth: 28, minHeight: 28),
                            onPressed: _loading || _processing
                                ? null
                                : () => _open(record, forReview: false),
                          ),
                        ] else ...[
                          OutlinedButton(
                            onPressed: _loading || _processing
                                ? null
                                : () => _open(record, forReview: false),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              minimumSize: const Size(0, 30),
                            ),
                            child: const Text('View Details',
                                style: TextStyle(fontSize: 11)),
                          ),
                        ],
                      ] else ...[
                        OutlinedButton(
                          onPressed: _loading || _processing
                              ? null
                              : () => _open(record),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            minimumSize: const Size(0, 30),
                          ),
                          child: Text(
                            _mode == PaymentsMode.reconciliation
                                ? 'Investigate'
                                : 'View',
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                      ],
                    ],
                  ),
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

  Widget _buildDedicatedReviewPage(BuildContext context,
      BoxConstraints constraints, PaymentReviewDetail detail) {
    final r = detail.payment;
    final isDesktop = constraints.maxWidth >= 1024;
    final horizontalPadding = constraints.maxWidth < 600 ? 16.0 : 28.0;

    return SingleChildScrollView(
      padding:
          EdgeInsets.fromLTRB(horizontalPadding, 20, horizontalPadding, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBreadcrumbHeader(r),
          ..._feedback(),
          const SizedBox(height: 16),
          _buildCrossNavigationBanner(r),
          const SizedBox(height: 14),
          _buildRefundSummaryCard(r),
          const SizedBox(height: 14),
          _buildStatusHierarchyCard(r, detail),
          const SizedBox(height: 16),
          if (isDesktop) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Main column ~65%
                Expanded(
                  flex: 65,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildRefundRequestCard(r),
                      const SizedBox(height: 16),
                      _buildOriginalPaymentCard(r),
                      const SizedBox(height: 16),
                      _buildContextCard(r),
                      const SizedBox(height: 16),
                      _buildAuditHistoryCard(detail),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                // Side column ~35%
                Expanded(
                  flex: 35,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildReviewActionsCard(r, detail),
                      const SizedBox(height: 16),
                      _buildTechnicalDetailsCard(r, detail),
                    ],
                  ),
                ),
              ],
            ),
          ] else ...[
            // Single-column layout for mobile / tablet < 1024
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildReviewActionsCard(r, detail),
                const SizedBox(height: 16),
                _buildRefundRequestCard(r),
                const SizedBox(height: 16),
                _buildOriginalPaymentCard(r),
                const SizedBox(height: 16),
                _buildContextCard(r),
                const SizedBox(height: 16),
                _buildTechnicalDetailsCard(r, detail),
                const SizedBox(height: 16),
                _buildAuditHistoryCard(detail),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBreadcrumbHeader(PaymentReviewRecord r) {
    final backLabel = switch (_mode) {
      PaymentsMode.transactions => 'Transactions',
      PaymentsMode.refunds => 'Refund Requests',
      PaymentsMode.reconciliation => 'Reconciliation',
    };

    return Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      alignment: WrapAlignment.spaceBetween,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            TextButton.icon(
              onPressed: _processing || _loading
                  ? null
                  : () => setState(() {
                        _reviewDetail = null;
                        _error = null;
                      }),
              icon: const Icon(Icons.arrow_back_rounded, size: 16),
              label: Text('Back to $backLabel'),
            ),
            Text(
              '· ${r.businessTitle} (${r.id})',
              style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: AppColors.inkSoft),
            ),
          ],
        ),
        OutlinedButton.icon(
          onPressed:
              _processing || _loading ? null : () => _open(r, forReview: true),
          icon: const Icon(Icons.refresh_rounded, size: 15),
          label:
              const Text('Refresh payment', style: TextStyle(fontSize: 12)),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            minimumSize: const Size(0, 32),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusHierarchyCard(
      PaymentReviewRecord r, PaymentReviewDetail detail) {
    final paymentStatusText = r.paymentLifecycleLabel;
    final isPaymentCleared = r.text('paymentStatus') == 'cleared';
    final paymentColor =
        isPaymentCleared ? const Color(0xFF2E7D32) : const Color(0xFF1565C0);
    final paymentBg =
        isPaymentCleared ? const Color(0xFFE8F5E9) : const Color(0xFFE3F2FD);

    final serviceStatusText = r.isMembership
        ? (r.text('membershipStatus').isNotEmpty
            ? _label(r.text('membershipStatus'))
            : 'Active')
        : r.fulfillmentLifecycleLabel;
    final isServiceCancelled = r.text('bookingStatus') == 'cancelled' ||
        r.text('fulfilmentStatus') != 'confirmed';
    final serviceColor =
        isServiceCancelled ? const Color(0xFFE65100) : const Color(0xFF2E7D32);
    final serviceBg =
        isServiceCancelled ? const Color(0xFFFFF3E0) : const Color(0xFFE8F5E9);

    final reviewStatusText = r.refundLifecycleLabel ?? 'Pending Review';
    final isApproved = r.text('refundStatus') == 'approved';
    final isRejected = r.text('refundStatus') == 'rejected';
    final isCompleted = r.text('refundStatus') == 'completed';
    final reviewColor = isCompleted
        ? const Color(0xFF2E7D32)
        : isApproved
            ? AppColors.primary
            : isRejected
                ? AppColors.danger
                : const Color(0xFFD32F2F);
    final reviewBg = isCompleted
        ? const Color(0xFFE8F5E9)
        : isApproved
            ? AppColors.primaryTint
            : isRejected
                ? AppColors.dangerTint
                : const Color(0xFFFFEBEE);

    final rawStatus = r.text('refundStatus');
    final executionStatusText = switch (rawStatus) {
      'completed' => 'Transferred / Succeeded',
      'processing' => 'Submitted to Gateway',
      'uncertain' => 'Requires Investigation',
      'approved' => detail.refundExecutionAvailable
          ? 'Pending Gateway Submission'
          : 'Approved (Admin Only)',
      'rejected' => 'Declined (No Payout)',
      _ => 'Not Initiated',
    };
    final executionColor = switch (rawStatus) {
      'completed' => const Color(0xFF2E7D32),
      'processing' => const Color(0xFF0288D1),
      'uncertain' => const Color(0xFFE65100),
      'approved' => const Color(0xFFF57C00),
      'rejected' => AppColors.inkSoft,
      _ => AppColors.inkSoft,
    };
    final executionBg = switch (rawStatus) {
      'completed' => const Color(0xFFE8F5E9),
      'processing' => const Color(0xFFE1F5FE),
      'uncertain' => const Color(0xFFFFF3E0),
      'approved' => const Color(0xFFFFF3E0),
      _ => AppColors.surfaceAlt,
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.hub_outlined, size: 18, color: AppColors.primary),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Status Hierarchy Breakdown',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 720;
              final isTablet = constraints.maxWidth >= 480;
              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: isDesktop ? 4 : (isTablet ? 2 : 1),
                childAspectRatio: isDesktop ? 2.2 : (isTablet ? 2.0 : 3.6),
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                children: [
                  _statusTile('1. Original Payment', paymentStatusText,
                      paymentColor, paymentBg, Icons.credit_card_rounded),
                  _statusTile(
                      r.isMembership
                          ? '2. Membership'
                          : '2. Booking Fulfillment',
                      serviceStatusText,
                      serviceColor,
                      serviceBg,
                      r.isMembership
                          ? Icons.badge_outlined
                          : Icons.event_available_rounded),
                  _statusTile('3. Refund Review', reviewStatusText, reviewColor,
                      reviewBg, Icons.gavel_rounded),
                  _statusTile('4. Refund Execution', executionStatusText,
                      executionColor, executionBg, Icons.payments_outlined),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFDE7),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFFF59D)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 16, color: Color(0xFFF57F17)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Policy Notice: Approving a refund records an administrative authorization. It does not automatically transfer funds. Fund payout occurs during the separate gateway execution phase.',
                    style: TextStyle(
                        fontSize: 12, color: Color(0xFF5D4037), height: 1.3),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusTile(String step, String status, Color textColor, Color bgColor,
      IconData icon) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: AppColors.inkSoft),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  step,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.inkSoft),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              status,
              style: TextStyle(
                  color: textColor,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRefundSummaryCard(PaymentReviewRecord r) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.hairline),
      ),
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
                    Text(
                      r.businessTitle,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (r.memberDisplay.isNotEmpty) ...[
                          Text(r.memberDisplay,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12.5)),
                          const Text('·',
                              style: TextStyle(color: AppColors.hairline)),
                        ],
                        Text('ID: ${r.id}',
                            style: const TextStyle(
                                color: AppColors.inkSoft, fontSize: 12)),
                        IconButton(
                          tooltip: 'Copy transaction ID',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                              minWidth: 20, minHeight: 20),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: r.id));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('ID copied to clipboard'),
                                duration: Duration(seconds: 2),
                                behavior: SnackBarBehavior.floating,
                                width: 240,
                              ),
                            );
                          },
                          icon: const Icon(Icons.copy_rounded, size: 14),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                r.amount,
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
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
            ],
          ),
          if (r.refundExplanation.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(r.refundExplanation,
                style: const TextStyle(
                    fontSize: 12.5, color: AppColors.inkSoft)),
          ],
        ],
      ),
    );
  }

  Widget _buildRefundRequestCard(PaymentReviewRecord r) {
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Eyebrow('Refund request details'),
          DetailRow('Claim status', r.refundLifecycleLabel ?? 'Pending Review'),
          if (r.text('refundReason').isNotEmpty)
            DetailRow('Member reason', r.text('refundReason'))
          else
            const DetailRow('Member reason', 'No reason specified by member'),
          if (r.text('refundNotes').isNotEmpty)
            DetailRow('Member notes', r.text('refundNotes')),
          if (r.data['cancelledAtMillis'] != null)
            DetailRow('Cancelled · MYT', _time(r.data['cancelledAtMillis'])),
          if (r.text('cancellationReason').isNotEmpty)
            DetailRow('Cancellation reason', r.text('cancellationReason')),
          if (r.refundClosed)
            DetailRow('Closure reason', r.text('refundClosureReason')),
          if (r.text('refundReference').isNotEmpty)
            DetailRow('Refund reference', r.text('refundReference')),
          if (r.text('reviewReason').isNotEmpty)
            DetailRow('Review note', r.text('reviewReason')),
          if (r.text('resolutionReason').isNotEmpty)
            DetailRow('Resolution reason', r.text('resolutionReason')),
        ],
      ),
    );
  }

  Widget _buildOriginalPaymentCard(PaymentReviewRecord r) {
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Eyebrow('Original payment details'),
          DetailRow('Payment status', r.paymentLifecycleLabel),
          DetailRow(
              r.text('paymentStatus') == 'cleared'
                  ? 'Amount collected'
                  : 'Checkout amount',
              r.amount),
          DetailRow('Payment type',
              r.isMembership ? r.text('kind') : 'CoachingBooking'),
          DetailRow(
              'Payment provider',
              switch (r.text('provider')) {
                'xendit' => 'Xendit',
                'billplz' => 'Billplz',
                _ => 'Not recorded',
              }),
          DetailRow('Provider reference',
              r.text('billId').isEmpty ? 'Not recorded' : r.text('billId')),
          DetailRow('Transaction created · MYT', r.formattedDate),
          if (r.data['paymentConfirmedAtMillis'] != null)
            DetailRow('Payment confirmed · MYT',
                _time(r.data['paymentConfirmedAtMillis'])),
          if (!r.isMembership) ...[
            const SizedBox(height: 8),
            const Align(
                alignment: Alignment.centerLeft,
                child: Text('Preferred payment method',
                    style: TextStyle(fontSize: 12, color: AppColors.inkSoft))),
            const SizedBox(height: 8),
            PaymentMethodSummary(
                label: r.selectedPaymentMethodLabel,
                category: r.selectedPaymentMethod == null
                    ? 'Legacy booking'
                    : 'Member preference',
                iconKey: r.selectedPaymentMethod?.choice.iconKey ?? 'unknown'),
            if (r.selectedPaymentMethod != null) ...[
              const SizedBox(height: 8),
              DetailRow(
                  'Selected at', _time(r.selectedPaymentMethod!.selectedAt)),
            ],
          ],
          if (r.hasPremiumVoucher) ...[
            const Divider(height: 20),
            DetailRow('Original booking fee', r.originalAmount),
            DetailRow('Premium voucher discount', r.voucherDiscount),
            DetailRow('Voucher finance', r.voucherFinanceReference),
            const SizedBox(height: 4),
            const Text(
                'Refund review uses the amount collected. Voucher reinstatement is unavailable.',
                style: TextStyle(fontSize: 11, color: AppColors.inkSoft)),
          ],
        ],
      ),
    );
  }

  Widget _buildContextCard(PaymentReviewRecord r) {
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Eyebrow(r.isMembership ? 'Membership context' : 'Booking context'),
          DetailRow(r.isMembership ? 'Membership plan' : 'Booked session',
              r.isMembership ? r.text('planName') : r.sessionSchedule),
          if (r.text('memberDisplayName').isNotEmpty)
            DetailRow('Member', r.text('memberDisplayName')),
          DetailRow('Member ID', r.text('memberId')),
          if (!r.isMembership) ...[
            DetailRow('Coach / branch',
                '${r.text('coachName')} / ${r.text('branchName')}'),
          ],
          if (r.text('bookingStatus').isNotEmpty)
            DetailRow('Booking status', _label(r.text('bookingStatus'))),
          DetailRow('Scope', 'Organization-wide'),
        ],
      ),
    );
  }

  Widget _buildReviewActionsCard(
      PaymentReviewRecord r, PaymentReviewDetail detail) {
    final canDecide = r.canDecide;
    final canSubmitRefund =
        r.text('refundStatus') == 'approved' && detail.refundExecutionAvailable;
    final isProcessingOrUncertain =
        ['processing', 'uncertain'].contains(r.text('refundStatus'));
    final canClose = r.canCloseRefund;
    final hasBillplzVerify =
        r.text('provider') != 'xendit' && r.text('billId').isNotEmpty;
    final hasBillplzRecover = r.text('provider') != 'xendit' &&
        r.text('billId').isEmpty &&
        r.text('paymentStatus') == 'pending';
    final hasAnyAction = canDecide ||
        canSubmitRefund ||
        isProcessingOrUncertain ||
        canClose ||
        hasBillplzVerify ||
        hasBillplzRecover;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: canDecide
                ? AppColors.primary.withValues(alpha: 0.4)
                : AppColors.hairline),
        boxShadow: canDecide
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.admin_panel_settings_outlined,
                size: 18,
                color: canDecide ? AppColors.primary : AppColors.inkSoft,
              ),
              const SizedBox(width: 8),
              Text(
                'Review Actions',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: canDecide ? AppColors.primary : AppColors.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            canDecide
                ? 'Action required: Review this refund claim and record an administrative decision.'
                : 'Available administrative and payment recovery actions for this record.',
            style: const TextStyle(fontSize: 12, color: AppColors.inkSoft),
          ),
          const Divider(height: 20, color: AppColors.hairline),
          if (!hasAnyAction) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline_rounded,
                      size: 16, color: Color(0xFF2E7D32)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No administrative actions pending. Record status: ${r.refundLifecycleLabel ?? r.paymentLifecycleLabel}.',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.inkSoft),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            if (canDecide) ...[
              if (r.text('refundStatus') != 'approved' ||
                  r.text('provider') == 'xendit') ...[
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _processing || _loading
                        ? null
                        : () => _action(
                              'approve_refund',
                              'Approve refund',
                              r.text('provider') == 'xendit'
                                  ? 'Approve and request a refund through Xendit. Membership or booking status changes after Xendit confirms success.'
                                  : 'Record approval for this paid reconciliation case.',
                              reason: true,
                            ),
                    icon: const Icon(Icons.check_circle_outline_rounded,
                        size: 16),
                    label: const Text('Approve refund'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF2E7D32),
                      side: const BorderSide(
                          color: Color(0xFF2E7D32), width: 1.5),
                      minimumSize: const Size(0, 42),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _processing || _loading
                      ? null
                      : () => _action(
                            'reject_refund',
                            'Reject refund',
                            'Record rejection and its reason. The paid booking remains in reconciliation for follow-up.',
                            reason: true,
                          ),
                  icon: const Icon(Icons.cancel_outlined, size: 16),
                  label: const Text('Reject refund'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(color: AppColors.danger),
                    minimumSize: const Size(0, 42),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (canSubmitRefund) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _processing || _loading
                      ? null
                      : () => _action(
                            'execute_refund',
                            'Submit refund',
                            'Submit the approved refund to the payment provider. Check its status before taking another action.',
                            reason: true,
                          ),
                  icon: const Icon(Icons.send_rounded, size: 16),
                  label: const Text('Submit refund'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary, width: 1.5),
                    minimumSize: const Size(0, 42),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (isProcessingOrUncertain) ...[
              if (r.text('refundOrderId').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _processing || _loading
                          ? null
                          : () => _action(
                                'check_refund',
                                'Check refund status',
                                'Read the existing provider refund status without creating another refund.',
                              ),
                      icon: const Icon(Icons.sync_rounded, size: 16),
                      label: const Text('Check refund status'),
                      style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 42)),
                    ),
                  ),
                ),
              if (r.text('refundOrderId').isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _processing || _loading
                          ? null
                          : () => _action(
                                'recover_refund',
                                'Recover refund',
                                'Attach the existing provider refund ID to verify its status and match it to the original payment.',
                                reason: true,
                                identifier: r.text('provider') == 'xendit'
                                    ? 'Xendit refund ID'
                                    : 'Provider Payment Order ID',
                              ),
                      icon: const Icon(Icons.build_circle_outlined, size: 16),
                      label: const Text('Recover refund'),
                      style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 42)),
                    ),
                  ),
                ),
            ],
            if (canClose) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _processing || _loading
                      ? null
                      : () => _action(
                            'close_refund',
                            'Close refund request',
                            'Record why this request is closed. The original payment will remain unrefunded.',
                            reason: true,
                          ),
                  icon: const Icon(Icons.lock_outline_rounded, size: 16),
                  label: const Text('Close refund request'),
                  style:
                      OutlinedButton.styleFrom(minimumSize: const Size(0, 42)),
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (hasBillplzVerify) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _processing || _loading
                      ? null
                      : () => _action(
                            'verify',
                            'Verify payment',
                            'Read provider status and reconcile this payment. This does not create another bill.',
                          ),
                  icon: const Icon(Icons.verified_outlined, size: 16),
                  label: const Text('Verify payment'),
                  style:
                      OutlinedButton.styleFrom(minimumSize: const Size(0, 42)),
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (hasBillplzRecover) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _processing || _loading
                      ? null
                      : () => _action(
                            'recover_bill',
                            'Recover bill',
                            'Attach an existing provider bill only after the server verifies its transaction reference, collection and amount. This never creates another bill.',
                            reason: true,
                            identifier: 'Provider bill ID',
                          ),
                  icon: const Icon(Icons.build_outlined, size: 16),
                  label: const Text('Recover bill'),
                  style:
                      OutlinedButton.styleFrom(minimumSize: const Size(0, 42)),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],
          if (!detail.refundExecutionAvailable && r.text('provider') != 'xendit')
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'Refund submission is unavailable for this payment.',
                style: TextStyle(fontSize: 11.5, color: AppColors.inkSoft),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTechnicalDetailsCard(
      PaymentReviewRecord r, PaymentReviewDetail detail) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          title: const Row(
            children: [
              Icon(Icons.code_rounded, size: 18, color: AppColors.inkSoft),
              SizedBox(width: 8),
              Expanded(
                child: Text('Technical Details',
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
              ),
            ],
          ),
          subtitle: const Text('Internal IDs, references, and timestamps',
              style: TextStyle(fontSize: 11, color: AppColors.inkSoft)),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            const Divider(height: 1, color: AppColors.hairline),
            const SizedBox(height: 12),
            _copyableTechnicalRow('Booking / Payment ID', r.id),
            _copyableTechnicalRow('Member ID', r.text('memberId')),
            if (r.text('billId').isNotEmpty)
              _copyableTechnicalRow(
                  'Provider Reference (Bill ID)', r.text('billId')),
            if (r.text('refundOrderId').isNotEmpty)
              _copyableTechnicalRow('Refund Order ID', r.text('refundOrderId')),
            if (r.text('refundReference').isNotEmpty)
              _copyableTechnicalRow('Refund Reference', r.text('refundReference')),
            if (r.text('refundFailureCode').isNotEmpty)
              _copyableTechnicalRow(
                  'Failure Code', r.text('refundFailureCode')),
            const Divider(height: 16, color: AppColors.hairline),
            DetailRow('Transaction created', r.formattedDate),
            if (r.data['paymentConfirmedAtMillis'] != null)
              DetailRow('Payment confirmed',
                  _time(r.data['paymentConfirmedAtMillis'])),
            DetailRow('Last updated', _time(r.data['updatedAtMillis'])),
            if (r.data['reviewedAtMillis'] != null)
              DetailRow(
                  'Admin decision date', _time(r.data['reviewedAtMillis'])),
          ],
        ),
      ),
    );
  }

  Widget _copyableTechnicalRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 12, color: AppColors.inkSoft)),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  value,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'monospace'),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy_rounded,
                    size: 14, color: AppColors.inkSoft),
                tooltip: 'Copy $label',
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 24, minHeight: 24),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: value));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('$label copied to clipboard'),
                      duration: const Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                      width: 280,
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAuditHistoryCard(PaymentReviewDetail detail) {
    final events = detail.events;
    final visibleEvents = _showAllEvents ? events : events.take(5).toList();

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          const SizedBox(height: 8),
          if (events.isEmpty)
            const Text('No payment events recorded.',
                style: TextStyle(color: AppColors.inkSoft, fontSize: 12))
          else
            for (var i = 0; i < visibleEvents.length; i++)
              _timelineEvent(visibleEvents[i], i == visibleEvents.length - 1),
        ],
      ),
    );
  }

  Widget _buildQuickDrawer(BuildContext context, BoxConstraints constraints,
      PaymentReviewDetail detail) {
    final r = detail.payment;
    final isReviewable =
        r.canDecide || r.isPendingRefundReview || r.canCloseRefund;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(-4, 0),
          ),
        ],
        border: const Border(left: BorderSide(color: AppColors.hairline)),
      ),
      child: Column(
        children: [
          // Drawer Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.hairline)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _mode == PaymentsMode.refunds
                            ? 'Refund Request Preview'
                            : 'Financial Detail',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        r.businessTitle,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.inkSoft),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (_mode == PaymentsMode.refunds || isReviewable) ...[
                  if (constraints.maxWidth < 450)
                    IconButton(
                      icon: const Icon(Icons.open_in_new_rounded, size: 18),
                      tooltip: 'Open Full Review',
                      onPressed: () {
                        setState(() {
                          _reviewDetail = detail;
                          _quickDrawerDetail = null;
                        });
                      },
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _reviewDetail = detail;
                          _quickDrawerDetail = null;
                        });
                      },
                      icon: const Icon(Icons.open_in_new_rounded, size: 14),
                      label: const Text('Open Full Review',
                          style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        minimumSize: const Size(0, 32),
                      ),
                    ),
                  const SizedBox(width: 4),
                ],
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  tooltip: 'Close details',
                  onPressed: () => setState(() => _quickDrawerDetail = null),
                ),
              ],
            ),
          ),
          // Drawer Body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCrossNavigationBanner(r),
                  const SizedBox(height: 12),
                  _buildStatusHierarchyCard(r, detail),
                  const SizedBox(height: 14),
                  _buildRefundSummaryCard(r),
                  const SizedBox(height: 14),
                  _buildRefundRequestCard(r),
                  const SizedBox(height: 14),
                  _buildOriginalPaymentCard(r),
                  const SizedBox(height: 14),
                  _buildContextCard(r),
                  const SizedBox(height: 14),
                  _buildReviewActionsCard(r, detail),
                  const SizedBox(height: 14),
                  _buildTechnicalDetailsCard(r, detail),
                  const SizedBox(height: 14),
                  _buildAuditHistoryCard(detail),
                ],
              ),
            ),
          ),
        ],
      ),
    );
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
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
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

  String _time(dynamic millis) =>
      PaymentReviewRecord.formatMalaysiaTimestamp(millis);
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
