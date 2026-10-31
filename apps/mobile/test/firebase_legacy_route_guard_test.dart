import 'support/signed_out_firebase.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_data/gainpath_data.dart';
import 'package:gainpath_data/identity.dart';
import 'package:gainpath_data/workout.dart';
import 'package:gainpath_identity/gainpath_identity.dart';
import 'package:gainpath_mobile/app/routing/feature_routes.dart';
import 'package:gainpath_mobile/features/membership/presentation/shared/billplz_checkout_screen.dart';
import 'package:gainpath_mobile/features/membership/presentation/shared/membership_dashboard_screen.dart';
import 'package:gainpath_mobile/navigation/feature_navigation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gainpath_mobile/features/gamification/presentation/member/move_and_catch_view.dart';

void main() {
  setUpAll(setUpSignedOutFirebase);
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
    RouteSettings(
        name: FeatureNavigation.coach,
        arguments: InMemoryCoachRepository().currentCoach),
    RouteSettings(
        name: FeatureNavigation.equipment,
        arguments: InMemoryEquipmentRepository().gymEquipment.first),
  ];
  testWidgets('Firebase motion game opens consent without starting camera',
      (tester) async {
    await open(
        tester, const RouteSettings(name: FeatureNavigation.moveAndCatch));
    expect(find.byType(MoveAndCatchView), findsOneWidget);
    expect(find.text('Enable camera'), findsOneWidget);
    expect(find.textContaining('No video is saved'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
  for (final settings in routes) {
    testWidgets('Firebase ${settings.name} cannot enter a prototype flow',
        (tester) async {
      await open(tester, settings);
      expect(find.textContaining('not connected to Firebase'), findsOneWidget);
      expect(find.byType(BillplzCheckoutScreen), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'Firebase membership fails closed when trusted billing is unavailable',
      (tester) async {
    await open(tester, const RouteSettings(name: FeatureNavigation.membership));
    expect(find.byType(MembershipDashboardScreen), findsOneWidget);
    expect(
        tester
            .widget<MembershipDashboardScreen>(
                find.byType(MembershipDashboardScreen))
            .connected,
        isTrue);
    expect(
        find.textContaining('Membership could not be loaded.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Free'), findsNothing);
    expect(find.text('Renew now'), findsNothing);
    expect(find.text('Upgrade'), findsNothing);
    expect(find.byType(Switch), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Firebase checkout retains the shared UI with payment disabled',
      (tester) async {
    await open(
        tester,
        const RouteSettings(
            name: FeatureNavigation.checkout,
            arguments:
                CheckoutArguments(amount: 75, description: 'Prototype')));
    expect(find.byType(BillplzCheckoutScreen), findsOneWidget);
    expect(
        tester
            .widget<BillplzCheckoutScreen>(find.byType(BillplzCheckoutScreen))
            .connected,
        isTrue);
    expect(find.text('Payment service unavailable'), findsOneWidget);
    expect(find.text('RM 75.00'), findsNothing);
    expect(find.text('billplz.com/bill/checkout'), findsNothing);
    await tester.tap(find.text('Maybank2u'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Payment unavailable'))
            .onPressed,
        isNull);
    expect(tester.takeException(), isNull);
  });

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
