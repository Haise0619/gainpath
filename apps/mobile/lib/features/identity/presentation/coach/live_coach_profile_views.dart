import 'coach_unsaved_changes_guard.dart';
import 'coach_account_session_guard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../application/coach_profile_cubit.dart';
import '../../../../infrastructure/firebase/firebase_coach_account_repository.dart';
import 'live_coach_account_settings.dart';
import 'live_coach_certifications.dart';
import 'coach_photo_crop.dart';

class LiveCoachAccountView extends StatefulWidget {
  const LiveCoachAccountView(
      {super.key,
      required this.repository,
      required this.isCurrent,
      required this.onSignOut,
      this.onOpenEditor,
      this.accountRepository});
  final FirebaseCoachAccountRepository? accountRepository;
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
  Widget build(BuildContext context) => BlocBuilder<CoachProfileCubit,
          CoachProfileState>(
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
              if (state.profile?.fields.photoPath != null &&
                  widget.accountRepository != null)
                FutureBuilder(
                    future: widget.accountRepository!
                        .read(state.profile!.fields.photoPath!),
                    builder: (context, snapshot) => snapshot.hasData
                        ? SizedBox(
                            height: 140,
                            child: Image.memory(snapshot.data!,
                                gaplessPlayback: false))
                        : const ListTile(
                            leading: Icon(Icons.person),
                            title: Text('Professional profile photo'),
                            subtitle: Text('Private photo preview'))),
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
              Text(state.publication?.certificationVerified == true
                  ? 'Credentials: Admin approved'
                  : 'Credentials: no approved publication summary'),
              Text(state.profile?.fields.consultationFeeMinor == null
                  ? 'Consultation fee: not set'
                  : 'Consultation fee: MYR ${(state.profile!.fields.consultationFeeMinor! / 100).toStringAsFixed(2)}'),
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
                      Text(
                          state.profile!.fields.specializationTags.join(' · ')),
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
              if (widget.accountRepository != null) ...[
                ListTile(
                    leading: const Icon(Icons.workspace_premium),
                    title: const Text('Certifications'),
                    subtitle:
                        const Text('Private evidence and Admin review status'),
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => CoachAccountSessionGuard(
                                repository: widget.accountRepository!,
                                child: LiveCoachCertifications(
                                    repository: widget.accountRepository!))))),
                ListTile(
                    leading: const Icon(Icons.settings),
                    title: const Text('Settings'),
                    subtitle: const Text(
                        'Private contact details, notifications and password'),
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => CoachAccountSessionGuard(
                                repository: widget.accountRepository!,
                                child: LiveCoachAccountSettings(
                                    repository: widget.accountRepository!))))),
              ],
            ],
            const SizedBox(height: 20),
            OutlinedButton.icon(
                onPressed: widget.onSignOut,
                icon: const Icon(Icons.logout),
                label: const Text('Sign out')),
          ])));
}

class LiveCoachProfileEditor extends StatefulWidget {
  const LiveCoachProfileEditor(
      {super.key, required this.controller, this.accountRepository});
  final CoachProfileCubit controller;
  final FirebaseCoachAccountRepository? accountRepository;
  @override
  State<LiveCoachProfileEditor> createState() => _LiveCoachProfileEditorState();
}

class _LiveCoachProfileEditorState extends State<LiveCoachProfileEditor> {
  final name = TextEditingController(),
      specialty = TextEditingController(),
      bio = TextEditingController(),
      tags = TextEditingController(),
      years = TextEditingController(),
      fee = TextEditingController();
  String? photoPath;
  AccountPhoto? photo;
  bool photoBusy = false;
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
    fee.text = fields?.consultationFeeMinor == null
        ? ''
        : (fields!.consultationFeeMinor! / 100).toStringAsFixed(2);
    photoPath = fields?.photoPath;
    photo = null;
    validation = null;
  }

  @override
  void dispose() {
    for (final c in [name, specialty, bio, tags, years, fee]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    try {
      final raw = years.text.trim(),
          parsed = raw.isEmpty ? null : int.tryParse(raw);
      if (raw.isNotEmpty && parsed == null) throw const FormatException();
      final rawFee = fee.text.trim();
      if (rawFee.isNotEmpty &&
          !RegExp(r'^\d{1,5}(\.\d{1,2})?$').hasMatch(rawFee)) {
        throw const FormatException(
            'Enter a fee with up to two decimal places.');
      }
      final feeMinor =
          rawFee.isEmpty ? null : (double.parse(rawFee) * 100).round();
      if (feeMinor != null && feeMinor > 1000000) {
        throw const FormatException('Fee must be MYR 10,000 or less.');
      }
      if (photo != null && widget.accountRepository != null) {
        setState(() => photoBusy = true);
        photoPath = await widget.accountRepository!.upload(
            'coachProfilePhotos',
            FirebaseCoachAccountRepository.randomId(),
            photo!.bytes,
            photo!.contentType);
        if (!mounted) return;
        photo = null;
        if (mounted) setState(() => photoBusy = false);
      }
      final fields = CoachProfessionalFields(
          displayName: name.text,
          specialty: specialty.text,
          bio: bio.text,
          specializationTags: tags.text
              .split(',')
              .map((t) => t.trim())
              .where((t) => t.isNotEmpty)
              .toList(),
          yearsExperience: parsed,
          consultationFeeMinor: feeMinor,
          photoPath: photoPath);
      setState(() => validation = null);
      final priorRevision = widget.controller.state.profile?.revision ?? 0;
      await widget.controller.save(fields);
      if (mounted && (widget.controller.state.profile?.revision ?? 0) > priorRevision) setState(_reset);
    } on FormatException {
      if (mounted) {
        setState(() => validation =
            'Check name, specialty, bio, tags, experience and fee (MYR 0–10,000, up to two decimals).');
      }
    } catch (_) {
      if (mounted) {
        setState(() => validation = 'Could not upload the photo. Try again.');
      }
    } finally {
      if (mounted) setState(() => photoBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<CoachProfileCubit,
          CoachProfileState>(
      bloc: widget.controller,
      builder: (context, state) {
        final enabled = state.status == CoachProfileStatus.ready &&
            !state.saving &&
            !state.conflict &&
            !photoBusy;
        final fields = state.profile?.fields;
        final dirty = photo != null ||
            photoPath != fields?.photoPath ||
            name.text != (fields?.displayName ?? '') ||
            specialty.text != (fields?.specialty ?? '') ||
            bio.text != (fields?.bio ?? '') ||
            tags.text != (fields?.specializationTags.join(', ') ?? '') ||
            years.text != (fields?.yearsExperience?.toString() ?? '') ||
            fee.text !=
                (fields?.consultationFeeMinor == null
                    ? ''
                    : (fields!.consultationFeeMinor! / 100).toStringAsFixed(2));
        return CoachUnsavedChangesGuard(
            dirty: dirty,
            busy: state.saving || photoBusy,
            isCurrent: widget.accountRepository?.isCurrent ??
                () => !widget.controller.isClosed,
            child: Scaffold(
                appBar: AppBar(title: const Text('Edit profile')),
                body: PageBody(children: [
                  const Text(
                      'Save a draft for Admin publication. Experience is self-reported.'),
                  if (widget.accountRepository != null) ...[
                    if (photo != null)
                      SizedBox(height: 160, child: Image.memory(photo!.bytes)),
                    OutlinedButton.icon(
                        onPressed: enabled
                            ? () async {
                                try {
                                  final selected = await pickCoachPhoto(
                                      context, widget.accountRepository!);
                                  widget.accountRepository!.check();
                                  if (selected != null && mounted) {
                                    setState(() {
                                      photo = selected;
                                    });
                                  }
                                } catch (_) {
                                  if (mounted) {
                                    setState(() => validation =
                                        'Photo could not be opened. Check permission or choose another image.');
                                  }
                                }
                              }
                            : null,
                        icon: const Icon(Icons.photo_camera),
                        label: Text(photo != null
                            ? 'Change selected photo'
                            : photoPath != null
                                ? 'Replace profile photo'
                                : 'Add profile photo')),
                    TextButton(
                        onPressed: enabled
                            ? () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => CoachAccountSessionGuard(
                                        repository: widget.accountRepository!,
                                        child: LiveCoachCertifications(
                                            repository:
                                                widget.accountRepository!))))
                            : null,
                        child: const Text('Manage private certifications')),
                  ],
                  for (final entry in [
                    (name, 'Display name', 80),
                    (specialty, 'Specialty', 80),
                    (bio, 'Bio', 1000),
                    (tags, 'Specialization tags (comma separated)', 334),
                    (years, 'Years experience (optional)', 2),
                    (fee, 'Consultation fee (MYR, optional)', 8)
                  ])
                    TextField(
                        controller: entry.$1,
                        onChanged: (_) => setState(() {}),
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
                ])));
      });
}
