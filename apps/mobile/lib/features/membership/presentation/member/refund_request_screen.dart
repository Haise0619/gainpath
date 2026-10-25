import 'package:flutter/material.dart';
import 'package:gainpath_domain/membership.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../application/membership_feature_host.dart';
import '../shared/membership_data_view.dart';

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
        return [
          const Panel(
              child: Text(
                  'Requests must be within seven days of payment clearance. Admin reviews each claim. Approval does not mean money has been returned.')),
          const SizedBox(height: 18),
          if (payments.isEmpty)
            const Text('No cleared membership payments available.'),
          if (payments.isNotEmpty)
            DropdownButtonFormField<String>(
                initialValue: exists ? _selected : null,
                decoration:
                    const InputDecoration(labelText: 'Membership payment'),
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
          if (selected != null) ...[
            const SizedBox(height: 16),
            Text(membershipPaymentLabel(selected)),
            if (selected['reviewReason'] != null)
              Text('Admin decision: ${selected['reviewReason']}'),
            if (!requested) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                  initialValue: _reason,
                  decoration: const InputDecoration(labelText: 'Reason'),
                  items: const [
                    'Charged twice for the same item',
                    'Incorrect membership charge',
                    'Something else'
                  ]
                      .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                      .toList(),
                  onChanged:
                      _busy ? null : (v) => setState(() => _reason = v!)),
              const SizedBox(height: 16),
              TextField(
                  controller: _notes,
                  maxLength: 2000,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Notes')),
              if (_busy) const LinearProgressIndicator(),
              FilledButton(
                  onPressed: _busy
                      ? null
                      : () async {
                          setState(() {
                            _busy = true;
                            _message = null;
                          });
                          try {
                            await widget.repository
                                .refund(_selected!, _reason, _notes.text);
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
                            if (context.mounted) setState(() => _busy = false);
                          }
                        },
                  child: const Text('Submit refund request')),
            ],
          ],
          if (_message != null) Text(_message!),
          const SizedBox(height: 24),
          const Eyebrow('Your refund cases'),
          ...payments.where((p) => p['refundStatus'] != null).map((p) => ListTile(
              title: Text(
                  '${p['planName']} · ${membershipMoney(p['amountMinor'])}'),
              subtitle: Text(
                  '${membershipPaymentLabel(p)}\n${p['reviewReason'] ?? 'Awaiting Admin review'}'))),
        ];
      });
}
