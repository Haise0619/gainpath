import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../data/mock_data.dart';
import '../../../widgets/shared.dart';
import '../admin_dialogs.dart';

/// AD-M11.7 — Process Refund Request. Promoted from a Dashboard-alert-only
/// flow into a real sidebar destination: list and detail live in one
/// page — a small in-page breadcrumb replaces the push+AppBar+back-button
/// pattern the rest of this console has already moved away from. The
/// Dashboard's "refund requests pending" alert jumps straight here.
class RefundsScreen extends StatefulWidget {
  const RefundsScreen({super.key});

  @override
  State<RefundsScreen> createState() => RefundsScreenState();
}

class RefundsScreenState extends State<RefundsScreen> {
  late final List<RefundClaim> _claims = [...MockData.refundClaims];
  RefundClaim? _selected;
  bool _processing = false;
  String _query = '';

  Future<void> _approve(RefundClaim claim) async {
    setState(() => _processing = true);
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;

    // Simulate an occasional gateway timeout: the claim stays pending
    // rather than silently failing, matching the doc's explicit edge case.
    final timedOut = claim.id == 'CLM-3092';
    if (timedOut) {
      setState(() => _processing = false);
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          icon: const Icon(Icons.wifi_off_rounded, color: AppColors.warning, size: 32),
          title: const Text('Gateway did not respond'),
          content: const Text(
              'The reversal request timed out. The claim stays Pending — nothing has been charged or refunded. Try again shortly.'),
          actions: [
            FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
          ],
        ),
      );
      return;
    }

    setState(() {
      _processing = false;
      _claims.remove(claim);
      _selected = null;
    });
    showToast(context, 'Refund approved for ${claim.memberName}.');
  }

  Future<void> _reject(RefundClaim claim) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => _RejectClaimDialog(claim: claim),
    );
    if (reason != null && reason.isNotEmpty && mounted) {
      setState(() {
        _claims.remove(claim);
        _selected = null;
      });
      showToast(context, 'Claim rejected. ${claim.memberName} has been notified.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _selected == null ? _list(context) : _detail(context, _selected!),
    );
  }

  Widget _list(BuildContext context) {
    final visible = _claims.where((c) {
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      return c.memberName.toLowerCase().contains(q) || c.transactionType.toLowerCase().contains(q);
    }).toList();
    final totalDisputed = _claims.fold<double>(0, (sum, c) => sum + c.amount);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Refund disputes', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 4),
          Text('Pending refund claims, oldest first.', style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: StatTile('${_claims.length}', 'Pending claims', valueColor: AppColors.danger)),
              const SizedBox(width: 10),
              Expanded(
                  child: StatTile('RM ${totalDisputed.toStringAsFixed(0)}', 'Total amount disputed')),
            ],
          ),
          const SizedBox(height: 18),
          TextField(
            onChanged: (v) => setState(() => _query = v),
            decoration: const InputDecoration(
              isDense: true,
              hintText: 'Search by member or transaction type',
              prefixIcon: Icon(Icons.search_rounded, size: 19),
            ),
          ),
          const SizedBox(height: 16),
          if (visible.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.task_alt_rounded, size: 40, color: AppColors.hairline),
                    const SizedBox(height: 14),
                    Text(
                        _claims.isEmpty
                            ? 'No pending disputes. All caught up.'
                            : 'No claims match that search.',
                        style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
            )
          else
            ...visible.map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Panel(
                    onTap: () => setState(() => _selected = c),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration:
                              BoxDecoration(color: AppColors.dangerTint, borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.receipt_long_rounded, size: 19, color: AppColors.danger),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(c.memberName, style: Theme.of(context).textTheme.titleMedium),
                              Text('${c.transactionType}  ·  ${c.reason}',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12.5)),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('RM ${c.amount.toStringAsFixed(2)}',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            statusPill(c.status),
                          ],
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: AppColors.inkSoft),
                      ],
                    ),
                  ),
                )),
        ],
      ),
    );
  }

  Widget _detail(BuildContext context, RefundClaim claim) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: () => setState(() => _selected = null),
                child: Text('Refunds',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.primary, fontWeight: FontWeight.w700)),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.inkSoft),
              ),
              Text(claim.id, style: Theme.of(context).textTheme.bodyLarge),
            ],
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 900;
              final claimPanel = _claimDetail(context, claim);
              final historyPanel = _transactionHistory(context, claim);
              return wide
                  ? IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 3, child: claimPanel),
                          const SizedBox(width: 16),
                          Expanded(flex: 2, child: historyPanel),
                        ],
                      ),
                    )
                  : Column(children: [claimPanel, const SizedBox(height: 16), historyPanel]);
            },
          ),
        ],
      ),
    );
  }

  Widget _claimDetail(BuildContext context, RefundClaim claim) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Panel(
          background: AppColors.dangerTint,
          child: Row(
            children: [
              const Icon(Icons.receipt_long_rounded, color: AppColors.danger, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('RM ${claim.amount.toStringAsFixed(2)} disputed',
                        style: Theme.of(context).textTheme.titleMedium),
                    Text('Submitted ${_ago(claim.submitted)}', style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
              statusPill(claim.status),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Eyebrow('Claim details'),
        Panel(
          child: Column(
            children: [
              DetailRow('Member', claim.memberName),
              const Divider(height: 20),
              DetailRow('Transaction', '${claim.transactionId} · ${claim.transactionType}'),
              const Divider(height: 20),
              DetailRow('Reason given', claim.reason),
              const Divider(height: 20),
              DetailRow('Amount', 'RM ${claim.amount.toStringAsFixed(2)}'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Eyebrow('Member notes'),
        Panel(child: Text(claim.notes, style: const TextStyle(fontSize: 14.5, height: 1.5))),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger, minimumSize: const Size(0, 48)),
                onPressed: _processing ? null : () => _reject(claim),
                child: const FittedBox(fit: BoxFit.scaleDown, child: Text('Reject', maxLines: 1)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                onPressed: _processing ? null : () => _approve(claim),
                child: _processing
                    ? const SizedBox(
                        width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                    : const FittedBox(fit: BoxFit.scaleDown, child: Text('Approve refund', maxLines: 1)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _transactionHistory(BuildContext context, RefundClaim claim) {
    final related = MockData.transactions.where((t) => t.id != claim.transactionId).take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Eyebrow('Transaction history'),
        Panel(
          padding: EdgeInsets.zero,
          child: Column(
            children: List.generate(related.length, (i) {
              final t = related[i];
              return Column(
                children: [
                  if (i > 0) const Divider(height: 1, indent: 16),
                  ListTile(
                    dense: true,
                    title: Text(t.type, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                    subtitle: Text(t.id, style: const TextStyle(fontSize: 12)),
                    trailing: Text('RM ${t.amount.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  ),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }

  String _ago(DateTime d) {
    final days = DateTime.now().difference(d).inDays;
    if (days == 0) return 'today';
    if (days == 1) return '1 day ago';
    return '$days days ago';
  }
}

class _RejectClaimDialog extends StatefulWidget {
  final RefundClaim claim;
  const _RejectClaimDialog({required this.claim});

  @override
  State<_RejectClaimDialog> createState() => _RejectClaimDialogState();
}

class _RejectClaimDialogState extends State<_RejectClaimDialog> {
  final _reason = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AdminDialog(
      width: 400,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Reject this claim?', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text('The invoice reverts to its original state and ${widget.claim.memberName} is notified.',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 16),
          TextField(
            controller: _reason,
            maxLines: 3,
            autofocus: true,
            decoration: InputDecoration(hintText: 'Reason shown to the member', errorText: _error, isDense: true),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
                  onPressed: () {
                    if (_reason.text.trim().isEmpty) {
                      setState(() => _error = 'A reason is required.');
                      return;
                    }
                    Navigator.pop(context, _reason.text.trim());
                  },
                  child: const Text('Reject claim'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
