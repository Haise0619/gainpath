import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../payment_review_repository.dart';

/// One payment review presentation for demo and session-scoped live repositories.
class RefundsScreen extends StatefulWidget {
  const RefundsScreen(
      {super.key, this.live = false, this.repository, this.isCurrent});
  final bool live;
  final PaymentReviewRepository? repository;
  final bool Function()? isCurrent;
  @override
  State<RefundsScreen> createState() => RefundsScreenState();
}

class RefundsScreenState extends State<RefundsScreen> {
  late final PaymentReviewRepository? _repository = widget.repository ??
      (widget.live ? null : EmptyPaymentReviewRepository());
  PaymentReviewPage? _page;
  PaymentReviewDetail? _selected;
  String? _error;
  bool _loading = false;
  bool _processing = false;
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
      if (_valid(generation)) setState(() => _page = page);
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
      // Refresh the current page so returning to the queue never shows stale state.
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
                    24,
                    constraints.maxWidth < 600 ? 16 : 28,
                    40),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_selected == null)
                        ..._list(context)
                      else
                        ..._detail(context, _selected!),
                    ]))));
  }

  List<Widget> _feedback() => [
        if (_loading || _processing)
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: LinearProgressIndicator()),
        if (_error != null)
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Semantics(
                  liveRegion: true,
                  child: Panel(
                      background: AppColors.dangerTint,
                      child: Text(_error!,
                          style: const TextStyle(color: AppColors.danger))))),
      ];
  List<Widget> _list(BuildContext context) {
    final records = _page?.records ?? [];
    final visible = records.where((r) {
      final match =
          '${r.id} ${r.text('memberId')} ${r.text('coachName')} ${r.text('branchName')} ${r.text('billId')}'
              .toLowerCase()
              .contains(_query.toLowerCase());
      return match &&
          (_filter == 'All' ||
              (_filter == 'Reconciliation' && r.needsReview) ||
              (_filter == 'Refunds' &&
                  (r.text('refundStatus').isNotEmpty ||
                      r.needsReview && r.text('paymentStatus') == 'cleared')) ||
              (_filter == 'Pending payment' &&
                  r.text('paymentStatus') == 'pending'));
    }).toList();
    return [
      Text('Payment review & refunds',
          style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 4),
      Text(
          '${widget.live ? 'Sandbox' : 'Not connected · Sandbox'} · Review membership and booking payments, recover uncertain bills, and resolve refunds.',
          style: Theme.of(context).textTheme.bodyLarge),
      const SizedBox(height: 18),
      Wrap(spacing: 10, runSpacing: 10, children: [
        SizedBox(
            width: 230,
            child: StatTile(
                _page == null || _repository is EmptyPaymentReviewRepository
                    ? '—'
                    : '${records.where((r) => r.needsReview).length}',
                'Needs review · this page',
                valueColor: AppColors.danger)),
        SizedBox(
            width: 230,
            child: StatTile(
                _page == null || _repository is EmptyPaymentReviewRepository
                    ? '—'
                    : 'RM ${(records.fold<int>(0, (sum, r) => sum + r.amountMinor) / 100).toStringAsFixed(2)}',
                'Payment amount · this page')),
      ]),
      const SizedBox(height: 18),
      TextField(
          onChanged: (value) => setState(() => _query = value),
          decoration: const InputDecoration(
              labelText: 'Search this page',
              hintText: 'Transaction, member, coach, branch or bill ID',
              prefixIcon: Icon(Icons.search_rounded))),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final filter in [
          'All',
          'Reconciliation',
          'Refunds',
          'Pending payment'
        ])
          ChoiceChip(
              label: Text(filter),
              selected: _filter == filter,
              onSelected: (_) => setState(() => _filter = filter)),
        OutlinedButton.icon(
            onPressed: _loading || _processing ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Refresh')),
      ]),
      ..._feedback(),
      const SizedBox(height: 16),
      if (!_loading && _error == null && visible.isEmpty)
        Panel(
            child: Text(records.isEmpty
                ? 'No payments on this page.'
                : 'No payments match this page’s search and filter.')),
      for (final record in visible)
        Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Panel(
                onTap: _loading || _processing ? null : () => _open(record),
                child: Row(children: [
                  Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                          color: AppColors.dangerTint,
                          borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.receipt_long_rounded,
                          color: AppColors.danger, size: 19)),
                  const SizedBox(width: 14),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(record.id,
                            style: Theme.of(context).textTheme.titleMedium),
                        Text(
                            '${record.text('memberDisplayName').isEmpty ? record.text('memberId') : record.text('memberDisplayName')} · ${record.isMembership ? record.text('kind') : record.text('coachName')}'),
                        Text(record.isMembership
                            ? '${record.text('planName')} · Organization-wide'
                            : record.sessionSchedule),
                        Text(
                            'Updated: ${_time(record.data['updatedAtMillis'])}'),
                        if (record.text('cancellationReason').isNotEmpty ||
                            record.text('reviewReason').isNotEmpty)
                          Text(
                              'Reason: ${record.text('cancellationReason').isEmpty ? record.text('reviewReason') : record.text('cancellationReason')}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                        Text(_status(record),
                            style: Theme.of(context).textTheme.bodyMedium),
                      ])),
                  const SizedBox(width: 8),
                  Text(record.amount,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right_rounded, size: 18),
                ]))),
      const SizedBox(height: 14),
      Wrap(
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
            Text(
                'Page ${_pageIndex + 1} · search and counts apply to this page'),
            OutlinedButton(
                onPressed: _page?.nextAfterId == null || _loading || _processing
                    ? null
                    : () {
                        final next = _page!.nextAfterId;
                        setState(() {
                          if (_cursors.length > _pageIndex + 1) {
                            _cursors.removeRange(
                                _pageIndex + 1, _cursors.length);
                          }
                          _cursors.add(next);
                          _pageIndex++;
                        });
                        _load();
                      },
                child: const Text('Next')),
          ]),
    ];
  }

  String _label(String value) => value
      .split('_')
      .map((word) =>
          word.isEmpty ? '' : '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
  String _status(PaymentReviewRecord r) => switch (r.text('refundStatus')) {
        'uncertain' => 'Refund outcome unknown · needs reconciliation',
        'approved' => 'Refund approved · not sent',
        'processing' => 'Sandbox refund submitted · awaiting confirmation',
        'completed' => 'Sandbox refund completed',
        'rejected' => 'Refund declined',
        'failed' => 'Sandbox refund needs attention',
        _ => r.needsReview && r.text('paymentStatus') == 'cleared'
            ? 'Paid · awaiting refund review'
            : '${_label(r.text('paymentStatus'))} · ${_label(r.text('fulfilmentStatus'))}',
      };
  List<Widget> _detail(BuildContext context, PaymentReviewDetail detail) {
    final r = detail.payment;
    return [
      Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
        TextButton(
            onPressed: _processing || _loading
                ? null
                : () => setState(() {
                      _selected = null;
                      _error = null;
                    }),
            child: const Text('Refunds')),
        const Icon(Icons.chevron_right_rounded, size: 18),
        Text(r.id)
      ]),
      const SizedBox(height: 18),
      Text(
          '${widget.live ? 'Sandbox' : 'Not connected · Sandbox'} · No real-money refund is issued by this console.'),
      ..._feedback(),
      const SizedBox(height: 16),
      LayoutBuilder(builder: (context, constraints) {
        final summary =
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Panel(
              background: AppColors.dangerTint,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.amount,
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(_status(r)),
                    const SizedBox(height: 8),
                    Text(r.refundExplanation),
                  ])),
          const SizedBox(height: 16),
          const Eyebrow('Payment details'),
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
              const Text(
                  'Refund review uses the amount collected. Voucher reinstatement is unavailable.'),
            ],
            const Divider(height: 20),
            DetailRow('Last updated', _time(r.data['updatedAtMillis'])),
            if (r.data['reviewedAtMillis'] != null)
              DetailRow('Admin decision', _time(r.data['reviewedAtMillis'])),
            if (r.data['refundReservedAtMillis'] != null)
              DetailRow(
                  'Refund attempted', _time(r.data['refundReservedAtMillis'])),
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
          const SizedBox(height: 20),
          Wrap(spacing: 12, runSpacing: 12, children: [
            if (r.text('billId').isNotEmpty)
              _button(
                  'Verify payment',
                  () => _action('verify', 'Verify payment',
                      'Read provider status and reconcile this payment. This does not create another bill.')),
            if (r.text('billId').isEmpty &&
                r.text('paymentStatus') == 'pending')
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
            if (['processing', 'uncertain']
                .contains(r.text('refundStatus'))) ...[
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
                padding: EdgeInsets.only(top: 12),
                child: Text(
                    'Sandbox refund execution is not configured. Approval records a decision only.')),
        ]);
        final history =
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Eyebrow('Payment history · most recent 100 events'),
          Panel(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                if (detail.events.isEmpty)
                  const Text('No payment events recorded.'),
                for (final event in detail.events)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                '${event['event'] ?? 'Payment event'}'
                                    .replaceAll('_', ' '),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            Text(_time(event['atMillis'])),
                            if (event['actorId'] != null)
                              Text('Actor: ${event['actorId']}'),
                            if (event['reason'] != null)
                              Text('${event['reason']}'),
                          ])),
              ]))
        ]);
        return constraints.maxWidth >= 900
            ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(flex: 3, child: summary),
                const SizedBox(width: 16),
                Expanded(flex: 2, child: history)
              ])
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [summary, const SizedBox(height: 16), history]);
      }),
      const SizedBox(height: 16),
      OutlinedButton.icon(
          onPressed: _processing || _loading ? null : () => _open(r),
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Refresh payment')),
    ];
  }

  Widget _button(String label, VoidCallback onPressed) => OutlinedButton(
      onPressed: _processing || _loading ? null : onPressed,
      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
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
