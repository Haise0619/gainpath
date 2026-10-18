import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_identity/gainpath_identity.dart';
import '../../features/identity/application/coach_account_gateway.dart';
import '../../infrastructure/local/mock_coach_module8_repository.dart';

class CoachModule8Dependencies {
  const CoachModule8Dependencies(
      {required this.profile, required this.account});
  final CoachProfileRepository profile;
  final CoachAccountGateway account;
}

/// Composition only. Presentation receives exactly the same contracts/classes.
CoachModule8Dependencies composeMockCoachModule8(BuildContext context) {
  final legacy = context.read<CoachRepository>();
  AuthBloc? auth;
  try {
    auth = context.read<AuthBloc>();
  } on ProviderNotFoundException {/* Legacy sample harness. */}
  final bloc = auth, session = auth?.state.session;
  final adapter = MockCoachModule8Repository(
      legacy: legacy,
      scope: session?.scope ??
          SessionScope(userId: legacy.currentCoach.id, organizationId: 'mock'),
      isCurrent: () =>
          bloc == null ||
          (session != null && identical(bloc.state.session, session)));
  return CoachModule8Dependencies(profile: adapter, account: adapter);
}
