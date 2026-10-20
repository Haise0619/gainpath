import 'package:flutter_test/flutter_test.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';
import 'package:gainpath_mobile/features/identity/presentation/coach/coach_phone_input.dart';

void main() {
  test('country selector catalog covers every supported phone region', () {
    expect(CoachPhoneInput.countryNames.keys.toSet(), IsoCode.values.toSet());
    expect(CoachPhoneInput.countryNames[IsoCode.TA], 'Tristan da Cunha');
  });
  test('normalizes supported country national input with actual metadata', () {
    for (final sample in [
      (IsoCode.MY, '012-3456789', '+60123456789'),
      (IsoCode.SG, '8123 4567', '+6581234567'),
      (IsoCode.GB, '020 7946 0018', '+442079460018'),
      (IsoCode.US, '(202) 555-0123', '+12025550123'),
    ]) {
      expect(CoachPhoneInput.normalize(sample.$2, sample.$1), sample.$3);
    }
  });
  test('blank clears, invalid lengths and letters never pass validation', () {
    expect(CoachPhoneInput.normalize(' ', IsoCode.MY), '');
    for (final input in [
      '0123',
      '01234567890123456789',
      'hello',
      '012ABC6789'
    ]) {
      expect(() => CoachPhoneInput.normalize(input, IsoCode.MY),
          throwsFormatException);
    }
  });
  test(
      'restores existing E164 country and national number and old unknown input',
      () {
    for (final sample in [
      (IsoCode.MY, '+60123456789'),
      (IsoCode.SG, '+6581234567'),
      (IsoCode.GB, '+442079460018'),
      (IsoCode.US, '+12025550123')
    ]) {
      final restored = CoachPhoneInput.restore(sample.$2);
      expect(restored.country, sample.$1);
      expect(CoachPhoneInput.normalize(restored.national, restored.country),
          sample.$2);
    }
    expect(CoachPhoneInput.restore('').country, IsoCode.MY);
    expect(
        CoachPhoneInput.restore('legacy unknown').national, 'legacy unknown');
  });
}
