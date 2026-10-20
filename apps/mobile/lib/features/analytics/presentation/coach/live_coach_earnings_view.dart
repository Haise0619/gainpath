import 'package:flutter/material.dart';
import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_domain/gainpath_domain.dart'
    show SessionScope, BookingListRepository, PersistedBookingRecord;
import 'earnings_screen.dart';

class LiveCoachEarningsView extends StatefulWidget {
  const LiveCoachEarningsView({
    super.key,
    required this.scope,
    required this.isCurrent,
    required this.coachId,
    required this.bookingListRepo,
    required this.bookingMapper,
  });

  final SessionScope scope;
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
      final now = DateTime.now();
      final thirtyDaysAgo = now.subtract(const Duration(days: 30));
      final dateStr =
          '${thirtyDaysAgo.year}-${thirtyDaysAgo.month.toString().padLeft(2, '0')}-${thirtyDaysAgo.day.toString().padLeft(2, '0')}';

      final page = await widget.bookingListRepo.load(
        coachId: widget.coachId,
        firstLocalDate: dateStr,
      );

      if (!mounted || !widget.isCurrent()) return;

      final list = page.records.map(widget.bookingMapper).toList();
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
      rating: null,
      reviews: null,
    );
  }
}
