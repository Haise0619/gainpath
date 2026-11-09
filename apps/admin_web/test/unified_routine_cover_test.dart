import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_domain/workout.dart';
import 'package:gainpath_admin_web/infrastructure/firebase/firebase_unified_admin.dart';
import 'package:gainpath_admin_web/infrastructure/firebase/unified_admin_content.dart';

class _Routines extends Fake
    implements RoutineTemplateRepository, RoutineCoverRepository {
  int uploads = 0;
  @override
  Future<RoutineBlueprint> saveWithCover(
      RoutineBlueprint b, EquipmentImage image) async {
    uploads++;
    return b;
  }
}

class _Catalog extends Fake implements TutorialRepository {}

void main() {
  test(
      'ordinary unified Admin forwards covers but blocks read-only/FYP/stale writes',
      () async {
    var current = true;
    final scope = SessionScope(userId: 'admin', organizationId: 'o'),
        canonical = _Routines();
    final transport = UnifiedAdminTransport(
        scope: scope,
        isCurrent: () => current,
        currentUid: () => scope.userId,
        invoke: (_) async => {});
    final repository = UnifiedAdminRoutines(transport, canonical, _Catalog());
    RoutineBlueprint blueprint(String id, {bool readOnly = false}) =>
        RoutineBlueprint(
            id: id,
            name: 'Routine',
            level: 'Beginner',
            assignedMembers: 0,
            days: [],
            readOnly: readOnly);
    final image = EquipmentImage(
        Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10, 0]));
    final entry = blueprint('r');
    expect(await repository.saveWithCover(entry, image), same(entry));
    for (final b in [
      blueprint('demo-m13-r'),
      blueprint('other', readOnly: true)
    ]) {
      await expectLater(Future.sync(() => repository.saveWithCover(b, image)),
          throwsA(isA<RoutineEditAuthorizationChanged>()));
    }
    current = false;
    await expectLater(Future.sync(() => repository.saveWithCover(entry, image)),
        throwsA(isA<RoutineEditAuthorizationChanged>()));
    expect(canonical.uploads, 1);
  });
}
