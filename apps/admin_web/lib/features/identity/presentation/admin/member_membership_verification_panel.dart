import 'package:flutter/material.dart';
import 'package:gainpath_domain/membership.dart';
import 'package:gainpath_ui/gainpath_ui.dart';

/// Deliberately requests a fresh, read-only server result for each staff check.
class MemberMembershipVerificationPanel extends StatefulWidget {
  const MemberMembershipVerificationPanel(
      {super.key, required this.memberId, required this.repository});
  final String memberId;
  final MembershipVerificationRepository repository;
  @override
  State<MemberMembershipVerificationPanel> createState() =>
      _MemberMembershipVerificationPanelState();
}

class _MemberMembershipVerificationPanelState
    extends State<MemberMembershipVerificationPanel> {
  MemberMembershipVerification? _result;
  bool _loading = false, _failed = false;
  int _generation = 0;
  @override
  void didUpdateWidget(MemberMembershipVerificationPanel old) {
    super.didUpdateWidget(old);
    if (old.memberId != widget.memberId ||
        old.repository != widget.repository) {
      _generation++;
      _result = null;
      _loading = false;
      _failed = false;
    }
  }

  Future<void> _verify() async {
    final generation = ++_generation;
    setState(() {
      _result = null;
      _failed = false;
      _loading = true;
    });
    try {
      final result = await widget.repository.verifyMembership(widget.memberId);
      if (!mounted || generation != _generation) return;
      setState(() {
        _result = result;
        _loading = false;
      });
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() {
          _result = null;
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  String _date(int? millis) => millis == null
      ? 'Not applicable'
      : DateTime.fromMillisecondsSinceEpoch(millis).toLocal().toString();
  @override
  Widget build(BuildContext context) {
    final result = _result;
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Divider(),
          const Text('Current membership',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text(
              'Use a fresh server verification for general gym admission.',
              style: TextStyle(color: AppColors.inkSoft, fontSize: 12)),
          if (_failed)
            const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                    'Current membership could not be verified. Retry when connected.')),
          if (result != null) ...[
            const SizedBox(height: 8),
            Text(switch (result.status) {
              'verified' =>
                'Verified membership: ${result.entitlement!.effectiveTier!.label}',
              'denied' => 'Membership verification denied',
              _ => 'Membership status unknown'
            }),
            Text(
                'General gym admission: ${result.gymAdmission ? 'Included' : 'Not included'}'),
            if (result.entitlement?.paidExpiresAtMillis != null)
              Text(
                  'Paid validity ends (local): ${_date(result.entitlement!.paidExpiresAtMillis)}'),
            Text('Verified (local): ${_date(result.verifiedAtMillis)}'),
          ],
          const SizedBox(height: 8),
          OutlinedButton.icon(
              onPressed: _loading ? null : _verify,
              icon: _loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.verified_user_outlined, size: 18),
              label: const Text('Verify current membership')),
        ]));
  }
}
