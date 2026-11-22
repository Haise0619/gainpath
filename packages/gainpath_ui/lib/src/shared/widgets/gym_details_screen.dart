import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../tokens/app_theme.dart';
import 'branch_directory_page.dart';
import 'branch_map.dart';

/// Full-screen Gym Details experience for gym discovery in GainPath.
/// Replaces the overcrowded modal dialog with a structured, native fitness layout.
class GymDetailsScreen extends StatefulWidget {
  const GymDetailsScreen({
    super.key,
    required this.branch,
    required this.isHome,
    required this.isSelected,
    required this.openDirections,
    required this.onSelectGym,
    this.onSetHome,
    this.onCheckIn,
    this.onOpenEquipment,
  });

  final Map<String, dynamic> branch;
  final bool isHome;
  final bool isSelected;
  final Future<bool> Function(Uri) openDirections;
  final Future<void> Function() onSelectGym;
  final Future<void> Function()? onSetHome;
  final Future<void> Function()? onCheckIn;
  final VoidCallback? onOpenEquipment;

  @override
  State<GymDetailsScreen> createState() => _GymDetailsScreenState();
}

class _GymDetailsScreenState extends State<GymDetailsScreen> {
  bool _weeklyHoursExpanded = false;
  bool _busy = false;

  Map<String, dynamic> get branch => widget.branch;

  String get _displayName =>
      branch['displayName'] as String? ?? 'GainPath Gym';
  String get _address => _branchAddress(branch);
  String? get _coverUrl => branch['coverUrl'] as String?;
  String? get _description => branch['description'] as String?;
  String? get _phone => branch['contactPhone'] as String?;
  List<dynamic>? get _hours => branch['openingHours'] as List<dynamic>?;
  List<dynamic>? get _facilities => branch['facilities'] as List<dynamic>?;
  String get _timeZone =>
      branch['timeZone'] as String? ?? 'Asia/Kuala_Lumpur';

  static String _branchAddress(Map<String, dynamic> branch) {
    final parts = [
      branch['address'],
      branch['city'],
      branch['state'],
      branch['postalCode'],
      branch['country'],
    ].whereType<String>().map((p) => p.trim()).where((p) => p.isNotEmpty);
    return parts.join(', ');
  }

  Future<void> _handleDirections() async {
    final point = branchMapPoint(branch);
    final destination = point == null
        ? _address
        : '${point.latitude},${point.longitude}';
    if (destination.isEmpty) return;

    try {
      final opened = await widget.openDirections(
        Uri.https('www.google.com', '/maps/dir/', {
          'api': '1',
          'destination': destination,
          'travelmode': 'driving',
          'dir_action': 'navigate',
        }),
      );
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open directions.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open directions.')),
        );
      }
    }
  }

  Future<void> _handleCall() async {
    if (_phone == null || _phone!.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: _phone);
    try {
      final opened = await widget.openDirections(uri);
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not start phone call.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not start phone call.')),
        );
      }
    }
  }

  void _copyAddress() {
    if (_address.isEmpty) return;
    Clipboard.setData(ClipboardData(text: _address));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Address copied to clipboard.')),
    );
  }

  Future<void> _confirmSetHome() async {
    if (widget.onSetHome == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set as Home Branch?'),
        content: Text(
          'Changing your Home Branch to $_displayName will update your default workout location, billing branch context, and primary trainer assignments.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      setState(() => _busy = true);
      try {
        await widget.onSetHome!();
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final openStatus = _hours == null
        ? 'Opening hours unavailable'
        : branchOpeningStatus(_hours!);
    final isOpenNow = openStatus.toLowerCase().contains('open');

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        slivers: [
          // Hero Cover App Bar
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: AppColors.primaryDark,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: CircleAvatar(
                backgroundColor: Colors.black.withValues(alpha: 0.45),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded,
                      color: Colors.white, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
            actions: [
              if (widget.onCheckIn != null && widget.isSelected)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: CircleAvatar(
                    backgroundColor: Colors.black.withValues(alpha: 0.45),
                    child: IconButton(
                      tooltip: 'Gym check-in',
                      icon: const Icon(Icons.qr_code_scanner_rounded,
                          color: Colors.white, size: 20),
                      onPressed: widget.onCheckIn,
                    ),
                  ),
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Hero Image
                  if (_coverUrl != null && _coverUrl!.isNotEmpty)
                    Image.network(
                      _coverUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _heroPlaceholder(),
                    )
                  else
                    _heroPlaceholder(),

                  // Scrim overlay
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.5),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.8),
                        ],
                        stops: const [0.0, 0.4, 1.0],
                      ),
                    ),
                  ),

                  // Bottom hero title & badges
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            _heroBadge(
                              openStatus,
                              isOpenNow
                                  ? AppColors.success
                                  : AppColors.inkSoft,
                              isOpenNow
                                  ? AppColors.successTint
                                  : AppColors.surface,
                            ),
                            if (widget.isHome)
                              _heroBadge(
                                'Home Branch',
                                AppColors.primary,
                                AppColors.primaryTint,
                              ),
                            if (widget.isSelected)
                              _heroBadge(
                                'Selected Gym',
                                Colors.white,
                                AppColors.primary,
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _displayName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Content body
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Quick Actions Row
                  _buildQuickActionsRow(),
                  const SizedBox(height: 16),

                  // About & Location Card
                  _buildAboutCard(),
                  const SizedBox(height: 16),

                  // Opening Hours Card
                  _buildHoursCard(openStatus),
                  const SizedBox(height: 16),

                  // Facilities Card
                  if (_facilities != null && _facilities!.isNotEmpty) ...[
                    _buildFacilitiesCard(),
                    const SizedBox(height: 16),
                  ],

                  // Equipment Inventory Link
                  if (widget.onOpenEquipment != null) ...[
                    _buildEquipmentLinkCard(),
                    const SizedBox(height: 16),
                  ],

                  // Home Branch Status Card
                  _buildHomeBranchCard(),
                ],
              ),
            ),
          ),
        ],
      ),

      // Sticky Bottom Action Bar
      bottomNavigationBar: _buildStickyBottomBar(),
    );
  }

  Widget _buildQuickActionsRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _actionButton(
            icon: Icons.directions_outlined,
            label: 'Get directions',
            onTap: _handleDirections,
          ),
          Container(width: 1, height: 28, color: AppColors.hairline),
          _actionButton(
            icon: Icons.content_copy_rounded,
            label: 'Copy address',
            onTap: _copyAddress,
          ),
          if (_phone != null && _phone!.isNotEmpty) ...[
            Container(width: 1, height: 28, color: AppColors.hairline),
            _actionButton(
              icon: Icons.phone_outlined,
              label: 'Call gym',
              onTap: _handleCall,
            ),
          ],
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: AppColors.primary),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAboutCard() {
    return Container(
      padding: const EdgeInsets.all(16),
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
              const Icon(Icons.place_outlined,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Location & Address',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _address.isNotEmpty ? _address : 'Address details unavailable.',
            style: const TextStyle(fontSize: 13.5, color: AppColors.ink),
          ),
          if (_description != null && _description!.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.hairline),
            const SizedBox(height: 12),
            Text(
              _description!,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.inkSoft,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHoursCard(String openStatus) {
    final hours = _hours;
    final isAllDay24 = hours != null &&
        hours.length == 7 &&
        hours.every((d) => d is Map && d['allDay'] == true);

    return Container(
      padding: const EdgeInsets.all(16),
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
              const Icon(Icons.access_time_rounded,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Opening Hours',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                ),
              ),
              Text(
                _timeZone,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.inkSoft,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    openStatus,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isAllDay24) ...[
            const SizedBox(height: 10),
            const Text(
              'Open 24 hours daily (Monday through Sunday).',
              style: TextStyle(fontSize: 12.5, color: AppColors.inkSoft),
            ),
          ] else if (hours != null && hours.length == 7) ...[
            const SizedBox(height: 10),
            InkWell(
              onTap: () =>
                  setState(() => _weeklyHoursExpanded = !_weeklyHoursExpanded),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _weeklyHoursExpanded
                            ? 'Hide weekly schedule'
                            : 'View full weekly schedule',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _weeklyHoursExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),
            ),
            if (_weeklyHoursExpanded) ...[
              const SizedBox(height: 8),
              const Divider(height: 1, color: AppColors.hairline),
              const SizedBox(height: 8),
              for (var i = 0; i < 7; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3.5),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 45,
                        child: Text(
                          _days[i],
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _dayLabel(hours[i]),
                        style: TextStyle(
                          fontSize: 12.5,
                          color: (hours[i] is Map &&
                                  (hours[i] as Map)['closed'] == true)
                              ? AppColors.danger
                              : AppColors.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildFacilitiesCard() {
    return Container(
      padding: const EdgeInsets.all(16),
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
              const Icon(Icons.spa_outlined,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Facilities & Amenities',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final facility in _facilities!)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.hairline),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _facilityIcon(facility.toString()),
                        size: 14,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        facility.toString(),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEquipmentLinkCard() {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: widget.onOpenEquipment,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.hairline),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primaryTint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.fitness_center_rounded,
                  size: 22,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Branch Equipment',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Browse machines and free weights available here.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.inkSoft,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: AppColors.inkSoft,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHomeBranchCard() {
    return Container(
      padding: const EdgeInsets.all(16),
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
              Icon(
                widget.isHome
                    ? Icons.verified_rounded
                    : Icons.home_work_outlined,
                size: 18,
                color: widget.isHome ? AppColors.success : AppColors.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.isHome ? 'Primary Home Branch' : 'Home Branch Assignment',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            widget.isHome
                ? '$_displayName is currently set as your primary Home Branch for membership entitlements and coach directory scoping.'
                : 'Your Home Branch is used for membership registration and default coach assignments. You can train at any active GainPath branch.',
            style: const TextStyle(fontSize: 12.5, color: AppColors.inkSoft),
          ),
          if (!widget.isHome && widget.onSetHome != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _busy ? null : _confirmSetHome,
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Set as Home Branch'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStickyBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(top: BorderSide(color: AppColors.hairline)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: widget.isSelected
            ? Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.successTint,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_rounded,
                            size: 16, color: AppColors.success),
                        SizedBox(width: 6),
                        Text(
                          'Selected Gym',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: widget.onCheckIn,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        minimumSize: const Size(0, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                      label: const Text(
                        'Gym check-in',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              )
            : FilledButton(
                onPressed: _busy
                    ? null
                    : () async {
                        setState(() => _busy = true);
                        try {
                          await widget.onSelectGym();
                        } finally {
                          if (mounted) setState(() => _busy = false);
                        }
                      },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Select this gym',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
      ),
    );
  }

  Widget _heroPlaceholder() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6D28D9), Color(0xFF4C1D95)],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.fitness_center_rounded,
          size: 48,
          color: Colors.white54,
        ),
      ),
    );
  }

  Widget _heroBadge(String label, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  IconData _facilityIcon(String facility) {
    final f = facility.toLowerCase();
    if (f.contains('shower')) return Icons.shower_outlined;
    if (f.contains('parking')) return Icons.local_parking_rounded;
    if (f.contains('wifi') || f.contains('wi-fi')) return Icons.wifi_rounded;
    if (f.contains('locker')) return Icons.lock_outline_rounded;
    if (f.contains('sauna')) return Icons.hot_tub_rounded;
    if (f.contains('pool')) return Icons.pool_rounded;
    return Icons.check_circle_outline_rounded;
  }
}

const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

String _dayLabel(Object? value) {
  if (value is! Map) return 'Unavailable';
  if (value['closed'] == true) return 'Closed';
  if (value['allDay'] == true) return 'Open 24 hours';
  final open = value['open'], close = value['close'];
  return (open is String && close is String) ? '$open – $close' : 'Unavailable';
}
