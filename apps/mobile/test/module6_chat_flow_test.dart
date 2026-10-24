import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/chatbot.dart';
import 'package:gainpath_mobile/features/chatbot/application/chat_bloc.dart';
import 'package:gainpath_mobile/features/chatbot/presentation/member/chatbot_screen.dart';

class LiveChat extends ChatRepository {
  bool accepted = false;
  bool requireNewNotice = false;
  int revision = 7;
  Completer<ChatMessage>? pending;
  int calls = 0;
  final ratings = <bool>[];
  ChatMessage? reply;
  @override
  bool get isLive => true;
  @override
  List<ChatMessage> get chatSeed => const [];
  @override
  final List<String> savedAdvice = [];
  @override
  List<FaqPrompt> get faqPrompts =>
      const [FaqPrompt('Training help', 'Never use canned answer')];
  @override
  String buildProgressAuditReply() => '';
  @override
  Future<ChatSessionInfo> initialize() async => ChatSessionInfo(
      disclaimer: ChatDisclaimer(
          text: revision == 7
              ? 'Server notice revision seven'
              : 'Updated server notice',
          revision: revision),
      acknowledged: accepted);
  @override
  Future<void> acknowledgeDisclaimer(ChatDisclaimer notice) async {
    accepted = true;
  }

  @override
  Future<ChatMessage> generateReply(
      {required String text, required List<ChatMessage> history}) async {
    calls++;
    expect(history.length, lessThanOrEqualTo(12));
    return pending == null
        ? reply ?? const ChatMessage('Server advice', false, id: 'reply-1')
        : pending!.future;
  }

  @override
  Future<void> setBookmarked(String text, bool saved) async {
    if (requireNewNotice) {
      requireNewNotice = false;
      revision = 8;
      accepted = false;
      throw const ChatFailure(
          'failed-precondition', 'Please accept the updated notice.');
    }
    await super.setBookmarked(text, saved);
  }

  @override
  Future<void> rateAdvice(ChatMessage message, bool helpful) async {
    ratings.add(helpful);
  }
}

void main() {
  testWidgets(
      'shared chat renders a reviewable booking suggestion without executing an action until tapped',
      (tester) async {
    final start =
        ((DateTime.now().millisecondsSinceEpoch ~/ 1800000) + 48) * 1800000;
    final suggestion = BookingSuggestionAttachment.fromJson({
      'schemaVersion': 1,
      'coachId': 'coach',
      'coachName': 'Real Coach',
      'branchId': 'branch',
      'branchName': 'Studio',
      'localDate': '2026-10-23',
      'timeZone': 'Asia/Kuala_Lumpur',
      'startAtMillis': start,
      'endAtMillis': start + 1800000,
      'startLabel': '10:00',
      'endLabel': '10:30',
      'durationMinutes': 30,
      'amountMinor': 12500,
      'currency': 'MYR',
      'expiresAtMillis': DateTime.now().millisecondsSinceEpoch + 60000,
      'requiresConfirmation': true
    });
    final repo = LiveChat()
      ..accepted = true
      ..reply = ChatMessage('Review this suggestion', false,
          attachment: suggestion, id: 'suggestion');
    var reviews = 0;
    await tester.pumpWidget(RepositoryProvider<ChatRepository>.value(
        value: repo,
        child: MaterialApp(
            home: ChatbotScreen(
                connected: true, onReviewBooking: (_) => reviews++))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Training help'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Not reserved or paid'), findsOneWidget);
    expect(reviews, 0);
    await tester.ensureVisible(find.text('Review in checkout'));
    await tester.tap(find.text('Review in checkout'));
    expect(reviews, 1);
  });
  test('bookmark refreshes changed notice and retries only after acceptance',
      () async {
    final repo = LiveChat()..accepted = true;
    final bloc = ChatBloc(chat: repo);
    await Future<void>.delayed(Duration.zero);
    repo.requireNewNotice = true;
    bloc.add(const AdviceBookmarkToggled('Keep this advice'));
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state.notice!.revision, 8);
    expect(bloc.state.acknowledged, isFalse);
    expect(repo.savedAdvice, isEmpty);
    bloc.add(const ChatRetried());
    await Future<void>.delayed(Duration.zero);
    expect(repo.savedAdvice, isEmpty);
    bloc.add(const DisclaimerAcknowledged());
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state.acknowledged, isTrue);
    expect(repo.savedAdvice, ['Keep this advice']);
    await bloc.close();
  });
  test(
      'gates sends, prevents parallel calls, and invalidates replies after clearing',
      () async {
    final repo = LiveChat()..pending = Completer<ChatMessage>();
    final bloc = ChatBloc(chat: repo);
    await Future<void>.delayed(Duration.zero);
    bloc.add(const MessageSent('Blocked'));
    await Future<void>.delayed(Duration.zero);
    expect(repo.calls, 0);
    bloc.add(const DisclaimerAcknowledged());
    await Future<void>.delayed(Duration.zero);
    bloc
      ..add(const MessageSent('One'))
      ..add(const MessageSent('Two'));
    await Future<void>.delayed(Duration.zero);
    expect(repo.calls, 1);
    bloc.add(const HistoryCleared());
    await Future<void>.delayed(Duration.zero);
    repo.pending!.complete(const ChatMessage('Stale', false));
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state.messages, isEmpty);
    expect(bloc.state.isReplying, isFalse);
    await bloc.close();
  });
  testWidgets('saved advice shortcut waits for acknowledgment', (tester) async {
    final repo = LiveChat()..savedAdvice.add('Saved tip');
    await tester.pumpWidget(RepositoryProvider<ChatRepository>.value(
        value: repo,
        child: const MaterialApp(
            home: ChatbotScreen(connected: true, openSavedAdvice: true))));
    await tester.pumpAndSettle();
    expect(find.text('Server notice revision seven'), findsOneWidget);
    expect(find.textContaining('General questions are sent to Google Gemini.'),
        findsOneWidget);
    expect(find.text('Saved tip'), findsNothing);
    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();
    expect(find.text('Saved tip'), findsOneWidget);
  });

  testWidgets(
      'connected shared UI acknowledges server notice, generates FAQ, rates and removes saved advice',
      (tester) async {
    final repo = LiveChat();
    await tester.pumpWidget(RepositoryProvider<ChatRepository>.value(
        value: repo,
        child: const MaterialApp(home: ChatbotScreen(connected: true))));
    await tester.pumpAndSettle();
    expect(find.text('Server notice revision seven'), findsOneWidget);
    expect(find.textContaining('General questions are sent to Google Gemini.'),
        findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Training help'));
    await tester.pumpAndSettle();
    expect(find.text('Server advice'), findsOneWidget);
    expect(find.text('Never use canned answer'), findsNothing);
    await tester.tap(find.text('Helpful'));
    await tester.pumpAndSettle();
    expect(repo.ratings, [true]);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Saved advice'));
    await tester.pumpAndSettle();
    expect(find.text('Server advice'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.delete_outline_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove').last);
    await tester.pumpAndSettle();
    expect(find.text('Nothing saved yet. Bookmark a reply to keep it here.'),
        findsOneWidget);
  });
}
