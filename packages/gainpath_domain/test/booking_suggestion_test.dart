import 'package:test/test.dart';
import 'package:gainpath_domain/chatbot.dart';

Map<String, dynamic> suggestion() => {
      'schemaVersion': 1,
      'coachId': 'coach',
      'coachName': 'Coach',
      'branchId': 'branch',
      'branchName': 'Studio',
      'localDate': '2026-10-23',
      'timeZone': 'Asia/Kuala_Lumpur',
      'startAtMillis': 1792717200000,
      'endAtMillis': 1792720800000,
      'startLabel': '10:00',
      'endLabel': '11:00',
      'durationMinutes': 60,
      'amountMinor': 12000,
      'currency': 'MYR',
      'expiresAtMillis': 1792717000000,
      'requiresConfirmation': true
    };
void main() {
  test('suggestion is immutable and requires exact confirmed navigation shape',
      () {
    final parsed = BookingSuggestionAttachment.fromJson(suggestion());
    expect(() => parsed.data['coachId'] = 'other', throwsUnsupportedError);
    for (final change in [
      {'requiresConfirmation': false},
      {'memberId': 'other'},
      {'amountMinor': 0},
      {'durationMinutes': 30},
      {'currency': 'USD'},
      {'expiresAtMillis': 1792720800000}
    ]) {
      expect(
          () => BookingSuggestionAttachment.fromJson(
              {...suggestion(), ...change}),
          throwsFormatException);
    }
  });
}
