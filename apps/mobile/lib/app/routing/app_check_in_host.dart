import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/gainpath_domain.dart'
    show SessionScope, AppRole;
import 'package:gainpath_identity/gainpath_identity.dart';
import '../../features/gamification/application/app_check_in_cubit.dart';
import '../../features/gamification/application/app_check_in_refresh_schedule.dart';
import '../../features/gamification/domain/app_check_in.dart';
import '../di/app_check_in_factory.dart';

class AppCheckInHost extends StatefulWidget {
  const AppCheckInHost(
      {super.key,
      required this.scope,
      required this.builder,
      this.repositoryFactory = createAppCheckInRepository});
  final SessionScope scope;
  final AppCheckInRepositoryFactory repositoryFactory;
  final Widget Function(
          AppCheckInState, Future<void> Function(), Future<void> Function())
      builder;
  @override
  State<AppCheckInHost> createState() => _AppCheckInHostState();
}

class _AppCheckInHostState extends State<AppCheckInHost>
    with WidgetsBindingObserver {
  AppCheckInCubit? _cubit;
  AuthBloc? _auth;
  StreamSubscription<AuthState>? _authListener;
  StreamSubscription<AppCheckInState>? _listener;
  Timer? _reset;
  final _schedule = AppCheckInRefreshSchedule();
  String? _error;
  bool _opening = false, _foreground = true;
  SessionScope? _current() => _auth?.state.session?.scope == widget.scope &&
          AuthRolePolicy.canEnter(_auth!.state, allowed: const {AppRole.member})
      ? widget.scope
      : null;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_auth != null) return;
    WidgetsBinding.instance.addObserver(this);
    _auth = context.read<AuthBloc>();
    _authListener = _auth!.stream.listen((_) {
      _cubit?.invalidate();
      if (_current() == null) _reset?.cancel();
    });
    unawaited(_open());
  }

  Future<void> _open() async {
    if (_opening || !mounted || _current() == null) return;
    _opening = true;
    try {
      final repo = await widget.repositoryFactory(widget.scope, _current);
      if (!mounted || _current() == null) return;
      if (repo.scope != widget.scope) {
        throw StateError('Check-in account mismatch');
      }
      final c = AppCheckInCubit(repository: repo, activeScope: _current);
      _listener = c.stream.listen((state) {
        _reset?.cancel();
        final delay = _schedule.next(state, foreground: _foreground);
        if (delay != null) _reset = Timer(delay, c.refresh);
      });
      setState(() {
        _error = null;
        _cubit = c;
      });
      await c.refresh();
    } catch (_) {
      if (mounted && _current() != null) {
        setState(() => _error = 'Check-in could not load. Refresh to retry.');
      }
    } finally {
      _opening = false;
    }
  }

  Future<void> _refresh() async {
    if (_current() == null) return;
    if (_cubit == null) {
      await _open();
    } else {
      await _cubit!.refresh();
    }
  }

  Future<void> _claim() async {
    if (_current() != null) await _cubit?.claim();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) {
      unawaited(_refresh());
    } else {
      _reset?.cancel();
    }
  }

  @override
  void dispose() {
    _reset?.cancel();
    unawaited(_authListener?.cancel());
    unawaited(_listener?.cancel());
    unawaited(_cubit?.close());
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<AuthBloc, AuthState>(
      bloc: _auth,
      builder: (context, auth) {
        if (_current() == null) {
          return widget.builder(
              const AppCheckInState(status: AppCheckInStatus.inactive),
              _refresh,
              _claim);
        }
        final c = _cubit;
        if (c == null) {
          return widget.builder(
              AppCheckInState(
                  status: _error == null
                      ? AppCheckInStatus.loading
                      : AppCheckInStatus.error,
                  message: _error),
              _refresh,
              _claim);
        }
        return BlocBuilder<AppCheckInCubit, AppCheckInState>(
            bloc: c,
            builder: (_, state) => widget.builder(state, _refresh, _claim));
      });
}
