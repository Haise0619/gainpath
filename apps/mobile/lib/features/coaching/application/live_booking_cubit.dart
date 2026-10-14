import 'dart:math';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/gainpath_domain.dart';

class LiveBookingState {
  const LiveBookingState(
      {this.options,
      this.intent,
      this.hold,
      this.busy = false,
      this.uncertain = false,
      this.message});
  final BookingOptionsContext? options;
  final CreateBookingHoldRequest? intent;
  final BookingHold? hold;
  final bool busy, uncertain;
  final String? message;
}

class LiveBookingCubit extends Cubit<LiveBookingState> {
  LiveBookingCubit(
      {required this.options,
      required this.writer,
      required this.coachId,
      required this.isCurrent,
      String Function()? requestId})
      : _requestId = requestId ?? _newId,
        super(const LiveBookingState());
  final MemberBookingOptionsRepository options;
  final BookingRepository writer;
  final String coachId;
  final bool Function() isCurrent;
  final String Function() _requestId;
  int _generation = 0;
  static String _newId() {
    final random = Random.secure();
    return List.generate(
            24, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'))
        .join();
  }

  bool _current(int generation) {
    if (isClosed) return false;
    if (!isCurrent()) {
      _generation++;
      emit(const LiveBookingState(
          message: 'Bookings unavailable for this session.'));
      return false;
    }
    return generation == _generation;
  }

  Future<void> refresh({String? localDate, int? durationMinutes}) async {
    if (state.busy || state.uncertain || !_current(_generation)) return;
    final generation = ++_generation;
    final duration = durationMinutes ?? state.options?.durationMinutes ?? 30;
    final date = localDate ?? state.options?.localDate;
    emit(const LiveBookingState(busy: true));
    try {
      final result = await options.load(
          coachId: coachId, localDate: date, durationMinutes: duration);
      if (_current(generation)) emit(LiveBookingState(options: result));
    } catch (error) {
      if (_current(generation)) emit(LiveBookingState(message: _safe(error)));
    }
  }

  void select(BookingOption option) {
    if (state.busy ||
        state.uncertain ||
        state.hold != null ||
        !_current(_generation)) {
      return;
    }
    final context = state.options;
    if (context == null || !context.options.contains(option)) return;
    if (state.intent?.startAt == option.startAt &&
        state.intent?.branchId.value == option.branchId &&
        state.intent?.durationMinutes == context.durationMinutes) {
      return;
    }
    final scope = options.scope;
    emit(LiveBookingState(
        options: context,
        intent: CreateBookingHoldRequest(
            requestId: _requestId(),
            organizationId: OrganizationId(scope.organizationId),
            memberId: UserId(scope.userId),
            coachId: UserId(coachId),
            branchId: BranchId(option.branchId),
            startAt: option.startAt,
            durationMinutes: context.durationMinutes)));
  }

  Future<void> submit() async {
    if (state.busy ||
        state.hold != null ||
        state.intent == null ||
        !_current(_generation)) {
      return;
    }
    final generation = ++_generation;
    final intent = state.intent!;
    final context = state.options;
    final wasUncertain = state.uncertain;
    emit(LiveBookingState(
        options: context,
        intent: intent,
        busy: true,
        uncertain: state.uncertain));
    try {
      final hold = await writer.createHold(intent);
      if (_current(generation)) {
        emit(LiveBookingState(options: context, intent: intent, hold: hold));
      }
    } catch (error) {
      if (!_current(generation)) return;
      final code = error is BookingException ? error.code : 'unknown';
      if (!wasUncertain && {'aborted', 'resource-exhausted'}.contains(code)) {
        emit(LiveBookingState(options: context, message: _safe(error)));
        await refresh();
        if (_current(_generation)) {
          emit(LiveBookingState(
              options: state.options,
              message: 'Availability changed. Select a time again.'));
        }
      } else {
        // Only explicit pre-write rejections are certain. Malformed replies and
        // transport failures may follow a committed write: preserve the intent.
        final uncertain = wasUncertain ||
            !{
              'permission-denied',
              'unauthenticated',
              'invalid-argument',
              'failed-precondition',
              'app-check-unavailable'
            }.contains(code);
        emit(LiveBookingState(
            options: context,
            intent: intent,
            uncertain: uncertain,
            message: _safe(error)));
      }
    }
  }

  /// Caller must first show the warning that the original hold may still exist.
  void discardUncertainIntent() {
    if (state.busy || !_current(_generation)) return;
    _generation++;
    emit(LiveBookingState(
        options: state.options,
        message:
            'Intent discarded here. Any existing hold remains unchanged. Refresh My bookings.'));
  }

  static String _safe(Object error) => error is BookingException
      ? error.message
      : const BookingException('unknown').message;
}

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
            ? 'Pending hold — time elapsed; expiry processing unavailable.'
            : 'Pending hold — not a paid reservation.'
        : record.rawStatus;
