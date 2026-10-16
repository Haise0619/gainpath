import 'dart:typed_data';
import '../entities/account_photo.dart';

/// The signed-in Admin's own name, private photo and authoritative sign-in email.
/// An empty name clears the optional name and uses the email as the label.
abstract class AdminAccountContactRepository {
  Future<AdminAccountContact> load();
  Future<AdminAccountContact> save(AdminAccountContact original,
      {required String displayName,
      AccountPhoto? photo,
      bool removePhoto = false});
  Future<Uint8List?> readPhoto(AdminAccountContact account);
  Future<Uint8List?> loadCurrentPhoto();
  Future<AdminAccountContact> saveNotificationPreferences(
      AdminAccountContact original,
      {required bool pushAlerts,
      required bool emailAlerts,
      required bool weeklyDigest});
}

abstract class AdminAccountContactBaseline {}

class AdminAccountContact {
  const AdminAccountContact(
      {required this.displayName,
      required this.email,
      this.avatarPath = '',
      this.notificationPreferences,
      required this.editBaseline});
  final String displayName, email;
  final String avatarPath;

  /// Null means no choices have been saved. This does not enable delivery.
  final Map<String, bool>? notificationPreferences;
  final AdminAccountContactBaseline editBaseline;
}

class AdminAccountContactConflict implements Exception {
  const AdminAccountContactConflict();
}

class AdminAccountContactSessionChanged implements Exception {
  const AdminAccountContactSessionChanged();
}
