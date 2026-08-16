import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../data/mock_data.dart';
import '../../../widgets/shared.dart';

/// AD-M4.4 — Request Refund. Charges outside the policy window are shown
/// but locked with an explanation rather than silently omitted or silently
/// accepted, matching the design doc's explicit "form locks, policy
/// warning shown" edge case.
class RefundRequestScreen extends StatefulWidget {
  /// When opened from a specific transaction row (e.g. Billing History),
  /// that transaction is pre-selected if it is still eligible.
  final String? preselectedTransactionId;
  const RefundRequestScreen({super.key, this.preselectedTransactionId});

  @override
  State<RefundRequestScreen> createState() => _RefundRequestScreenState();
}

class _RefundRequestScreenState extends State<RefundRequestScreen> {
  String? _transactionId;
  String? _reason;

  final _reasons = const [
    'Coach cancelled the session',
    'Charged twice for the same item',
    'Charged after cancelling',
    'Something else',
  ];

  @override
  void initState() {
    super.initState();
    final preselected = widget.preselectedTransactionId;
    if (preselected != null) {
      final match = MockData.transactions.where((t) => t.id == preselected);
      if (match.isNotEmpty && _isEligible(match.first)) {
        _transactionId = preselected;
      }
    }
  }

  bool _isEligible(Transaction t) =>
      DateTime.now().difference(t.date).inDays <= MockData.refundWindowDays;

  @override
  Widget build(BuildContext context) {
    final eligible = MockData.transactions.where(_isEligible).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Request a refund')),
      body: PageBody(
        children: [
          Panel(
            background: AppColors.surfaceAlt,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.schedule_rounded,
                    size: 18, color: AppColors.inkSoft),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Refunds can be requested within ${MockData.refundWindowDays} days of a charge. '
                    'Staff review each request before any money is returned.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Eyebrow('Which charge?'),
          if (eligible.isEmpty)
            Panel(
              background: AppColors.dangerTint,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Icon(Icons.info_outline_rounded, size: 18, color: AppColors.danger),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'No charges in the last ${MockData.refundWindowDays} days are eligible for a refund.',
                      style: TextStyle(fontSize: 13.5, color: AppColors.danger),
                    ),
                  ),
                ],
              ),
            )
          else
            ...MockData.transactions.map((t) {
              final ok = _isEligible(t);
              final selected = _transactionId == t.id;
              final daysAgo = DateTime.now().difference(t.date).inDays;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Panel(
                  onTap: ok ? () => setState(() => _transactionId = t.id) : null,
                  background: selected ? AppColors.primaryTint : null,
                  child: Opacity(
                    opacity: ok ? 1 : 0.5,
                    child: Row(
                      children: [
                        Icon(
                            selected
                                ? Icons.radio_button_checked_rounded
                                : Icons.radio_button_unchecked_rounded,
                            size: 20,
                            color: selected ? AppColors.primary : AppColors.hairline),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(t.type, style: Theme.of(context).textTheme.titleMedium),
                              Text(
                                  ok
                                      ? '${t.id}  ·  $daysAgo days ago'
                                      : '${t.id}  ·  Outside the ${MockData.refundWindowDays}-day window',
                                  style: ok
                                      ? Theme.of(context).textTheme.bodyMedium
                                      : Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.danger)),
                            ],
                          ),
                        ),
                        Text('RM ${t.amount.toStringAsFixed(2)}',
                            style: const TextStyle(
                                fontSize: 14.5, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
              );
            }),
          const SizedBox(height: 14),
          const Eyebrow('Why?'),
          Panel(
            padding: EdgeInsets.zero,
            child: Column(
              children: _reasons
                  .map((r) => RadioListTile<String>(
                        value: r,
                        groupValue: _reason,
                        onChanged: (v) => setState(() => _reason = v),
                        title: Text(r,
                            style: const TextStyle(fontSize: 14.5)),
                        dense: true,
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 14),
          const TextField(
            maxLines: 4,
            decoration:
                InputDecoration(hintText: 'Add any details that would help'),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: (_transactionId == null || _reason == null)
                ? null
                : () {
                    Navigator.pop(context);
                    showToast(context,
                        'Request submitted. We will email you once it is reviewed.');
                  },
            child: const Text('Submit request'),
          ),
        ],
      ),
    );
  }
}
