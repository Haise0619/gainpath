import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_identity/gainpath_identity.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:gainpath_domain/analytics.dart';
import '../features/analytics/presentation/member/activity_timeline_screen.dart';
import 'member_typography_theme.dart';
import 'notifications/member_notifications_screen.dart';
import 'notifications/member_recommendation_navigator.dart';
import '../features/identity/presentation/shared/login_screen.dart';
import '../features/identity/presentation/shared/email_verification_screen.dart';
import '../features/identity/presentation/member/privacy_and_data_settings_screen.dart';
import '../features/recommendation/presentation/member/personalized_recommendation_settings_screen.dart';
import '../infrastructure/firebase/firebase_demo_recommendation.dart';

class Module13DemoMemberApp extends StatelessWidget {
  const Module13DemoMemberApp(
      {super.key,
      required this.authRepository,
      required this.repositories,
      this.theme});
  final AuthRepository authRepository;
  final ThemeData? theme;
  final FirebaseDemoMemberRepositories Function(AuthSession, bool Function())
      repositories;
  @override
  Widget build(BuildContext context) => RepositoryProvider.value(
      value: authRepository,
      child: BlocProvider(
          create: (_) => AuthBloc(repository: authRepository),
          child: MaterialApp(
              title: 'GainPath Member Demo',
              theme: theme ?? buildMemberTypographyTheme(),
              debugShowCheckedModeBanner: false,
              home: BlocBuilder<AuthBloc, AuthState>(builder: (context, state) {
                final session = state.session;
                if (state.status == AuthStatus.checkingSession) {
                  return const Scaffold(
                      body: Center(child: CircularProgressIndicator()));
                }
                if (state.status == AuthStatus.needsVerification &&
                    session != null) {
                  return EmailVerificationScreen(
                      email: session.email,
                      onSignOut: () =>
                          context.read<AuthBloc>().add(const LoggedOut()));
                }
                if (state.status != AuthStatus.signedIn || session == null) {
                  return const LoginScreen(role: AppRole.member);
                }
                if (session.role != AppRole.member) {
                  return Scaffold(
                      body: Center(
                          child: TextButton(
                              onPressed: () => context
                                  .read<AuthBloc>()
                                  .add(const LoggedOut()),
                              child: const Text(
                                  'Demo Member account required · Sign out'))));
                }
                return _DemoMemberSession(
                    key: ValueKey(session),
                    session: session,
                    factory: repositories);
              }))));
}

class _DemoMemberSession extends StatefulWidget {
  const _DemoMemberSession(
      {super.key, required this.session, required this.factory});
  final AuthSession session;
  final FirebaseDemoMemberRepositories Function(AuthSession, bool Function())
      factory;
  @override
  State<_DemoMemberSession> createState() => _DemoMemberSessionState();
}

class _DemoMemberSessionState extends State<_DemoMemberSession> {
  late FirebaseDemoMemberRepositories repo;
  late Future<Map<String, Object?>> access;
  late MemberRecommendationNavigator destination;
  bool current() =>
      mounted &&
      identical(context.read<AuthBloc>().state.session, widget.session);
  @override
  void initState() {
    super.initState();
    repo = widget.factory(widget.session, current);
    access = repo.access();
    destination = MemberRecommendationNavigator(
        session: widget.session,
        repository: repo.recommendation,
        isCurrent: current,
        coachDirectory: repo.directory,
        catalog: repo.catalog,
        bookingNavigationEnabled: false);
  }

  Future<void> recommendations() async {
    try {
      final notice = await repo.notice();
      if (!current()) {
        return;
      }
      await Navigator.push<void>(
          context,
          MaterialPageRoute(
              builder: (_) => PersonalizedRecommendationSettingsScreen(
                  isCurrent: current,
                  repository: repo.consent,
                  notice: notice)));
    } catch (_) {
      if (current()) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Reviewed demo notice is unavailable. No permission was changed.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
          body: SafeArea(
              child: Column(children: [
        Row(children: [
          const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('Demo Data',
                  style: TextStyle(color: AppColors.primary))),
          const Spacer(),
          IconButton(
              tooltip: 'Workout history',
              icon: const Icon(Icons.history),
              onPressed: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                      builder: (_) => _DemoHistory(
                          load: repo.loadWorkoutProgress,
                          isCurrent: current)))),
          IconButton(
              tooltip: 'Privacy & Data',
              icon: const Icon(Icons.privacy_tip_outlined),
              onPressed: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                      builder: (_) => PrivacyAndDataSettingsScreen(
                          isCurrent: current,
                          repository: repo.inbox,
                          onOpenRecommendations: recommendations)))),
          IconButton(
              tooltip: 'Sign out',
              onPressed: () => context.read<AuthBloc>().add(const LoggedOut()),
              icon: const Icon(Icons.logout))
        ]),
        Expanded(
            child: FutureBuilder<Map<String, Object?>>(
                future: access,
                builder: (context, s) {
                  if (s.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (s.hasError ||
                      s.data?['role'] != 'member' ||
                      s.data?['databaseId'] != 'module13-demo') {
                    return const Center(
                        child: Text(
                            'Controlled demo access is unavailable. Sign in with an approved demo account.'));
                  }
                  return MemberNotificationsScreen(
                      session: widget.session,
                      isCurrent: current,
                      module9Repository: repo.inbox,
                      recommendationRepository: repo.recommendation,
                      onOpenRecommendationTarget: destination.open,
                      recommendationPhotoBuilder: destination.buildCoachPhoto);
                }))
      ])));
}

class _DemoHistory extends StatefulWidget {
  const _DemoHistory({required this.load, required this.isCurrent});
  final Future<MemberLocalProgress> Function() load;
  final bool Function() isCurrent;
  @override
  State<_DemoHistory> createState() => _DemoHistoryState();
}

class _DemoHistoryState extends State<_DemoHistory> {
  late Future<MemberLocalProgress> result;
  @override
  void initState() {
    super.initState();
    result = widget.load();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<MemberLocalProgress>(
      future: result,
      builder: (context, s) {
        if (!widget.isCurrent() || s.hasError) {
          return Scaffold(
              appBar: AppBar(title: const Text('Workout history')),
              body: const Center(
                  child: Text(
                      'Demo workout history is unavailable. No activity was changed.')));
        }
        if (!s.hasData) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        return Column(children: [
          const SafeArea(
              bottom: false,
              child: Material(
                  child: Padding(
                      padding: EdgeInsets.all(8),
                      child: Text(
                          'Demo Data · fictional Firebase backups · no physical capture or reward acceptance')))),
          Expanded(child: ActivityTimelineScreen(localProgress: s.data))
        ]);
      });
}
