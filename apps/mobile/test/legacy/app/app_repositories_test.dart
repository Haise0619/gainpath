import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/mock_app_repositories.dart';
import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_domain/gamification.dart';

void main() {
  testWidgets('AppRepositories provides every repository to the subtree',
      (tester) async {
    BookingRepository? bookings;
    GamificationRepository? gamification;
    await tester.pumpWidget(
      MockAppRepositories(
        child: Builder(builder: (context) {
          bookings = context.read<BookingRepository>();
          gamification = context.read<GamificationRepository>();
          return const SizedBox();
        }),
      ),
    );
    expect(bookings, isNotNull);
    expect(bookings!.allBookings, isNotEmpty);
    expect(gamification!.points, greaterThan(0));
  });
}
