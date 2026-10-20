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

    emit(AdminReportingState(query: query, isLoading: true));

    try {
      final result = await gateway.load(query);
      if (isClosed || _generation != currentGen) return;
      if (result.query != query) {
        throw const FormatException('Reporting query mismatch');
      }
      emit(AdminReportingState(query: query, snapshot: result));
    } catch (_) {
      if (isClosed || _generation != currentGen) return;
      emit(AdminReportingState(
        query: query,
        errorMessage:
            'Could not load reports. Check your connection and retry.',
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
