import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../../app/routing/branch_directions.dart';

class BookingLocation extends StatefulWidget {
  const BookingLocation({
    super.key,
    required this.bookingId,
    this.organizationId,
    this.showName = false,
  });

  final String bookingId;
  final String? organizationId;
  final bool showName;

  @override
  State<BookingLocation> createState() => _BookingLocationState();
}

class _BookingLocationState extends State<BookingLocation> {
  late Future<Map?> _location = _load();

  @override
  void didUpdateWidget(covariant BookingLocation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bookingId != widget.bookingId ||
        oldWidget.organizationId != widget.organizationId) {
      _location = _load();
    }
  }

  Future<Map?> _load() async {
    try {
      final auth = FirebaseAuth.instance;
      final uid = auth.currentUser?.uid;
      if (uid == null) return null;
      final organizationId = widget.organizationId ??
          (await FirebaseFirestore.instance.collection('users').doc(uid).get())
              .data()?['organizationId'];
      if (organizationId is! String || auth.currentUser?.uid != uid) {
        return null;
      }
      final response =
          await FirebaseFunctions.instanceFor(region: 'asia-southeast1')
              .httpsCallable('branchManagementCommand')
              .call({
        'action': 'bookingLocation',
        'organizationId': organizationId,
        'bookingId': widget.bookingId
      });
      final data = response.data;
      if (auth.currentUser?.uid != uid || data is! Map) return null;
      final branch = data['branch'];
      return branch is Map ? branch : null;
    } on FirebaseException {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map?>(
        key: ValueKey((widget.organizationId, widget.bookingId)),
        future: _location,
        builder: (context, snapshot) {
          final location = snapshot.data;
          if (location == null) return const SizedBox.shrink();
          final address = location['address'];
          final name = location['displayName'];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.showName && name is String && name.trim().isNotEmpty)
                Text(name, style: Theme.of(context).textTheme.titleSmall),
              if (address is String && address.trim().isNotEmpty)
                Text(address, style: Theme.of(context).textTheme.bodySmall),
              if (branchDestination(location) != null)
                TextButton.icon(
                  onPressed: () => openBranchDirections(context, location),
                  icon: const Icon(Icons.directions_outlined),
                  label: const Text('Get directions'),
                ),
            ],
          );
        },
      );
}
