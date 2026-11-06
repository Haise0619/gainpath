import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gainpath_domain/content.dart';
import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show AuthSession;
import 'package:gainpath_ui/gainpath_ui.dart';
import '../di/booking_factory.dart';
import '../../features/recommendation/application/member_recommendation_repository.dart';
import '../../features/recommendation/presentation/member/member_recommendation_sheet.dart';

enum NotificationCategoryFilter {
  all,
  announcements,
  coaching,
  bookings,
  recommendations,
}

class UnifiedNotificationItem {
  const UnifiedNotificationItem({
    required this.id,
    required this.category,
    required this.title,
    required this.message,
    this.timestamp,
    this.isRead,
    this.noticeId,
    this.bookingId,
    this.announcement,
    this.recommendation,
  });

  final String id;
  final NotificationCategoryFilter category;
  final String title;
  final String message;
  final DateTime? timestamp;
  final bool? isRead;
  final String? noticeId;
  final String? bookingId;
  final Announcement? announcement;
  final RecommendationNotice? recommendation;
}

/// Full-screen Member Notification Center unifying gym announcements,
/// coach session notices, and booking updates.
class MemberNotificationsScreen extends StatefulWidget {
  const MemberNotificationsScreen({
    super.key,
    this.session,
    this.announcementReader,
    this.module9Repository,
    this.bookingListFactory,
    required this.isCurrent,
    this.onOpenBookings,
    this.initialItems,
    this.recommendationRepository,
    this.onOpenRecommendationTarget,
    this.recommendationPhotoBuilder,
    this.onBrowseCoaches,
  });

  final AuthSession? session;
  final AnnouncementReader? announcementReader;
  final Module9Repository? module9Repository;
  final BookingListFactory? bookingListFactory;
  final bool Function() isCurrent;
  final VoidCallback? onOpenBookings;
  final List<UnifiedNotificationItem>? initialItems;
  final MemberRecommendationRepository? recommendationRepository;
  final MemberRecommendationOpener? onOpenRecommendationTarget;
  final MemberRecommendationPhotoBuilder? recommendationPhotoBuilder;
  final VoidCallback? onBrowseCoaches;

  @override
  State<MemberNotificationsScreen> createState() =>
      _MemberNotificationsScreenState();
}

class _MemberNotificationsScreenState extends State<MemberNotificationsScreen> {
  NotificationCategoryFilter _selectedFilter = NotificationCategoryFilter.all;
  final List<UnifiedNotificationItem> _items = [];
  bool _loading = false;
  bool _loadingMore = false;
  String? _nextInboxCursor;
  int _generation = 0;
  String? _error;
  StreamSubscription<void>? _inboxUpdates;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    if (widget.initialItems != null) {
      _items.addAll(widget.initialItems!);
    } else {
      _load();
    }
    if (widget.module9Repository != null) {
      _inboxUpdates = widget.module9Repository!.watchInbox().listen((_) {
        if (!_loading) _load(silent: true);
      }, onError: (_) {/* Manual and pull-to-refresh remain available */});
      _pollingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (!_loading) _load(silent: true);
      });
    }
  }

  @override
  void dispose() {
    _generation++;
    unawaited(_inboxUpdates?.cancel());
    _pollingTimer?.cancel();
    super.dispose();
  }

  bool get _current => mounted && widget.isCurrent();

  Future<void> _load({bool silent = false}) async {
    if (!_current) return;
    final generation = ++_generation;
    String? nextCursor;
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    final newItems = <UnifiedNotificationItem>[];
    String? loadError;

    // 1. Gym announcements
    if (widget.announcementReader != null) {
      try {
        final page = await widget.announcementReader!.loadAnnouncements();
        for (final a in page.items) {
          if (a.isActive) {
            newItems.add(UnifiedNotificationItem(
              id: 'announcement_${a.id}',
              category: NotificationCategoryFilter.announcements,
              title: a.title,
              message: a.body,
              timestamp: a.validFrom,
              announcement: a,
            ));
          }
        }
      } catch (_) {
        loadError = 'Could not load gym announcements.';
      }
    }

    // 2. Coaching & booking notices from Module 9
    if (widget.module9Repository != null) {
      try {
        final noticePage = await widget.module9Repository!.loadInbox();
        nextCursor = noticePage.nextAfterId;
        for (final notice in noticePage.records) {
          final isBooking = notice.bookingId != null;
          newItems.add(UnifiedNotificationItem(
            id: 'notice_${notice.id}',
            category: notice.recommendation != null
                ? NotificationCategoryFilter.recommendations
                : isBooking
                    ? NotificationCategoryFilter.bookings
                    : NotificationCategoryFilter.coaching,
            title: notice.title,
            message: notice.message,
            timestamp: notice.createdAt,
            isRead: notice.read,
            noticeId: notice.id,
            bookingId: notice.bookingId,
            recommendation: notice.recommendation,
          ));
        }
      } catch (_) {
        loadError = loadError == null
            ? 'Could not load coaching notices.'
            : 'Could not load notifications.';
      }
    }

    if (widget.module9Repository == null && widget.announcementReader == null) {
      loadError = 'Notifications are currently unavailable.';
    }

    // Sort chronologically by timestamp (newest first)
    newItems.sort((a, b) {
      final ta = a.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
      final tb = b.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
      return tb.compareTo(ta);
    });

    if (!_current || generation != _generation) return;
    setState(() {
      _nextInboxCursor = nextCursor;
      _loadingMore = false;
      _items.clear();
      _items.addAll(newItems);
      _loading = false;
      _error = loadError;
    });
  }

  Future<void> _loadMore() async {
    final cursor = _nextInboxCursor;
    final repository = widget.module9Repository;
    if (!_current ||
        _loading ||
        _loadingMore ||
        cursor == null ||
        repository == null) {
      return;
    }
    final generation = _generation;
    setState(() => _loadingMore = true);
    try {
      final page = await repository.loadInbox(afterId: cursor);
      if (!_current || generation != _generation) return;
      if (page.nextAfterId == cursor) {
        throw const FormatException('Invalid inbox cursor');
      }
      setState(() {
        final known = _items.map((i) => i.id).toSet();
        for (final notice in page.records) {
          if (!known.add('notice_${notice.id}')) continue;
          _items.add(UnifiedNotificationItem(
              id: 'notice_${notice.id}',
              category: notice.recommendation != null
                  ? NotificationCategoryFilter.recommendations
                  : notice.bookingId != null
                      ? NotificationCategoryFilter.bookings
                      : NotificationCategoryFilter.coaching,
              title: notice.title,
              message: notice.message,
              timestamp: notice.createdAt,
              isRead: notice.read,
              noticeId: notice.id,
              bookingId: notice.bookingId,
              recommendation: notice.recommendation));
        }
        _items.sort((a, b) => (b.timestamp ?? DateTime(1970))
            .compareTo(a.timestamp ?? DateTime(1970)));
        _nextInboxCursor = page.nextAfterId;
        _loadingMore = false;
        _error = null;
      });
    } catch (_) {
      if (_current && generation == _generation) {
        setState(() {
          _loadingMore = false;
          _error = 'Could not load older notifications. Please retry.';
        });
      }
    }
  }

  Future<void> _handleItemTap(UnifiedNotificationItem item) async {
    if (!_current) return;
    if (item.recommendation != null) {
      final repository = widget.recommendationRepository;
      if (repository == null ||
          !repository.enabled ||
          !repository.isCurrent ||
          (widget.session != null &&
              repository.scope != widget.session!.scope)) {
        showToast(context, 'Recommendations are currently unavailable.');
        return;
      }
      await showMemberRecommendationDetail(context,
          recommendationId: item.recommendation!.recommendationId,
          repository: repository,
          isCurrent: () => _current,
          onOpenTarget: widget.onOpenRecommendationTarget,
          scopedPhotoBuilder: widget.recommendationPhotoBuilder,
          onBrowseCoaches: widget.onBrowseCoaches,
          onChanged: () => unawaited(_load(silent: true)));
      return;
    }
    // 1. If it has a noticeId, mark it as read in the repository
    if (item.noticeId != null && widget.module9Repository != null) {
      try {
        await widget.module9Repository!.markRead(item.noticeId!);
        if (!_current) return;
        // Locally mark as read immediately
        setState(() {
          final idx = _items.indexWhere((i) => i.id == item.id);
          if (idx >= 0) {
            final old = _items[idx];
            _items[idx] = UnifiedNotificationItem(
              id: old.id,
              category: old.category,
              title: old.title,
              message: old.message,
              timestamp: old.timestamp,
              isRead: true,
              noticeId: old.noticeId,
              bookingId: old.bookingId,
              announcement: old.announcement,
              recommendation: old.recommendation,
            );
          }
        });
      } catch (_) {
        // Continue navigation or view even if markRead fails
      }
    }

    if (!_current) return;

    // 2. Destination routing
    if (item.bookingId != null) {
      if (widget.onOpenBookings != null) {
        widget.onOpenBookings!();
      } else {
        showToast(context, 'Opening booking details.');
      }
      return;
    }

    // 3. Announcement or Coach Notice detail dialog
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(item.title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (item.timestamp != null) ...[
                Text(
                  _formatDate(item.timestamp!),
                  style: Theme.of(ctx)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.inkSoft),
                ),
                const SizedBox(height: 12),
              ],
              Text(item.message, style: Theme.of(ctx).textTheme.bodyMedium),
              if (item.announcement != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.hairline),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.event_available_rounded,
                          size: 16, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Valid until ${_formatDate(item.announcement!.validTo)}',
                          style: Theme.of(ctx).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    final now = DateTime.now();
    final difference = now.difference(local);

    if (difference.inMinutes < 60 && difference.inMinutes >= 0) {
      final mins = difference.inMinutes;
      return mins <= 1 ? 'Just now' : '$mins mins ago';
    } else if (difference.inHours < 24 && difference.inHours >= 0) {
      final hours = difference.inHours;
      return hours == 1 ? '1 hour ago' : '$hours hours ago';
    } else if (difference.inDays < 7 && difference.inDays >= 0) {
      final days = difference.inDays;
      return days == 1 ? 'Yesterday' : '$days days ago';
    }

    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }

  List<UnifiedNotificationItem> get _filteredItems {
    if (_selectedFilter == NotificationCategoryFilter.all) return _items;
    return _items.where((i) => i.category == _selectedFilter).toList();
  }

  Widget _buildCategoryChip(String label, NotificationCategoryFilter filter) {
    final selected = _selectedFilter == filter;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: AppColors.primaryTint,
      labelStyle: TextStyle(
        color: selected ? AppColors.primary : AppColors.ink,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
      onSelected: (val) {
        if (val) setState(() => _selectedFilter = filter);
      },
    );
  }

  IconData _iconForCategory(NotificationCategoryFilter category) =>
      switch (category) {
        NotificationCategoryFilter.announcements => Icons.campaign_rounded,
        NotificationCategoryFilter.coaching => Icons.sports_rounded,
        NotificationCategoryFilter.bookings => Icons.event_rounded,
        NotificationCategoryFilter.recommendations =>
          Icons.auto_awesome_rounded,
        _ => Icons.notifications_rounded,
      };

  Color _colorForCategory(NotificationCategoryFilter category) =>
      switch (category) {
        NotificationCategoryFilter.announcements => AppColors.warning,
        NotificationCategoryFilter.coaching => AppColors.primary,
        NotificationCategoryFilter.bookings => AppColors.accent,
        _ => AppColors.primaryDark,
      };

  String _labelForCategory(NotificationCategoryFilter category) =>
      switch (category) {
        NotificationCategoryFilter.announcements => 'Announcement',
        NotificationCategoryFilter.coaching => 'Coaching',
        NotificationCategoryFilter.bookings => 'Booking',
        NotificationCategoryFilter.recommendations => 'Recommendation',
        _ => 'Notification',
      };

  String get _emptyMessage => switch (_selectedFilter) {
        NotificationCategoryFilter.announcements =>
          'No gym announcements at this time.',
        NotificationCategoryFilter.coaching => 'No coaching notices yet.',
        NotificationCategoryFilter.bookings => 'No booking updates yet.',
        NotificationCategoryFilter.recommendations => 'No recommendations yet.',
        _ => 'No notifications at this time.',
      };

  @override
  Widget build(BuildContext context) {
    if (!widget.isCurrent()) {
      return const Scaffold(
        body: Center(child: Text('Session changed. Return to sign in.')),
      );
    }

    final filtered = _filteredItems;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : () => _load(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(),
        color: AppColors.primary,
        child: Column(
          children: [
            if (_loading) const LinearProgressIndicator(),
            if (widget.initialItems != null ||
                widget.recommendationRepository?.fixtureOnly == true)
              const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('Synthetic local preview',
                      style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700))),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildCategoryChip('All', NotificationCategoryFilter.all),
                    const SizedBox(width: 8),
                    _buildCategoryChip('Announcements',
                        NotificationCategoryFilter.announcements),
                    const SizedBox(width: 8),
                    _buildCategoryChip(
                        'Coaching', NotificationCategoryFilter.coaching),
                    const SizedBox(width: 8),
                    _buildCategoryChip(
                        'Bookings', NotificationCategoryFilter.bookings),
                    const SizedBox(width: 8),
                    _buildCategoryChip('Recommendations',
                        NotificationCategoryFilter.recommendations),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Panel(
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          color: AppColors.danger),
                      const SizedBox(width: 12),
                      Expanded(child: Text(_error!)),
                      TextButton(
                        onPressed: () => _load(),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: filtered.isEmpty && !_loading
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 80),
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _iconForCategory(_selectedFilter),
                                size: 48,
                                color: AppColors.inkSoft.withValues(alpha: 0.5),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _emptyMessage,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyLarge
                                    ?.copyWith(color: AppColors.inkSoft),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        final unread = item.isRead == false;
                        final color = _colorForCategory(item.category);

                        return Panel(
                          padding: EdgeInsets.zero,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => _handleItemTap(item),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      _iconForCategory(item.category),
                                      color: color,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 4,
                                          crossAxisAlignment:
                                              WrapCrossAlignment.center,
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2),
                                              decoration: BoxDecoration(
                                                color: color.withValues(
                                                    alpha: 0.12),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                _labelForCategory(
                                                    item.category),
                                                style: TextStyle(
                                                  color: color,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                            if (item.timestamp != null)
                                              Text(
                                                _formatDate(item.timestamp!),
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall
                                                    ?.copyWith(
                                                      color: AppColors.inkSoft,
                                                      fontSize: 11.5,
                                                    ),
                                              ),
                                            if (unread)
                                              const Text('Unread',
                                                  style: TextStyle(
                                                      color: AppColors.primary,
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w700)),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          item.title,
                                          style: TextStyle(
                                            fontWeight: unread
                                                ? FontWeight.w700
                                                : FontWeight.w600,
                                            fontSize: 15,
                                            color: AppColors.ink,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          item.message,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                color: AppColors.inkSoft,
                                                fontSize: 13.5,
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
                      },
                    ),
            ),
            if (_nextInboxCursor != null)
              SafeArea(
                  top: false,
                  child: TextButton(
                      onPressed: _loadingMore ? null : _loadMore,
                      child: Text(_loadingMore
                          ? 'Loading older notifications…'
                          : 'Load older notifications'))),
          ],
        ),
      ),
    );
  }
}
