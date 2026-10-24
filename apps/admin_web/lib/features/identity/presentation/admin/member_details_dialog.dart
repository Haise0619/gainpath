import 'package:flutter/material.dart';
import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:gainpath_domain/membership.dart';
import 'member_membership_verification_panel.dart';

class MemberDetailsDialog extends StatefulWidget {
  const MemberDetailsDialog(
      {super.key,
      required this.memberId,
      required this.repository,
      this.verificationRepository});
  final String memberId;
  final AdminMemberDirectoryRepository repository;
  final MembershipVerificationRepository? verificationRepository;
  @override
  State<MemberDetailsDialog> createState() => _MemberDetailsDialogState();
}

class _MemberDetailsDialogState extends State<MemberDetailsDialog> {
  AdminMemberDetails? _details;
  bool _loading = true, _failed = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
      _details = null;
    });
    try {
      final details = await widget.repository.loadDetails(widget.memberId);
      if (!mounted) return;
      setState(() {
        _details = details;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _failed = true;
        _loading = false;
      });
    }
  }

  String _date(int? value) {
    if (value == null) return 'Not recorded';
    final date = DateTime.fromMillisecondsSinceEpoch(value).toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)} ${two(date.hour)}:${two(date.minute)}';
  }

  Widget _field(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(color: AppColors.inkSoft, fontSize: 12)),
        const SizedBox(height: 3),
        SelectableText(value.isEmpty ? 'Not recorded' : value),
      ]));
  @override
  Widget build(BuildContext context) {
    final details = _details;
    final verification = widget.verificationRepository ??
        (widget.repository is MembershipVerificationRepository
            ? widget.repository as MembershipVerificationRepository
            : null);
    return AdminDialog(
        width: 540,
        child: ConstrainedBox(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * .8),
            child: SingleChildScrollView(
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Row(children: [
                    const Expanded(
                        child: Text('Member details',
                            style: TextStyle(
                                fontSize: 21, fontWeight: FontWeight.w700))),
                    IconButton(
                        tooltip: 'Close member details',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded))
                  ]),
                  const Text('Read-only organization membership record'),
                  const SizedBox(height: 16),
                  if (_loading)
                    const Center(
                        child: Padding(
                            padding: EdgeInsets.all(24),
                            child: CircularProgressIndicator())),
                  if (_failed) ...[
                    const Text(
                        'Could not load this member. The record or your Admin access may have changed.'),
                    TextButton(onPressed: _load, child: const Text('Retry')),
                  ],
                  if (details != null) ...[
                    _field('Full name', details.member.name),
                    _field('Email', details.member.email),
                    _field('Member ID', details.member.id),
                    _field('Organization', details.organizationId),
                    _field('Membership status', details.member.statusLabel),
                    _field(
                        'Branches',
                        details.branchIds.isEmpty
                            ? 'None recorded'
                            : details.branchIds.join(', ')),
                    _field(
                        'Joined (local time)', _date(details.createdAtMillis)),
                    _field('Last updated (local time)',
                        _date(details.updatedAtMillis)),
                    if (verification != null)
                      MemberMembershipVerificationPanel(
                          key: ValueKey(details),
                          memberId: widget.memberId,
                          repository: verification),
                  ],
                  const SizedBox(height: 16),
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    TextButton(
                        onPressed: _loading ? null : _load,
                        child: const Text('Refresh details')),
                    const SizedBox(width: 8),
                    OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close')),
                  ]),
                ]))));
  }
}
