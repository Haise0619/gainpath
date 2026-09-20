import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/analytics.dart';
import 'package:gainpath_mobile/features/chatbot/application/chat_bloc.dart';
import 'package:gainpath_domain/chatbot.dart';
import 'package:gainpath_domain/workout.dart';

class _FakeChat implements ChatRepository {
  @override
  List<ChatMessage> get chatSeed => const [ChatMessage('Hi! Ask me anything.', false)];
  @override
  final List<String> savedAdvice = ['Warm up first.'];
  @override
  List<FaqPrompt> get faqPrompts => const [FaqPrompt('How often?', 'Three times a week.')];
  @override
  String buildProgressAuditReply() => 'Volume is up.';
}

class _FakeEquipment implements EquipmentRepository {
  @override
  List<GymEquipment> get gymEquipment => [
        GymEquipment(id: '1', name: 'Chest Press', category: 'Strength', description: '', howToUse: const [],
            safetyTips: const [], imageUrl: '', muscleGroup: 'Chest'),
      ];
}

class _FakeAnalytics implements AnalyticsRepository {
  @override
  List<int> get postureTrend => const [60, 70];
  @override
  List<int> get volumeTrend => const [2000, 2500];
  @override
  List<WeightEntry> get weightHistory => const [];
  @override
  List<MuscleGroupShare> get muscleGroupSplit => const [];
  @override
  List<int> get sessionsPerWeek => const [];
  @override
  List<String> get sessionWeekLabels => const [];
  @override
  List<int> get pointsHistory => const [];
  @override
  List<String> get pointsWeekLabels => const [];
  @override
  List<List<String>> get adminStats => const [];
  @override
  List<int> get usageByHour => const [];
  @override
  List<int> get postureWeeklyTrend => const [];
  @override
  List<ChartSlice> get retentionRiskMix => const [];
  @override
  List<int> get rewardWeeklyRedemptions => const [];
  @override
  List<ChartSlice> get rewardRedemptionMix => const [];
  @override
  List<ChartSlice> get streakDistribution => const [];
}

ChatBloc _bloc(_FakeChat chat) =>
    ChatBloc(chat: chat, equipment: _FakeEquipment(), analytics: _FakeAnalytics(), replyDelay: Duration.zero);

void main() {
  late _FakeChat chat;
  setUp(() => chat = _FakeChat());

  blocTest<ChatBloc, ChatState>(
    'sending a message appends the question, then the reply',
    build: () => _bloc(chat),
    act: (b) => b.add(const MessageSent('hello')),
    verify: (b) {
      expect(b.state.messages.map((m) => m.text).toList(),
          ['Hi! Ask me anything.', 'hello', ReplyGenerator.genericReply]);
      expect(b.state.isReplying, isFalse);
    },
  );

  blocTest<ChatBloc, ChatState>(
    'blank messages are ignored',
    build: () => _bloc(chat),
    act: (b) => b.add(const MessageSent('   ')),
    expect: () => const <ChatState>[],
  );

  blocTest<ChatBloc, ChatState>(
    'an FAQ prompt replies with its canned answer',
    build: () => _bloc(chat),
    act: (b) => b.add(const PromptSent(FaqPrompt('How often?', 'Three times a week.'))),
    verify: (b) => expect(b.state.messages.last.text, 'Three times a week.'),
  );

  blocTest<ChatBloc, ChatState>(
    'progress audit adds a question and a chart reply',
    build: () => _bloc(chat),
    act: (b) => b.add(const ProgressAuditRequested()),
    verify: (b) {
      expect(b.state.messages.length, 3);
      expect(b.state.messages.last.attachment, isA<ProgressChartAttachment>());
    },
  );

  blocTest<ChatBloc, ChatState>(
    'bookmark toggles membership in the shared saved-advice list',
    build: () => _bloc(chat),
    act: (b) => b
      ..add(const AdviceBookmarkToggled('Brace your core.'))
      ..add(const AdviceBookmarkToggled('Warm up first.')),
    verify: (b) {
      expect(chat.savedAdvice, ['Brace your core.']);
      expect(b.state.isBookmarked(const ChatMessage('Brace your core.', false)), isTrue);
      expect(b.state.revision, 2);
    },
  );

  blocTest<ChatBloc, ChatState>(
    'clearing history empties messages but keeps bookmarks',
    build: () => _bloc(chat),
    act: (b) => b.add(const HistoryCleared()),
    verify: (b) {
      expect(b.state.messages, isEmpty);
      expect(chat.savedAdvice, ['Warm up first.']);
    },
  );
}
