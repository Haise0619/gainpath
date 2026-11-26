import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../tokens/app_theme.dart';

typedef ClassCall = Future<Map<String, dynamic>> Function(
    String, Map<String, dynamic>);

List<Map<String, dynamic>> classRows(Object? input) => (input as List)
    .map((row) => Map<String, dynamic>.from(row as Map))
    .toList();

String classRequestId() =>
    '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 31)}';

DateTime classLocal(Object? value) =>
    DateTime.fromMillisecondsSinceEpoch((value as num).toInt(), isUtc: true)
        .add(const Duration(hours: 8));

String classDate(Object? value) {
  if (value == null) return '—';
  final date = classLocal(value);
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

String classTime(Object? value) {
  if (value == null) return '—';
  final date = classLocal(value);
  return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

String classWhen(Map row) =>
    '${classDate(row['startAtMillis'])} · ${classTime(row['startAtMillis'])}–${classTime(row['endAtMillis'])} MYT';

String classEligibility(Object? value) =>
    value == 'Premium Only' ? 'Premium Only' : 'Paid Members';

String classError(Object error) {
  final message = error.toString();
  final normalized =
      message.replaceFirst(RegExp(r'^\[firebase_functions/[^\]]+\]\s*'), '');
  if (normalized.contains('\n') ||
      normalized.length > 240 ||
      normalized.startsWith('Instance of')) {
    return 'Could not complete this request. Try again.';
  }
  return normalized;
}

String? _status(Object? value) =>
    value is Map ? value['status'] as String? : value as String?;

IconData classCategoryIcon(String? category) {
  switch (category?.toLowerCase()) {
    case 'yoga':
      return Icons.self_improvement_rounded;
    case 'hiit':
      return Icons.flash_on_rounded;
    case 'strength':
      return Icons.fitness_center_rounded;
    case 'dance':
      return Icons.music_note_rounded;
    case 'pilates':
      return Icons.accessibility_new_rounded;
    default:
      return Icons.sports_gymnastics_rounded;
  }
}

class GroupClassCover extends StatelessWidget {
  const GroupClassCover({
    super.key,
    this.url,
    this.bytes,
    this.height = 148,
    this.borderRadius,
  });

  final String? url;
  final Uint8List? bytes;
  final double height;
  final BorderRadius? borderRadius;

  Widget get _fallback => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF7C3AED), Color(0xFF4C1D95)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              right: -16,
              bottom: -16,
              child: Icon(
                Icons.groups_rounded,
                size: 96,
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),
            Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.fitness_center_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'GainPath Studio',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final localImage = bytes;
    final remoteUrl = url;
    final imageWidget = SizedBox(
      height: height,
      width: double.infinity,
      child: localImage != null
          ? Image.memory(localImage, fit: BoxFit.cover, cacheWidth: 1200)
          : remoteUrl == null || remoteUrl.trim().isEmpty
              ? _fallback
              : Image.network(
                  remoteUrl,
                  fit: BoxFit.cover,
                  webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                  errorBuilder: (_, __, ___) => _fallback,
                ),
    );

    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: imageWidget);
    }
    return imageWidget;
  }
}

class ClassInstructorAvatar extends StatelessWidget {
  const ClassInstructorAvatar({
    super.key,
    required this.name,
    this.photoUrl,
    this.image,
    this.radius = 20,
  });

  final String name;
  final String? photoUrl;
  final ImageProvider? image;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final initial =
        name.trim().isEmpty ? '?' : name.trim().characters.first.toUpperCase();
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primaryTint,
      foregroundColor: AppColors.primary,
      foregroundImage:
          image ?? (photoUrl == null ? null : NetworkImage(photoUrl!)),
      onForegroundImageError:
          image == null && photoUrl == null ? null : (_, __) {},
      child: Text(
        initial,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: radius * 0.85,
        ),
      ),
    );
  }
}

class GroupClassInstructor extends StatefulWidget {
  const GroupClassInstructor({
    super.key,
    required this.row,
    required this.call,
  });

  final Map<String, dynamic> row;
  final ClassCall call;

  @override
  State<GroupClassInstructor> createState() => _GroupClassInstructorState();
}

class _GroupClassInstructorState extends State<GroupClassInstructor> {
  late final Future<MemoryImage?> _photo = _loadPhoto();

  Future<MemoryImage?> _loadPhoto() async {
    if (widget.row['coachId'] == null) return null;
    try {
      final result = await widget
          .call('instructorPhoto', {'coachId': widget.row['coachId']});
      final bytes = result['bytesBase64'];
      return bytes is String ? MemoryImage(base64Decode(bytes)) : null;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final instructor = widget.row['instructor'] as String? ?? 'Instructor';
    final specialty = (widget.row['specialty'] as String?)?.trim();
    final isInternal = widget.row['coachId'] != null;

    return FutureBuilder<MemoryImage?>(
      future: _photo,
      builder: (_, snapshot) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.hairline),
        ),
        child: Row(
          children: [
            ClassInstructorAvatar(
              name: instructor,
              photoUrl: widget.row['instructorPhoto'] as String?,
              image: snapshot.data,
              radius: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          instructor,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isInternal
                              ? AppColors.primaryTint
                              : const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isInternal ? 'Coach' : 'Guest Instructor',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: isInternal
                                ? AppColors.primary
                                : const Color(0xFF4B5563),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    specialty?.isNotEmpty == true
                        ? specialty!
                        : 'Certified Fitness Instructor',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.inkSoft,
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
}

class GroupClassStatusBadge extends StatelessWidget {
  const GroupClassStatusBadge({super.key, required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color border;
    Color text;
    IconData icon;
    String label = status;

    switch (status) {
      case 'Open':
        bg = const Color(0xFFF0FDF4);
        border = const Color(0xFFBBF7D0);
        text = const Color(0xFF16A34A);
        icon = Icons.check_circle_rounded;
        break;
      case 'Full':
        bg = const Color(0xFFFFFBEB);
        border = const Color(0xFFFDE68A);
        text = const Color(0xFFD97706);
        icon = Icons.people_alt_rounded;
        label = 'Fully booked';
        break;
      case 'Closed':
        bg = const Color(0xFFF3F4F6);
        border = const Color(0xFFE5E7EB);
        text = const Color(0xFF6B7280);
        icon = Icons.lock_outline_rounded;
        label = 'Closed';
        break;
      case 'Draft':
        bg = const Color(0xFFF5F3FF);
        border = const Color(0xFFDDD6FE);
        text = const Color(0xFF7C3AED);
        icon = Icons.edit_note_rounded;
        break;
      case 'Scheduled':
        bg = const Color(0xFFEFF6FF);
        border = const Color(0xFFBFDBFE);
        text = const Color(0xFF2563EB);
        icon = Icons.schedule_rounded;
        break;
      case 'In progress':
        bg = const Color(0xFFEEF2FF);
        border = const Color(0xFFC7D2FE);
        text = const Color(0xFF4F46E5);
        icon = Icons.play_circle_filled_rounded;
        break;
      case 'Completed':
        bg = const Color(0xFFF1F5F9);
        border = const Color(0xFFCBD5E1);
        text = const Color(0xFF475569);
        icon = Icons.task_alt_rounded;
        break;
      case 'Cancelled':
        bg = const Color(0xFFFFF1F2);
        border = const Color(0xFFFECDD3);
        text = const Color(0xFFE11D48);
        icon = Icons.cancel_rounded;
        break;
      default:
        bg = const Color(0xFFF9FAFB);
        border = const Color(0xFFE5E7EB);
        text = const Color(0xFF4B5563);
        icon = Icons.info_outline_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: text),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: text,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class GroupClassCard extends StatelessWidget {
  const GroupClassCard({
    super.key,
    required this.row,
    this.onOpen,
    this.showAdminActions = false,
    this.coverBytes,
  });

  final Map<String, dynamic> row;
  final VoidCallback? onOpen;
  final bool showAdminActions;
  final Uint8List? coverBytes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final capacity = (row['capacity'] as num?)?.toInt() ?? 0;
    final enrolled = (row['activeCount'] as num?)?.toInt() ?? 0;
    final spots = (capacity - enrolled).clamp(0, capacity);
    final status = row['status'] as String? ?? 'Open';
    final category = row['category'] as String? ?? 'Fitness';
    final durationMinutes = (((row['endAtMillis'] as num?)?.toInt() ?? 0) -
            ((row['startAtMillis'] as num?)?.toInt() ?? 0)) ~/
        60000;
    final eligibility = classEligibility(row['eligibility']);
    final difficulty = row['difficulty'] as String? ?? 'All levels';
    final title = row['title'] as String? ?? 'Group Class';
    final instructor = row['instructor'] as String? ?? 'Instructor';
    final branchName = row['branchName'] as String? ?? 'GainPath';
    final venue = row['venue'] as String? ?? 'Studio';

    final isFull = spots == 0 || status == 'Full';
    final progressColor = isFull
        ? const Color(0xFFD97706)
        : (capacity > 0 && enrolled / capacity >= 0.8
            ? const Color(0xFFEAB308)
            : AppColors.primary);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.hairline),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cover Image Header with overlays
              Stack(
                children: [
                  GroupClassCover(
                    url: row['coverUrl'] as String?,
                    bytes: coverBytes,
                    height: 140,
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.25),
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.45),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Category pill top-left
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            classCategoryIcon(category),
                            size: 13,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            category,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Status badge top-right
                  Positioned(
                    top: 10,
                    right: 10,
                    child: GroupClassStatusBadge(status: status),
                  ),
                  // Eligibility badge bottom-left
                  Positioned(
                    bottom: 8,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primaryDark.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            eligibility == 'Premium Only'
                                ? Icons.workspace_premium_rounded
                                : (eligibility == 'Paid Members'
                                    ? Icons.stars_rounded
                                    : Icons.group_rounded),
                            size: 11,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            eligibility,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // Content Body
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                        fontSize: 17,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),

                    // When (Date & Time MYT)
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_rounded,
                          size: 14,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            classWhen(row),
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.ink,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Duration & Difficulty
                    Row(
                      children: [
                        const Icon(
                          Icons.schedule_rounded,
                          size: 14,
                          color: AppColors.inkSoft,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$durationMinutes min',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.inkSoft,
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6),
                          child: Text('·',
                              style: TextStyle(color: AppColors.inkSoft)),
                        ),
                        const Icon(
                          Icons.speed_rounded,
                          size: 14,
                          color: AppColors.inkSoft,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            difficulty,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.inkSoft,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Instructor & Location
                    Row(
                      children: [
                        const Icon(
                          Icons.person_outline_rounded,
                          size: 14,
                          color: AppColors.inkSoft,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            instructor,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.ink,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6),
                          child: Text('·',
                              style: TextStyle(color: AppColors.inkSoft)),
                        ),
                        const Icon(
                          Icons.place_outlined,
                          size: 14,
                          color: AppColors.inkSoft,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '$venue, $branchName',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.inkSoft,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Capacity Progress
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: capacity == 0
                            ? 0
                            : (enrolled / capacity).clamp(0.0, 1.0),
                        backgroundColor: const Color(0xFFF1F5F9),
                        valueColor:
                            AlwaysStoppedAnimation<Color>(progressColor),
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Spots left & participant count
                    SizedBox(
                      width: double.infinity,
                      child: Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Text(
                            isFull
                                ? 'Class full ($capacity/$capacity)'
                                : '$spots spots left',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isFull
                                  ? const Color(0xFFD97706)
                                  : AppColors.primary,
                            ),
                          ),
                          Text(
                            '$enrolled / $capacity registered',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppColors.inkSoft,
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
      ),
    );
  }
}

Widget classFilter(
  String label,
  String? value,
  Iterable<String> values,
  ValueChanged<String?> changed,
) {
  final options = {...values, if (value != null && value.isNotEmpty) value}
      .where((s) => s.isNotEmpty)
      .toList()
    ..sort();

  return LayoutBuilder(
    builder: (context, constraints) {
      final maxTextWidth = constraints.hasBoundedWidth
          ? (constraints.maxWidth - 52).clamp(64.0, double.infinity)
          : 220.0;

      Widget boundedText(String text, TextStyle? style) => ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxTextWidth),
            child: Text(
              text,
              style: style,
              overflow: TextOverflow.ellipsis,
            ),
          );

      return Container(
        constraints: const BoxConstraints(minHeight: 38),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: value != null ? AppColors.primaryTint : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: value != null ? AppColors.primary : AppColors.hairline,
          ),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            key: Key('filter_$label'),
            hint: boundedText(
              label,
              TextStyle(
                fontSize: 13,
                fontWeight: value != null ? FontWeight.w700 : FontWeight.w500,
                color: value != null ? AppColors.primary : AppColors.inkSoft,
              ),
            ),
            value: value,
            icon: Icon(
              Icons.arrow_drop_down_rounded,
              color: value != null ? AppColors.primary : AppColors.inkSoft,
            ),
            isDense: true,
            items: [
              DropdownMenuItem(
                value: '',
                child: boundedText(
                  'All $label',
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
              for (final option in options)
                DropdownMenuItem(
                  value: option,
                  child: boundedText(option, const TextStyle(fontSize: 13)),
                ),
            ],
            onChanged: (v) => changed(v == '' ? null : v),
          ),
        ),
      );
    },
  );
}

/// Standalone Group Classes discovery and booking screen with its own AppBar.
class MemberGroupClassesScreen extends StatelessWidget {
  const MemberGroupClassesScreen({
    super.key,
    required this.call,
    required this.onUpgrade,
    this.startInMyClasses = false,
  });

  final ClassCall call;
  final VoidCallback onUpgrade;
  final bool startInMyClasses;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final scaled14 = MediaQuery.textScalerOf(context).scale(14);
    final showSubtitle = width >= 360 && scaled14 <= 18;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FC),
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: AppColors.hairline),
        ),
        title: showSubtitle
            ? const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Group Classes',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                      letterSpacing: -0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Explore & book fitness classes',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.inkSoft,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              )
            : const Text(
                'Group Classes',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                  letterSpacing: -0.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
      ),
      body: SafeArea(
        top: false,
        child: MemberGroupClassesPage(
          startInMyClasses: startInMyClasses,
          call: call,
          onUpgrade: onUpgrade,
        ),
      ),
    );
  }
}

class MemberGroupClassesPage extends StatefulWidget {
  const MemberGroupClassesPage({
    super.key,
    required this.call,
    required this.onUpgrade,
    this.startInMyClasses = false,
  });

  final ClassCall call;
  final VoidCallback onUpgrade;
  final bool startInMyClasses;

  @override
  State<MemberGroupClassesPage> createState() => _MemberGroupClassesPageState();
}

class _MemberGroupClassesPageState extends State<MemberGroupClassesPage> {
  List<Map<String, dynamic>> _rows = [];
  late bool _mine = widget.startInMyClasses;
  bool _loading = false;
  String? _error, _branch, _category, _date;
  String _search = '';
  String _section = 'Upcoming';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.call('list', {});
      final rows = classRows(result['classes'])
        ..sort((a, b) =>
            (a['startAtMillis'] as int).compareTo(b['startAtMillis'] as int));
      if (mounted) setState(() => _rows = rows);
    } catch (error) {
      if (mounted) setState(() => _error = classError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(Map row) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => MemberGroupClassDetails(
        call: widget.call,
        id: row['id'] as String,
        onUpgrade: widget.onUpgrade,
      ),
    ));
    if (mounted) await _load();
  }

  void _clearFilters() => setState(() {
        _branch = null;
        _category = null;
        _date = null;
        _search = '';
        _searchController.clear();
      });

  bool _matches(Map row) {
    final registration = _status(row['registration']);
    if (_mine) {
      if (registration == null) return false;
      if (_section == 'Cancelled') {
        return registration == 'Cancelled' || row['status'] == 'Cancelled';
      }
      if (registration == 'Cancelled' || row['status'] == 'Cancelled') {
        return false;
      }
      return (row['status'] == 'Completed') == (_section == 'Completed');
    }

    final query = _search.trim().toLowerCase();
    if (query.isNotEmpty) {
      final title = (row['title'] as String? ?? '').toLowerCase();
      final instructor = (row['instructor'] as String? ?? '').toLowerCase();
      final venue = (row['venue'] as String? ?? '').toLowerCase();
      final branch = (row['branchName'] as String? ?? '').toLowerCase();
      if (!title.contains(query) &&
          !instructor.contains(query) &&
          !venue.contains(query) &&
          !branch.contains(query)) {
        return false;
      }
    }

    return !['Completed', 'Cancelled'].contains(row['status']) &&
        (_branch == null || _branch == row['branchName']) &&
        (_category == null || _category == row['category']) &&
        (_date == null || _date == classDate(row['startAtMillis']));
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows.where(_matches).toList();
    final hasAvailableUpcoming =
        _rows.any((row) => !['Completed', 'Cancelled'].contains(row['status']));
    final hasActiveFilters = _branch != null ||
        _category != null ||
        _date != null ||
        _search.trim().isNotEmpty;
    final uniqueDates = {
      for (final r in _rows)
        if (!['Completed', 'Cancelled'].contains(r['status']))
          classDate(r['startAtMillis'])
    }.toList();

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          // Segmented Navigation: Explore vs My Classes
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFEDE7FB),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _mine = false),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 9),
                      decoration: BoxDecoration(
                        color: !_mine ? AppColors.surface : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: !_mine
                            ? const [
                                BoxShadow(
                                  color: Color(0x10000000),
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                )
                              ]
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Explore Classes',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight:
                              !_mine ? FontWeight.w800 : FontWeight.w600,
                          color: !_mine
                              ? const Color(0xFF7027DC)
                              : AppColors.inkSoft,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _mine = true),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 9),
                      decoration: BoxDecoration(
                        color: _mine ? AppColors.surface : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: _mine
                            ? const [
                                BoxShadow(
                                  color: Color(0x10000000),
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                )
                              ]
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'My Classes',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: _mine ? FontWeight.w800 : FontWeight.w600,
                          color: _mine
                              ? const Color(0xFF7027DC)
                              : AppColors.inkSoft,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          if (_mine) ...[
            // Sub-navigation for My Classes: Upcoming | Completed | Cancelled
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final section in ['Upcoming', 'Completed', 'Cancelled'])
                  ChoiceChip(
                    label: Text(section),
                    selected: _section == section,
                    selectedColor: AppColors.primaryTint,
                    backgroundColor: AppColors.surface,
                    side: BorderSide(
                      color: _section == section
                          ? Colors.transparent
                          : AppColors.hairline,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    labelStyle: TextStyle(
                      fontSize: 12.5,
                      fontWeight: _section == section
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: _section == section
                          ? const Color(0xFF7027DC)
                          : AppColors.ink,
                    ),
                    onSelected: (_) => setState(() => _section = section),
                  ),
              ],
            ),
          ] else ...[
            // Search Bar
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 46),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search classes, instructors, studios...',
                  hintStyle:
                      const TextStyle(fontSize: 13, color: AppColors.inkSoft),
                  prefixIcon: const Icon(Icons.search_rounded,
                      size: 20, color: AppColors.inkSoft),
                  suffixIcon: _search.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _search = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.surface,
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.hairline),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.hairline),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: Color(0xFF7027DC), width: 1.5),
                  ),
                ),
                style: const TextStyle(fontSize: 13),
                onChanged: (v) => setState(() => _search = v),
              ),
            ),
            const SizedBox(height: 10),

            // Horizontal Date strip (if multiple dates available)
            if (uniqueDates.length > 1) ...[
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: const Text('All Dates'),
                        selected: _date == null,
                        selectedColor: AppColors.primaryTint,
                        backgroundColor: AppColors.surface,
                        side: BorderSide(
                          color: _date == null
                              ? Colors.transparent
                              : AppColors.hairline,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        labelStyle: TextStyle(
                          fontSize: 11.5,
                          fontWeight:
                              _date == null ? FontWeight.w700 : FontWeight.w500,
                          color: _date == null
                              ? const Color(0xFF7027DC)
                              : AppColors.ink,
                        ),
                        onSelected: (_) => setState(() => _date = null),
                      ),
                    ),
                    for (final dateStr in uniqueDates)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(dateStr),
                          selected: _date == dateStr,
                          selectedColor: AppColors.primaryTint,
                          backgroundColor: AppColors.surface,
                          side: BorderSide(
                            color: _date == dateStr
                                ? Colors.transparent
                                : AppColors.hairline,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          labelStyle: TextStyle(
                            fontSize: 11.5,
                            fontWeight: _date == dateStr
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: _date == dateStr
                                ? const Color(0xFF7027DC)
                                : AppColors.ink,
                          ),
                          onSelected: (_) => setState(() => _date = dateStr),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Filter Chips (Branch + Category)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                classFilter(
                  'Branch',
                  _branch,
                  _rows
                      .map((r) => r['branchName'] as String? ?? '')
                      .where((s) => s.isNotEmpty),
                  (v) => setState(() => _branch = v),
                ),
                classFilter(
                  'Category',
                  _category,
                  _rows
                      .map((r) => r['category'] as String? ?? '')
                      .where((s) => s.isNotEmpty),
                  (v) => setState(() => _category = v),
                ),
                if (hasActiveFilters)
                  TextButton.icon(
                    onPressed: _clearFilters,
                    icon: const Icon(Icons.refresh_rounded, size: 14),
                    label: const Text('Reset', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 32),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),

          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            ),

          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFECDD3)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          color: Color(0xFFE11D48)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            color: Color(0xFFE11D48),
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  FilledButton.tonal(
                    onPressed: _load,
                    child: const Text('Try again'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          if (!_loading && _error == null && rows.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.hairline),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primaryTint,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _mine
                          ? Icons.event_available_outlined
                          : (hasAvailableUpcoming && hasActiveFilters
                              ? Icons.search_off_rounded
                              : Icons.calendar_today_rounded),
                      size: 36,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _mine
                        ? 'No $_section Classes'
                        : (hasAvailableUpcoming && hasActiveFilters
                            ? 'No matching classes'
                            : 'No classes available yet'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _mine
                        ? (_section == 'Upcoming'
                            ? 'You have not registered for any upcoming classes yet.'
                            : 'No ${_section.toLowerCase()} classes in your booking history.')
                        : (hasAvailableUpcoming && hasActiveFilters
                            ? 'Try adjusting your filters or search terms to find available sessions.'
                            : 'New classes will appear here when the gym publishes upcoming sessions.'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.inkSoft,
                    ),
                  ),
                  if (!_mine && hasAvailableUpcoming && hasActiveFilters) ...[
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _clearFilters,
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Clear Filters'),
                    ),
                  ],
                  if (_mine && _section == 'Upcoming') ...[
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => setState(() => _mine = false),
                      icon: const Icon(Icons.explore_rounded, size: 18),
                      label: const Text('Explore Classes'),
                    ),
                  ],
                ],
              ),
            ),

          for (final row in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: GroupClassCard(
                row: row,
                onOpen: () => _open(row),
              ),
            ),
        ],
      ),
    );
  }
}

class MemberGroupClassDetails extends StatefulWidget {
  const MemberGroupClassDetails({
    super.key,
    required this.call,
    required this.id,
    required this.onUpgrade,
  });

  final ClassCall call;
  final String id;
  final VoidCallback onUpgrade;

  @override
  State<MemberGroupClassDetails> createState() =>
      _MemberGroupClassDetailsState();
}

class _MemberGroupClassDetailsState extends State<MemberGroupClassDetails> {
  Map<String, dynamic>? _item;
  bool _busy = false;
  String? _error, _notice;
  int? _serverNow;
  String? _pendingAction, _pendingId;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run([String? action]) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      if (action != null) {
        if (_pendingAction != action) {
          _pendingAction = action;
          _pendingId = classRequestId();
        }
        await widget.call(action, {'id': widget.id, 'requestId': _pendingId});
        _pendingAction = null;
        _pendingId = null;
      }
      final result = await widget.call('detail', {'id': widget.id});
      if (mounted) {
        setState(() {
          _item = Map<String, dynamic>.from(result['item'] as Map);
          _serverNow = result['serverNowMillis'] as int?;
          if (action != null) {
            _notice = action == 'join'
                ? 'You’re registered. Find this session in My Classes.'
                : 'Registration cancelled.';
          }
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = classError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Cancel registration?'),
        content: const Text(
          'Your spot will be released for another member. Remember that cancellations close 2 hours before the session.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Keep spot'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE11D48),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Cancel registration'),
          ),
        ],
      ),
    );
    if (mounted && confirmed == true) await _run('leave');
  }

  @override
  Widget build(BuildContext context) {
    final row = _item;
    final registered = _status(row?['registration']) == 'Registered';
    final status = row?['status'] as String? ?? 'Open';
    final startAt = (row?['startAtMillis'] as num?)?.toInt() ?? 0;
    final now = _serverNow ?? DateTime.now().millisecondsSinceEpoch;
    final canCancel = (now < startAt - 7200000);
    final durationMinutes =
        (((row?['endAtMillis'] as num?)?.toInt() ?? 0) - startAt) ~/ 60000;
    final capacity = (row?['capacity'] as num?)?.toInt() ?? 0;
    final enrolled = (row?['activeCount'] as num?)?.toInt() ?? 0;
    final eligibility = classEligibility(row?['eligibility']);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FC),
      appBar: AppBar(
        title: const Text('Class details'),
        centerTitle: false,
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh class',
            onPressed: _busy ? null : () => _run(),
          ),
        ],
      ),
      body: row == null && _busy
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              children: [
                if (_busy) const LinearProgressIndicator(),
                if (_error != null) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFECDD3)),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        color: Color(0xFFE11D48),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                if (_notice != null) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded,
                            color: Color(0xFF16A34A), size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _notice!,
                            style: const TextStyle(
                              color: Color(0xFF16A34A),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (row != null) ...[
                  // Hero Card with Cover & Badges
                  GroupClassCard(row: row),
                  const SizedBox(height: 16),

                  // About Section
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
                          'About the class',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${row['description']}',
                          style: const TextStyle(
                            fontSize: 13.5,
                            color: AppColors.inkSoft,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Instructor Section
                  GroupClassInstructor(
                    key: ValueKey(row['coachId']),
                    row: row,
                    call: widget.call,
                  ),
                  const SizedBox(height: 14),

                  // Location & Schedule Card
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
                          'Schedule & Location',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.event_rounded,
                                size: 18, color: AppColors.primary),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    classWhen(row),
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.ink,
                                    ),
                                  ),
                                  Text(
                                    '$durationMinutes minutes · ${row['difficulty']}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.inkSoft,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 20),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.place_rounded,
                                size: 18, color: AppColors.primary),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${row['venue']}',
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.ink,
                                    ),
                                  ),
                                  Text(
                                    '${row['branchName']}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.inkSoft,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Registration & Policy Rules
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
                          'Booking Policy & Eligibility',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(Icons.verified_user_outlined,
                                size: 16, color: AppColors.inkSoft),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Eligibility: $eligibility on class date',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.ink,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: const [
                            Icon(Icons.access_time_rounded,
                                size: 16, color: AppColors.inkSoft),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Cancellation deadline: At least 2 hours before start time.',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: AppColors.inkSoft,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.group_outlined,
                                size: 16, color: AppColors.inkSoft),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Enrolled: $enrolled / $capacity participants',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: AppColors.inkSoft,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
      bottomNavigationBar: row == null
          ? null
          : Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.hairline)),
              ),
              child: SafeArea(
                child: Builder(
                  builder: (context) {
                    if (registered &&
                        !['Cancelled', 'Completed', 'In progress']
                            .contains(status)) {
                      return Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFE11D48),
                                side:
                                    const BorderSide(color: Color(0xFFFECDD3)),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: _busy || !canCancel ? null : _cancel,
                              child: Text(
                                canCancel
                                    ? 'Cancel registration'
                                    : 'Cancellation closed (<2h)',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        ],
                      );
                    }

                    if (row['eligible'] == false && status == 'Open') {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            eligibility == 'Premium Only'
                                ? 'An active Premium membership is required on the class date.'
                                : 'An active paid membership is required on the class date.',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFFD97706),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: widget.onUpgrade,
                              child: const Text('Upgrade Membership',
                                  style:
                                      TextStyle(fontWeight: FontWeight.w700)),
                            ),
                          ),
                        ],
                      );
                    }

                    if (!registered) {
                      final isOpen = status == 'Open';
                      final isFull = status == 'Full';
                      return SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: isOpen
                                ? AppColors.primary
                                : const Color(0xFF94A3B8),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed:
                              _busy || !isOpen ? null : () => _run('join'),
                          child: Text(
                            isFull
                                ? 'Fully booked'
                                : (isOpen ? 'Join Class' : status),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      );
                    }

                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),
    );
  }
}

class UpcomingGroupClasses extends StatefulWidget {
  const UpcomingGroupClasses({
    super.key,
    required this.call,
    required this.onExplore,
    required this.onViewAll,
    required this.onOpen,
    this.active = true,
  });

  final ClassCall call;
  final Future<void> Function() onExplore, onViewAll;
  final Future<void> Function(String) onOpen;
  final bool active;

  @override
  UpcomingGroupClassesState createState() => UpcomingGroupClassesState();
}

class UpcomingGroupClassesState extends State<UpcomingGroupClasses> {
  late Future<Map<String, dynamic>> _feed = _load();

  Future<Map<String, dynamic>> _load() async => widget.call('list', {});

  @override
  void didUpdateWidget(covariant UpcomingGroupClasses oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) _feed = _load();
  }

  Future<void> refresh() async {
    if (!mounted || !widget.active) return;
    final next = _load();
    setState(() {
      _feed = next;
    });
    try {
      await next;
    } catch (_) {
      // The FutureBuilder displays the error and retry action.
    }
  }

  Future<void> _visit(Future<void> Function() open) async {
    await open();
    await refresh();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(
              child:
                  Text('Upcoming Classes', style: theme.textTheme.titleLarge)),
          TextButton(
              onPressed: () => _visit(widget.onViewAll),
              child: const Text('View all')),
        ]),
        const SizedBox(height: 8),
        FutureBuilder(
          future: _feed,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Could not load upcoming classes',
                        style: TextStyle(color: colors.error)),
                    TextButton(
                        onPressed: refresh, child: const Text('Try again')),
                  ]);
            }
            if (!snapshot.hasData) {
              return const LinearProgressIndicator(
                  semanticsLabel: 'Loading upcoming classes');
            }
            final data = snapshot.data!;
            final now = (data['serverNowMillis'] as num?)?.toInt() ??
                DateTime.now().millisecondsSinceEpoch;
            final rows = classRows(data['classes']).where((row) {
              final start = row['startAtMillis'];
              return start is num &&
                  start > now &&
                  _status(row['registration']) == 'Registered' &&
                  !['Completed', 'Cancelled', 'In progress']
                      .contains(row['status']);
            }).toList()
              ..sort((a, b) => (a['startAtMillis'] as num)
                  .compareTo(b['startAtMillis'] as num));
            if (rows.isEmpty) {
              return Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('No upcoming classes',
                      style: theme.textTheme.bodyMedium),
                  TextButton(
                      onPressed: () => _visit(widget.onExplore),
                      child: const Text('Explore classes')),
                ],
              );
            }
            final next = rows.first;
            final date = classLocal(next['startAtMillis']);
            final localizedDate = MaterialLocalizations.of(context);
            final dateParts = classDate(next['startAtMillis']).split(' ');
            final locations = [
              if (next['venue'] case final String venue
                  when venue.trim().isNotEmpty)
                venue,
              if (next['branchName'] case final String branch
                  when branch.trim().isNotEmpty)
                branch,
            ];
            return Card(
              margin: EdgeInsets.zero,
              elevation: 0,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                side: const BorderSide(color: AppColors.hairline),
                borderRadius: BorderRadius.circular(16),
              ),
              child: InkWell(
                onTap: () => _visit(() => widget.onOpen(next['id'] as String)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Semantics(
                        label: localizedDate.formatFullDate(date),
                        child: ExcludeSemantics(
                          child: Container(
                            constraints: const BoxConstraints(minWidth: 58),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 6),
                            decoration: BoxDecoration(
                              color: colors.primary.withValues(alpha: .10),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(children: [
                              Text(dateParts[1].toUpperCase(),
                                  style: theme.textTheme.bodySmall
                                      ?.copyWith(color: colors.primary)),
                              Text(localizedDate.formatDecimal(date.day),
                                  style: theme.textTheme.titleLarge?.copyWith(
                                      color: colors.primary,
                                      fontWeight: FontWeight.w700)),
                            ]),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(next['title'] as String,
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 3),
                          Text(
                              '${classTime(next['startAtMillis'])}–${classTime(next['endAtMillis'])} MYT',
                              style: theme.textTheme.bodySmall),
                          if (locations.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(locations.join(' · '),
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(color: colors.onSurfaceVariant)),
                          ],
                        ],
                      )),
                      Icon(Icons.chevron_right, color: colors.onSurfaceVariant),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
