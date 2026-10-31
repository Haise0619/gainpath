import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'admin_reporting_gateway.dart';

@immutable
class AdminReportingState {
  final AdminReportQuery query;
  final AdminReportingSnapshot? snapshot;
  final bool isLoading;
  final String? errorMessage;

  const AdminReportingState({
    required this.query,
    this.snapshot,
    this.isLoading = false,
    this.errorMessage,
  });

  AdminReportingState copyWith({
    AdminReportQuery? query,
    AdminReportingSnapshot? snapshot,
    bool? isLoading,
    String? errorMessage,
    bool clearSnapshot = false,
  }) =>
      AdminReportingState(
        query: query ?? this.query,
        snapshot: clearSnapshot ? null : snapshot ?? this.snapshot,
        isLoading: isLoading ?? this.isLoading,
        errorMessage: errorMessage,
      );
}

class AdminReportingCubit extends Cubit<AdminReportingState> {
  final AdminReportingGateway gateway;
  int _generation = 0;

  AdminReportingCubit({
    required this.gateway,
    AdminReportQuery? initialQuery,
  }) : super(AdminReportingState(
          query: initialQuery ??
              AdminReportQuery(
                range: DateTimeRange(
                  start: DateTime.now().subtract(const Duration(days: 7)),
                  end: DateTime.now(),
                ),
              ),
        ));

  Future<void> load([AdminReportQuery? targetQuery]) async {
    if (isClosed) return;
    final query = targetQuery ?? state.query;
    final currentGen = ++_generation;

    final retained = query == state.query &&
            (gateway is! AdminReportingSessionGuard ||
                (gateway as AdminReportingSessionGuard).canRetainSnapshot)
        ? state.snapshot
        : null;
    emit(
        AdminReportingState(query: query, snapshot: retained, isLoading: true));

    try {
      final result = await gateway.load(query);
      if (isClosed || _generation != currentGen) return;
      if (gateway is AdminReportingSessionGuard &&
          !(gateway as AdminReportingSessionGuard).canRetainSnapshot) {
        throw StateError('Reporting account changed');
      }
      if (result.query != query) {
        throw const FormatException('Reporting query mismatch');
      }
      emit(AdminReportingState(query: query, snapshot: result));
    } catch (error) {
      if (isClosed || _generation != currentGen) return;
      emit(AdminReportingState(
        query: query,
        snapshot: (gateway is AdminReportingSessionGuard &&
                    !(gateway as AdminReportingSessionGuard)
                        .canRetainSnapshot) ||
                (error is AdminReportingException &&
                    error.invalidatesSnapshot) ||
                error is StateError ||
                error is FormatException
            ? null
            : retained,
        errorMessage: error is AdminReportingException
            ? error.message
            : error is StateError
                ? 'Your reporting session changed. Sign in again.'
                : error is FormatException
                    ? 'The report response could not be validated. Retry or request a source review.'
                    : 'Reports are temporarily unavailable. Check your connection and retry.',
      ));
    }
  }

  void setRange(DateTimeRange newRange) {
    if (state.query.range == newRange) return;
    load(AdminReportQuery(range: newRange, branchId: state.query.branchId));
  }

  void setBranch(String? branchId) {
    if (state.query.branchId == branchId) return;
    load(AdminReportQuery(range: state.query.range, branchId: branchId));
  }

  void refresh() {
    load();
  }

  @override
  Future<void> close() {
    _generation++;
    return super.close();
  }
}
