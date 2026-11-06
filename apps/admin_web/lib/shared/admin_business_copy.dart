/// Display-only wording. Stored provenance, IDs and authorization are untouched.
String adminBusinessDetail(String value) => value
    .replaceAll(
        'Persistent FYP fictional record · read-only', 'Managed record · read-only')
    .replaceAll(
        'Fictional observations; no real camera workout, accepted workout or rewards claim',
        'Recorded observations do not establish verified camera workouts, accepted results or rewards')
    .replaceAll('synthetic sessions', 'recorded sessions')
    .replaceAll('illustrative assignment, not an actual enrollment',
        'Recorded assignment; enrollment has not been activated')
    .replaceAll('simulation only; no entitlement', 'No active entitlement')
    .replaceAll('simulation only', 'No reservation or settlement')
    .replaceAll(
        'Fictional completed appointment', 'Recorded completed appointment')
    .replaceAll(
        'Fictional cancelled appointment', 'Recorded cancelled appointment')
    .replaceAll('Sample subscription', 'Subscription')
    .replaceAll('Sample appointment', 'Appointment');
