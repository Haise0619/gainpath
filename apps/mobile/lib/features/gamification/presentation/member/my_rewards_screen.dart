import 'package:flutter/material.dart';
import 'package:gainpath_domain/gamification.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../application/rewards_feature_host.dart';
import 'reward_details.dart';
import 'voucher_screen.dart';

class MyRewardsScreen extends StatelessWidget {
  const MyRewardsScreen({super.key, this.repository});
  final VerifiedRewardsRepository? repository;
  @override
  Widget build(BuildContext context) => repository == null
      ? RewardsFeatureHost(builder: (repo) => _MyRewardsView(repository: repo))
      : RewardsRepositoryGuard(
          repository: repository!,
          child: _MyRewardsView(repository: repository!));
}

class _MyRewardsView extends StatefulWidget {
  const _MyRewardsView({required this.repository});
  final VerifiedRewardsRepository repository;
  @override
  State<_MyRewardsView> createState() => _MyRewardsViewState();
}

class _MyRewardsViewState extends State<_MyRewardsView>
    with WidgetsBindingObserver {
  final _rows = <VerifiedRewardRedemption>[];
  String _filter = 'Available';
  String? _cursor, _error;
  bool _loading = true;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.repository.current) {
      _load();
    }
  }

  Future<void> _load({bool more = false}) async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
      if (!more) {
        _rows.clear();
        _cursor = null;
      }
    });
    if (!widget.repository.current) {
      setState(() => _loading = false);
      return;
    }
    try {
      final page =
          await widget.repository.history(afterId: more ? _cursor : null);
      if (!mounted || generation != _generation || !widget.repository.current) {
        return;
      }
      setState(() {
        _rows.addAll(page.redemptions);
        _cursor = page.nextCursor;
      });
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() => _error =
            'Your rewards could not load. Refresh to check current status.');
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _open(VerifiedRewardRedemption row) async {
    if (!widget.repository.current) return;
    await Navigator.push(
        context,
        MaterialPageRoute<void>(
            builder: (_) =>
                VoucherScreen(redemption: row, repository: widget.repository)));
    if (mounted && widget.repository.current) await _load();
  }

  @override
  void dispose() {
    ++_generation;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('My Rewards'), actions: [
        IconButton(
            tooltip: 'Refresh my rewards',
            onPressed: () => _load(),
            icon: const Icon(Icons.refresh_rounded)),
      ]),
      body: !widget.repository.current
          ? const Center(child: Text('Rewards unavailable for this session.'))
          : SafeArea(
              child: RefreshIndicator(
                  onRefresh: () => _load(),
                  child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                      children: [
                        const Text('Your saved rewards',
                            style: TextStyle(
                                fontSize: 24, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        const Text(
                            'Open a voucher to check its current collection status. Issued rewards keep their saved terms until expiry.'),
                        const SizedBox(height: 16),
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          for (final label in ['Available', 'Used', 'Expired'])
                            ChoiceChip(
                                label: Text(label),
                                selected: _filter == label,
                                onSelected: (_) =>
                                    setState(() => _filter = label))
                        ]),
                        const SizedBox(height: 16),
                        if (_loading && _rows.isEmpty)
                          const Center(child: CircularProgressIndicator()),
                        if (_error != null)
                          Panel(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(_error!),
                                TextButton(
                                    onPressed: () =>
                                        _load(more: _rows.isNotEmpty),
                                    child: const Text('Retry'))
                              ])),
                        if (!_loading &&
                            _error == null &&
                            !_rows.any((r) => r.statusLabel == _filter))
                          Panel(
                              child: Text(
                                  'No ${_filter.toLowerCase()} rewards in the loaded history.')),
                        for (final row
                            in _rows.where((r) => r.statusLabel == _filter))
                          Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Panel(
                                  onTap: () => _open(row),
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Icon(
                                                  Icons
                                                      .confirmation_number_outlined,
                                                  color: AppColors.primary),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                  child: Text(row.title,
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .titleMedium)),
                                              const Icon(
                                                  Icons.chevron_right_rounded)
                                            ]),
                                        const SizedBox(height: 10),
                                        Text(
                                            '${row.points} points spent · ${row.statusLabel}'),
                                        const SizedBox(height: 6),
                                        Text(row.expiresAtMillis == null
                                            ? 'Expiry not recorded — check with reception.'
                                            : 'Expires ${rewardDate(row.expiresAtMillis!)}'),
                                      ]))),
                        if (_cursor != null)
                          OutlinedButton(
                              onPressed:
                                  _loading ? null : () => _load(more: true),
                              child: Text(_loading ? 'Loading…' : 'Load more')),
                      ]))));
}
