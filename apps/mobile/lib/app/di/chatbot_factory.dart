import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/chatbot.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_identity/gainpath_identity.dart';
import '../../features/chatbot/presentation/member/chatbot_screen.dart';
import '../../infrastructure/firebase/firebase_chat_repository.dart';
import 'local_member_progress_factory.dart';
import 'booking_factory.dart';

/// The route owns one account-bound repository; auth changes dispose its Bloc.
Widget buildMemberChatbot(AuthSession expected,
        {bool openSavedAdvice = false}) =>
    _MemberChatHost(expected: expected, openSavedAdvice: openSavedAdvice);

class _MemberChatHost extends StatefulWidget {
  const _MemberChatHost(
      {required this.expected, required this.openSavedAdvice});
  final AuthSession expected;
  final bool openSavedAdvice;
  @override
  State<_MemberChatHost> createState() => _MemberChatHostState();
}

class _MemberChatHostState extends State<_MemberChatHost> {
  bool _reviewing = false;
  FirebaseChatRepository? _repository;
  AuthBloc? _auth;
  SessionScope? _active() => mounted &&
          _auth?.state.session?.scope == widget.expected.scope &&
          AuthRolePolicy.canEnter(_auth!.state, allowed: const {AppRole.member})
      ? widget.expected.scope
      : null;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _auth ??= context.read<AuthBloc>();
    _repository ??= FirebaseChatRepository(
        scope: widget.expected.scope,
        activeScope: _active,
        progressLoader: () async {
          final reader = await createLocalMemberProgressRepository(
              widget.expected.scope, _active);
          return reader.load();
        });
  }

  @override
  Widget build(BuildContext context) =>
      RepositoryProvider<ChatRepository>.value(
          value: _repository!,
          child: BlocBuilder<AuthBloc, AuthState>(
              builder: (context, state) => _active() == widget.expected.scope
                  ? ChatbotScreen(
                      onReviewBooking: (suggestion) async {
                        if (_active() != widget.expected.scope || _reviewing) {
                          return;
                        }
                        if (suggestion.expired) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                              content: Text(
                                  'This suggestion expired. Ask for current available times.')));
                          return;
                        }
                        _reviewing = true;
                        try {
                          await openMemberBooking(
                              context, widget.expected, suggestion.coachId,
                              suggestion: suggestion);
                        } finally {
                          _reviewing = false;
                        }
                      },
                      connected: true,
                      openSavedAdvice: widget.openSavedAdvice)
                  : const Scaffold(
                      body: Center(
                          child: Text('Sign in to reopen the assistant.')))));
}
