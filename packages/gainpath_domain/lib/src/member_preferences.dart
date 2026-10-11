import 'identity.dart';

/// Personal choices, separate from identity, entitlements and fitness data.
class MemberPreferences {
  const MemberPreferences({
    this.pushNotifications = false,
    this.emailUpdates = false,
    this.voiceCoaching = false,
  });

  final bool pushNotifications;
  final bool emailUpdates;
  final bool voiceCoaching;

  MemberPreferences copyWith({
    bool? pushNotifications,
    bool? emailUpdates,
    bool? voiceCoaching,
  }) =>
      MemberPreferences(
        pushNotifications: pushNotifications ?? this.pushNotifications,
        emailUpdates: emailUpdates ?? this.emailUpdates,
        voiceCoaching: voiceCoaching ?? this.voiceCoaching,
      );
}

abstract interface class MemberPreferencesRepository {
  SessionScope get scope;
  Future<MemberPreferences> load();
  Future<void> save(MemberPreferences preferences);
}

class MemberPreferencesException implements Exception {
  const MemberPreferencesException(this.message);
  final String message;
  @override
  String toString() => message;
}
