import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../shared/admin_business_copy.dart';
import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:gainpath_domain/membership.dart';
import 'member_membership_verification_panel.dart';

class MemberDetailsDialog extends StatefulWidget {
  const MemberDetailsDialog({
    super.key,
    required this.memberId,
    required this.repository,
    this.verificationRepository,
  });

  final String memberId;
  final AdminMemberDirectoryRepository repository;
  final MembershipVerificationRepository? verificationRepository;

  @override
  State<MemberDetailsDialog> createState() => _MemberDetailsDialogState();
}

class _MemberDetailsDialogState extends State<MemberDetailsDialog> {
  AdminMemberDetails? _details;
  bool _loading = true, _failed = false;
  int _selectedTab = 0;

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
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppColors.inkSoft,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 3),
            SelectableText(
              value.isEmpty ? 'Not recorded' : value,
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );

  Widget _buildStatusBadge(String label, String rawStatus) {
    final status = rawStatus.toLowerCase();
    Color bg;
    Color fg;
    Color dot;
    if (status == 'active') {
      bg = AppColors.successTint;
      fg = AppColors.success;
      dot = AppColors.success;
    } else if (status == 'suspended') {
      bg = AppColors.dangerTint;
      fg = AppColors.danger;
      dot = AppColors.danger;
    } else {
      bg = AppColors.membershipFreeTint;
      fg = AppColors.membershipFreeInk;
      dot = AppColors.membershipFreeInk;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: fg.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroHeader(AdminMemberDetails details) {
    final initial = details.member.name.trim().isNotEmpty
        ? details.member.name.trim()[0].toUpperCase()
        : 'M';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              gradient: AppColors.heroGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.22),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: SelectableText(
                        details.member.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _buildStatusBadge(
                      details.member.statusLabel,
                      details.member.status,
                    ),
                    if (details.readOnly) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.hairline,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Read-only',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.inkSoft,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 16,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.email_outlined,
                            size: 14, color: AppColors.inkSoft),
                        const SizedBox(width: 5),
                        SelectableText(
                          details.member.email.isEmpty
                              ? 'No email provided'
                              : details.member.email,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.inkSoft,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.badge_outlined,
                            size: 14, color: AppColors.inkSoft),
                        const SizedBox(width: 5),
                        SelectableText(
                          details.member.id,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.inkSoft,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Tooltip(
                          message: 'Copy Member ID',
                          child: InkWell(
                            borderRadius: BorderRadius.circular(4),
                            onTap: () {
                              Clipboard.setData(
                                  ClipboardData(text: details.member.id));
                              showToast(context, 'Member ID copied');
                            },
                            child: const Padding(
                              padding: EdgeInsets.all(3),
                              child: Icon(Icons.copy_rounded,
                                  size: 13, color: AppColors.primary),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.hairline),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppColors.primaryTint,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: AppColors.primary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: AppColors.inkSoft,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    final tabs = [
      (Icons.dashboard_outlined, 'Overview & Access'),
      (Icons.fitness_center_outlined, 'Fitness & Health'),
      (Icons.sports_rounded, 'Activity & Services'),
    ];

    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.hairline)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < tabs.length; i++)
              InkWell(
                onTap: () => setState(() => _selectedTab = i),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: _selectedTab == i
                            ? AppColors.primary
                            : Colors.transparent,
                        width: 2.5,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        tabs[i].$1,
                        size: 16,
                        color: _selectedTab == i
                            ? AppColors.primary
                            : AppColors.inkSoft,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        tabs[i].$2,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: _selectedTab == i
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: _selectedTab == i
                              ? AppColors.primary
                              : AppColors.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewTab(AdminMemberDetails details,
      MembershipVerificationRepository? verification) {
    final generalExtra = details.extra.where((e) {
      final label = e['label'] ?? '';
      return label != 'Data source' &&
          !label.contains('fitness') &&
          !label.contains('goal') &&
          !label.contains('workout') &&
          !label.contains('appointment') &&
          !label.contains('subscription') &&
          !['gender', 'ageBracket', 'age', 'heightCm', 'weightKg', 'experience', 'activity', 'goals']
              .contains(label);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 14),
        Row(
          children: [
            _buildMetricCard(
              'Facility',
              details.organizationId.toUpperCase(),
              Icons.business_rounded,
            ),
            const SizedBox(width: 10),
            _buildMetricCard(
              'Primary Branch',
              details.branchIds.isEmpty
                  ? 'None'
                  : details.branchIds.first.toUpperCase(),
              Icons.location_on_outlined,
            ),
            const SizedBox(width: 10),
            _buildMetricCard(
              'Joined Date',
              _date(details.createdAtMillis).split(' ').first,
              Icons.calendar_today_outlined,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.hairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Account Record',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 480;
                    if (isWide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _field('Email', details.member.email),
                                _field('Member ID', details.member.id),
                                _field('Organization', details.organizationId),
                              ],
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _field('Membership status',
                                    details.member.statusLabel),
                                _field(
                                  'Branches',
                                  details.branchIds.isEmpty
                                      ? 'None recorded'
                                      : details.branchIds.join(', '),
                                ),
                                _field('Joined (local time)',
                                    _date(details.createdAtMillis)),
                                _field('Last updated (local time)',
                                    _date(details.updatedAtMillis)),
                              ],
                            ),
                          ),
                        ],
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _field('Email', details.member.email),
                        _field('Member ID', details.member.id),
                        _field('Organization', details.organizationId),
                        _field(
                            'Membership status', details.member.statusLabel),
                        _field(
                          'Branches',
                          details.branchIds.isEmpty
                              ? 'None recorded'
                              : details.branchIds.join(', '),
                        ),
                        _field('Joined (local time)',
                            _date(details.createdAtMillis)),
                        _field('Last updated (local time)',
                            _date(details.updatedAtMillis)),
                      ],
                    );
                },
              ),
              if (generalExtra.isNotEmpty) ...[
                const Divider(height: 24),
                for (final field in generalExtra)
                  _field(
                    adminBusinessDetail(field['label']!),
                    adminBusinessDetail(field['value']!),
                  ),
              ],
            ],
          ),
        ),
        if (verification != null && !details.readOnly) ...[
          const SizedBox(height: 14),
          MemberMembershipVerificationPanel(
            key: ValueKey(details),
            memberId: widget.memberId,
            repository: verification,
          ),
        ],
      ],
    );
  }

  Widget _buildFitnessTab(AdminMemberDetails details) {
    final fitnessMap = <String, String>{};
    for (final item in details.extra) {
      if (item['label'] != null && item['value'] != null) {
        fitnessMap[item['label']!] = item['value']!;
      }
    }

    final hasProfile = fitnessMap.containsKey('gender') ||
        fitnessMap.containsKey('heightCm') ||
        fitnessMap.containsKey('weightKg') ||
        fitnessMap.containsKey('experience') ||
        fitnessMap.containsKey('goals') ||
        fitnessMap.containsKey('Recorded fitness goal') ||
        fitnessMap.containsKey('Medical & physical waiver');

    if (!hasProfile) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 24),
        padding: const EdgeInsets.all(28),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.hairline),
        ),
        child: Column(
          children: const [
            Icon(Icons.fitness_center_outlined,
                size: 40, color: AppColors.inkSoft),
            SizedBox(height: 12),
            Text(
              'No fitness profile recorded yet',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'This member has not yet saved physical metrics (height, weight, goals) in the GainPath mobile app.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.inkSoft,
              ),
            ),
          ],
        ),
      );
    }

    String? bmiDisplay;
    final hStr = fitnessMap['heightCm'];
    final wStr = fitnessMap['weightKg'];
    if (hStr != null && wStr != null) {
      final h = double.tryParse(hStr.replaceAll(RegExp(r'[^0-9.]'), ''));
      final w = double.tryParse(wStr.replaceAll(RegExp(r'[^0-9.]'), ''));
      if (h != null && w != null && h > 0) {
        final bmi = w / ((h / 100) * (h / 100));
        final category = bmi < 18.5
            ? 'Underweight'
            : bmi < 25
                ? 'Normal'
                : bmi < 30
                    ? 'Overweight'
                    : 'Obese';
        bmiDisplay = '${bmi.toStringAsFixed(1)} ($category)';
      }
    }

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildMetricCard(
                'Height',
                fitnessMap['heightCm'] != null
                    ? '${fitnessMap['heightCm']} cm'
                    : 'Not set',
                Icons.straighten_rounded,
              ),
              const SizedBox(width: 10),
              _buildMetricCard(
                'Weight',
                fitnessMap['weightKg'] != null
                    ? '${fitnessMap['weightKg']} kg'
                    : 'Not set',
                Icons.monitor_weight_outlined,
              ),
              const SizedBox(width: 10),
              _buildMetricCard(
                'BMI',
                bmiDisplay ?? 'Not calculated',
                Icons.health_and_safety_outlined,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.hairline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Physical & Training Profile',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _field('Gender', fitnessMap['gender'] ?? 'Not set'),
                          _field(
                            'Age Bracket',
                            fitnessMap['ageBracket'] ??
                                fitnessMap['age'] ??
                                'Not set',
                          ),
                          _field(
                            'Experience Level',
                            fitnessMap['experience'] ?? 'Not set',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _field(
                            'Activity Level',
                            fitnessMap['activity'] ?? 'Not set',
                          ),
                          _field(
                            'Primary Fitness Goals',
                            fitnessMap['goals'] ?? 'Not set',
                          ),
                          _field(
                            'Physical Activity Waiver',
                            fitnessMap['Medical & physical waiver'] ??
                                'Not recorded',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (fitnessMap.containsKey('Recorded fitness goal')) ...[
                  const Divider(height: 20),
                  _field('Recorded fitness goal',
                      fitnessMap['Recorded fitness goal']!),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityTab(AdminMemberDetails details) {
    final activityItems = details.extra.where((e) {
      final label = e['label'] ?? '';
      return label.contains('workout') ||
          label.contains('observation') ||
          label.contains('subscription') ||
          label.contains('Subscription') ||
          label.contains('program') ||
          label.contains('appointment') ||
          label.contains('Appointment') ||
          label.contains('Recommendation');
    }).toList();

    if (activityItems.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 24),
        padding: const EdgeInsets.all(28),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.hairline),
        ),
        child: Column(
          children: const [
            Icon(Icons.history_rounded, size: 40, color: AppColors.inkSoft),
            SizedBox(height: 12),
            Text(
              'No recorded activity or appointments',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Workout observations, coaching appointments, and subscriptions will appear here as the member trains.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.inkSoft,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.hairline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Workouts, Appointments & Services',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 12),
                for (final item in activityItems)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.hairline),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.primaryTint,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            item['label']!.contains('workout')
                                ? Icons.timer_outlined
                                : item['label']!.contains('appointment')
                                    ? Icons.event_available_outlined
                                    : Icons.layers_outlined,
                            size: 16,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                adminBusinessDetail(item['label']!),
                                style: const TextStyle(
                                  color: AppColors.inkSoft,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 3),
                              SelectableText(
                                adminBusinessDetail(item['value']!),
                                style: const TextStyle(
                                  color: AppColors.ink,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final details = _details;
    final verification = widget.verificationRepository ??
        (widget.repository is MembershipVerificationRepository
            ? widget.repository as MembershipVerificationRepository
            : null);

    return AdminDialog(
      width: 760,
      child: SizedBox(
        width: 760,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .88,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Member details',
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Close member details',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const Text(
              'Read-only organization membership record',
              style: TextStyle(color: AppColors.inkSoft, fontSize: 13),
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(),
                ),
              ),
            if (_failed) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.dangerTint,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.danger.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: AppColors.danger),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Could not load this member. The record or your Admin access may have changed.',
                        style: TextStyle(
                          color: AppColors.danger,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _load,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ],
            if (details != null) ...[
              _buildHeroHeader(details),
              const SizedBox(height: 14),
              _buildTabBar(),
              Flexible(
                child: SingleChildScrollView(
                  child: IndexedStack(
                    index: _selectedTab,
                    children: [
                      _buildOverviewTab(details, verification),
                      _buildFitnessTab(details),
                      _buildActivityTab(details),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (details != null)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 38),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                    ),
                    icon: const Icon(Icons.copy_rounded, size: 14),
                    label: const Text('Copy info'),
                    onPressed: () {
                      final summary = [
                        'Member Name: ${details.member.name}',
                        'Email: ${details.member.email}',
                        'ID: ${details.member.id}',
                        'Status: ${details.member.statusLabel}',
                        'Organization: ${details.organizationId}',
                        'Branches: ${details.branchIds.join(', ')}',
                        'Joined: ${_date(details.createdAtMillis)}',
                      ].join('\n');
                      Clipboard.setData(ClipboardData(text: summary));
                      showToast(context, 'Member information copied');
                    },
                  )
                else
                  const SizedBox.shrink(),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: _loading ? null : _load,
                      child: const Text('Refresh details'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    ),);
  }
}
