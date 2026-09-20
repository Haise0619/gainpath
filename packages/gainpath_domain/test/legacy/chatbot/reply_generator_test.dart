import 'package:test/test.dart';
import 'package:gainpath_domain/src/chatbot/entities/chat_message.dart';
import 'package:gainpath_domain/src/chatbot/policies/reply_generator.dart';
import 'package:gainpath_domain/src/workout/entities/gym_equipment.dart';

GymEquipment _eq(String id, String name, String muscle, {bool active = true}) => GymEquipment(
      id: id, name: name, category: 'Strength', description: '', howToUse: const [], safetyTips: const [],
      imageUrl: '', muscleGroup: muscle, isActive: active);

void main() {
  const gen = ReplyGenerator();
  final equipment = [_eq('1', 'Leg Press', 'Quads'), _eq('2', 'Chest Press', 'Chest')];
  const trend = [64, 70, 76];

  test('equipment question returns the matching equipment card', () {
    final r = gen.replyFor('which machine works my chest?', equipment: equipment, postureTrend: trend);
    expect((r.attachment as EquipmentAttachment).equipment.name, 'Chest Press');
  });

  test('equipment question with no specific match falls back to the first active machine', () {
    final list = [_eq('0', 'Broken', 'Back', active: false), ...equipment];
    final r = gen.replyFor('what equipment should I use', equipment: list, postureTrend: trend);
    expect((r.attachment as EquipmentAttachment).equipment.name, 'Leg Press');
  });

  test('progress question returns a form-score chart with the delta', () {
    final r = gen.replyFor('how is my workout progress?', equipment: equipment, postureTrend: trend);
    final chart = r.attachment as ProgressChartAttachment;
    expect(chart.values, trend);
    expect(chart.delta, '+12 pts');
  });

  test('anything else gets the generic reply', () {
    final r = gen.replyFor('hello', equipment: equipment, postureTrend: trend);
    expect(r.text, ReplyGenerator.genericReply);
    expect(r.attachment, isNull);
  });

  test('progress audit wraps the summary with a volume chart', () {
    final r = gen.progressAudit(summary: 'Solid month.', volumeTrend: const [2400, 3400]);
    expect(r.text, 'Solid month.');
    expect((r.attachment as ProgressChartAttachment).delta, '+1000 kg');
  });
}
