import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gainpath/app/di/app_repositories.dart';
import 'package:gainpath/features/coaching/domain/repositories/booking_repository.dart';
import 'package:gainpath/features/gamification/domain/repositories/gamification_repository.dart';

void main() {
  testWidgets('AppRepositories provides every repository to the subtree', (tester) async {
    BookingRepository? bookings;
    GamificationRepository? gamification;
    await tester.pumpWidget(
      AppRepositories(
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
