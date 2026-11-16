import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_mobile/features/chatbot/presentation/member/saved_advice_screen.dart';
import 'package:gainpath_domain/chatbot.dart';
import 'package:gainpath_mobile/features/chatbot/application/chat_bloc.dart';
import 'module6_chat_flow_test.dart' show LiveChat;

class FailingChat extends LiveChat {
  int saves = 0;
  bool failReply = true;
  @override
  Future<ChatMessage> generateReply(
      {required String text, required List<ChatMessage> history}) async {
    calls++;
    if (failReply) throw const ChatFailure('unavailable', 'Offline');
    return const ChatMessage('Recovered', false);
  }

  @override
  Future<void> setBookmarked(String text, bool saved) async {
    saves++;
    throw const ChatFailure('unavailable', 'Save failed');
  }
}

class RacingChat extends FailingChat {
  final save = Completer<void>();
  @override
  Future<void> setBookmarked(String text, bool saved) {
    saves++;
    return save.future;
  }
}

class PendingReplyChat extends FailingChat {
  final pendingReply = Completer<ChatMessage>();
  @override
  Future<ChatMessage> generateReply(
      {required String text, required List<ChatMessage> history}) {
    calls++;
    return calls == 1
        ? pendingReply.future
        : Future.value(const ChatMessage('Recovered', false));
  }
}

Future<void> tick() => Future<void>.delayed(const Duration(milliseconds: 10));
void main() {
  test('message failure after a concurrent save failure retries the question',
      () async {
    final repo = PendingReplyChat()..accepted = true;
    final bloc = ChatBloc(chat: repo);
    await tick();
    bloc.add(const MessageSent('Question'));
    await tick();
    bloc.add(const AdviceBookmarkToggled('Other advice'));
    await tick();
    repo.pendingReply
        .completeError(const ChatFailure('unavailable', 'Reply failed'));
    await tick();
    bloc.add(const ChatRetried());
    await tick();
    expect(repo.calls, 2);
    expect(repo.saves, 1);
    await bloc.close();
  });
  test('late old save failure cannot steal latest message retry', () async {
    final repo = RacingChat()..accepted = true;
    final bloc = ChatBloc(chat: repo);
    await tick();
    bloc.add(const AdviceBookmarkToggled('Old save'));
    await tick();
    expect(bloc.state.pendingAdvice, contains('Old save'));
    bloc.add(const MessageSent('Current question'));
    await tick();
    repo.save
        .completeError(const ChatFailure('unavailable', 'Old save failed'));
    await tick();
    repo.failReply = false;
    bloc.add(const ChatRetried());
    await tick();
    expect(repo.saves, 1);
    expect(repo.calls, 2);
    expect(bloc.state.messages.last.text, 'Recovered');
    await bloc.close();
  });
  testWidgets(
      'saved advice failure stays visible and retry repeats the save action',
      (tester) async {
    final repo = FailingChat()
      ..accepted = true
      ..savedAdvice.add('Saved advice fixture');
    final bloc = ChatBloc(chat: repo);
    addTearDown(bloc.close);
    await tester.pumpWidget(BlocProvider.value(
        value: bloc, child: const MaterialApp(home: SavedAdviceScreen())));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Remove saved advice'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove').last);
    await tester.pumpAndSettle();
    expect(find.text('Save failed'), findsOneWidget);
    expect(find.text('Saved advice fixture'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(repo.saves, 2);
    expect(tester.takeException(), isNull);
  });
  test('failed question remains visible and retry targets latest question',
      () async {
    final repo = FailingChat()..accepted = true;
    final bloc = ChatBloc(chat: repo);
    await tick();
    bloc.add(const AdviceBookmarkToggled('Old advice'));
    await tick();
    bloc.add(const MessageSent('My question'));
    await tick();
    expect(bloc.state.messages.last.text, 'My question');
    expect(bloc.state.failedText, 'My question');
    repo.failReply = false;
    bloc.add(const ChatRetried());
    await tick();
    expect(repo.saves, 1);
    expect(repo.calls, 2);
    expect(bloc.state.messages.where((m) => m.fromUser).length, 1);
    expect(bloc.state.messages.last.text, 'Recovered');
    await bloc.close();
  });
  test('stop waiting rejects late replies without removing the question',
      () async {
    final repo = LiveChat()
      ..accepted = true
      ..pending = Completer<ChatMessage>();
    final bloc = ChatBloc(chat: repo);
    await tick();
    bloc.add(const MessageSent('Wait'));
    await tick();
    bloc.add(const ReplyCancelled());
    await tick();
    repo.pending!.complete(const ChatMessage('Late', false));
    await tick();
    expect(bloc.state.isReplying, false);
    expect(bloc.state.messages.single.text, 'Wait');
    await bloc.close();
  });
}
