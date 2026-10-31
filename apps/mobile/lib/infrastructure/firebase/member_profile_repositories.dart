import 'package:gainpath_data/gainpath_data.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_domain/identity.dart';
import 'firebase_member_photo_gateway.dart';
import 'firebase_member_photo_store.dart';
import 'firebase_numeric_fitness_goal_gateway.dart';
import 'firebase_fitness_profile_gateway.dart';

MemberPhotoRepository createMemberPhotoRepository(
        SessionScope scope, bool Function() isCurrent) =>
    FirebaseMemberPhotoRepository(
        scope: scope,
        isCurrent: isCurrent,
        gateway: FlutterMemberPhotoGateway(scope: scope, isCurrent: isCurrent),
        photos: FirebaseAccountPhotoStore(scope: scope, isCurrent: isCurrent));

NumericFitnessGoalRepository createNumericFitnessGoalRepository(
        SessionScope scope, bool Function() isCurrent) =>
    FirebaseNumericFitnessGoalRepository(
        scope: scope,
        gateway: FlutterNumericFitnessGoalGateway(isSessionCurrent: isCurrent));

FitnessProfileRepository createReportFitnessProfileRepository(
        SessionScope scope, bool Function() isCurrent) =>
    FirebaseFitnessProfileRepository(
        scope: scope,
        gateway: FlutterFitnessProfileGateway(isSessionCurrent: isCurrent));
