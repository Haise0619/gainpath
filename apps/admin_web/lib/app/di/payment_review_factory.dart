import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_identity/gainpath_identity.dart';
import '../../features/membership/payment_review_repository.dart';
import '../../features/membership/presentation/admin/refunds_screen.dart';
import 'catalog_edit_session_guard.dart';

class AdminPaymentReviewRoute extends StatefulWidget {
  const AdminPaymentReviewRoute({super.key, required this.session});
  final AuthSession session;
  @override
  State<AdminPaymentReviewRoute> createState() =>
      _AdminPaymentReviewRouteState();
}

class _AdminPaymentReviewRouteState extends State<AdminPaymentReviewRoute> {
  CatalogEditSessionGuard? _guard;
  PaymentReviewRepository? _repository;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_guard != null) return;
    final auth = context.read<AuthBloc>();
    final guard = CatalogEditSessionGuard(
        expected: widget.session,
        current: () => auth.state,
        changes: auth.stream);
    _guard = guard;
    _repository = FirebasePaymentReviewRepository(
        session: widget.session, isCurrent: guard.isCurrent);
  }

  @override
  void dispose() {
    _guard?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<AuthBloc, AuthState>(
      builder: (_, state) => _guard!.isCurrent()
          ? RefundsScreen(
              live: true,
              repository: _repository!,
              isCurrent: _guard!.isCurrent)
          : const Center(
              child: Text('Payment review unavailable for this session.')));
}
