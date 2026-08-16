import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../data/mock_data.dart';
import '../../../widgets/shared.dart';
import 'refund_request_screen.dart';

/// AD-M4.2 (billing history detail) — split out from the dashboard into
/// its own screen so the full transaction list, filtering, and per-charge
/// actions (invoice, refund) have room to breathe.
class BillingHistoryScreen extends StatefulWidget {
  const BillingHistoryScreen({super.key});

  @override
  State<BillingHistoryScreen> createState() => _BillingHistoryScreenState();
}

class _BillingHistoryScreenState extends State<BillingHistoryScreen> {
  static const _filters = ['All', 'Membership', 'Coaching'];
  String _filter = 'All';

  bool _isEligible(Transaction t) =>
      DateTime.now().difference(t.date).inDays <= MockData.refundWindowDays;

  String _date(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final visible = MockData.transactions.where((t) {
      if (_filter == 'All') return true;
      return t.type.toLowerCase().contains(_filter.toLowerCase());
    }).toList();
    final totalThisYear = MockData.transactions
        .where((t) => t.date.year == DateTime.now().year)
        .fold<double>(0, (sum, t) => sum + t.amount);

    return Scaffold(
      appBar: AppBar(title: const Text('Billing history')),
      body: PageBody(
        children: [
          Panel(
            background: AppColors.primaryTint,
            child: Row(
              children: [
                const Icon(Icons.receipt_long_rounded, color: AppColors.primary),
                const SizedBox(width: 12),
                Text('RM ${totalThisYear.toStringAsFixed(2)} spent this year',
                    style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final f = _filters[i];
                final selected = f == _filter;
                return ChoiceChip(
                  label: Text(f),
                  selected: selected,
                  onSelected: (_) => setState(() => _filter = f),
                  backgroundColor: AppColors.surface,
                  selectedColor: AppColors.primary,
                  labelStyle: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600, color: selected ? Colors.white : AppColors.ink),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                    side: const BorderSide(color: AppColors.hairline),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          if (visible.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text('No transactions in this category.',
                    style: Theme.of(context).textTheme.bodyMedium),
              ),
            )
          else
            ...visible.map((t) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Panel(
                    onTap: () => _openDetail(context, t),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceAlt,
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Icon(
                              t.type.contains('Coaching')
                                  ? Icons.sports_rounded
                                  : Icons.card_membership_rounded,
                              size: 19,
                              color: AppColors.primary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(t.type, style: Theme.of(context).textTheme.titleMedium),
                              Text('${t.id}  ·  ${_date(t.date)}',
                                  style: Theme.of(context).textTheme.bodyMedium),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('RM ${t.amount.toStringAsFixed(2)}',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            statusPill(t.status),
                          ],
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: AppColors.inkSoft),
                      ],
                    ),
                  ),
                )),
        ],
      ),
    );
  }

  void _openDetail(BuildContext context, Transaction t) {
    final eligible = _isEligible(t);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(ctx).padding.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(t.type, style: Theme.of(ctx).textTheme.titleLarge)),
                statusPill(t.status),
              ],
            ),
            const SizedBox(height: 16),
            Panel(
              child: Column(
                children: [
                  DetailRow('Reference', t.id),
                  const Divider(height: 20),
                  DetailRow('Date', _date(t.date)),
                  const Divider(height: 20),
                  DetailRow('Amount', 'RM ${t.amount.toStringAsFixed(2)}'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  showToast(context, 'Invoice saved to your device.');
                },
                icon: const Icon(Icons.download_rounded, size: 18),
                label: const Text('Download invoice'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: eligible
                  ? OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => RefundRequestScreen(preselectedTransactionId: t.id)),
                        );
                      },
                      icon: const Icon(Icons.receipt_long_rounded, size: 18),
                      label: const Text('Request a refund'),
                    )
                  : Text(
                      'Outside the ${MockData.refundWindowDays}-day refund window.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12.5, color: AppColors.inkSoft),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
