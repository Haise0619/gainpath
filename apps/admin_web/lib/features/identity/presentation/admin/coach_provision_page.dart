import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:gainpath_ui/gainpath_ui.dart';

class CoachProvisionPage extends StatefulWidget {
  const CoachProvisionPage({
    super.key,
    required this.branches,
    required this.create,
    required this.onCancel,
    required this.onCreated,
    this.onLeaveCheckChanged,
  });

  final Map<String, String> branches;
  final Future<String> Function(Map<String, Object?>) create;
  final VoidCallback onCancel;
  final ValueChanged<String> onCreated;
  final ValueChanged<Future<bool> Function()?>? onLeaveCheckChanged;

  @override
  State<CoachProvisionPage> createState() => _CoachProvisionPageState();
}

class _CoachProvisionPageState extends State<CoachProvisionPage> {
  final _fields = List.generate(8, (_) => TextEditingController());
  final _branches = <String>{};
  static String _newRequestId() => List.generate(
      4, (_) => Random.secure().nextInt(1 << 30).toRadixString(16)).join('-');
  String _requestId = _newRequestId();
  int _step = 0;
  String? _error;
  bool _busy = false;
  bool _submitted = false;
  Future<bool>? _discardConfirmation;

  @override
  void initState() {
    super.initState();
    widget.onLeaveCheckChanged?.call(_canLeave);
    for (final controller in _fields) {
      controller.addListener(_onFieldChanged);
    }
  }

  void _onFieldChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.onLeaveCheckChanged?.call(null);
    for (final controller in _fields) {
      controller.removeListener(_onFieldChanged);
      controller.dispose();
    }
    super.dispose();
  }

  Future<bool> _canLeave() async {
    if (_busy) return false;
    if (_branches.isEmpty && _fields.every((field) => field.text.isEmpty)) {
      return true;
    }
    return _discardConfirmation ??= confirmDialog(
      context,
      title: 'Discard coach onboarding?',
      message: 'The information entered in this form will be lost.',
      confirmLabel: 'Discard',
      destructive: true,
    ).whenComplete(() => _discardConfirmation = null);
  }

  Future<void> _cancel() async {
    if (await _canLeave() && mounted) widget.onCancel();
  }

  String _value(int index) => _fields[index].text.trim();

  Widget _field(int index, String label, {int? maxLength, int lines = 1}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: TextField(
          controller: _fields[index],
          maxLength: maxLength,
          maxLines: lines,
          enabled: !_submitted,
          style: const TextStyle(fontSize: 14, color: AppColors.ink),
          decoration: InputDecoration(
            labelText: label,
            filled: true,
            fillColor: Colors.white,
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
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      );

  Future<void> _next() async {
    setState(() => _error = null);
    if (_step == 0) {
      final email = _value(1);
      final phone = _value(2).replaceAll(RegExp(r'[ ()-]'), '');
      if (_value(0).isEmpty ||
          !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email) ||
          (phone.isNotEmpty && !RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(phone))) {
        setState(() => _error =
            'Enter a name, valid email and optional international phone number.');
        return;
      }
    }
    final years = int.tryParse(_value(4));
    final price = double.tryParse(_value(5));
    final tags = _value(7)
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();
    if (_step == 1 &&
        (_value(3).isEmpty ||
            years == null ||
            years < 0 ||
            years > 60 ||
            price == null ||
            !price.isFinite ||
            price <= 0 ||
            price > 10000 ||
            !RegExp(r'^\d+(?:\.\d{1,2})?$').hasMatch(_value(5)) ||
            tags.length > 8 ||
            tags.any((s) => s.length > 40))) {
      setState(() => _error =
          'Enter a specialty, 0–60 years and a valid MYR session price. Use up to 8 specialty tags.');
      return;
    }
    if (_step < 2) {
      setState(() => _step++);
      return;
    }
    if (_branches.isEmpty || _branches.length > 8) {
      setState(() => _error = 'Choose 1–8 enabled branches.');
      return;
    }
    setState(() {
      _busy = true;
      _submitted = true;
    });
    try {
      final id = await widget.create({
        'action': 'provisionCoach',
        'requestId': _requestId,
        'displayName': _value(0),
        'email': _value(1),
        'phone': _value(2),
        'specialty': _value(3),
        'yearsExperience': years,
        'consultationFeeMinor': (price! * 100).round(),
        'bio': _value(6),
        'specializationTags': tags.isEmpty ? [_value(3)] : tags,
        'branchIds': _branches.toList()..sort(),
      });
      if (mounted) widget.onCreated(id);
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        setState(() {
          if (const {
            'already-exists',
            'invalid-argument',
            'failed-precondition',
            'permission-denied'
          }.contains(e.code)) {
            _submitted = false;
            if (e.code == 'already-exists') _requestId = _newRequestId();
          }
          _error = e.message ??
              'Coach setup could not finish. Retry in this window.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() =>
            _error = 'Coach setup could not finish. Retry in this window.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.transparent,
        body: SizedBox.expand(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 22, 28, 36),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Page Header
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Coach onboarding',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppColors.ink,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Provision and assign a new coach profile across organization branches.',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.inkSoft,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    TextButton.icon(
                      onPressed: _busy ? null : _cancel,
                      icon: const Icon(Icons.arrow_back, size: 16),
                      label: const Text('Back to Coaches'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.inkSoft,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Stepper Header
                _buildStepper(),
                const SizedBox(height: 24),

                // 2-Column Responsive Body
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isDesktop = constraints.maxWidth >= 840;
                    if (isDesktop) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 6,
                            child: _buildFormCard(context),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            flex: 4,
                            child: _buildSidePanel(context),
                          ),
                        ],
                      );
                    } else {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildFormCard(context),
                          const SizedBox(height: 20),
                          _buildSidePanel(context),
                        ],
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      );

  Widget _buildStepper() {
    const steps = [
      ('1', 'Account info', 'Name & email'),
      ('2', 'Professional profile', 'Specialty & rate'),
      ('3', 'Branch assignment', 'Location setup'),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.hairline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          for (var i = 0; i < steps.length; i++) ...[
            if (i > 0)
              Container(
                width: 20,
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                color: _step >= i ? AppColors.primary : AppColors.hairline,
              ),
            Expanded(
              child: _buildStepNode(
                index: i,
                number: steps[i].$1,
                title: steps[i].$2,
                subtitle: steps[i].$3,
                isActive: _step == i,
                isCompleted: _step > i,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStepNode({
    required int index,
    required String number,
    required String title,
    required String subtitle,
    required bool isActive,
    required bool isCompleted,
  }) {
    final Color circleBg;
    final Color circleBorder;
    final Widget circleContent;
    final Color titleColor;

    if (isCompleted) {
      circleBg = AppColors.primary;
      circleBorder = AppColors.primary;
      circleContent = const Icon(Icons.check, size: 13, color: Colors.white);
      titleColor = AppColors.primary;
    } else if (isActive) {
      circleBg = AppColors.primary;
      circleBorder = AppColors.primary;
      circleContent = Text(
        number,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      );
      titleColor = AppColors.primary;
    } else {
      circleBg = const Color(0xFFF1F0F5);
      circleBorder = AppColors.hairline;
      circleContent = Text(
        number,
        style: const TextStyle(
          color: AppColors.inkSoft,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      );
      titleColor = AppColors.inkSoft;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: circleBg,
            shape: BoxShape.circle,
            border: Border.all(color: circleBorder),
          ),
          alignment: Alignment.center,
          child: circleContent,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight:
                      isActive || isCompleted ? FontWeight.w600 : FontWeight.w500,
                  color: titleColor,
                ),
              ),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.inkSoft,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFormCard(BuildContext context) {
    return Card(
      color: AppColors.surface,
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.hairline),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Exact step label for test compatibility
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                [
                  '1 of 3 · Account information',
                  '2 of 3 · Professional profile',
                  '3 of 3 · Branch assignment'
                ][_step],
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              [
                'Account Credentials & Details',
                'Coaching Qualifications & Rates',
                'Branch Assignment & Draft Status',
              ][_step],
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              [
                'Provide the coach\'s legal name, email address for portal access, and optional direct contact phone number.',
                'Specify coaching specialty, years of verified experience, and 60-minute session consultation rate in MYR.',
                'Assign the coach to one or more organization branches. The profile starts as an unpublished draft.',
              ][_step],
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.inkSoft,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),

            // Step Forms
            if (_step == 0) ...[
              _field(0, 'Full name', maxLength: 80),
              _field(1, 'Email address', maxLength: 254),
              _field(2, 'Phone number (optional)'),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9F8FD),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.hairline),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.shield_outlined,
                        size: 16, color: AppColors.primary),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Account role: Coach',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (_step == 1) ...[
              _field(3, 'Primary specialty', maxLength: 40),
              _field(4, 'Years of experience'),
              _field(5, 'Session price (MYR)'),
              _field(6, 'Professional biography', maxLength: 1000, lines: 3),
              _field(7, 'Specialty tags (comma separated, optional)'),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9F8FD),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.hairline),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline,
                        size: 16, color: AppColors.inkSoft),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'The Coach can add a photo and submit qualifications and certificates in the Coach workspace.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.inkSoft,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (_step == 2) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF9FD),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.hairline),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_value(0)} · ${_value(1)}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_value(3)} · RM ${_value(5)} per session',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'The profile starts as a private draft.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.inkSoft,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Available Gym Branches',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              for (final branch in widget.branches.entries)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    branch.value,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.ink,
                    ),
                  ),
                  value: _branches.contains(branch.key),
                  activeColor: AppColors.primary,
                  onChanged: _submitted
                      ? null
                      : (selected) => setState(() {
                            if (selected == true) {
                              _branches.add(branch.key);
                            } else {
                              _branches.remove(branch.key);
                            }
                          }),
                ),
            ],

            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        size: 18, color: Color(0xFFDC2626)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          color: Color(0xFFDC2626),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),
            _buildActionBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildActionBar() {
    return Row(
      children: [
        TextButton(
          onPressed: _busy ? null : _cancel,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.inkSoft,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          child: const Text('Cancel'),
        ),
        const Spacer(),
        if (_step > 0) ...[
          OutlinedButton(
            onPressed: _busy || _submitted
                ? null
                : () => setState(() {
                      _error = null;
                      _step--;
                    }),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              side: const BorderSide(color: AppColors.hairline),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Back'),
          ),
          const SizedBox(width: 12),
        ],
        FilledButton(
          onPressed: _busy ? null : _next,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_busy) ...[
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Text(_busy
                  ? 'Creating…'
                  : _step == 2
                      ? 'Create Coach'
                      : 'Continue'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSidePanel(BuildContext context) {
    if (_step == 0) {
      return _buildStep0Guidance();
    } else if (_step == 1) {
      return _buildStep1LivePreview();
    } else {
      return _buildStep2Summary();
    }
  }

  Widget _buildStep0Guidance() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.shield_outlined,
                    size: 20, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Coach Onboarding Guidance',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildGuidanceItem(
            icon: Icons.badge_outlined,
            title: 'Role Scoping',
            description:
                'Coach accounts are automatically scoped to coaching responsibilities with non-escalatable permissions.',
          ),
          const SizedBox(height: 14),
          _buildGuidanceItem(
            icon: Icons.hub_outlined,
            title: 'Multi-Branch Support',
            description:
                'A single coach profile can be assigned across multiple gym branches with centralized booking and ratings.',
          ),
          const SizedBox(height: 14),
          _buildGuidanceItem(
            icon: Icons.verified_user_outlined,
            title: 'Verification Lifecycle',
            description:
                'New profiles start as private drafts. Verification documents can be submitted and reviewed before publication.',
          ),
          const SizedBox(height: 14),
          _buildGuidanceItem(
            icon: Icons.payments_outlined,
            title: 'Session Pricing Contract',
            description:
                'Base rates are configured per 60-minute personal training session in Malaysian Ringgit (MYR).',
          ),
          const SizedBox(height: 14),
          _buildGuidanceItem(
            icon: Icons.mark_email_read_outlined,
            title: 'Credential Invitation',
            description:
                'An authentication invite is securely dispatched to the coach email upon account provisioning.',
          ),
        ],
      ),
    );
  }

  Widget _buildGuidanceItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.inkSoft,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStep1LivePreview() {
    final name = _value(0).isEmpty ? 'Coach Name' : _value(0);
    final specialty = _value(3).isEmpty ? 'Fitness Coach' : _value(3);
    final years = _value(4).isEmpty ? '—' : '${_value(4)} yrs';
    final price = _value(5).isEmpty ? '—' : 'RM ${_value(5)}';
    final bio = _value(6).isEmpty
        ? 'No biography provided yet. The coach can introduce their background, certifications, and training philosophy.'
        : _value(6);
    final tags = _value(7)
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    String initials = '';
    if (_value(0).isNotEmpty) {
      final parts = _value(0).trim().split(RegExp(r'\s+'));
      if (parts.length > 1) {
        initials = '${parts.first[0]}${parts.last[0]}'.toUpperCase();
      } else {
        initials = parts.first[0].toUpperCase();
      }
    } else {
      initials = 'CP';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.hairline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.visibility_outlined,
                  size: 16, color: AppColors.inkSoft),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Live Profile Preview',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.inkSoft,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: const Text(
                  'Draft Preview',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFD97706),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Mini coach card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF9FD),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.hairline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                      child: Text(
                        initials,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.ink,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            specialty,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppColors.primary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Metric row
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.hairline),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                          child: _buildPreviewMetric('Rating', '— (0 revs)')),
                      Container(height: 20, width: 1, color: AppColors.hairline),
                      Expanded(
                          child: _buildPreviewMetric('Experience', years)),
                      Container(height: 20, width: 1, color: AppColors.hairline),
                      Expanded(
                          child: _buildPreviewMetric('60-min Rate', price)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  bio,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.inkSoft,
                    height: 1.4,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                if (tags.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      for (final tag in tags.take(4))
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.hairline),
                          ),
                          child: Text(
                            tag,
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.inkSoft),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewMetric(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 9.5,
            color: AppColors.inkSoft,
          ),
        ),
      ],
    );
  }

  Widget _buildStep2Summary() {
    final name = _value(0);
    final email = _value(1);
    final specialty = _value(3);
    final price = _value(5);
    final selectedBranchNames = widget.branches.entries
        .where((e) => _branches.contains(e.key))
        .map((e) => e.value)
        .toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.assignment_turned_in_outlined,
                  size: 20, color: AppColors.primary),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Onboarding Summary',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSummaryRow('Full Name', name.isEmpty ? '—' : name),
          const SizedBox(height: 10),
          _buildSummaryRow('Email Address', email.isEmpty ? '—' : email),
          const SizedBox(height: 10),
          _buildSummaryRow('Specialty', specialty.isEmpty ? '—' : specialty),
          const SizedBox(height: 10),
          _buildSummaryRow(
              'Session Rate', price.isEmpty ? '—' : 'RM $price / session'),
          const SizedBox(height: 10),
          _buildSummaryRow(
            'Assigned Branches',
            selectedBranchNames.isEmpty
                ? 'None selected'
                : '${selectedBranchNames.length} selected (${selectedBranchNames.join(', ')})',
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F0FD),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFD6C8F6)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 16, color: AppColors.primary),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'The profile will be created as a private draft. The coach can log in to update credentials and set work hours.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.primary,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.inkSoft,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
        ),
      ],
    );
  }
}
