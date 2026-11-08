import 'package:flutter/widgets.dart';

/// One authorized public-profile result shared by list and already-open details.
typedef BookingCoachInfo = ({String name, String? specialty, Widget? photo});

const BookingCoachInfo unavailableBookingCoachInfo =
    (name: 'Coach information unavailable', specialty: null, photo: null);
