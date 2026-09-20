import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_data/gainpath_data.dart'
    show BackendConfig, BackendMode;
import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_domain/gamification.dart';
import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_domain/membership.dart';
import 'di/app_repositories.dart';
import '../features/coaching/application/booking_bloc.dart';
import '../features/gamification/application/gamification_bloc.dart';
import '../features/membership/application/membership_bloc.dart';

/// Recreated for each authenticated identity by the application root.
class AppScope extends StatelessWidget {
  const AppScope(
      {super.key,
      required this.child,
      this.config = const BackendConfig(BackendMode.mock)});
  final Widget child;
  final BackendConfig config;

  @override
  Widget build(BuildContext context) => AppRepositories(
        config: config,
        child: MultiBlocProvider(
          providers: [
            BlocProvider(
                create: (context) =>
                    BookingBloc(context.read<BookingRepository>())
                      ..add(const BookingsRequested())),
            BlocProvider(
                create: (context) =>
                    GamificationBloc(context.read<GamificationRepository>())),
            BlocProvider(
                create: (context) => MembershipBloc(
                    context.read<MembershipRepository>(),
                    memberName:
                        context.read<MemberProfileRepository>().memberName)),
          ],
          child: child,
        ),
      );
}
