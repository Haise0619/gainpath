import 'dart:typed_data';
import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:gainpath_domain/identity.dart';
import '../member/browse_coaches_screen.dart';
import 'coach_profile_screen.dart';
import 'published_coach_presentation.dart';

/// Compatibility entry point; the original directory owns the presentation.
class LiveCoachDirectoryView extends StatelessWidget {
  const LiveCoachDirectoryView(
      {super.key,
      required this.repository,
      required this.isCurrent,
      required this.onOpen,
      this.onOpenBookings});
  final CoachDirectoryRepository repository;
  final bool Function() isCurrent;
  final void Function(String) onOpen;
  final VoidCallback? onOpenBookings;
  @override
  Widget build(BuildContext context) => BrowseCoachesScreen(
      live: true,
      liveRepository: repository,
      isCurrent: isCurrent,
      onOpenPublished: onOpen,
      onOpenBookings: onOpenBookings);
}

class LiveCoachDetailView extends StatefulWidget {
  const LiveCoachDetailView(
      {super.key,
      required this.coachId,
      required this.repository,
      required this.isCurrent,
      this.onOpenSchedule,
      this.onOpenBooking});
  final String coachId;
  final CoachDirectoryRepository repository;
  final bool Function() isCurrent;
  final VoidCallback? onOpenSchedule;
  final VoidCallback? onOpenBooking;
  @override
  State<LiveCoachDetailView> createState() => _LiveCoachDetailViewState();
}

class _LiveCoachDetailViewState extends State<LiveCoachDetailView> {
  late Future<PublishedCoachProfile?> future =
      widget.repository.loadPublished(widget.coachId);
  void _refresh() => setState(() {
        future = widget.repository.loadPublished(widget.coachId);
      });
  Widget _status(Widget child) => Scaffold(
      appBar: AppBar(title: const Text('Coach profile'), actions: [
        IconButton(
            tooltip: 'Refresh profile',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh))
      ]),
      body: child);
  @override
  Widget build(BuildContext context) => FutureBuilder<PublishedCoachProfile?>(
      future: future,
      builder: (context, snapshot) {
        if (!widget.isCurrent()) {
          return _status(const Center(
              child: Text('Profile unavailable for this session.')));
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return _status(const Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return _status(const Center(
              child: Text('Could not load Coach profile. Refresh to retry.')));
        }
        final coach = snapshot.data;
        if (coach == null) {
          return _status(const Center(
              child: Text('This Coach profile is no longer published.')));
        }
        return CoachProfileScreen(
          coach: publishedCoachPresentation(coach),
          published: coach,
          photo: PublishedCoachPhoto(
              coach: coach,
              repository: widget.repository,
              isCurrent: widget.isCurrent,
              size: 84),
          onRefresh: _refresh,
          onOpenSchedule: widget.onOpenSchedule,
          onOpenBooking: widget.onOpenBooking,
        );
      });
}

class PublishedCoachPhoto extends StatefulWidget {
  const PublishedCoachPhoto(
      {super.key,
      required this.coach,
      required this.repository,
      required this.isCurrent,
      required this.size});
  final PublishedCoachProfile coach;
  final CoachDirectoryRepository repository;
  final bool Function() isCurrent;
  final double size;
  @override
  State<PublishedCoachPhoto> createState() => PublishedCoachPhotoState();
}

class PublishedCoachPhotoState extends State<PublishedCoachPhoto> {
  Future<Uint8List?>? bytes;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(covariant PublishedCoachPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.coach != widget.coach) load();
  }

  void load() {
    final coach = widget.coach;
    final path = coach.fields.photoPath;
    final prefix =
        'orgs/${widget.repository.scope.organizationId}/coachProfilePhotos/${coach.id}/';
    bytes = widget.isCurrent() &&
            coach.isPublished &&
            coach.certificationVerified &&
            path != null &&
            path.startsWith(prefix)
        ? _readPhoto(path)
        : null;
  }

  @override
  Widget build(BuildContext context) => SizedBox(
      width: widget.size,
      height: widget.size,
      child: FutureBuilder<Uint8List?>(
          future: bytes,
          builder: (context, snapshot) {
            final data = snapshot.data;
            if (!widget.isCurrent() ||
                !widget.coach.certificationVerified ||
                data == null) {
              return Icon(Icons.person_outline, size: widget.size);
            }
            return ClipOval(
                child: Image.memory(data,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        Icon(Icons.person_outline, size: widget.size)));
          }));
}

extension on PublishedCoachPhotoState {
  Future<Uint8List?> _readPhoto(String path) async {
    if (!widget.isCurrent()) return null;
    final result = await FirebaseFunctions.instance
        .httpsCallable('getCoachPublishedPhotoCommand')
        .call({
      'schemaVersion': 1,
      'organizationId': widget.repository.scope.organizationId,
      'coachId': widget.coach.id,
    });
    if (!widget.isCurrent()) return null;
    final data = Map<String, dynamic>.from(result.data as Map);
    final encoded = data['bytesBase64'];
    if (data['schemaVersion'] != 1 ||
        data['photoPath'] != path ||
        encoded is! String ||
        encoded.length > 7 * 1024 * 1024 ||
        !['image/jpeg', 'image/png', 'image/webp']
            .contains(data['contentType'])) {
      return null;
    }
    final bytes = base64Decode(encoded);
    return bytes.length <= 5 * 1024 * 1024 ? bytes : null;
  }
}
