import 'dart:typed_data';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_mobile/features/identity/application/coach_account_gateway.dart';

class CoachAccountGatewayFake implements CoachAccountGateway {
  bool failAvatar = false;
  @override
  final scope = SessionScope(userId: 'coach', organizationId: 'o');
  @override
  bool Function() get isCurrent => () => true;
  @override
  String get email => 'coach@example.test';
  @override
  String? get publicAvatarUrl => null;
  @override
  bool get passwordManagementAvailable => false;
  @override
  CoachAccountMetrics get metrics => const CoachAccountMetrics();
  @override
  void check() {}
  @override
  Future<CoachCertificationSummary> loadCertificationSummary() async =>
      const CoachCertificationSummary(approved: 0, pending: 0, verified: false);
  @override
  Future<Uint8List?> loadProfilePhoto(String? path) async {
    if (failAvatar) throw const FormatException('Invalid image');
    return null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
