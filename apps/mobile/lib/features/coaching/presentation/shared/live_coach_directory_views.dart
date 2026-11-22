import 'dart:typed_data';
import 'dart:convert';
import '../../../../infrastructure/firebase/firebase_function_transport.dart';
import 'package:flutter/material.dart';
import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../member/browse_coaches_screen.dart';
import '../../../../presentation/shared/coach_profile_screen.dart';
import '../../../../presentation/shared/published_coach_presentation.dart';

/// Compatibility entry point; the original directory owns the presentation.
class LiveCoachDirectoryView extends StatelessWidget {
  const LiveCoachDirectoryView(
      {super.key,
      required this.repository,
      required this.isCurrent,
      required this.onOpen,
      this.bookingsBuilder});
  final CoachDirectoryRepository repository;
  final bool Function() isCurrent;
  final void Function(String) onOpen;
  final WidgetBuilder? bookingsBuilder;
  @override
  Widget build(BuildContext context) => BrowseCoachesScreen(
      live: true,
      liveRepository: repository,
      isCurrent: isCurrent,
      onOpenPublished: onOpen,
      bookingsBuilder: bookingsBuilder);
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
          branchNames: coach.statistics?.branchNames ?? const {},
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
  Widget build(BuildContext context) {
    Widget placeholder() => Container(
          width: widget.size,
          height: widget.size,
          decoration: const BoxDecoration(
            color: AppColors.primaryTint,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Icon(
              Icons.person_rounded,
              size: widget.size * 0.52,
              color: AppColors.primary,
            ),
          ),
        );

    return SizedBox(
        width: widget.size,
        height: widget.size,
        child: FutureBuilder<Uint8List?>(
            future: bytes,
            builder: (context, snapshot) {
              final data = snapshot.data;
              if (!widget.isCurrent() ||
                  !widget.coach.certificationVerified ||
                  data == null) {
                return placeholder();
              }
              return ClipOval(
                  child: Image.memory(data,
                      width: widget.size,
                      height: widget.size,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => placeholder()));
            }));
  }
}

/// Same protected loader for directory and recommendation avatars; never direct Storage reads.
Future<Uint8List?> loadPublishedCoachPhotoBytes(
    {required String organizationId,
    required String coachId,
    required String photoPath,
    required bool Function() isCurrent}) async {
  if (!isCurrent() ||
      !photoPath.startsWith(
          'orgs/$organizationId/coachProfilePhotos/$coachId/')) {
    return null;
  }
  try {
    final result = await firebaseCallable('getCoachPublishedPhotoCommand')
        .call({
      'schemaVersion': 1,
      'organizationId': organizationId,
      'coachId': coachId
    });
    if (!isCurrent()) return null;
    final data = Map<String, dynamic>.from(result.data as Map),
        encoded = data['bytesBase64'];
    if (data['schemaVersion'] != 1 ||
        data['photoPath'] != photoPath ||
        encoded is! String ||
        encoded.length > 7 * 1024 * 1024 ||
        !['image/jpeg', 'image/png', 'image/webp']
            .contains(data['contentType'])) {
      return null;
    }
    final bytes = base64Decode(encoded);
    return bytes.length <= 5 * 1024 * 1024 ? bytes : null;
  } catch (_) {
    return null;
  }
}

extension on PublishedCoachPhotoState {
  Future<Uint8List?> _readPhoto(String path) => loadPublishedCoachPhotoBytes(
      organizationId: widget.repository.scope.organizationId,
      coachId: widget.coach.id,
      photoPath: path,
      isCurrent: widget.isCurrent);
}
