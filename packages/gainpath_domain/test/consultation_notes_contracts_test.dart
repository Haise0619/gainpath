import 'package:gainpath_domain/coaching.dart';
import 'package:test/test.dart';

void main() {
  group('ConsultationNotesResult', () {
    test('parses notes with newlines, carriage returns, and tabs', () {
      const multilineText = 'Session focus: good\n\n'
          'Coach observations: good\r\n'
          'Technique cues covered:\tgood\n'
          'Next session recommendations: good';
      final json = {
        'schemaVersion': 1,
        'bookingId': 'booking-123',
        'status': 'completed',
        'canPublish': false,
        'note': {
          'text': multilineText,
          'publishedAtMillis': 1792466515934,
        },
      };

      final result = ConsultationNotesResult.fromJson(json,
          expectedBookingId: 'booking-123');
      expect(result.bookingId, 'booking-123');
      expect(result.status, 'completed');
      expect(result.canPublish, isFalse);
      expect(result.text, multilineText);
      expect(result.publishedAtMillis, 1792466515934);
    });

    test('parses unnoted confirmed booking eligible for notes', () {
      final json = {
        'schemaVersion': 1,
        'bookingId': 'booking-123',
        'status': 'confirmed',
        'canPublish': true,
        'note': null,
      };

      final result = ConsultationNotesResult.fromJson(json,
          expectedBookingId: 'booking-123');
      expect(result.bookingId, 'booking-123');
      expect(result.status, 'confirmed');
      expect(result.canPublish, isTrue);
      expect(result.text, isNull);
      expect(result.publishedAtMillis, isNull);
    });

    test('rejects non-whitespace control characters in notes', () {
      final badChars = ['\x00', '\x07', '\x08', '\x0B', '\x0C', '\x1F', '\x7F'];
      for (final bad in badChars) {
        final json = {
          'schemaVersion': 1,
          'bookingId': 'booking-123',
          'status': 'completed',
          'canPublish': false,
          'note': {
            'text': 'Good session$bad with cues',
            'publishedAtMillis': 1792466515934,
          },
        };

        expect(
          () => ConsultationNotesResult.fromJson(json,
              expectedBookingId: 'booking-123'),
          throwsFormatException,
          reason: 'Control character 0x${bad.codeUnitAt(0).toRadixString(16)} should be rejected',
        );
      }
    });

    test('rejects whitespace-only or oversized notes', () {
      for (final emptyText in ['', '   ', '\n\n\t  \r\n']) {
        final json = {
          'schemaVersion': 1,
          'bookingId': 'booking-123',
          'status': 'completed',
          'canPublish': false,
          'note': {
            'text': emptyText,
            'publishedAtMillis': 1792466515934,
          },
        };
        expect(
          () => ConsultationNotesResult.fromJson(json,
              expectedBookingId: 'booking-123'),
          throwsFormatException,
        );
      }

      final oversizedJson = {
        'schemaVersion': 1,
        'bookingId': 'booking-123',
        'status': 'completed',
        'canPublish': false,
        'note': {
          'text': 'A' * 5001,
          'publishedAtMillis': 1792466515934,
        },
      };
      expect(
        () => ConsultationNotesResult.fromJson(oversizedJson,
            expectedBookingId: 'booking-123'),
        throwsFormatException,
      );
    });

    test('rejects mismatched bookingId or unexpected fields', () {
      final json = {
        'schemaVersion': 1,
        'bookingId': 'booking-123',
        'status': 'completed',
        'canPublish': false,
        'note': {
          'text': 'Great session',
          'publishedAtMillis': 1792466515934,
        },
      };

      expect(
        () => ConsultationNotesResult.fromJson(json,
            expectedBookingId: 'different-booking-id'),
        throwsFormatException,
      );

      final extraFieldJson = {
        ...json,
        'unexpectedField': true,
      };
      expect(
        () => ConsultationNotesResult.fromJson(extraFieldJson,
            expectedBookingId: 'booking-123'),
        throwsFormatException,
      );
    });
  });
}
