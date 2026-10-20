import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/gainpath_domain.dart';

class BookingListState {
  const BookingListState(
      {this.page, this.records = const [], this.busy = false, this.message});
  final BookingPage? page;
  final List<PersistedBookingRecord> records;
  final bool busy;
  final String? message;
}

class BookingListCubit extends Cubit<BookingListState> {
  BookingListCubit(
      {required this.repository, required this.isCurrent, this.coachId})
      : super(const BookingListState());
  final BookingListRepository repository;
  final bool Function() isCurrent;
  final String? coachId;
  int _generation = 0;
  bool _current(int generation) {
    if (isClosed) return false;
    if (!isCurrent()) {
      _generation++;
      emit(const BookingListState(
          message: 'Bookings unavailable for this session.'));
      return false;
    }
    return generation == _generation;
  }

  Future<void> refresh() => _load(false);
  Future<void> loadMore() => _load(true);
  Future<void> _load(bool more) async {
    if (state.busy ||
        !_current(_generation) ||
        (more && state.page?.nextCursor == null)) {
      return;
    }
    final generation = ++_generation;
    final previous = state;
    emit(BookingListState(
        page: more ? previous.page : null,
        records: more ? previous.records : const [],
        busy: true));
    try {
      final page = await repository.load(
          coachId: coachId,
          firstLocalDate: more ? previous.page!.firstLocalDate : null,
          cursor: more ? previous.page!.nextCursor : null);
      if (_current(generation)) {
        emit(BookingListState(
            page: page,
            records: List.unmodifiable(
                [if (more) ...previous.records, ...page.records])));
      }
    } catch (error) {
      if (_current(generation)) {
        emit(BookingListState(
            message: error is BookingException
                ? error.message
                : const BookingException('unknown').message));
      }
    }
  }
}

String bookingStatusLabel(PersistedBookingRecord record, int serverNowMillis) =>
    record.status == BookingStatus.pendingHold
        ? serverNowMillis >= record.holdExpiresAtMillis
            ? 'Pending hold — time elapsed; awaiting server expiry.'
            : 'Pending hold — not a paid reservation.'
        : record.rawStatus;
