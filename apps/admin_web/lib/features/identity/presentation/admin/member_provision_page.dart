import 'dart:math';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:google_fonts/google_fonts.dart';

typedef MemberSetupRequest = Future<Map<String, dynamic>> Function(
    Map<String, Object?> input);

typedef MemberBranch = ({String id, String name, bool active});

class MemberProvisionPage extends StatefulWidget {
  const MemberProvisionPage({
    super.key,
    required this.request,
    required this.loadBranches,
    required this.onClose,
    this.onLeaveCheckChanged,
    this.homeBranchId,
    this.onCreated,
  });

  final MemberSetupRequest request;
  final Future<List<MemberBranch>> Function() loadBranches;
  final String? homeBranchId;
  final VoidCallback? onCreated;
  final ValueChanged<String?> onClose;
  final ValueChanged<Future<bool> Function()?>? onLeaveCheckChanged;

  @override
  State<MemberProvisionPage> createState() => _MemberProvisionPageState();
}

class _MemberProvisionPageState extends State<MemberProvisionPage> {
  final _form = GlobalKey<FormState>();
  final _scrollController = ScrollController();
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
  Future<bool>? _discardConfirmation;

  @override
  void initState() {
    super.initState();
    _branchId = widget.homeBranchId;
    _branches = widget.loadBranches();
    widget.onLeaveCheckChanged?.call(_canLeave);
  }

  @override
  void dispose() {
    widget.onLeaveCheckChanged?.call(null);
    _scrollController.dispose();
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<bool> _canLeave() async {
    if (_busy) return false;
    if (_result != null ||
        (!_uncertain &&
            _branchId == widget.homeBranchId &&
            [_name, _email, _phone]
                .every((field) => field.text.trim().isEmpty))) {
      return true;
    }
    return _discardConfirmation ??= confirmDialog(
      context,
      title: 'Discard member onboarding?',
      message: 'The information entered in this form will be lost.',
      confirmLabel: 'Discard',
      destructive: true,
    ).whenComplete(() => _discardConfirmation = null);
  }

  Future<void> _leave([String? memberId]) async {
    if (await _canLeave() && mounted) widget.onClose(memberId);
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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(0);
        }
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

  InputDecoration _fieldDecoration({
    required String labelText,
    required String hintText,
    required IconData prefixIcon,
    String? helperText,
  }) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: const TextStyle(
        fontSize: 13.5,
        fontWeight: FontWeight.w500,
        color: AppColors.inkSoft,
      ),
      floatingLabelStyle: const TextStyle(
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
        color: AppColors.primary,
      ),
      floatingLabelBehavior: FloatingLabelBehavior.always,
      hintText: hintText,
      hintStyle: const TextStyle(
        fontSize: 13.5,
        color: Color(0xFFA59DB8),
      ),
      helperText: helperText,
      helperStyle: const TextStyle(
        fontSize: 11.5,
        color: AppColors.inkSoft,
      ),
      prefixIcon: Icon(prefixIcon, size: 19, color: AppColors.inkSoft),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.hairline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.hairline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.danger, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
      ),
      errorStyle: const TextStyle(
        fontSize: 11.5,
        color: AppColors.danger,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _sectionHeading({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.primaryTint,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: AppColors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.inkSoft,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _formBody(List<MemberBranch> branches) {
    final active = branches.where((branch) => branch.active).toList();
    final enabled = !_busy && !_uncertain;

    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionHeading(
            icon: Icons.person_outline_rounded,
            title: 'Personal information',
            subtitle: 'Enter the new member\'s primary contact details.',
          ),
          const SizedBox(height: 18),
          TextFormField(
            autofocus: true,
            controller: _name,
            enabled: enabled,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            style: const TextStyle(fontSize: 14, color: AppColors.ink),
            decoration: _fieldDecoration(
              labelText: 'Full Name *',
              hintText: 'e.g. Sarah Jenkins',
              prefixIcon: Icons.badge_outlined,
            ),
            validator: (value) => (value ?? '').trim().isEmpty
                ? 'Enter the full name.'
                : (value ?? '').trim().length > 120
                    ? 'Use up to 120 characters.'
                    : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _email,
            enabled: enabled,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            style: const TextStyle(fontSize: 14, color: AppColors.ink),
            decoration: _fieldDecoration(
              labelText: 'Email Address *',
              hintText: 'sarah.jenkins@example.com',
              prefixIcon: Icons.mail_outline_rounded,
              helperText: 'A secure setup email will be delivered to this address.',
            ),
            validator: (value) {
              final email = (value ?? '').trim();
              return email.length > 254 ||
                      !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)
                  ? 'Enter a valid email address.'
                  : null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _phone,
            enabled: enabled,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            style: const TextStyle(fontSize: 14, color: AppColors.ink),
            decoration: _fieldDecoration(
              labelText: 'Phone Number (Optional)',
              hintText: '+60 12-345 6789',
              prefixIcon: Icons.phone_outlined,
              helperText: 'Optional contact number for emergency and booking notifications.',
            ),
            validator: (value) {
              final phone =
                  (value ?? '').trim().replaceAll(RegExp(r'[ ()-]'), '');
              return phone.isEmpty || RegExp(r'^\+?[0-9]{7,15}$').hasMatch(phone)
                  ? null
                  : 'Enter a valid phone number.';
            },
          ),
          const SizedBox(height: 24),
          const Divider(height: 1, color: AppColors.hairline),
          const SizedBox(height: 20),
          _sectionHeading(
            icon: Icons.storefront_outlined,
            title: 'Branch assignment',
            subtitle: 'Select the home gym where this member is registered.',
          ),
          const SizedBox(height: 18),
          DropdownButtonFormField<String>(
            initialValue: active.any((branch) => branch.id == _branchId)
                ? _branchId
                : null,
            decoration: _fieldDecoration(
              labelText: 'Home Branch *',
              hintText: 'Select a home branch',
              prefixIcon: Icons.location_on_outlined,
              helperText: 'Designates the member\'s default gym facility and access pass.',
            ),
            icon: const Icon(Icons.keyboard_arrow_down_rounded,
                color: AppColors.inkSoft),
            dropdownColor: Colors.white,
            borderRadius: BorderRadius.circular(12),
            isExpanded: true,
            style: const TextStyle(fontSize: 14, color: AppColors.ink),
            items: active
                .map((branch) => DropdownMenuItem(
                      value: branch.id,
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              branch.name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.ink,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Active',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF16A34A),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ))
                .toList(),
            onChanged:
                enabled ? (value) => setState(() => _branchId = value) : null,
            validator: (value) =>
                value == null ? 'Select an active home branch.' : null,
          ),
          if (active.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        size: 18, color: Color(0xFFD97706)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'No active branches are available. Configure a branch first.',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF92400E)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
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

    final isFailed = data['delivery'] == 'failed';
    final isSent = data['delivery'] == 'sent';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF86EFAC)),
              ),
              child: const Icon(Icons.check_circle_outline,
                  color: Color(0xFF16A34A), size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Member created successfully.',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Account provisioned and registered in directory.',
                    style: TextStyle(fontSize: 12.5, color: AppColors.inkSoft),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.hairline),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            children: [
              _summaryRow('Member', data['displayName'] as String),
              const Divider(height: 16, color: AppColors.hairline),
              _summaryRow('Email Address', _email.text.trim()),
              const Divider(height: 16, color: AppColors.hairline),
              _summaryRow('Home Branch', data['branchName'] as String),
              const Divider(height: 16, color: AppColors.hairline),
              _summaryRow('Initial Membership', 'Free Plan'),
              const Divider(height: 16, color: AppColors.hairline),
              _summaryRow('Account Status', status,
                  badge: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: status == 'Setup complete'
                          ? const Color(0xFFDCFCE7)
                          : const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Account Status: $status',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: status == 'Setup complete'
                            ? const Color(0xFF16A34A)
                            : const Color(0xFFB45309),
                      ),
                    ),
                  )),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isFailed
                ? const Color(0xFFFEF3C7)
                : isSent
                    ? const Color(0xFFF0FDF4)
                    : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isFailed
                  ? const Color(0xFFFDE68A)
                  : isSent
                      ? const Color(0xFFBBF7D0)
                      : AppColors.hairline,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isFailed
                    ? Icons.warning_amber_rounded
                    : isSent
                        ? Icons.mark_email_read_outlined
                        : Icons.info_outline_rounded,
                size: 20,
                color: isFailed
                    ? const Color(0xFFD97706)
                    : isSent
                        ? const Color(0xFF16A34A)
                        : AppColors.inkSoft,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      delivery,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: isFailed
                            ? const Color(0xFF92400E)
                            : isSent
                                ? const Color(0xFF166534)
                                : AppColors.ink,
                      ),
                    ),
                    if (isFailed) ...[
                      const SizedBox(height: 4),
                      const Text(
                        'The member record is safely saved. You can click Resend Setup Email once delivery availability recovers.',
                        style: TextStyle(fontSize: 11.5, color: Color(0xFF78350F)),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _summaryRow(String label, String value, {Widget? badge}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: AppColors.inkSoft,
          ),
        ),
        if (badge != null)
          badge
        else
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
          ),
      ],
    );
  }

  Widget _panel(Widget child) => Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.hairline),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x061E1538),
              blurRadius: 16,
              offset: Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(24),
        child: child,
      );

  Widget _setupSummary() {
    final result = _result;
    final isSent = result != null && result['delivery'] == 'sent';
    final isFailed = result != null && result['delivery'] == 'failed';

    return _panel(Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.primaryTint,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.assignment_turned_in_outlined,
                  size: 18, color: AppColors.primary),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Account Setup Summary',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  Text(
                    'Default tier & activation workflow',
                    style: TextStyle(fontSize: 11.5, color: AppColors.inkSoft),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const Divider(height: 1, color: AppColors.hairline),
        const SizedBox(height: 16),
        const Text(
          'Initial membership',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFAF7FF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE9D5FF)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.card_membership_outlined,
                        size: 18, color: AppColors.primary),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Free Plan',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primaryTint,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Standard',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Members can upgrade after activating their account.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.inkSoft,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 10),
              _benefitItem('Gym discovery and multi-branch visit check-in'),
              _benefitItem('AI pose estimation and real-time workout tracking'),
              _benefitItem('Personal routine history & progress analytics'),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Divider(height: 1, color: AppColors.hairline),
        const SizedBox(height: 16),
        const Text(
          'Account setup',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'The member receives a secure email to set their password and verify their address.',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.inkSoft,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 14),
        _workflowStep(
          step: 1,
          title: 'Member account created',
          subtitle: 'Profile registered with assigned home gym.',
          done: result != null,
        ),
        const SizedBox(height: 12),
        _workflowStep(
          step: 2,
          title: 'Secure setup email sent',
          subtitle: 'Invite link dispatched via Brevo service.',
          done: isSent,
          failed: isFailed,
        ),
        const SizedBox(height: 12),
        _workflowStep(
          step: 3,
          title: 'Password setup & verification',
          subtitle: 'Member establishes self-service credentials.',
          done: false,
          pendingText: result != null ? 'Awaiting member sign-in' : null,
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.hairline),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lock_outline_rounded,
                  size: 16, color: AppColors.inkSoft),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Admins never set temporary passwords. Credentials are verified directly by the user.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppColors.inkSoft,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ));
  }

  Widget _benefitItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_rounded, size: 14, color: AppColors.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 11.5,
                color: AppColors.inkSoft,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _workflowStep({
    required int step,
    required String title,
    required String subtitle,
    required bool done,
    bool failed = false,
    String? pendingText,
  }) {
    final Color badgeBg;
    final Widget badgeChild;

    if (done) {
      badgeBg = const Color(0xFFDCFCE7);
      badgeChild = const Icon(Icons.check_rounded, size: 14, color: Color(0xFF16A34A));
    } else if (failed) {
      badgeBg = const Color(0xFFFEF3C7);
      badgeChild = const Icon(Icons.priority_high_rounded, size: 14, color: Color(0xFFD97706));
    } else {
      badgeBg = AppColors.surfaceAlt;
      badgeChild = Text(
        '$step',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.inkSoft,
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: badgeBg,
            shape: BoxShape.circle,
            border: Border.all(
              color: done
                  ? const Color(0xFF86EFAC)
                  : failed
                      ? const Color(0xFFFDE68A)
                      : AppColors.hairline,
            ),
          ),
          alignment: Alignment.center,
          child: badgeChild,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: done ? AppColors.ink : AppColors.inkSoft,
                      ),
                    ),
                  ),
                  if (pendingText != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        pendingText,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.inkSoft,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFFA59DB8),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;

    return FutureBuilder<List<MemberBranch>>(
      future: _branches,
      builder: (context, snapshot) {
        final branches = snapshot.data;

        final form = _panel(Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (result != null)
              _success(result)
            else if (branches != null)
              _formBody(branches)
            else if (snapshot.hasError)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: Color(0xFFDC2626)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextButton(
                        style: TextButton.styleFrom(
                          alignment: Alignment.centerLeft,
                          padding: EdgeInsets.zero,
                          foregroundColor: const Color(0xFF991B1B),
                        ),
                        onPressed: () =>
                            setState(() => _branches = widget.loadBranches()),
                        child: const Text(
                          'Could not load home branches. Retry',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: LinearProgressIndicator(
                    semanticsLabel: 'Loading home branches'),
              ),
            if (_busy)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: LinearProgressIndicator(
                    semanticsLabel: 'Submitting member setup'),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Semantics(
                  liveRegion: true,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            size: 19, color: Color(0xFFDC2626)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _error!,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF991B1B),
                                ),
                              ),
                              if (_uncertain) ...[
                                const SizedBox(height: 4),
                                const Text(
                                  'The request was interrupted. You can safely retry without creating duplicate records.',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: Color(0xFF7F1D1D),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 24),
            const Divider(height: 1, color: AppColors.hairline),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (result == null) ...[
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.ink,
                      side: const BorderSide(color: AppColors.hairline),
                      backgroundColor: Colors.white,
                      minimumSize: const Size(0, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                    onPressed: _busy ? null : () => _leave(),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 44),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                    onPressed: _busy ||
                            branches?.any((branch) => branch.active) != true
                        ? null
                        : () => _send(resend: false),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_busy) ...[
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          _uncertain
                              ? 'Retry Create Member'
                              : 'Create Member',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  if (result['accountStatus'] == 'pending') ...[
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        backgroundColor: Colors.white,
                        minimumSize: const Size(0, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9),
                        ),
                      ),
                      onPressed: _busy ? null : () => _send(resend: true),
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text(
                        'Resend Setup Email',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 44),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                    onPressed: _busy
                        ? null
                        : () => _leave(result['memberId'] as String),
                    icon: const Icon(Icons.visibility_outlined, size: 16),
                    label: const Text(
                      'View Member',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ));

        return ColoredBox(
          color: AppColors.bg,
          child: SingleChildScrollView(
            controller: _scrollController,
            key: const ValueKey('add-member-page'),
            padding: const EdgeInsets.fromLTRB(28, 22, 28, 40),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1160),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Add New Member',
                              style: GoogleFonts.poppins(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Create a member account and assign their home branch.',
                              style: TextStyle(
                                fontSize: 13.5,
                                color: AppColors.inkSoft,
                              ),
                            ),
                          ],
                        ),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.ink,
                            side: const BorderSide(color: AppColors.hairline),
                            backgroundColor: Colors.white,
                            minimumSize: const Size(0, 38),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(9),
                            ),
                          ),
                          onPressed: _busy ? null : () => _leave(),
                          icon: const Icon(Icons.arrow_back_rounded, size: 16),
                          label: const Text(
                            'Back to Members',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    LayoutBuilder(builder: (context, constraints) {
                      final summary = _setupSummary();
                      if (constraints.maxWidth >= 880) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 65, child: form),
                            const SizedBox(width: 24),
                            Expanded(flex: 35, child: summary),
                          ],
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [form, const SizedBox(height: 20), summary],
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
