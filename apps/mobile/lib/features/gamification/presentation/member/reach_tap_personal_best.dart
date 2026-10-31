import 'package:flutter/material.dart';
import 'package:gainpath_domain/gamification.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../domain/reach_tap_ports.dart';

/// Reach & Tap's existing account-scoped aggregate store, never another game.
class ReachTapPersonalBest extends StatefulWidget {
  const ReachTapPersonalBest(
      {super.key, this.reader, this.store, this.revision = 0});
  final MiniGameContentReader? reader;
  final ReachTapHistoryStore? store;
  final int revision;
  @override
  State<ReachTapPersonalBest> createState() => _ReachTapPersonalBestState();
}

class _ReachTapPersonalBestState extends State<ReachTapPersonalBest> {
  int? _best;
  bool _loading = false;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ReachTapPersonalBest oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.reader, oldWidget.reader) ||
        !identical(widget.store, oldWidget.store) ||
        widget.revision != oldWidget.revision) {
      _load();
    }
  }

  Future<void> _load() async {
    final reader = widget.reader,
        store = widget.store,
        generation = ++_generation;
    _best = null;
    _loading = reader != null && reader.current && store != null;
    if (!_loading) return;
    int? best;
    try {
      best = (await store!.load(reader!.scope)).bestScore;
    } catch (_) {/* Unavailable, never a synthetic zero. */}
    if (!mounted || generation != _generation || !reader!.current) return;
    setState(() {
      _best = best;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) => widget.reader != null &&
          !widget.reader!.current
      ? const SizedBox.shrink()
      : Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.hairline),
              borderRadius: BorderRadius.circular(18)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.emoji_events_outlined, color: AppColors.primary),
            const SizedBox(height: 10),
            Text(
                _loading
                    ? 'Personal best · Loading…'
                    : _best == null
                        ? 'Personal best · Unavailable'
                        : 'Personal best · $_best',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            const Text('On this device · Reach & Tap Game Score'),
          ]));
}
