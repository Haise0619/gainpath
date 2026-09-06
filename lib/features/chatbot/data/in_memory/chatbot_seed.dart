import 'package:gainpath/features/analytics/data/in_memory/analytics_seed.dart';
import 'package:gainpath/features/chatbot/domain/entities/chat_message.dart';
import 'package:gainpath/features/chatbot/domain/entities/faq_prompt.dart';
import 'package:gainpath/features/workout/data/in_memory/workout_seed.dart';

/// In-memory seed data for the chatbot feature (frontend prototype).
class ChatbotSeed {
  static const chatSeed = <ChatMessage>[
    ChatMessage('How do I stop my knees caving in during squats?', true),
    ChatMessage(
        'Knee valgus usually comes from weak glute medius or a stance that is too narrow. Try widening your stance slightly and consciously pushing your knees out as you descend. Adding banded side-steps before your session can help too.\n\nThis is general educational guidance, not medical advice.',
        false),
  ];

  static final savedAdvice = <String>[
    'Widen your stance slightly and push the knees out on the descent.',
    'Aim for a neutral spine on deadlifts, brace before the pull.',
    'Progressive overload works best in small weekly increments.',
  ];

  static const faqPrompts = <FaqPrompt>[
    FaqPrompt(
      'How do I fix my squat depth?',
      'Depth usually gets limited by tight ankles or hips rather than weak '
      'legs. Try elevating your heels slightly on a small plate and pause '
      'for two seconds at the bottom of each rep to build control there.\n\n'
      'This is general educational guidance, not medical advice.',
    ),
    FaqPrompt(
      'What should I eat after a workout?',
      'Aim for a mix of protein and carbs within a couple of hours of '
      'training — think grilled chicken with rice, or a protein shake with '
      'a banana. Protein supports muscle repair, carbs refill the energy '
      'you just used.\n\n'
      'This is general nutrition guidance, not a personalised meal plan.',
    ),
    FaqPrompt(
      'How many rest days do I need per week?',
      'Most people training 4-5 days a week do well with at least 1-2 full '
      'rest days, plus lighter days for any muscle group you hit hard. '
      'Watch for ongoing soreness or dropping performance — that is '
      'usually a sign to add another rest day.\n\n'
      'This is general guidance, not medical advice.',
    ),
    FaqPrompt(
      'Why do my knees hurt during lunges?',
      'Knee discomfort in lunges is often about tracking — check that your '
      'front knee stays roughly over your ankle rather than drifting '
      'inward or past your toes, and shorten your stride if it still '
      'bothers you.\n\n'
      'If the pain is sharp or persistent, stop and see a physiotherapist '
      'rather than pushing through it.',
    ),
    FaqPrompt(
      'How do I know when to increase my weights?',
      'A good rule of thumb: if you can complete all your sets and reps '
      'with good form and have 2+ reps left in the tank, add a small '
      'amount of weight next session. Keep increases small and consistent '
      'rather than jumping up all at once.\n\n'
      'This is general programming guidance, not personalised coaching.',
    ),
  ];

  static String buildProgressAuditReply() {
    final formChange = AnalyticsSeed.postureTrend.last - AnalyticsSeed.postureTrend.first;
    final volumeChangePct =
        ((AnalyticsSeed.volumeTrend.last - AnalyticsSeed.volumeTrend.first) / AnalyticsSeed.volumeTrend.first * 100).round();
    final weakest = WorkoutSeed.history.reduce((a, b) => a.accuracy < b.accuracy ? a : b);
    return 'Over the last ${AnalyticsSeed.postureTrend.length} sessions your average form score '
        'is up $formChange GamificationSeed.points, and lifting volume has grown about '
        '$volumeChangePct% over that span. ${weakest.exercise} is currently your '
        'lowest-scoring lift at ${weakest.accuracy}%, so that is the best place to '
        'focus next.\n\n'
        'This is general educational guidance, not medical advice.';
  }
}
