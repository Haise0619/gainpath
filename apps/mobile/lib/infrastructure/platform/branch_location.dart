import 'package:geolocator/geolocator.dart';

Future<({double latitude, double longitude})> locateNearbyGyms() async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    throw StateError('Turn on location services to find nearby gyms.');
  }
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission != LocationPermission.whileInUse &&
      permission != LocationPermission.always) {
    throw StateError('Location access is off. You can still browse branches.');
  }
  final point = await Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.medium,
      timeLimit: Duration(seconds: 12),
    ),
  );
  return (latitude: point.latitude, longitude: point.longitude);
}
