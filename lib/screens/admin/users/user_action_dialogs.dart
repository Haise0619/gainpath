import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../data/mock_data.dart';
import '../../../widgets/shared.dart';
import '../admin_dialogs.dart';

/// Every user-account action in the admin console (suspend, deactivate,
/// verify, provision) opens through one of the dialogs in this file —
/// built on the shared `AdminDialog`/`confirmDialog` primitives in
/// `admin_dialogs.dart` — rather than a mobile bottom sheet, and sized
/// to what each action actually needs rather than taking the full page.
/// Shared between the Members and Coaches screens so the two don't
/// duplicate this plumbing.

/// Admin-initiated password reset — distinct from a member/coach's own
/// self-service change-password flow. No account state to mutate here;
/// this only triggers an email, so a confirm dialog is the whole flow.
Future<void> resetPasswordFlow(BuildContext context, UserAccount user) async {
  final ok = await confirmDialog(
    context,
    title: 'Reset password for ${user.name}?',
    message: 'They will get an email at ${user.email} with a link to set a new password. Their current password stops working once they do.',
    confirmLabel: 'Send reset link',
  );
  if (ok && context.mounted) {
    showToast(context, 'Password reset link sent to ${user.email}.');
  }
}

/// AD-M11.3 — Suspend Gym Member Account.
Future<void> suspendMemberFlow(BuildContext context, UserAccount user, VoidCallback onChanged) async {
  final result = await showDialog<Map<String, String>>(
    context: context,
    builder: (ctx) => _SuspendMemberDialog(memberName: user.name),
  );
  if (result != null) {
    user.status = 'Suspended';
    onChanged();
    if (context.mounted) {
      showToast(context, '${user.name} suspended (${result['duration']}) — ${result['reason']}.');
    }
  }
}

Future<void> liftSuspensionFlow(BuildContext context, UserAccount user, VoidCallback onChanged) async {
  final ok = await confirmDialog(context,
      title: 'Lift suspension for ${user.name}?', message: 'Their account regains full access immediately.');
  if (ok) {
    user.status = 'Active';
    onChanged();
    if (context.mounted) showToast(context, '${user.name} can access their account again.');
  }
}

/// AD-M11.3 — Deactivate Coach Account.
Future<void> deactivateCoachFlow(BuildContext context, UserAccount user, VoidCallback onChanged) async {
  final reason = await showDialog<String>(
    context: context,
    builder: (ctx) => _DeactivateCoachDialog(coachName: user.name),
  );
  if (reason != null && reason.isNotEmpty) {
    user.status = 'Deactivated';
    onChanged();
    if (context.mounted) {
      showToast(context, '${user.name} deactivated. Upcoming sessions were cancelled and members notified.');
    }
  }
}

/// AD-M11.3 — Verify Coach Credentials.
Future<void> verifyCoachFlow(BuildContext context, UserAccount user, VoidCallback onChanged) async {
  await showDialog(context: context, builder: (ctx) => _VerifyCoachDialog(user: user));
  onChanged();
}

/// AD-M11.3 — Provision Coach Account.
Future<void> provisionCoachFlow(BuildContext context, VoidCallback onChanged) async {
  final created = await showDialog<bool>(context: context, builder: (ctx) => const _ProvisionCoachDialog());
  if (created == true) {
    onChanged();
    if (context.mounted) showToast(context, 'Invitation sent — visible in the directory as Invited.');
  }
}

class _SuspendMemberDialog extends StatefulWidget {
  final String memberName;
  const _SuspendMemberDialog({required this.memberName});

  @override
  State<_SuspendMemberDialog> createState() => _SuspendMemberDialogState();
}

class _SuspendMemberDialogState extends State<_SuspendMemberDialog> {
  static const _reasons = [
    'Harassment or abusive behaviour',
    'Payment fraud or chargeback abuse',
    'Misuse of gym facility or equipment',
    'Other policy violation',
  ];
  static const _durations = ['7 days', '30 days', 'Indefinite'];

  String _reason = _reasons.first;
  String _duration = _durations.first;

  @override
  Widget build(BuildContext context) {
    return AdminDialog(
      width: 400,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Suspend ${widget.memberName}?', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text('Future bookings are cancelled and gamification points are frozen while suspended.',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _reason,
            decoration: const InputDecoration(labelText: 'Violation reason', isDense: true),
            items: _reasons.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
            onChanged: (v) => setState(() => _reason = v ?? _reason),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _duration,
            decoration: const InputDecoration(labelText: 'Duration', isDense: true),
            items: _durations.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
            onChanged: (v) => setState(() => _duration = v ?? _duration),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
                  onPressed: () => Navigator.pop(context, {'reason': _reason, 'duration': _duration}),
                  child: const FittedBox(fit: BoxFit.scaleDown, child: Text('Suspend account', maxLines: 1)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DeactivateCoachDialog extends StatefulWidget {
  final String coachName;
  const _DeactivateCoachDialog({required this.coachName});

  @override
  State<_DeactivateCoachDialog> createState() => _DeactivateCoachDialogState();
}

class _DeactivateCoachDialogState extends State<_DeactivateCoachDialog> {
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
          Text('Deactivate ${widget.coachName}?', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text('Their profile is removed from the directory and upcoming sessions are cancelled.',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 14),
          TextField(
            controller: _reason,
            maxLines: 2,
            decoration: InputDecoration(labelText: 'Reason for deactivation', errorText: _error, isDense: true),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
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
                  child: const FittedBox(fit: BoxFit.scaleDown, child: Text('Deactivate', maxLines: 1)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProvisionCoachDialog extends StatefulWidget {
  const _ProvisionCoachDialog();

  @override
  State<_ProvisionCoachDialog> createState() => _ProvisionCoachDialogState();
}

class _ProvisionCoachDialogState extends State<_ProvisionCoachDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _specialty = TextEditingController();
  String? _branch;
  bool _triedSubmit = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _specialty.dispose();
    super.dispose();
  }

  void _submit() {
    setState(() => _triedSubmit = true);
    final formOk = _formKey.currentState?.validate() ?? false;
    if (!formOk || _branch == null) return;
    MockData.users.add(UserAccount(_name.text.trim(), _email.text.trim(), 'Coach', 'Invited',
        branch: _branch, specialty: _specialty.text.trim()));
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return AdminDialog(
      width: 480,
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add a coach', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 3),
            Text('They will get an email invitation to set their password.',
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _name,
                    decoration: const InputDecoration(labelText: 'Full name', isDense: true),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _email,
                    decoration: const InputDecoration(labelText: 'Work email', isDense: true),
                    validator: (v) {
                      final value = v?.trim() ?? '';
                      if (value.isEmpty) return 'Required';
                      if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)) {
                        return 'Enter a valid email.';
                      }
                      final taken = MockData.users.any((u) => u.email.toLowerCase() == value.toLowerCase());
                      if (taken) return 'Already registered.';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _specialty,
                    decoration: const InputDecoration(labelText: 'Specialty', isDense: true),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _branch,
                    decoration: InputDecoration(
                      labelText: 'Branch',
                      isDense: true,
                      errorText: _triedSubmit && _branch == null ? 'Required' : null,
                    ),
                    items: MockData.branches.map((b) => DropdownMenuItem(value: b.name, child: Text(b.name))).toList(),
                    onChanged: (v) => setState(() => _branch = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: _submit,
                    child: const Text('Send invitation'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _VerifyCoachDialog extends StatefulWidget {
  final UserAccount user;
  const _VerifyCoachDialog({required this.user});

  @override
  State<_VerifyCoachDialog> createState() => _VerifyCoachDialogState();
}

class _VerifyCoachDialogState extends State<_VerifyCoachDialog> {
  final _rejectReason = TextEditingController();
  bool _rejecting = false;
  String? _reasonError;

  @override
  void dispose() {
    _rejectReason.dispose();
    super.dispose();
  }

  void _approve() {
    widget.user.status = 'Verified';
    Navigator.pop(context);
    showToast(context, '${widget.user.name} is now visible to members.');
  }

  void _reject() {
    if (!_rejecting) {
      setState(() => _rejecting = true);
      return;
    }
    if (_rejectReason.text.trim().isEmpty) {
      setState(() => _reasonError = 'Enter a reason so the coach knows what to fix.');
      return;
    }
    widget.user.status = 'Rejected';
    Navigator.pop(context);
    showToast(context, 'Sent back for correction.');
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    return AdminDialog(
      width: 460,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Verify credentials', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text('${user.name}  ·  ${user.email}', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 14),
          Container(
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.hairline),
            ),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.description_outlined, size: 30, color: AppColors.inkSoft),
                  SizedBox(height: 6),
                  Text('NASM-CPT-Certificate.pdf',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.inkSoft)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_rejecting) ...[
            TextField(
              controller: _rejectReason,
              maxLines: 2,
              autofocus: true,
              onChanged: (_) {
                if (_reasonError != null) setState(() => _reasonError = null);
              },
              decoration: InputDecoration(
                hintText: 'Reason shown to the coach',
                errorText: _reasonError,
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                  onPressed: _reject,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(_rejecting ? 'Confirm rejection' : 'Reject', maxLines: 1),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: _approve,
                  child: const FittedBox(fit: BoxFit.scaleDown, child: Text('Approve and publish', maxLines: 1)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
