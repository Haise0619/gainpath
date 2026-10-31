import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_ui/gainpath_ui.dart';

/// Member-owned controls. Data never stays visible after the session changes.
/// Posture and camera privacy controls are located under Profile > Settings > Privacy & Data.
class CoachingUpdatesScreen extends StatefulWidget {
  const CoachingUpdatesScreen(
      {super.key,
      required this.repository,
      required this.isCurrent,
      this.onOpenBookings});
  final Module9Repository repository;
  final bool Function() isCurrent;
  final VoidCallback? onOpenBookings;
  @override
  State<CoachingUpdatesScreen> createState() => _CoachingUpdatesScreenState();
}

class _CoachingUpdatesScreenState extends State<CoachingUpdatesScreen> {
  final List<MemberNotice> _notices = [];
  String? _next, _error;
  bool _busy = false;
  Timer? _timer;
  StreamSubscription<void>? _updates;
  @override
  void initState() {
    super.initState();
    _load();
    _updates = widget.repository.watchInbox().listen((_) {
      if (!_busy) _load(silent: true);
    }, onError: (_) {/* Refresh remains available. */});
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!_busy) _load(silent: true);
    });
  }

  @override
  void dispose() {
    unawaited(_updates?.cancel());
    _timer?.cancel();
    super.dispose();
  }

  bool get _current => mounted && widget.isCurrent();
  Future<void> _load({bool more = false, bool silent = false}) async {
    if (!_current || _busy) return;
    setState(() {
      _busy = true;
      if (!silent) _error = null;
    });
    try {
      final page =
          await widget.repository.loadInbox(afterId: more ? _next : null);
      if (!_current) return;
      setState(() {
        if (!more) _notices.clear();
        _notices.addAll(page.records);
        _next = page.nextAfterId;
        _error = null;
      });
    } catch (_) {
      if (_current) {
        setState(
            () => _error = 'Could not load coaching updates. Please retry.');
      }
    } finally {
      if (_current) setState(() => _busy = false);
    }
  }

  Future<void> _open(MemberNotice notice) async {
    try {
      await widget.repository.markRead(notice.id);
      if (!_current) return;
      widget.onOpenBookings?.call();
      await _load();
    } catch (_) {
      if (_current) {
        showToast(context, 'Could not open this update. Please retry.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isCurrent()) {
      return const Scaffold(
          body: Center(child: Text('Session changed. Return to sign in.')));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Coaching updates'), actions: [
        IconButton(
            tooltip: 'Refresh',
            onPressed: _busy ? null : _load,
            icon: const Icon(Icons.refresh))
      ]),
      body: RefreshIndicator(
          onRefresh: _load,
          child: ListView(padding: const EdgeInsets.all(16), children: [
            Text('Session notifications',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (_error != null)
              Panel(
                  child: Column(children: [
                Text(_error!),
                TextButton(
                    onPressed: _busy ? null : _load, child: const Text('Retry'))
              ])),
            if (_busy) const LinearProgressIndicator(),
            if (!_busy && _notices.isEmpty && _error == null)
              const Panel(
                  child: Text(
                      'No coaching updates yet. Cancellation notices will appear here.')),
            ..._notices.map((n) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Panel(
                    padding: EdgeInsets.zero,
                    child: ListTile(
                      leading: Icon(n.read
                          ? Icons.mark_email_read_outlined
                          : Icons.mark_email_unread_outlined),
                      title: Text(n.title),
                      subtitle: Text('${n.message}\n${n.createdAt.toLocal()}'),
                      isThreeLine: true,
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _open(n),
                    )))),
            if (_next != null)
              TextButton(
                  onPressed: _busy ? null : () => _load(more: true),
                  child: const Text('Load earlier updates')),
          ])),
    );
  }
}
