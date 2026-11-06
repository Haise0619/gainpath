import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_identity/gainpath_identity.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'admin_app.dart'
    show buildControlledDemoAdminLogin, buildControlledDemoAdminVerification;
import '../features/recommendation/application/recommendation_queue.dart';
import '../features/recommendation/presentation/admin/admin_recommendation_screens.dart';
import '../infrastructure/firebase/firebase_demo_recommendation.dart';

/// Separate entrypoint: existing recommendation body and identity widgets only.
/// No ordinary dashboard, payment, booking or default-database service starts.
class Module13DemoAdminApp extends StatelessWidget {
  const Module13DemoAdminApp(
      {super.key,
      required this.authRepository,
      required this.repositories,
      this.theme});
  final AuthRepository authRepository;
  final ThemeData? theme;
  final FirebaseDemoAdminRepositories Function(AuthSession, bool Function())
      repositories;
  @override
  Widget build(BuildContext context) => RepositoryProvider.value(
      value: authRepository,
      child: BlocProvider(
          create: (_) => AuthBloc(repository: authRepository),
          child: MaterialApp(
              title: 'GainPath Admin Demo',
              theme: theme ?? AppTheme.build(),
              debugShowCheckedModeBanner: false,
              home: BlocBuilder<AuthBloc, AuthState>(builder: (context, state) {
                if (state.status == AuthStatus.checkingSession) {
                  return const Scaffold(
                      body: Center(child: CircularProgressIndicator()));
                }
                final session = state.session;
                if (state.status == AuthStatus.needsVerification &&
                    session != null) {
                  return buildControlledDemoAdminVerification(session);
                }
                if (state.status != AuthStatus.signedIn || session == null) {
                  return buildControlledDemoAdminLogin();
                }
                if (session.role != AppRole.admin) {
                  return Scaffold(
                      body: Center(
                          child: TextButton(
                              onPressed: () => context
                                  .read<AuthBloc>()
                                  .add(const LoggedOut()),
                              child: const Text(
                                  'Demo Admin account required · Sign out'))));
                }
                return _DemoAdminSession(
                    key: ValueKey(session),
                    session: session,
                    factory: repositories);
              }))));
}

class _DemoAdminSession extends StatefulWidget {
  const _DemoAdminSession(
      {super.key, required this.session, required this.factory});
  final AuthSession session;
  final FirebaseDemoAdminRepositories Function(AuthSession, bool Function())
      factory;
  @override
  State<_DemoAdminSession> createState() => _DemoAdminSessionState();
}

class _DemoAdminSessionState extends State<_DemoAdminSession> {
  late FirebaseDemoAdminRepositories repo;
  late Future<Map<String, Object?>> access;
  bool delivering = false;
  bool current() =>
      mounted &&
      identical(context.read<AuthBloc>().state.session, widget.session);
  @override
  void initState() {
    super.initState();
    repo = widget.factory(widget.session, current);
    access = repo.access();
  }

  Future<void> deliver() async {
    if (!current() || delivering) {
      return;
    }
    setState(() => delivering = true);
    int delivered = 0;
    try {
      for (final kind in ['trainer', 'content']) {
        var query = RecommendationQueueQuery.recent(
                'gainpath', kind, DateTime.now().toUtc(), 30)
            .filtered(status: 'sent');
        for (var page = 0; page < 4; page++) {
          final raw =
              await repo.transport.map('admin.queue.list', query.toJson());
          final records = RecommendationQueuePage.parse(raw, query);
          if (!current()) {
            return;
          }
          for (final value in raw['leads'] as List) {
            final row = value as Map;
            final decision = row['decision'];
            final id =
                decision is Map ? decision['recipientRecommendationId'] : null;
            if (id is String) {
              await repo.deliver(id);
              delivered++;
            }
          }
          if (records.nextAfterLeadId == null) {
            break;
          }
          query = query.filtered(
              status: 'sent', afterLeadId: records.nextAfterLeadId);
        }
      }
      if (current()) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Delivery confirmed for $delivered demo recommendations.')));
      }
    } catch (_) {
      if (current()) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('Demo delivery was not confirmed. Reload and retry.')));
      }
    } finally {
      if (current()) {
        setState(() => delivering = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
          title: const Text('GainPath · Demo Data'),
          bottom: const PreferredSize(
              preferredSize: Size.fromHeight(24),
              child: Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                      'Fictional records · structured mock ranking · no live Gemini calls',
                      style: TextStyle(fontSize: 11)))),
          actions: [
            TextButton(
                onPressed: delivering ? null : deliver,
                child: Text(delivering ? 'Delivering…' : 'Deliver prepared')),
            IconButton(
                tooltip: 'Sign out',
                onPressed: () =>
                    context.read<AuthBloc>().add(const LoggedOut()),
                icon: const Icon(Icons.logout))
          ]),
      body: FutureBuilder<Map<String, Object?>>(
          future: access,
          builder: (context, s) {
            if (s.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (s.hasError ||
                s.data?['role'] != 'admin' ||
                s.data?['databaseId'] != 'module13-demo') {
              return const Center(
                  child: Text(
                      'Controlled demo access is unavailable. Sign in with an approved demo account.'));
            }
            return RiskLeaderboardScreen(
                insightsRepository: repo.insights, queueRepository: repo.queue);
          }));
}
