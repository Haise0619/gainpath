import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gainpath_domain/gamification.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../application/app_check_in_cubit.dart';
import '../../application/rewards_feature_host.dart';
import 'points_history_screen.dart';
import 'reward_details.dart';

/// The live member page; opening it only reads data. Claims remain explicit.
class RewardsCheckInPage extends StatefulWidget {
  const RewardsCheckInPage(
      {super.key,
      required this.repository,
      required this.checkIn,
      required this.refreshCheckIn,
      required this.claimCheckIn,
      this.now});
  final VerifiedRewardsRepository repository;
  final AppCheckInState checkIn;
  final Future<void> Function() refreshCheckIn, claimCheckIn;
  final DateTime Function()? now;
  @override
  State<RewardsCheckInPage> createState() => _RewardsCheckInPageState();
}

class _RewardsCheckInPageState extends State<RewardsCheckInPage>
    with WidgetsBindingObserver {
  PointsHistorySnapshot? _data;
  int? _balance;
  Future<void>? _pending;
  String? _error;
  int _generation = 0;
  bool _foreground = true, _claiming = false, _historyOpen = false;
  late DateTime _asOf;
  @override
  void initState() {
    super.initState();
    _asOf = (widget.now ?? DateTime.now)();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_load());
  }

  @override
  void didUpdateWidget(RewardsCheckInPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.repository.current) {
      ++_generation;
      _data = null;
      _balance = null;
      _error = null;
    }
  }

  Future<void> _load() {
    if (_pending != null) return _pending!;
    if (!_foreground || !widget.repository.current) return Future.value();
    final repo = widget.repository, generation = ++_generation;
    return _pending = Future<void>.microtask(() => _fetch(repo, generation));
  }

  Future<void> _fetch(VerifiedRewardsRepository repo, int generation) async {
    try {
      final data = await repo.pointsHistory();
      if (!mounted ||
          generation != _generation ||
          !repo.current ||
          !widget.repository.current ||
          !_foreground) {
        return;
      }
      setState(() {
        _data = data;
        _balance = data.balance;
        _asOf = (widget.now ?? DateTime.now)();
        _error = null;
      });
    } catch (_) {
      if (!mounted ||
          generation != _generation ||
          !repo.current ||
          !widget.repository.current ||
          !_foreground) {
        return;
      }
      // Receipt retention/coverage failures must not hide a usable wallet.
      // This established overview endpoint reads the independent live balance.
      int? confirmedBalance;
      try {
        final overview = await repo.overview();
        if (overview.available) confirmedBalance = overview.balance;
      } catch (_) {/* Keep useful previously loaded values when offline. */}
      if (mounted &&
          generation == _generation &&
          repo.current &&
          widget.repository.current &&
          _foreground) {
        setState(() {
          if (confirmedBalance != null) _balance = confirmedBalance;
          _error = confirmedBalance != null
              ? 'Receipt activity could not refresh. Your available balance is confirmed separately; previously loaded receipts may be out of date.'
              : _data == null
                  ? 'Points could not load. Connect and try again.'
                  : 'Could not refresh points. Showing your last loaded balance and receipts.';
        });
      }
    } finally {
      _pending = null;
      if (mounted) setState(() {});
    }
  }

  Future<void> _refresh() async {
    if (!mounted || !_foreground || !widget.repository.current) return;
    final points = _load();
    setState(() {});
    await Future.wait([points, widget.refreshCheckIn()]);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) {
      ++_generation;
    } else {
      final pending = _pending;
      if (pending == null) {
        unawaited(_refresh());
      } else {
        unawaited(pending.then((_) {
          if (mounted && _foreground) return _refresh();
        }));
      }
    }
  }

  Future<void> _claim() async {
    if (_claiming ||
        widget.checkIn.claiming ||
        widget.checkIn.snapshot?.claimedToday == true ||
        !widget.repository.current ||
        !_foreground) {
      return;
    }
    setState(() => _claiming = true);
    try {
      await widget.claimCheckIn();
      if (mounted && widget.repository.current && _foreground) {
        await _pending;
        if (mounted && widget.repository.current && _foreground) await _load();
      }
    } finally {
      if (mounted) setState(() => _claiming = false);
    }
  }

  Future<void> _history() async {
    if (_historyOpen || !widget.repository.current) return;
    setState(() => _historyOpen = true);
    try {
      await Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => PointsHistoryScreen(repository: widget.repository)));
      if (mounted) await _refresh();
    } finally {
      if (mounted) setState(() => _historyOpen = false);
    }
  }

  @override
  void dispose() {
    ++_generation;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Widget _surface(Widget child, {Color? color}) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: color ?? Colors.white,
          borderRadius: BorderRadius.circular(22)),
      child: child);
  Widget _heading(String title) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(title,
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.w700)));
  @override
  Widget build(BuildContext context) {
    final data = _data, checkIn = widget.checkIn, snapshot = checkIn.snapshot;
    final local = _asOf.toUtc().add(const Duration(hours: 8));
    final start = DateTime.utc(local.year, local.month, local.day)
        .subtract(const Duration(days: 29, hours: 8));
    final entries = data?.entries
            .where((e) =>
                e.wallet == 'spendable' &&
                e.occurredAtMillis >= start.millisecondsSinceEpoch &&
                e.occurredAtMillis <= _asOf.millisecondsSinceEpoch)
            .toList() ??
        [];
    final earned =
        entries.where((e) => e.points > 0).fold(0, (int n, e) => n + e.points);
    final spent =
        entries.where((e) => e.points < 0).fold(0, (int n, e) => n - e.points);
    final current = widget.repository.current, busy = _pending != null;
    final todayKnown = snapshot != null &&
        checkIn.status == AppCheckInStatus.ready &&
        _foreground;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 180);
    return RewardsRepositoryGuard(
        repository: widget.repository,
        child: Scaffold(
            backgroundColor: AppColors.bg,
            appBar: AppBar(
                toolbarHeight:
                    MediaQuery.textScalerOf(context).scale(1) > 1.4 ? 96 : 64,
                title: const Text('Rewards & Check-in', maxLines: 2),
                actions: [
                  IconButton(
                      tooltip: 'Refresh rewards and check-in',
                      onPressed:
                          !current || busy || _claiming ? null : _refresh,
                      icon: const Icon(Icons.refresh_rounded))
                ]),
            body: !current
                ? const Center(
                    child: Text('Rewards unavailable for this session.'))
                : SafeArea(
                    child: RefreshIndicator(
                        onRefresh: _refresh,
                        child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                            children: [
                              if (busy)
                                const Padding(
                                    padding: EdgeInsets.only(bottom: 12),
                                    child:
                                        LinearProgressIndicator(minHeight: 2)),
                              if (_error != null) ...[
                                _surface(Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(_error!),
                                      TextButton.icon(
                                          onPressed: busy ? null : _refresh,
                                          icon: const Icon(Icons.refresh),
                                          label: const Text('Retry'))
                                    ])),
                                const SizedBox(height: 16)
                              ],
                              _surface(
                                  Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Icon(Icons.stars_rounded,
                                            color: AppColors.primary, size: 30),
                                        const SizedBox(height: 12),
                                        const Text('Available points'),
                                        const SizedBox(height: 4),
                                        AnimatedSwitcher(
                                            duration: duration,
                                            child: Text(
                                                _balance == null
                                                    ? '—'
                                                    : '$_balance',
                                                key: ValueKey(_balance),
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .displaySmall
                                                    ?.copyWith(
                                                        color:
                                                            AppColors.primary,
                                                        fontWeight:
                                                            FontWeight.w800))),
                                        const SizedBox(height: 8),
                                        const Text(
                                            'Points currently available to use on rewards.'),
                                      ]),
                                  color: AppColors.primaryTint),
                              const SizedBox(height: 24),
                              _heading('Daily check-in'),
                              _surface(Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                        snapshot == null
                                            ? 'Check-in streak unavailable'
                                            : 'Check-in streak: ${snapshot.currentStreak} ${snapshot.currentStreak == 1 ? 'day' : 'days'}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                                fontWeight: FontWeight.w700)),
                                    if (snapshot != null) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                          'Longest check-in streak: ${snapshot.longestStreak} ${snapshot.longestStreak == 1 ? 'day' : 'days'}')
                                    ],
                                    const SizedBox(height: 12),
                                    AnimatedSwitcher(
                                        duration: duration,
                                        child: Align(
                                            key: ValueKey(
                                                '${checkIn.status}/${snapshot?.claimedToday}'),
                                            alignment: Alignment.centerLeft,
                                            child: Text(
                                                !todayKnown
                                                    ? (checkIn.message ??
                                                        'Confirming today’s check-in…')
                                                    : snapshot.claimedToday
                                                        ? 'Checked in today · ${snapshot.today}'
                                                        : 'Your daily check-in is ready.',
                                                style: const TextStyle(
                                                    color:
                                                        AppColors.inkSoft)))),
                                    if (todayKnown &&
                                        !snapshot.claimedToday) ...[
                                      const SizedBox(height: 12),
                                      SizedBox(
                                          width: double.infinity,
                                          child: FilledButton.icon(
                                              style: FilledButton.styleFrom(
                                                  minimumSize:
                                                      const Size(48, 48)),
                                              onPressed:
                                                  checkIn.claiming || _claiming
                                                      ? null
                                                      : _claim,
                                              icon: const Icon(Icons
                                                  .check_circle_outline_rounded),
                                              label: Text(checkIn.claiming ||
                                                      _claiming
                                                  ? 'Checking in…'
                                                  : 'Check in · ${snapshot.pointsPerClaim} points')))
                                    ],
                                    if (!todayKnown &&
                                        checkIn.status !=
                                            AppCheckInStatus.loading)
                                      TextButton.icon(
                                          onPressed: busy ? null : _refresh,
                                          icon: const Icon(Icons.refresh),
                                          label: const Text('Retry check-in')),
                                    if (checkIn.claiming)
                                      const LinearProgressIndicator(),
                                  ])),
                              const SizedBox(height: 24),
                              _heading('Points activity'),
                              Text('Last 30 days · Malaysia time',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                          fontSize: 12,
                                          color: AppColors.inkSoft)),
                              const SizedBox(height: 12),
                              if (data == null)
                                _surface(Text(busy
                                    ? 'Loading reward receipts…'
                                    : 'Reward receipts unavailable. Retry to load your activity.'))
                              else ...[
                                if (!data.reconciled) ...[
                                  const Text(
                                      'Receipt history is incomplete. Amounts below reflect returned receipts only; earlier earnings or spending may be missing.'),
                                  const SizedBox(height: 12)
                                ],
                                _surface(Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                          'Recorded earnings: ${earned == 0 && !data.reconciled ? 'Unavailable' : '+$earned points'}'),
                                      const SizedBox(height: 8),
                                      Text(
                                          'Recorded spending: ${spent == 0 && !data.reconciled ? 'Unavailable' : '$spent points'}'),
                                      if (entries.isEmpty) ...[
                                        const SizedBox(height: 16),
                                        Text(data.reconciled
                                            ? 'No points activity in this period.'
                                            : 'No receipts returned for this period.')
                                      ],
                                      for (final entry in entries.take(4)) ...[
                                        const Divider(
                                            height: 28,
                                            color: AppColors.hairline),
                                        Text(entry.title,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w600)),
                                        const SizedBox(height: 4),
                                        Text(
                                            '${entry.points > 0 ? 'Earned +' : 'Spent '}${entry.points.abs()} points · ${rewardDate(entry.occurredAtMillis)}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium
                                                ?.copyWith(
                                                    fontSize: 12,
                                                    color: AppColors.inkSoft))
                                      ],
                                    ])),
                              ],
                              const SizedBox(height: 16),
                              OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                      minimumSize: const Size(48, 48)),
                                  onPressed: _historyOpen ? null : _history,
                                  icon: const Icon(Icons.receipt_long_outlined),
                                  label: const Text('View reward history')),
                            ])))));
  }
}
