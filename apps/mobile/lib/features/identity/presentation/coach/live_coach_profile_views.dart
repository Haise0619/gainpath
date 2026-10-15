import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../application/coach_profile_cubit.dart';

class LiveCoachAccountView extends StatefulWidget {
  const LiveCoachAccountView(
      {super.key,
      required this.repository,
      required this.isCurrent,
      required this.onSignOut,
      this.onOpenEditor});
  final CoachProfileRepository repository;
  final bool Function() isCurrent;
  final VoidCallback onSignOut;
  final void Function(CoachProfileCubit)? onOpenEditor;
  @override
  State<LiveCoachAccountView> createState() => _LiveCoachAccountViewState();
}

class _LiveCoachAccountViewState extends State<LiveCoachAccountView> {
  late final controller = CoachProfileCubit(
      repository: widget.repository, isCurrent: widget.isCurrent)
    ..reload();
  @override
  void dispose() {
    controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<CoachProfileCubit, CoachProfileState>(
          bloc: controller,
          builder: (context, state) => Scaffold(
              appBar: AppBar(title: const Text('My account'), actions: [
                IconButton(
                    tooltip: 'Refresh profile',
                    onPressed: state.saving ? null : controller.reload,
                    icon: const Icon(Icons.refresh))
              ]),
              body: PageBody(children: [
                if (state.status == CoachProfileStatus.loading)
                  const LinearProgressIndicator(),
                if (state.message != null) Text(state.message!),
                if (state.status == CoachProfileStatus.ready) ...[
                  Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                          gradient: AppColors.heroGradient,
                          borderRadius: BorderRadius.circular(20)),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                state.profile?.fields.displayName ??
                                    'Professional profile',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold)),
                            Text(
                                state.profile?.fields.specialty ??
                                    'No professional profile yet',
                                style: const TextStyle(color: Colors.white70)),
                          ])),
                  const SizedBox(height: 16),
                  Text(state.publication?.isPublished == true
                      ? 'Directory: published'
                      : state.publication == null
                          ? 'Directory: not published'
                          : 'Directory: inactive'),
                  Text(state.profile == null
                      ? 'Create a profile for Admin review.'
                      : state.publication?.isPublished == true &&
                              state.publication?.sourceRevision ==
                                  state.profile?.revision
                          ? 'Current profile is published. Publication is not certification verification.'
                          : 'Saved draft / pending Admin publication. Previous public content remains until Admin republishes or deactivates.'),
                  const SizedBox(height: 16),
                  if (state.profile != null)
                    Panel(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(state.profile!.fields.bio),
                          Text(state.profile!.fields.specializationTags
                              .join(' · ')),
                          if (state.profile!.fields.yearsExperience != null)
                            Text(
                                '${state.profile!.fields.yearsExperience} years experience (self-reported)')
                        ])),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                      onPressed: widget.onOpenEditor == null
                          ? null
                          : () => widget.onOpenEditor!(controller),
                      icon: const Icon(Icons.edit_note),
                      label: const Text('Edit professional profile')),
                  const SizedBox(height: 16),
                  const Text(
                      'Availability and pending bookings are available in their tabs. Certifications and earnings are unavailable.'),
                ],
                const SizedBox(height: 20),
                OutlinedButton.icon(
                    onPressed: widget.onSignOut,
                    icon: const Icon(Icons.logout),
                    label: const Text('Sign out')),
              ])));
}

class LiveCoachProfileEditor extends StatefulWidget {
  const LiveCoachProfileEditor({super.key, required this.controller});
  final CoachProfileCubit controller;
  @override
  State<LiveCoachProfileEditor> createState() => _LiveCoachProfileEditorState();
}

class _LiveCoachProfileEditorState extends State<LiveCoachProfileEditor> {
  final name = TextEditingController(),
      specialty = TextEditingController(),
      bio = TextEditingController(),
      tags = TextEditingController(),
      years = TextEditingController();
  String? validation;
  @override
  void initState() {
    super.initState();
    _reset();
  }

  void _reset() {
    final fields = widget.controller.state.profile?.fields;
    name.text = fields?.displayName ?? '';
    specialty.text = fields?.specialty ?? '';
    bio.text = fields?.bio ?? '';
    tags.text = fields?.specializationTags.join(', ') ?? '';
    years.text = fields?.yearsExperience?.toString() ?? '';
    validation = null;
  }

  @override
  void dispose() {
    for (final c in [name, specialty, bio, tags, years]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    try {
      final raw = years.text.trim(),
          parsed = raw.isEmpty ? null : int.tryParse(raw);
      if (raw.isNotEmpty && parsed == null) throw const FormatException();
      final fields = CoachProfessionalFields(
          displayName: name.text,
          specialty: specialty.text,
          bio: bio.text,
          specializationTags: tags.text
              .split(',')
              .map((t) => t.trim())
              .where((t) => t.isNotEmpty)
              .toList(),
          yearsExperience: parsed);
      setState(() => validation = null);
      await widget.controller.save(fields);
    } on FormatException {
      if (mounted) {
        setState(() => validation =
            'Check name, specialty, tags, bio and nullable whole-year experience.');
      }
    }
  }

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<CoachProfileCubit, CoachProfileState>(
          bloc: widget.controller,
          builder: (context, state) {
            final enabled = state.status == CoachProfileStatus.ready &&
                !state.saving &&
                !state.conflict;
            return Scaffold(
                appBar: AppBar(title: const Text('Edit profile')),
                body: PageBody(children: [
                  const Text(
                      'Save a draft for Admin publication. Experience is self-reported.'),
                  for (final entry in [
                    (name, 'Display name', 80),
                    (specialty, 'Specialty', 80),
                    (bio, 'Bio', 1000),
                    (tags, 'Specialization tags (comma separated)', 334),
                    (years, 'Years experience (optional)', 2)
                  ])
                    TextField(
                        controller: entry.$1,
                        enabled: enabled,
                        maxLength: entry.$3,
                        maxLines: entry.$1 == bio ? 5 : 1,
                        decoration: InputDecoration(labelText: entry.$2)),
                  if (validation != null) Text(validation!),
                  if (state.message != null) Text(state.message!),
                  FilledButton(
                      onPressed: enabled ? _save : null,
                      child: Text(state.saving ? 'Saving…' : 'Save profile')),
                  TextButton(
                      onPressed: state.saving
                          ? null
                          : () async {
                              await widget.controller.reload();
                              if (mounted &&
                                  widget.controller.state.status ==
                                      CoachProfileStatus.ready) {
                                setState(_reset);
                              }
                            },
                      child: const Text('Discard and reload')),
                ]));
          });
}
