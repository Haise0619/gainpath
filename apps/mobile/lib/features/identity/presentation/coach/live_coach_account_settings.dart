// Historical import compatibility. Both backends render CoachSettingsScreen.
import 'coach_settings_screen.dart';
export 'coach_settings_screen.dart';

@Deprecated('Use CoachSettingsScreen with CoachAccountGateway.')
typedef LiveCoachAccountSettings = CoachSettingsScreen;
