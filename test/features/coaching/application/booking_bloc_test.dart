import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath/features/coaching/application/booking_bloc.dart';
import 'package:gainpath/features/coaching/domain/entities/booking.dart';
import 'package:gainpath/features/coaching/domain/enums/booking_status.dart';
import 'package:gainpath/features/coaching/domain/repositories/booking_repository.dart';

/// Isolated in-memory repository so tests never touch the shared seeds.
class _FakeBookingRepository implements BookingRepository {
  _FakeBookingRepository(this.memberName, this.coachName, this.allBookings);
  final String memberName;
  final String coachName;
  @override
  final List<Booking> allBookings;
  @override
  List<Booking> get memberBookings => allBookings.where((b) => b.memberName == memberName).toList();
  @override
  List<Booking> get coachRoster => allBookings.where((b) => b.coachName == coachName).toList();
}

Booking _booking(String id, {BookingStatus status = BookingStatus.confirmed, int daysAhead = 2}) => Booking(
      id: id,
      coachId: 'c1',
      coachName: 'Jason Lim',
      memberName: 'ZhengYang',
      start: DateTime.now().add(Duration(days: daysAhead)),
      branch: 'Fury Fitness KL',
      status: status,
      fee: 120,
    );

void main() {
  late _FakeBookingRepository repo;

  setUp(() {
    repo = _FakeBookingRepository('ZhengYang', 'Jason Lim', [
      _booking('b1'),
      _booking('b2', status: BookingStatus.completed, daysAhead: -3),
    ]);
  });

  blocTest<BookingBloc, BookingState>(
    'BookingsRequested splits member bookings by status',
    build: () => BookingBloc(repo),
    act: (bloc) => bloc.add(const BookingsRequested()),
    verify: (bloc) {
      expect(bloc.state.memberUpcoming.map((b) => b.id), ['b1']);
      expect(bloc.state.memberCompleted.map((b) => b.id), ['b2']);
      expect(bloc.state.memberCancelled, isEmpty);
      expect(bloc.state.coachRoster.length, 2);
    },
  );

  blocTest<BookingBloc, BookingState>(
    'BookingCreated adds to the repository and to upcoming',
    build: () => BookingBloc(repo),
    act: (bloc) => bloc.add(BookingCreated(_booking('b3', daysAhead: 5))),
    verify: (bloc) {
      expect(repo.allBookings.length, 3);
      expect(bloc.state.memberUpcoming.map((b) => b.id), ['b1', 'b3']);
    },
  );

  blocTest<BookingBloc, BookingState>(
    'BookingCancelled moves a session out of upcoming and records the reason',
    build: () => BookingBloc(repo),
    act: (bloc) => bloc.add(const BookingCancelled('b1', 'Member requested.')),
    verify: (bloc) {
      expect(bloc.state.memberUpcoming, isEmpty);
      expect(bloc.state.memberCancelled.single.cancellationReason, 'Member requested.');
    },
  );

  blocTest<BookingBloc, BookingState>(
    'BookingRescheduled changes the start time',
    build: () => BookingBloc(repo),
    act: (bloc) => bloc.add(BookingRescheduled('b1', DateTime(2030, 1, 1, 9))),
    verify: (bloc) => expect(bloc.state.memberUpcoming.single.start, DateTime(2030, 1, 1, 9)),
  );

  blocTest<BookingBloc, BookingState>(
    'BookingNotesPublished completes the session with notes',
    build: () => BookingBloc(repo),
    act: (bloc) => bloc.add(const BookingNotesPublished('b1', 'Great squat depth.')),
    verify: (bloc) {
      final b = bloc.state.memberCompleted.firstWhere((b) => b.id == 'b1');
      expect(b.notes, 'Great squat depth.');
      expect(b.status, BookingStatus.completed);
    },
  );

  blocTest<BookingBloc, BookingState>(
    'every mutation bumps the revision so listeners rebuild',
    build: () => BookingBloc(repo),
    act: (bloc) => bloc
      ..add(const BookingsRequested())
      ..add(const BookingRated('b2'))
      ..add(const BookingMessageSent('b1', senderRole: 'Member', text: 'See you then')),
    verify: (bloc) {
      expect(bloc.state.revision, 3);
      expect(repo.allBookings.firstWhere((b) => b.id == 'b2').rated, isTrue);
      expect(repo.allBookings.firstWhere((b) => b.id == 'b1').messages.single.text, 'See you then');
    },
  );
}
