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
      required this.onOpen});
  final CoachDirectoryRepository repository;
  final bool Function() isCurrent;
  final void Function(String) onOpen;
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
                          const Icon(Icons.person_outline, size: 40),
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
              const Text(
                  'Booking is unavailable until availability and booking integration are completed.'),
            ]));
      });
}

class LiveCoachDetailView extends StatefulWidget {
  const LiveCoachDetailView(
      {super.key,
      required this.coachId,
      required this.repository,
      required this.isCurrent});
  final String coachId;
  final CoachDirectoryRepository repository;
  final bool Function() isCurrent;
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
                    const Icon(Icons.person_outline,
                        color: Colors.white, size: 64),
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
              Text(coach.fields.specializationTags.join(' · ')),
              Text('Branches: ${coach.branchIds.join(', ')}'),
              if (coach.fields.yearsExperience != null)
                Text(
                    '${coach.fields.yearsExperience} years experience (self-reported)'),
              const SizedBox(height: 18),
              const Text(
                  'Directory publication does not verify certifications. Booking is unavailable.')
            ]);
          }));
}
