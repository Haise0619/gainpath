import 'dart:typed_data';

class CoachAccountSettings {
  const CoachAccountSettings(
      {required this.revision,
      required this.contactPhone,
      required this.newBookings,
      required this.cancellations,
      required this.reminders});
  final int revision;
  final String contactPhone;
  final bool newBookings, cancellations, reminders;
  factory CoachAccountSettings.fromJson(Map<String, dynamic> data) {
    final prefs = data['coachNotificationPreferences'];
    if (data['schemaVersion'] != 1 ||
        data['revision'] is! int ||
        data['revision'] < 0 ||
        data['contactPhone'] is! String ||
        prefs is! Map ||
        prefs['newBookings'] is! bool ||
        prefs['cancellations'] is! bool ||
        prefs['reminders'] is! bool) {
      throw const FormatException('Unsupported Coach account settings.');
    }
    return CoachAccountSettings(
        revision: data['revision'],
        contactPhone: data['contactPhone'],
        newBookings: prefs['newBookings'],
        cancellations: prefs['cancellations'],
        reminders: prefs['reminders']);
  }
}

class PrivateCoachCertification {
  const PrivateCoachCertification(
      {required this.id,
      required this.title,
      required this.issuer,
      required this.storagePath,
      required this.status,
      required this.revision,
      required this.createdAtMillis,
      required this.updatedAtMillis,
      this.reason});
  final String id, title, issuer, storagePath, status;
  final String? reason;
  final int revision, createdAtMillis, updatedAtMillis;
  factory PrivateCoachCertification.fromJson(Map<String, dynamic> data) {
    if (['id', 'title', 'issuer', 'storagePath', 'status']
            .any((key) => data[key] is! String) ||
        !RegExp(r'^[a-f0-9]{32}$').hasMatch(data['id']) ||
        !['pending', 'approved', 'rejected', 'archived']
            .contains(data['status']) ||
        ['revision', 'createdAtMillis', 'updatedAtMillis']
            .any((key) => data[key] is! int || data[key] < 0) ||
        (data['reason'] != null && data['reason'] is! String)) {
      throw const FormatException('Unsupported certification.');
    }
    return PrivateCoachCertification(
        id: data['id'],
        title: data['title'],
        issuer: data['issuer'],
        storagePath: data['storagePath'],
        status: data['status'],
        revision: data['revision'],
        createdAtMillis: data['createdAtMillis'],
        updatedAtMillis: data['updatedAtMillis'],
        reason: data['reason']);
  }
}

/// Evidence has no public download URL. The original local filename is discarded.
class CoachCertificationFile {
  CoachCertificationFile(Uint8List source)
      : bytes = Uint8List.fromList(source).asUnmodifiableView() {
    if (bytes.isEmpty || bytes.length > maxBytes) {
      throw const FormatException('Choose a file no larger than 5 MB.');
    }
    bool starts(List<int> prefix) =>
        bytes.length >= prefix.length &&
        List.generate(prefix.length, (i) => bytes[i] == prefix[i])
            .every((v) => v);
    contentType = starts([37, 80, 68, 70, 45])
        ? 'application/pdf'
        : starts([137, 80, 78, 71, 13, 10, 26, 10])
            ? 'image/png'
            : starts([255, 216, 255])
                ? 'image/jpeg'
                : throw const FormatException(
                    'Choose a PDF, JPEG or PNG file.');
  }
  static const maxBytes = 5 * 1024 * 1024;
  final Uint8List bytes;
  late final String contentType;
}
