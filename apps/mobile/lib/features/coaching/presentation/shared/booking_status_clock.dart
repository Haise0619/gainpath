import 'dart:async';
import 'package:flutter/material.dart';

/// Advances a server snapshot locally at known boundaries. Never fetches data.
/// A new server snapshot reanchors the clock; backward phone-clock changes do
/// not affect the monotonic elapsed time. Optional elapsed source is for tests.
class BookingStatusClock extends StatefulWidget {
  const BookingStatusClock(
      {super.key,
      required this.serverNowMillis,
      required this.boundaryMillis,
      required this.builder,
      this.elapsedMillis});
  final int? serverNowMillis;
  final List<int> boundaryMillis;
  final Widget Function(BuildContext context, int nowMillis) builder;
  final int Function()? elapsedMillis;
  @override
  State<BookingStatusClock> createState() => _BookingStatusClockState();
}

class _BookingStatusClockState extends State<BookingStatusClock> {
  final _elapsed = Stopwatch();
  Timer? _boundary;
  late int _anchor;
  int get _now =>
      _anchor + (widget.elapsedMillis?.call() ?? _elapsed.elapsedMilliseconds);
  @override
  void initState() {
    super.initState();
    _reset();
  }

  void _reset() {
    _anchor = widget.serverNowMillis ?? DateTime.now().millisecondsSinceEpoch;
    _elapsed
      ..reset()
      ..start();
    _schedule();
  }

  @override
  void didUpdateWidget(covariant BookingStatusClock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.serverNowMillis != oldWidget.serverNowMillis) {
      _reset();
    } else {
      _schedule();
    }
  }

  void _schedule() {
    _boundary?.cancel();
    final now = _now;
    final upcoming =
        widget.boundaryMillis.where((epoch) => epoch > now).toList()..sort();
    if (upcoming.isEmpty) return;
    // Bound timer delays and re-evaluate after distant deadlines without IO.
    final delay = (upcoming.first - now).clamp(1, 2147483647);
    _boundary = Timer(Duration(milliseconds: delay), () {
      if (!mounted) return;
      setState(() {});
      _schedule();
    });
  }

  @override
  void dispose() {
    _boundary?.cancel();
    _elapsed.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _now);
}
