import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../data/mock_data.dart';
import '../../widgets/shared.dart';

/// AD-M11.7 — Process Refund Request. Reached from a Dashboard alert
/// rather than a sidebar destination, since disputes are reactive rather
/// than something staff navigate to proactively.
class RefundDisputeDeskScreen extends StatefulWidget {
  const RefundDisputeDeskScreen({super.key});

  @override
  State<RefundDisputeDeskScreen> createState() => _RefundDisputeDeskScreenState();
}

class _RefundDisputeDeskScreenState extends State<RefundDisputeDeskScreen> {
  late final List<RefundClaim> _claims = [...MockData.refundClaims];

  Future<void> _openClaim(RefundClaim claim) async {
    final resolved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => RefundClaimDetailScreen(claim: claim)),
    );
    if (resolved == true) {
      setState(() => _claims.remove(claim));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dispute control desk')),
      body: PageBody(
        children: [
          Text('Pending refund claims, oldest first.', style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 18),
          if (_claims.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.task_alt_rounded, size: 40, color: AppColors.hairline),
                    const SizedBox(height: 14),
                    Text('No pending disputes. All caught up.',
                        style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
            )
          else
            ..._claims.map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Panel(
                    onTap: () => _openClaim(c),
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
                      ],
                    ),
                  ),
                )),
        ],
      ),
    );
  }
}

class RefundClaimDetailScreen extends StatefulWidget {
  final RefundClaim claim;
  const RefundClaimDetailScreen({super.key, required this.claim});

  @override
  State<RefundClaimDetailScreen> createState() => _RefundClaimDetailScreenState();
}

class _RefundClaimDetailScreenState extends State<RefundClaimDetailScreen> {
  bool _processing = false;

  Future<void> _approve() async {
    setState(() => _processing = true);
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;

    // Simulate an occasional gateway timeout: the claim stays pending
    // rather than silently failing, matching the doc's explicit edge case.
    final timedOut = widget.claim.id == 'CLM-3092';
    if (timedOut) {
      setState(() => _processing = false);
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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

    if (!mounted) return;
    Navigator.pop(context, true);
    showToast(context, 'Refund approved for ${widget.claim.memberName}.');
  }

  Future<void> _reject() async {
    final reasonController = TextEditingController();
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Reject this claim?', style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text('The invoice reverts to its original state and the member is notified.',
                style: Theme.of(ctx).textTheme.bodyMedium),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(hintText: 'Reason shown to the member'),
            ),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () => Navigator.pop(ctx, reasonController.text.trim().isNotEmpty),
              child: const Text('Reject claim'),
            ),
          ],
        ),
      ),
    );
    if (confirmed == true && mounted) {
      Navigator.pop(context, true);
      showToast(context, 'Claim rejected. ${widget.claim.memberName} has been notified.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final claim = widget.claim;
    return Scaffold(
      appBar: AppBar(title: Text('Claim ${claim.id}')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          final claimPanel = _claimDetail(context);
          final historyPanel = _transactionHistory(context);
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            child: wide
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
                : Column(children: [claimPanel, const SizedBox(height: 16), historyPanel]),
          );
        },
      ),
    );
  }

  Widget _claimDetail(BuildContext context) {
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
                    Text('RM ${widget.claim.amount.toStringAsFixed(2)} disputed',
                        style: Theme.of(context).textTheme.titleMedium),
                    Text('Submitted ${_ago(widget.claim.submitted)}',
                        style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
              statusPill(widget.claim.status),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Eyebrow('Claim details'),
        Panel(
          child: Column(
            children: [
              DetailRow('Member', widget.claim.memberName),
              const Divider(height: 20),
              DetailRow('Transaction', '${widget.claim.transactionId} · ${widget.claim.transactionType}'),
              const Divider(height: 20),
              DetailRow('Reason given', widget.claim.reason),
              const Divider(height: 20),
              DetailRow('Amount', 'RM ${widget.claim.amount.toStringAsFixed(2)}'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Eyebrow('Member notes'),
        Panel(
          child: Text(widget.claim.notes, style: const TextStyle(fontSize: 14.5, height: 1.5)),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger, minimumSize: const Size(0, 48)),
                onPressed: _processing ? null : _reject,
                child: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('Reject', maxLines: 1),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                onPressed: _processing ? null : _approve,
                child: _processing
                    ? const SizedBox(
                        width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                    : const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('Approve refund', maxLines: 1),
                      ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _transactionHistory(BuildContext context) {
    final related = MockData.transactions.where((t) => t.id != widget.claim.transactionId).take(3).toList();
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
