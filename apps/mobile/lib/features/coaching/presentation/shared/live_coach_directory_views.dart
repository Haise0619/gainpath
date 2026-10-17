import 'dart:typed_data';
import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../application/coach_directory_cubit.dart';

class LiveCoachDirectoryView extends StatefulWidget {
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
  State<LiveCoachDirectoryView> createState() => _LiveCoachDirectoryViewState();
}

class _LiveCoachDirectoryViewState extends State<LiveCoachDirectoryView> {
  late final controller = CoachDirectoryCubit(
      repository: widget.repository, isCurrent: widget.isCurrent)
    ..refresh();
  String search = '';
  @override
  void dispose() {
    controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<CoachDirectoryCubit,
          CoachDirectoryState>(
      bloc: controller,
      builder: (context, state) {
        final q = search.trim().toLowerCase();
        final entries = state.items.where((c) =>
            '${c.fields.displayName} ${c.fields.specialty} ${c.fields.specializationTags.join(' ')}'
                .toLowerCase()
                .contains(q));
        return Scaffold(
            appBar: AppBar(title: const Text('Coaches'), actions: [
              if (widget.onOpenBookings != null)
                TextButton(
                    onPressed: widget.onOpenBookings,
                    child: const Text('My bookings')),
              IconButton(
                  tooltip: 'Refresh Coaches',
                  onPressed: state.loading ? null : controller.refresh,
                  icon: const Icon(Icons.refresh))
            ]),
            body: PageBody(children: [
              TextField(
                  decoration: const InputDecoration(
                      labelText: 'Search loaded Coaches',
                      prefixIcon: Icon(Icons.search)),
                  onChanged: (value) => setState(() => search = value)),
              const SizedBox(height: 12),
              if (state.loading) const LinearProgressIndicator(),
              if (state.message != null) Text(state.message!),
              if (!state.loading &&
                  state.message == null &&
                  state.items.isEmpty)
                const Text(
                    'No published Coaches are available for this organization.'),
              if (!state.loading && state.items.isNotEmpty && entries.isEmpty)
                const Text('No matches in the loaded page(s).'),
              for (final coach in entries)
                Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Panel(
                        onTap: () => widget.onOpen(coach.id),
                        child: Row(children: [
                          _PublishedCoachPhoto(
                              coach: coach,
                              repository: widget.repository,
                              isCurrent: widget.isCurrent,
                              size: 40),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(coach.fields.displayName,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium),
                                Text(coach.fields.specialty),
                                Text(_consultationFee(coach)),
                                if (coach.certificationVerified)
                                  const Text('Certification verified'),
                                Text('Branches: ${coach.branchIds.join(', ')}'),
                                Text(
                                    coach.fields.specializationTags.join(' · '))
                              ])),
                          const Icon(Icons.chevron_right)
                        ]))),
              if (state.nextCursor != null)
                TextButton(
                    onPressed: state.loadingMore ? null : controller.loadMore,
                    child: Text(
                        state.loadingMore ? 'Loading…' : 'Load more Coaches')),
              Text(widget.onOpenBookings == null
                  ? 'Booking is unavailable until availability and booking integration are completed.'
                  : 'Choose a published Coach to request a pending hold. My bookings remains available for existing records.'),
            ]));
      });
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
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Coach profile'), actions: [
        IconButton(
            tooltip: 'Refresh profile',
            onPressed: () => setState(() {
                  future = widget.repository.loadPublished(widget.coachId);
                }),
            icon: const Icon(Icons.refresh))
      ]),
      body: FutureBuilder<PublishedCoachProfile?>(
          future: future,
          builder: (context, snapshot) {
            if (!widget.isCurrent()) {
              return const Center(
                  child: Text('Profile unavailable for this session.'));
            }
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return const Center(
                  child:
                      Text('Could not load Coach profile. Refresh to retry.'));
            }
            final coach = snapshot.data;
            if (coach == null) {
              return const Center(
                  child: Text('This Coach profile is no longer published.'));
            }
            return PageBody(children: [
              Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                      gradient: AppColors.heroGradient,
                      borderRadius: BorderRadius.circular(20)),
                  child: Column(children: [
                    _PublishedCoachPhoto(
                        coach: coach,
                        repository: widget.repository,
                        isCurrent: widget.isCurrent,
                        size: 64),
                    Text(coach.fields.displayName,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 22)),
                    Text(coach.fields.specialty,
                        style: const TextStyle(color: Colors.white70))
                  ])),
              const SizedBox(height: 18),
              const Eyebrow('About'),
              Panel(child: Text(coach.fields.bio)),
              const SizedBox(height: 18),
              Text(_consultationFee(coach)),
              if (coach.certificationVerified)
                const Text('Certification verified'),
              Text(coach.fields.specializationTags.join(' · ')),
              Text('Branches: ${coach.branchIds.join(', ')}'),
              if (coach.fields.yearsExperience != null)
                Text(
                    '${coach.fields.yearsExperience} years experience (self-reported)'),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                  onPressed: widget.onOpenSchedule,
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: const Text('View schedule')),
              if (widget.onOpenBooking != null)
                FilledButton(
                    onPressed: widget.onOpenBooking,
                    child: const Text('Choose time')),
              Text(widget.onOpenBooking == null
                  ? 'Booking is unavailable.'
                  : 'Consultation fees are profile information; existing booking prices are unchanged.')
            ]);
          }));
}

String _consultationFee(PublishedCoachProfile coach) {
  final minor = coach.fields.consultationFeeMinor;
  return minor == null
      ? 'Consultation fee not provided'
      : 'Consultation fee: MYR ${(minor / 100).toStringAsFixed(2)}';
}

class _PublishedCoachPhoto extends StatefulWidget {
  const _PublishedCoachPhoto(
      {required this.coach,
      required this.repository,
      required this.isCurrent,
      required this.size});
  final PublishedCoachProfile coach;
  final CoachDirectoryRepository repository;
  final bool Function() isCurrent;
  final double size;
  @override
  State<_PublishedCoachPhoto> createState() => _PublishedCoachPhotoState();
}

class _PublishedCoachPhotoState extends State<_PublishedCoachPhoto> {
  Future<Uint8List?>? bytes;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(covariant _PublishedCoachPhoto oldWidget) {
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
                data == null)
              return Icon(Icons.person_outline, size: widget.size);
            return ClipOval(
                child: Image.memory(data,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        Icon(Icons.person_outline, size: widget.size)));
          }));
}

extension on _PublishedCoachPhotoState {
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
            .contains(data['contentType'])) return null;
    final bytes = base64Decode(encoded);
    return bytes.length <= 5 * 1024 * 1024 ? bytes : null;
  }
}
