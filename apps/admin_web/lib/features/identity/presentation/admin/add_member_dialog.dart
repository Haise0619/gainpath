import 'dart:math';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:google_fonts/google_fonts.dart';

typedef MemberSetupRequest = Future<Map<String, dynamic>> Function(
    Map<String, Object?> input);

typedef MemberBranch = ({String id, String name, bool active});

class AddMemberDialog extends StatefulWidget {
  const AddMemberDialog({
    super.key,
    required this.request,
    required this.loadBranches,
    this.homeBranchId,
    this.onCreated,
  });

  final MemberSetupRequest request;
  final Future<List<MemberBranch>> Function() loadBranches;
  final String? homeBranchId;
  final VoidCallback? onCreated;

  @override
  State<AddMemberDialog> createState() => _AddMemberDialogState();
}

class _AddMemberDialogState extends State<AddMemberDialog> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  late final String _requestId =
      List.generate(24, (_) => Random.secure().nextInt(16).toRadixString(16))
          .join();
  late Future<List<MemberBranch>> _branches;
  String? _branchId;
  String? _error;
  bool _busy = false;
  bool _uncertain = false;
  Map<String, dynamic>? _result;

  @override
  void initState() {
    super.initState();
    _branchId = widget.homeBranchId;
    _branches = widget.loadBranches();
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _send({required bool resend}) async {
    if (_busy || (!resend && !_form.currentState!.validate())) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.request({
        'schemaVersion': 1,
        'action': resend ? 'resend' : 'create',
        if (resend) 'memberId': _result!['memberId'] as String,
        if (!resend) ...{
          'requestId': _requestId,
          'displayName': _name.text.trim(),
          'email': _email.text.trim(),
          'phoneNumber': _phone.text.trim(),
          'homeBranchId': _branchId,
        },
      });
      if (!mounted) return;
      if (result['memberId'] is! String ||
          result['displayName'] is! String ||
          result['branchName'] is! String ||
          result['accountStatus'] is! String) {
        throw const FormatException('Incomplete member setup result.');
      }
      setState(() {
        _result = result;
        _uncertain = false;
      });
      if (!resend) widget.onCreated?.call();
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      setState(() {
        _uncertain = !resend &&
            ![
              'already-exists',
              'invalid-argument',
              'permission-denied',
              'unauthenticated',
              'failed-precondition'
            ].contains(error.code);
        _error = switch (error.code) {
          'already-exists' => 'This email already belongs to an account.',
          'permission-denied' ||
          'unauthenticated' =>
            'Your Admin access could not be verified. Sign in again.',
          'invalid-argument' ||
          'failed-precondition' =>
            error.message ?? 'Check the member details and home branch.',
          _ =>
            'Setup could not be confirmed. Retry to recover the same request.',
        };
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _uncertain = !resend;
          _error =
              'Setup could not be confirmed. Retry to recover the same request.';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _section(String title) => Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(title,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.ink,
                fontWeight: FontWeight.w700,
              )));

  Widget _formBody(List<MemberBranch> branches) {
    final active = branches.where((branch) => branch.active).toList();
    final enabled = !_busy && !_uncertain;
    return Form(
      key: _form,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Create a new member account and assign a home branch.'),
        _section('Personal information'),
        TextFormField(
          autofocus: true,
          controller: _name,
          enabled: enabled,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(labelText: 'Full Name *'),
          validator: (value) => (value ?? '').trim().isEmpty
              ? 'Enter the full name.'
              : (value ?? '').trim().length > 120
                  ? 'Use up to 120 characters.'
                  : null,
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _email,
          enabled: enabled,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(labelText: 'Email Address *'),
          validator: (value) {
            final email = (value ?? '').trim();
            return email.length > 254 ||
                    !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)
                ? 'Enter a valid email address.'
                : null;
          },
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _phone,
          enabled: enabled,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          decoration:
              const InputDecoration(labelText: 'Phone Number (Optional)'),
          validator: (value) {
            final phone =
                (value ?? '').trim().replaceAll(RegExp(r'[ ()-]'), '');
            return phone.isEmpty || RegExp(r'^\+?[0-9]{7,15}$').hasMatch(phone)
                ? null
                : 'Enter a valid phone number.';
          },
        ),
        _section('Branch assignment'),
        DropdownButtonFormField<String>(
          initialValue:
              active.any((branch) => branch.id == _branchId) ? _branchId : null,
          decoration: const InputDecoration(labelText: 'Home Branch *'),
          isExpanded: true,
          items: active
              .map((branch) => DropdownMenuItem(
                  value: branch.id,
                  child: Text(branch.name, overflow: TextOverflow.ellipsis)))
              .toList(),
          onChanged:
              enabled ? (value) => setState(() => _branchId = value) : null,
          validator: (value) =>
              value == null ? 'Select an active home branch.' : null,
        ),
        if (active.isEmpty) const Text('No active branches are available.'),
        _section('Initial membership'),
        Card(
          margin: EdgeInsets.zero,
          color: AppColors.primaryTint,
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: const ListTile(
            leading: Icon(Icons.card_membership_outlined),
            iconColor: AppColors.primary,
            textColor: AppColors.ink,
            title: Text('Free Plan',
                style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle:
                Text('Member can upgrade membership after account activation.'),
          ),
        ),
        _section('Account setup email'),
        const Text(
            'The member will receive instructions to securely set their password and activate their account.'),
      ]),
    );
  }

  Widget _success(Map<String, dynamic> data) {
    final status = switch (data['accountStatus']) {
      'complete' => 'Setup complete',
      'disabled' => 'Disabled',
      _ => 'Pending setup',
    };
    final delivery = switch (data['delivery']) {
      'sent' => 'Brevo accepted the setup email for delivery.',
      'failed' =>
        'The member account was created. The setup email could not be sent.',
      'rate_limited' => 'The setup email is limited. Try again later.',
      _ => 'Invitation delivery is pending.',
    };
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(Icons.check_circle_outline,
          color: Theme.of(context).colorScheme.primary),
      const SizedBox(height: 8),
      Text('Member: ${data['displayName']}'),
      Text('Home Branch: ${data['branchName']}'),
      Text('Account Status: $status'),
      if (data['accountStatus'] == 'pending') ...[
        const SizedBox(height: 8),
        Text(delivery),
      ],
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return PopScope(
      canPop: !_busy,
      child: FutureBuilder<List<MemberBranch>>(
        future: _branches,
        builder: (context, snapshot) {
          final branches = snapshot.data;
          return AlertDialog(
            constraints: const BoxConstraints(maxWidth: 560),
            titleTextStyle: GoogleFonts.poppins(
              fontSize: 21,
              color: AppColors.ink,
              fontWeight: FontWeight.w700,
            ),
            title: Text(result == null
                ? 'Add New Member'
                : 'Member created successfully.'),
            scrollable: true,
            content: SizedBox(
              width: 480,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                if (result != null)
                  Align(
                      alignment: Alignment.centerLeft, child: _success(result))
                else if (branches != null)
                  _formBody(branches)
                else if (snapshot.hasError)
                  TextButton(
                    onPressed: () =>
                        setState(() => _branches = widget.loadBranches()),
                    child: const Text('Could not load home branches. Retry'),
                  )
                else
                  const LinearProgressIndicator(
                      semanticsLabel: 'Loading home branches'),
                if (_busy)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: LinearProgressIndicator(),
                  ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Semantics(
                        liveRegion: true,
                        child: Text(_error!,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error))),
                  ),
              ]),
            ),
            actions: [
              TextButton(
                  onPressed: _busy ? null : () => Navigator.of(context).pop(),
                  child: Text(result == null ? 'Cancel' : 'Back to Members')),
              if (result == null)
                FilledButton(
                  onPressed: _busy || branches?.any((b) => b.active) != true
                      ? null
                      : () => _send(resend: false),
                  child: Text(
                      _uncertain ? 'Retry Create Member' : 'Create Member'),
                )
              else ...[
                if (result['accountStatus'] == 'pending')
                  OutlinedButton(
                      onPressed: _busy ? null : () => _send(resend: true),
                      child: const Text('Resend Setup Email')),
                FilledButton(
                    onPressed: _busy
                        ? null
                        : () => Navigator.of(context).pop(result['memberId']),
                    child: const Text('View Member')),
              ],
            ],
          );
        },
      ),
    );
  }
}
