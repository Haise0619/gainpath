import 'package:phone_numbers_parser/phone_numbers_parser.dart';
import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';

/// Country metadata owns trunk-prefix removal, numbering plans and E.164 output.
class CoachPhoneInput {
  const CoachPhoneInput({required this.country, required this.national});
  final IsoCode country;
  final String national;
  static final Map<IsoCode, String> countryNames = Map.unmodifiable({
    for (final code in IsoCode.values)
      code: Country.tryParse(code.name)?.name ??
          (code == IsoCode.TA ? 'Tristan da Cunha' : code.name),
  });
  static String flag(IsoCode country) =>
      Country.tryParse(country.name)?.flagEmoji ??
      String.fromCharCodes(country.name.codeUnits.map((unit) => unit + 127397));
  static String dialCode(IsoCode country) =>
      PhoneNumber(isoCode: country, nsn: '').countryCode;
  static String normalize(String input, IsoCode country) {
    final raw = input.trim();
    if (raw.isEmpty) return '';
    // Permit phone punctuation, never silently discard arbitrary text.
    if (!RegExp(r'^[+0-9\s().-]+$').hasMatch(raw)) {
      throw const FormatException('Enter a valid phone number using digits.');
    }
    try {
      final parsed = raw.startsWith('+')
          ? PhoneNumber.parse(raw)
          : PhoneNumber.parse(raw, destinationCountry: country);
      if (!parsed.isValid()) throw const FormatException();
      if (parsed.countryCode != dialCode(country)) {
        throw const FormatException(
            'Choose the country matching this phone number.');
      }
      return parsed.international;
    } on FormatException catch (error) {
      if (error.message.toString().isNotEmpty) rethrow;
      throw const FormatException(
          'Enter a valid phone number for the selected country.');
    } catch (_) {
      throw const FormatException(
          'Enter a valid phone number for the selected country.');
    }
  }

  static CoachPhoneInput restore(String stored) {
    final raw = stored.trim();
    if (raw.startsWith('+')) {
      try {
        final parsed = PhoneNumber.parse(raw);
        return CoachPhoneInput(
            country: parsed.isoCode, national: parsed.formatNsn());
      } catch (_) {
        /* Preserve old unexpected data for correction, never erase it. */
      }
    }
    return CoachPhoneInput(country: IsoCode.MY, national: raw);
  }
}

Future<IsoCode?> showCoachPhoneCountryPicker(BuildContext context) =>
    showModalBottomSheet<IsoCode>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => const _PhoneCountrySheet());

class _PhoneCountrySheet extends StatefulWidget {
  const _PhoneCountrySheet();
  @override
  State<_PhoneCountrySheet> createState() => _PhoneCountrySheetState();
}

class _PhoneCountrySheetState extends State<_PhoneCountrySheet> {
  String query = '';
  @override
  Widget build(BuildContext context) {
    const favorites = [IsoCode.MY, IsoCode.SG, IsoCode.GB, IsoCode.US];
    final rest = IsoCode.values
        .where((code) => !favorites.contains(code))
        .toList()
      ..sort((a, b) => CoachPhoneInput.countryNames[a]!
          .compareTo(CoachPhoneInput.countryNames[b]!));
    final choices = [...favorites, ...rest]
        .where((code) =>
            '${CoachPhoneInput.countryNames[code]} ${code.name} +${CoachPhoneInput.dialCode(code)}'
                .toLowerCase()
                .contains(query.toLowerCase()))
        .toList();
    return Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SizedBox(
            height: MediaQuery.sizeOf(context).height * .75,
            child: Column(children: [
              Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                      autofocus: false,
                      decoration: const InputDecoration(
                          labelText: 'Search country or calling code',
                          prefixIcon: Icon(Icons.search)),
                      onChanged: (value) => setState(() => query = value))),
              Expanded(
                  child: ListView.builder(
                      itemCount: choices.length,
                      itemBuilder: (context, index) {
                        final code = choices[index];
                        return ListTile(
                            leading: Text(CoachPhoneInput.flag(code)),
                            title: Text(
                                '${CoachPhoneInput.countryNames[code]} (${code.name})'),
                            trailing:
                                Text('+${CoachPhoneInput.dialCode(code)}'),
                            onTap: () => Navigator.pop(context, code));
                      })),
            ])));
  }
}
