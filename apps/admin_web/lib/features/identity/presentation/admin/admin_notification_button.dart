import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_ui/gainpath_ui.dart';

import '../../application/coach_review_alerts_cubit.dart';
import '../../../membership/payment_review_repository.dart';
import 'admin_notification_seen.dart'
    if (dart.library.js_interop) 'admin_notification_seen_web.dart';

enum AdminNotificationKind {
  coach('Coach review', Icons.badge_outlined),
  refund('Refund requests', Icons.assignment_return_outlined),
  support('Support requests', Icons.support_agent_outlined);

  const AdminNotificationKind(this.label, this.icon);
  final String label;
  final IconData icon;
}

class AdminNotification {
  const AdminNotification(
      this.kind, this.id, this.title, this.summary, this.updatedAtMillis,
      {this.revision});

  final AdminNotificationKind kind;
  final String id, title, summary;
  final int updatedAtMillis;
  final String? revision;

  String get readKey => '${kind.name}:$id:${revision ?? updatedAtMillis}';
}

typedef AdminNotificationLoader = Future<List<AdminNotification>> Function();

class AdminNotificationButton extends StatefulWidget {
  const AdminNotificationButton({
    super.key,
    required this.scope,
    required this.onOpen,
    this.isCurrent,
    this.loadRefunds,
    this.loadSupport,
  });

  final String scope;
  final Future<bool> Function(AdminNotification item) onOpen;
  final bool Function()? isCurrent;
  final AdminNotificationLoader? loadRefunds, loadSupport;

  @override
  State<AdminNotificationButton> createState() =>
      _AdminNotificationButtonState();
}

class _AdminNotificationButtonState extends State<AdminNotificationButton>
    with WidgetsBindingObserver {
  final _feed = ValueNotifier(0);
  final _items = <AdminNotificationKind, List<AdminNotification>>{};
  final _failed = <AdminNotificationKind>{};
  late final _seen = readSeenNotifications(widget.scope);
  CoachReviewAlertsCubit? _coach;
  Timer? _timer;
  DateTime? _updatedAt;
  bool _loading = false;

  bool get _current => mounted && (widget.isCurrent?.call() ?? true);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(minutes: 2), (_) {
      final lifecycle = WidgetsBinding.instance.lifecycleState;
      if (lifecycle == null || lifecycle == AppLifecycleState.resumed) {
        unawaited(_refresh());
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final repository = context.read<CoachProfileAdminRepository>();
    if (identical(_coach?.repository, repository)) return;
    _coach?.close();
    _coach = CoachReviewAlertsCubit(repository);
    _updatedAt = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_current) unawaited(_refresh());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_refresh());
  }

  Future<List<AdminNotification>> _coachAlerts() async {
    final cubit = _coach!;
    await cubit.refresh();
    if (cubit.state.loading) throw StateError('Coach reviews are still loading.');
    if (cubit.state.accessLost) {
      throw const CoachRepositoryException('permission-denied');
    }
    if (cubit.state.error != null) throw StateError(cubit.state.error!);
    return cubit.state.items
        .map((item) => AdminNotification(
            AdminNotificationKind.coach,
            item.coachId,
            item.name,
            'Profile changes awaiting Admin publication',
            item.updatedAtMillis))
        .toList(growable: false);
  }

  Future<void> _refresh({bool force = false}) async {
    if (!_current || _loading || _coach == null) return;
    final last = _updatedAt;
    if (!force &&
        last != null &&
        DateTime.now().difference(last) < const Duration(seconds: 30)) {
      return;
    }
    _loading = true;
    _feed.value++;
    final sources = <AdminNotificationKind, AdminNotificationLoader>{
      AdminNotificationKind.coach: _coachAlerts,
      if (widget.loadRefunds case final loader?)
        AdminNotificationKind.refund: loader,
      if (widget.loadSupport case final loader?)
        AdminNotificationKind.support: loader,
    };
    await Future.wait(sources.entries.map((source) async {
      try {
        final next = await source.value().timeout(const Duration(seconds: 25));
        if (!_current) return;
        _items[source.key] = next;
        _failed.remove(source.key);
      } catch (error) {
        if (!_current) return;
        if ((error is FirebaseFunctionsException &&
                error.code == 'permission-denied') ||
            (error is PaymentReviewException &&
                error.code == 'permission-denied') ||
            (error is CoachRepositoryException &&
                error.code == 'permission-denied')) {
          _items.remove(source.key);
        }
        _failed.add(source.key);
      }
      _feed.value++;
    }));
    _loading = false;
    if (_current) {
      _updatedAt = DateTime.now();
      _feed.value++;
    }
  }

  List<AdminNotification> get _notifications => [
        for (final items in _items.values) ...items,
      ]..sort((a, b) => b.updatedAtMillis.compareTo(a.updatedAtMillis));

  bool _unread(AdminNotification item) => !_seen.contains(item.readKey);

  void _markRead(Iterable<AdminNotification> notices) {
    if (!_current) return;
    for (final notice in notices) {
      _seen
        ..remove(notice.readKey)
        ..add(notice.readKey);
    }
    while (_seen.length > 300) {
      _seen.remove(_seen.first);
    }
    writeSeenNotifications(widget.scope, _seen);
    _feed.value++;
  }

  Future<void> _open() async {
    if (!_current) return;
    unawaited(_refresh());
    final picked = await showDialog<AdminNotification>(
      context: context,
      builder: (dialogContext) => Dialog(
        alignment: Alignment.topRight,
        insetPadding: const EdgeInsets.fromLTRB(12, 62, 16, 16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420, maxHeight: 560),
          child: AnimatedBuilder(
            animation: _feed,
            builder: (_, __) => _buildPanel(dialogContext),
          ),
        ),
      ),
    );
    if (picked != null && _current && await widget.onOpen(picked)) {
      _markRead([picked]);
    }
  }

  Widget _buildPanel(BuildContext dialogContext) {
    final notices = _current ? _notifications : const <AdminNotification>[];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 4, 4),
          child: Row(children: [
            Expanded(
              child: Text('Recent notifications',
                  style: Theme.of(dialogContext).textTheme.titleLarge),
            ),
            IconButton(
              tooltip: 'Refresh notifications',
              onPressed:
                  _current && !_loading ? () => _refresh(force: true) : null,
              icon: const Icon(Icons.refresh),
            ),
            IconButton(
              tooltip: 'Close notifications',
              onPressed: () => Navigator.pop(dialogContext),
              icon: const Icon(Icons.close),
            ),
          ]),
        ),
        if (_loading) const LinearProgressIndicator(),
        if (_current && _failed.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Could not refresh ${_failed.map((kind) => kind.label.toLowerCase()).join(', ')}.',
              style:
                  TextStyle(color: Theme.of(dialogContext).colorScheme.error),
            ),
          ),
        if (notices.isEmpty && !_loading && _failed.isEmpty)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text('No notifications available'),
          ),
        if (notices.isNotEmpty)
          Flexible(
            child: ListView.separated(
              primary: false,
              shrinkWrap: true,
              itemCount: notices.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final item = notices[i];
                final unread = _unread(item);
                return ListTile(
                  leading: Icon(item.kind.icon, color: AppColors.primary),
                  title: Text(item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontWeight: unread ? FontWeight.w700 : null)),
                  subtitle: Text('${item.kind.label} · ${item.summary}',
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  trailing: unread
                      ? const Tooltip(
                          message: 'Unread',
                          child: Icon(Icons.circle,
                              size: 8, color: AppColors.primary))
                      : null,
                  onTap: () => Navigator.pop(dialogContext, item),
                );
              },
            ),
          ),
        if (notices.any(_unread))
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => _markRead(notices),
              child: const Text('Mark all as read'),
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _coach?.close();
    _feed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _feed,
        builder: (_, __) {
          final count = _current ? _notifications.where(_unread).length : 0;
          return IconButton(
            tooltip: 'Notifications',
            onPressed: _current ? _open : null,
            icon: Badge(
              isLabelVisible: count > 0,
              label: Text(count > 99 ? '99+' : '$count'),
              child: const Icon(Icons.notifications_outlined),
            ),
          );
        },
      );
}
