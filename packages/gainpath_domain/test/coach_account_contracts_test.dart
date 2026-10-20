import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:gainpath_domain/identity.dart';

void main() {
  Map<String, dynamic> fields() => {
        'displayName': 'Coach',
        'specialty': 'Strength',
        'bio': 'Bio',
        'specializationTags': ['Strength'],
        'yearsExperience': null
      };
  test(
      'legacy profile has no fabricated fee or photo and nullable updates clear both',
      () {
    final legacy = CoachProfessionalFields.fromJson(fields());
    expect(legacy.consultationFeeMinor, isNull);
    expect(legacy.photoPath, isNull);
    final edited = CoachProfessionalFields.fromJson({
      ...fields(),
      'consultationFeeMinor': 12345,
      'photoPath': 'orgs/gym/coachProfilePhotos/coach/${'a' * 32}'
    });
    expect(CoachProfilePatch.between(edited, legacy).toJson(),
        {'consultationFeeMinor': null, 'photoPath': null});
    expect(
        () => CoachProfessionalFields.fromJson(
            {...fields(), 'consultationFeeMinor': 1.5}),
        throwsFormatException);
    expect(
        () => CoachProfessionalFields.fromJson(
            {...fields(), 'consultationFeeMinor': 1000001}),
        throwsFormatException);
    expect(
        () => CoachProfessionalFields.fromJson(
            {...fields(), 'photoPath': 'https://public.example/photo'}),
        throwsFormatException);
  });
  test(
      'public verification requires explicit server summary and positive approval count',
      () {
    final data = {
      ...fields(),
      'schemaVersion': 1,
      'revision': 1,
      'sourceRevision': 1,
      'status': 'published',
      'branchIds': ['main'],
      'createdAtMillis': 1,
      'updatedAtMillis': 1,
      'publishedAtMillis': 1
    };
    expect(
        PublishedCoachProfile.fromDocument('coach', data).certificationVerified,
        isFalse);
    expect(
        PublishedCoachProfile.fromDocument('coach', {
          ...data,
          'certificationVerified': true,
          'approvedCertificationCount': 0
        }).certificationVerified,
        isFalse);
    expect(
        PublishedCoachProfile.fromDocument('coach', {
          ...data,
          'certificationVerified': true,
          'approvedCertificationCount': 1
        }).certificationVerified,
        isTrue);
    expect(
        () => PublishedCoachProfile.fromDocument(
            'coach', {...data, 'storagePath': 'secret'}),
        throwsFormatException);
  });
  test('account notification choices require separate explicit booleans', () {
    final data = {
      'schemaVersion': 1,
      'revision': 0,
      'contactPhone': '',
      'coachNotificationPreferences': {
        'newBookings': true,
        'cancellations': false,
        'reminders': false
      }
    };
    final settings = CoachAccountSettings.fromJson(data);
    expect(settings.newBookings, isTrue);
    expect(settings.cancellations, isFalse);
    expect(
        () => CoachAccountSettings.fromJson({
              ...data,
              'coachNotificationPreferences': {
                'bookingUpdates': true,
                'reminders': false
              }
            }),
        throwsFormatException);
  });
  test(
      'private evidence rejects unsupported signature, oversize and copies bytes',
      () {
    expect(() => CoachCertificationFile(Uint8List.fromList([1, 2, 3])),
        throwsFormatException);
    expect(
        () => CoachCertificationFile(
            Uint8List(CoachCertificationFile.maxBytes + 1)),
        throwsFormatException);
    final bytes = Uint8List.fromList([37, 80, 68, 70, 45, 49]);
    final file = CoachCertificationFile(bytes);
    bytes[0] = 0;
    expect(file.contentType, 'application/pdf');
    expect(file.bytes[0], 37);
    expect(() => file.bytes[0] = 0, throwsUnsupportedError);
  });
}
