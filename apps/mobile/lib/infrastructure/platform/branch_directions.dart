import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

String? branchDestination(Map location) {
  final latitude = location['latitude'], longitude = location['longitude'];
  if (latitude is num &&
      longitude is num &&
      latitude.isFinite &&
      longitude.isFinite &&
      latitude.abs() <= 90 &&
      longitude.abs() <= 180) {
    return '$latitude,$longitude';
  }
  final address = location['address'];
  return address is String && address.trim().isNotEmpty ? address : null;
}

Future<void> openBranchDirections(BuildContext context, Map location) async {
  final destination = branchDestination(location);
  if (destination == null) return;
  final uri = Uri.https(
      'www.google.com', '/maps/dir/', {'api': '1', 'destination': destination});
  try {
    if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
  } catch (_) {
    // Keep inventory visible when a device cannot launch Maps.
  }
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open directions.')));
  }
}
