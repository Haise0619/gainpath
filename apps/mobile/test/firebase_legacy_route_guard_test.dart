import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_data/gainpath_data.dart';
import 'package:gainpath_data/identity.dart';
import 'package:gainpath_data/workout.dart';
import 'package:gainpath_identity/gainpath_identity.dart';
import 'package:gainpath_mobile/app/routing/feature_routes.dart';
import 'package:gainpath_mobile/features/membership/presentation/shared/billplz_checkout_screen.dart';
import 'package:gainpath_mobile/navigation/feature_navigation.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<void> open(WidgetTester tester, RouteSettings settings,
      {bool firebase = true}) async {
    final repository = InMemoryAuthRepository();
    await repository.signIn(
        email: 'member@example.com', password: 'password123');
    final auth = AuthBloc(repository: repository);
    addTearDown(() async {
      await auth.close();
      await repository.dispose();
    });
    await tester.pumpWidget(BlocProvider.value(
        value: auth,
        child: MaterialApp(
            onGenerateRoute: (settings) =>
                buildFeatureRoute(settings, firebase: firebase),
            home: Builder(
                builder: (context) => Scaffold(
                    body: TextButton(
                        onPressed: () => Navigator.pushNamed(
                            context, settings.name!,
                            arguments: settings.arguments),
                        child: const Text('Open feature')))))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open feature'));
    await tester.pumpAndSettle();
  }

  final routes = [
    const RouteSettings(name: FeatureNavigation.membership),
    const RouteSettings(
        name: FeatureNavigation.checkout,
        arguments: CheckoutArguments(amount: 75, description: 'Prototype')),
    RouteSettings(
        name: FeatureNavigation.coach,
        arguments: InMemoryCoachRepository().currentCoach),
    RouteSettings(
        name: FeatureNavigation.equipment,
        arguments: InMemoryEquipmentRepository().gymEquipment.first),
  ];
  for (final settings in routes) {
    testWidgets('Firebase ${settings.name} cannot enter a prototype flow',
        (tester) async {
      await open(tester, settings);
      expect(find.textContaining('not connected to Firebase'), findsOneWidget);
      expect(find.byType(BillplzCheckoutScreen), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('mock checkout preserves simulated payment navigation',
      (tester) async {
    await open(
        tester,
        const RouteSettings(
            name: FeatureNavigation.checkout,
            arguments: CheckoutArguments(amount: 75, description: 'Prototype')),
        firebase: false);
    expect(find.byType(BillplzCheckoutScreen), findsOneWidget);
    expect(find.textContaining('not connected to Firebase'), findsNothing);
  });

  test('unowned routes remain available to their existing route builders', () {
    expect(
        buildFeatureRoute(const RouteSettings(name: '/unowned'),
            firebase: true),
        isNull);
  });
}
