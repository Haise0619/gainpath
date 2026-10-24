import 'package:gainpath_domain/coaching.dart';

typedef GoogleIntegrationCall = Future<Map<String, dynamic>> Function(
    String, Map<String, dynamic>);

/// Transport-neutral scoped adapter. Neither tokens nor Calendar IDs enter clients.
class ScopedGoogleIntegrationRepository implements GoogleIntegrationRepository {
  ScopedGoogleIntegrationRepository(
      {required this.organizationId,
      required this.userId,
      required this.isCurrent,
      required this.currentUid,
      required this.call});
  final String organizationId, userId;
  final bool Function() isCurrent;
  final String? Function() currentUid;
  final GoogleIntegrationCall call;
  bool _invalidated = false;
  void _check() {
    if (_invalidated || !isCurrent() || currentUid() != userId) {
      _invalidated = true;
      throw StateError('Account changed. Sign in again.');
    }
  }

  Future<Map<String, dynamic>> _run(
      String command, Map<String, dynamic> input) async {
    _check();
    final result =
        await call(command, {'organizationId': organizationId, ...input});
    _check();
    return result;
  }

  @override
  Future<GoogleIntegrationStatus> load({String? coachId}) async =>
      GoogleIntegrationStatus.fromJson(await _run('googleGymConnectionCommand',
          {'action': 'status', if (coachId != null) 'coachId': coachId}));
  @override
  Future<String> beginConnect() async {
    final d = await _run('googleGymConnectionCommand', {'action': 'connect'});
    final url = Uri.tryParse(d['authorizationUrl'] as String? ?? '');
    if (url == null ||
        url.scheme != 'https' ||
        url.host != 'accounts.google.com' ||
        url.path != '/o/oauth2/v2/auth' ||
        url.userInfo.isNotEmpty ||
        url.hasPort) {
      throw const FormatException('Invalid Google authorization link.');
    }
    return url.toString();
  }

  @override
  Future<void> disconnect() async {
    await _run('googleGymConnectionCommand',
        {'action': 'disconnect', 'confirmed': true});
  }

  @override
  Future<void> acknowledgeRevocation() async {
    await _run('googleGymConnectionCommand',
        {'action': 'acknowledgeRevocation', 'confirmed': true});
  }

  @override
  Future<void> createCoachCalendar(String coachId) async {
    await _run('googleGymConnectionCommand',
        {'action': 'createCalendar', 'coachId': coachId, 'confirmed': true});
  }

  @override
  Future<String> syncBooking(String bookingId, {required bool email}) async {
    final d = await _run('syncGymBookingCommand', {
      'bookingId': bookingId,
      'kind': email ? 'email' : 'calendar',
      'confirmed': true
    });
    if (!['sending', 'delivered', 'uncertain', 'reconciliation_required']
        .contains(d['status'])) {
      throw const FormatException('Invalid delivery status.');
    }
    return d['status'] as String;
  }
}
