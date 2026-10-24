import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_domain/gamification.dart';
import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_domain/membership.dart';
import 'mock_app_repositories.dart';
import 'package:gainpath_mobile/features/coaching/application/booking_bloc.dart';
import 'package:gainpath_mobile/features/gamification/application/gamification_bloc.dart';
import 'package:gainpath_mobile/features/membership/application/membership_bloc.dart';

/// Recreated for each authenticated identity by the application root.
class MockAppScope extends StatelessWidget {
  const MockAppScope({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => MockAppRepositories(
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
