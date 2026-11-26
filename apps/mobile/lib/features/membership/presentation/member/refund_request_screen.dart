import 'package:flutter/material.dart';
import 'package:gainpath_domain/membership.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../application/membership_feature_host.dart';
import '../shared/membership_data_view.dart';
import 'widgets/membership_components.dart';

class RefundRequestScreen extends StatelessWidget {
  const RefundRequestScreen(
      {super.key,
      this.preselectedTransactionId,
      this.connected = false,
      this.repository});
  final String? preselectedTransactionId;
  final bool connected;
  final MembershipCommerceRepository? repository;
  @override
  Widget build(BuildContext context) => repository != null
      ? MembershipRepositoryGuard(
          repository: repository!, child: _body(repository!))
      : MembershipFeatureHost(connected: connected, builder: _body);
  Widget _body(MembershipCommerceRepository repo) =>
      _RefundForm(repository: repo, selected: preselectedTransactionId);
}

class _RefundForm extends StatefulWidget {
  const _RefundForm({required this.repository, this.selected});
  final MembershipCommerceRepository repository;
  final String? selected;
  @override
  State<_RefundForm> createState() => _RefundFormState();
}

class _RefundFormState extends State<_RefundForm> {
  late String? _selected = widget.selected;
  final _notes = TextEditingController();
  String _reason = 'Charged twice for the same item';
  bool _busy = false;
  String? _message;
  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MembershipDataView(
      repository: widget.repository,
      title: 'Refund requests',
      builder: (context, data, refresh) {
        final payments = membershipRows(data['transactions'])
            .where((p) => p['paymentStatus'] == 'cleared')
            .toList();
        final exists = payments.any((p) => p['transactionId'] == _selected);
        final selected =
            payments.where((p) => p['transactionId'] == _selected).firstOrNull;
        final requested = selected?['refundStatus'] != null;
        final now = data['serverNowMillis'];
        final cleared = selected?['clearedAtMillis'];
        final deadline = cleared is num
            ? cleared.toInt() + const Duration(days: 7).inMilliseconds
            : null;
        final verified = data['cached'] != true &&
            now is int &&
            deadline != null &&
            cleared is num &&
            now >= cleared;
        final eligible = verified && now <= deadline;
        final cases = payments.where((p) => p['refundStatus'] != null).toList();

        return [
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.hairline),
            ),
            padding: const EdgeInsets.all(16),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 20, color: AppColors.primary),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Requests must be within seven days of payment clearance. Admin reviews each claim. Approval does not mean money has been returned.',
                    style: TextStyle(
                        fontSize: 13, color: AppColors.ink, height: 1.45),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (payments.isEmpty)
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.hairline),
              ),
              padding: const EdgeInsets.all(20),
              child: const Center(
                child: Text(
                  'No cleared membership payments available.',
                  style: TextStyle(color: AppColors.inkSoft, fontSize: 13.5),
                ),
              ),
            ),
          if (payments.isNotEmpty)
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.hairline),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: DropdownButtonFormField<String>(
                  initialValue: exists ? _selected : null,
                  decoration: const InputDecoration(
                    labelText: 'Membership payment',
                    border: InputBorder.none,
                  ),
                  items: payments
                      .map((p) => DropdownMenuItem(
                          value: p['transactionId'] as String,
                          child: Text(
                              '${p['planName']} · ${membershipMoney(p['amountMinor'])} · ${membershipDate(p['createdAtMillis'])}',
                              overflow: TextOverflow.ellipsis)))
                      .toList(),
                  isExpanded: true,
                  onChanged: _busy
                      ? null
                      : (v) => setState(() {
                            _selected = v;
                            _message = null;
                          })),
            ),
          if (selected != null) ...[
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.hairline),
              ),
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '${selected['planName']} · ${membershipMoney(selected['amountMinor'])}',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink,
                              ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      PaymentStatusIndicator(
                        status: selected['paymentStatus'] as String?,
                        refundStatus: selected['refundStatus'] as String?,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    membershipPaymentLabel(selected),
                    style: const TextStyle(
                        fontSize: 13.5, color: AppColors.ink),
                  ),
                  if (selected['reviewReason'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'Admin decision: ${selected['reviewReason']}',
                        style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  if (!requested && deadline != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Row(
                        children: [
                          const Icon(Icons.timer_outlined,
                              size: 16, color: AppColors.inkSoft),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Request deadline: ${membershipDate(deadline)}',
                              style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.ink),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (!requested && !eligible)
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppColors.warning.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        verified
                            ? 'The seven-day request window has ended. Your payment and membership history remain available.'
                            : 'Refresh online to verify the payment date and refund eligibility.',
                        style: const TextStyle(
                            color: AppColors.warning, fontSize: 13),
                      ),
                    ),
                ],
              ),
            ),
            if (!requested && eligible) ...[
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.hairline),
                ),
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<String>(
                        initialValue: _reason,
                        isExpanded: true,
                        decoration:
                            const InputDecoration(labelText: 'Reason'),
                        items: const [
                          'Charged twice for the same item',
                          'Incorrect membership charge',
                          'Something else'
                        ]
                            .map((v) => DropdownMenuItem(
                                value: v,
                                child: Text(v,
                                    overflow: TextOverflow.ellipsis)))
                            .toList(),
                        onChanged:
                            _busy ? null : (v) => setState(() => _reason = v!)),
                    const SizedBox(height: 16),
                    TextField(
                        controller: _notes,
                        enabled: !_busy,
                        maxLength: 2000,
                        maxLines: 4,
                        decoration:
                            const InputDecoration(labelText: 'Notes')),
                    if (_busy) const LinearProgressIndicator(),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 48,
                      child: FilledButton(
                          onPressed: _busy
                              ? null
                              : () async {
                                  setState(() {
                                    _busy = true;
                                    _message = null;
                                  });
                                  try {
                                    await widget.repository.refund(
                                        _selected!, _reason, _notes.text);
                                    if (context.mounted) {
                                      setState(() => _message =
                                          'Request submitted for Admin review. No refund transfer was made.');
                                      refresh();
                                    }
                                  } catch (_) {
                                    if (context.mounted) {
                                      setState(() => _message =
                                          'Request not accepted. A cleared payment within seven days and a current verified account are required. Refresh before retrying.');
                                    }
                                  } finally {
                                    if (context.mounted) {
                                      setState(() => _busy = false);
                                    }
                                  }
                                },
                          style: FilledButton.styleFrom(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            textStyle: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600),
                          ),
                          child: const Text('Submit refund request')),
                    ),
                  ],
                ),
              ),
            ],
          ],
          if (_message != null)
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.infoTint,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _message!,
                style: const TextStyle(color: AppColors.info, fontSize: 13),
              ),
            ),
          const SizedBox(height: 24),
          const Eyebrow('Your refund cases'),
          const SizedBox(height: 8),
          if (cases.isEmpty)
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.hairline),
              ),
              padding: const EdgeInsets.all(18),
              child: const Center(
                child: Text(
                  'No submitted refund cases.',
                  style: TextStyle(color: AppColors.inkSoft, fontSize: 13),
                ),
              ),
            ),
          ...cases.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.hairline),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                '${p['planName']} · ${membershipMoney(p['amountMinor'])}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 14),
                              ),
                            ),
                            const SizedBox(width: 8),
                            PaymentStatusIndicator(
                              status: p['paymentStatus'] as String?,
                              refundStatus: p['refundStatus'] as String?,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${membershipPaymentLabel(p)}\n${p['reviewReason'] ?? 'Awaiting Admin review'}',
                          style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColors.inkSoft,
                              height: 1.35),
                        ),
                      ],
                    ),
                  ),
                ),
              )),
          const SizedBox(height: 16),
        ];
      });
}
