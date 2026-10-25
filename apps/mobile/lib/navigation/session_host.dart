import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show AuthSession;
import 'package:gainpath_identity/gainpath_identity.dart';

class CoachSessionHost extends StatefulWidget {
  const CoachSessionHost(
      {super.key, required this.session, required this.builder});
  final AuthSession session;
  final Widget Function(BuildContext, bool Function()) builder;
  @override
  State<CoachSessionHost> createState() => _CoachSessionHostState();
}

class _CoachSessionHostState extends State<CoachSessionHost> {
  AuthBloc? _auth;
  StreamSubscription<AuthState>? _subscription;
  bool _invalidated = false;
  Widget? _child;
  bool _matches(AuthState state) =>
      identical(state.session, widget.session) &&
      AuthRolePolicy.canEnter(state, allowed: {widget.session.role});
  bool _current() {
    if (_auth == null || !_matches(_auth!.state)) _invalidated = true;
    return !_invalidated;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_auth != null) return;
    _auth = context.read<AuthBloc>();
    _subscription = _auth!.stream.listen((state) {
      if (!_matches(state)) {
        _invalidated = true;
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();
      }
    });
    _child = widget.builder(context, _current);
  }

  @override
  void dispose() {
    _invalidated = true;
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) => _current()
          ? _child!
          : const Scaffold(
              body: Center(
                  child:
                      Text('Coach workflow unavailable for this session.'))));
}
