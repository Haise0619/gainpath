import 'package:flutter/material.dart';
import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_domain/gainpath_domain.dart'
    show
        SessionScope,
        BookingListRepository,
        PersistedBookingRecord,
        BookingCursor;
import 'earnings_screen.dart';

class LiveCoachEarningsView extends StatefulWidget {
  const LiveCoachEarningsView({
    super.key,
    required this.scope,
    required this.isCurrent,
    required this.coachId,
    required this.bookingListRepo,
    required this.bookingMapper,
    this.performance,
    this.exportPdf,
  });

  final SessionScope scope;
  final Module9Repository? performance;
  final Future<bool> Function(List<String>)? exportPdf;
  final bool Function() isCurrent;
  final String coachId;
  final BookingListRepository bookingListRepo;
  final Booking Function(PersistedBookingRecord) bookingMapper;

  @override
  State<LiveCoachEarningsView> createState() => _LiveCoachEarningsViewState();
}

class _LiveCoachEarningsViewState extends State<LiveCoachEarningsView> {
  bool _loading = true;
  String? _error;
  List<Booking> _bookings = [];
  CoachReport? _report;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted || !widget.isCurrent()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (widget.performance != null) {
        final report = await widget.performance!.loadPerformance();
        if (!mounted || !widget.isCurrent()) return;
        setState(() {
          _report = report;
          _bookings = report.sessions.map((s) => s.booking).toList();
          _loading = false;
        });
        return;
      }
      final now = DateTime.now();
      final thirtyDaysAgo = now.subtract(const Duration(days: 30));
      final dateStr =
          '${thirtyDaysAgo.year}-${thirtyDaysAgo.month.toString().padLeft(2, '0')}-${thirtyDaysAgo.day.toString().padLeft(2, '0')}';

      final list = <Booking>[];
      BookingCursor? cursor;
      final seen = <String>{};
      do {
        final page = await widget.bookingListRepo.load(
          coachId: widget.coachId,
          firstLocalDate: dateStr,
          cursor: cursor,
        );
        if (!mounted || !widget.isCurrent()) return;
        list.addAll(page.records.map(widget.bookingMapper));
        cursor = page.nextCursor;
        if (cursor != null &&
            !seen.add('${cursor.startAtMillis}:${cursor.bookingId}')) {
          throw StateError('Unable to load complete report. Please retry.');
        }
      } while (cursor != null);
      setState(() {
        _bookings = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || !widget.isCurrent()) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Performance')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Performance')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Unable to load performance data: $_error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _load,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return EarningsScreen(
      connected: true,
      bookings: _bookings,
      rating: _report?.averageRating,
      reviews: _report?.reviewCount,
      report: _report,
      exportPdf: widget.exportPdf,
    );
  }
}
