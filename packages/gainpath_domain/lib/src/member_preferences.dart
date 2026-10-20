import 'identity.dart';

/// Personal choices, separate from identity, entitlements and fitness data.
class MemberPreferences {
  const MemberPreferences({
    this.pushNotifications = false,
    this.emailUpdates = false,
    this.voiceCoaching = false,
    this.editBaseline,
  });

  final bool pushNotifications;
  final bool emailUpdates;
  final bool voiceCoaching;

  /// Opaque repository provenance; never serialized as a preference field.
  final Object? editBaseline;

  MemberPreferences copyWith({
    bool? pushNotifications,
    bool? emailUpdates,
    bool? voiceCoaching,
  }) =>
      MemberPreferences(
        pushNotifications: pushNotifications ?? this.pushNotifications,
        emailUpdates: emailUpdates ?? this.emailUpdates,
        voiceCoaching: voiceCoaching ?? this.voiceCoaching,
        editBaseline: editBaseline,
      );
}

abstract interface class MemberPreferencesRepository {
  SessionScope get scope;
  Future<MemberPreferences> load();
  Future<void> save(MemberPreferences preferences);
}

class MemberPreferencesException implements Exception {
  const MemberPreferencesException(this.message, {this.reloadRequired = false});
  final String message;
  final bool reloadRequired;
  @override
  String toString() => message;
}
