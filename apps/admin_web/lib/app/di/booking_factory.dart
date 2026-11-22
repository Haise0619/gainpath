import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_identity/gainpath_identity.dart';
import '../../features/coaching/presentation/admin/booking_list_view.dart';
import '../../infrastructure/firebase/firebase_data_scope.dart';
import 'catalog_edit_session_guard.dart';

class AdminBookingListRoute extends StatefulWidget {
  const AdminBookingListRoute(
      {super.key,
      required this.session,
      required this.repository,
      this.coachId,
      this.branchId,
      this.bookingId,
      this.loadBranches});
  final AuthSession session;
  final BookingListRepository repository;
  final String? coachId;
  final String? branchId;
  final String? bookingId;
  final Future<Map<String, ({String name, bool active})>> Function()?
      loadBranches;
  @override
  State<AdminBookingListRoute> createState() => _AdminBookingListRouteState();
}

class _AdminBookingListRouteState extends State<AdminBookingListRoute> {
  CatalogEditSessionGuard? guard;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (guard != null) return;
    final auth = context.read<AuthBloc>();
    guard = CatalogEditSessionGuard(
        expected: widget.session,
        current: () => auth.state,
        changes: auth.stream);
  }

  @override
  void dispose() {
    guard?.dispose();
    super.dispose();
  }

  Future<AdminBookingFocus> _loadBooking() async {
    final id = widget.bookingId!;
    final sessionGuard = guard!;
    if (!sessionGuard.isCurrent() ||
        !RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(id)) {
      throw const BookingException('permission-denied');
    }
    final scope = widget.session.scope;
    final organization = FirebaseFirestore.instance.scopeRoot(scope);
    final snapshot = await organization
        .collection('bookings')
        .doc(id)
        .get(const GetOptions(source: Source.server));
    if (!sessionGuard.isCurrent()) {
      throw const BookingException('permission-denied');
    }
    final data = snapshot.data();
    if (data == null ||
        data['bookingId'] != id ||
        data['organizationId'] != scope.organizationId ||
        (widget.coachId != null && data['coachId'] != widget.coachId) ||
        (widget.branchId != null && data['branchId'] != widget.branchId)) {
      throw const BookingException('not-found');
    }

    final record = PersistedBookingRecord.fromJson({
      ...data,
      'startLabel': _malaysiaTime(data['startAtMillis'] as int),
      'endLabel': _malaysiaTime(data['endAtMillis'] as int),
      'expiryLabel':
          _malaysiaTime(data['holdExpiresAtMillis'] as int, date: true),
    }..remove('createdBy'));
    final names = await Future.wait([
      () async {
        try {
          final directory = await widget.loadBranches?.call();
          return directory?[record.branchId]?.name;
        } catch (_) {
          return null;
        }
      }(),
      () async {
        try {
          final coach = await organization
              .collection('coaches')
              .doc(record.coachId)
              .get(const GetOptions(source: Source.server));
          final name = coach.data()?['displayName'];
          return name is String && name.trim().isNotEmpty ? name.trim() : null;
        } catch (_) {
          return null;
        }
      }(),
    ]);
    if (!sessionGuard.isCurrent()) {
      throw const BookingException('permission-denied');
    }
    return (booking: record, branchName: names[0], coachName: names[1]);
  }

  String _malaysiaTime(int millis, {bool date = false}) {
    final local = DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true)
        .add(const Duration(hours: 8))
        .toIso8601String();
    final time = '${local.substring(11, 16)} MYT';
    return date ? '${local.substring(0, 10)} $time' : time;
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) => guard!.isCurrent()
          ? AdminBookingListView(
              repository: widget.repository,
              coachId: widget.coachId,
              branchId: widget.branchId,
              loadFocusedBooking:
                  widget.bookingId == null ? null : _loadBooking,
              isCurrent: guard!.isCurrent)
          : const Scaffold(
              body: Center(
                  child: Text('Bookings unavailable for this session.'))));
}
