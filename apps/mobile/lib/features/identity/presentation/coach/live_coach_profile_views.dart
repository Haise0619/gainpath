import 'dart:typed_data';
import 'coach_account_presentation.dart';
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
  int? approvedCount, pendingCount;
  bool? credentialsVerified;
  String? cachedPhotoPath;
  int? cachedPhotoRevision;
  Future<Uint8List?>? cachedPhoto;
  @override
  void initState() {
    super.initState();
    loadCertificationSummary();
  }

  Future<void> loadCertificationSummary() async {
    final repository = widget.accountRepository;
    if (repository == null || !widget.isCurrent()) return;
    try {
      final response =
          await repository.command('getCoachCertificationsCommand');
      final count = response['approvedCount'],
          entries = response['certifications'];
      if (!mounted || !widget.isCurrent()) return;
      if (response['schemaVersion'] != 1 ||
          count is! int ||
          count < 0 ||
          response['certificationVerified'] is! bool ||
          entries is! List) {
        return;
      }
      setState(() {
        approvedCount = count;
        credentialsVerified =
            response['certificationVerified'] == true && count > 0;
        pendingCount = response['nextCursor'] == null
            ? entries
                .where((entry) => entry is Map && entry['status'] == 'pending')
                .length
            : null;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          approvedCount = null;
          pendingCount = null;
          credentialsVerified = null;
        });
      }
    }
  }

  Future<void> openAccount(Widget child) async {
    final repository = widget.accountRepository;
    if (repository == null || !widget.isCurrent()) return;
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => CoachAccountSessionGuard(
                repository: repository, child: child)));
    if (mounted && widget.isCurrent()) {
      await controller.reload();
      await loadCertificationSummary();
    }
  }

  Future<void> refresh() async {
    // An explicit retry must also recover a failed image fetch at this revision.
    cachedPhoto = null;
    await controller.reload();
    await loadCertificationSummary();
  }

  Future<Uint8List?> photoFor(String? path, int revision) {
    if (cachedPhoto == null ||
        cachedPhotoPath != path ||
        cachedPhotoRevision != revision) {
      cachedPhotoPath = path;
      cachedPhotoRevision = revision;
      cachedPhoto = path == null
          ? Future.value(null)
          : (widget.accountRepository?.loadProfilePhoto(path) ??
                  Future<Uint8List?>.value(null))
              .catchError((_) => null);
    }
    return cachedPhoto!;
  }

  CoachAccountData dataFor(CoachProfileState state,
      CoachProfessionalFields? fields, ImageProvider? photo,
      {bool draftPreview = false}) {
    final publication = state.publication;
    final published = publication?.isPublished == true;
    return CoachAccountData(
        name: fields?.displayName ?? '-',
        specialty: fields?.specialty ?? '-',
        photo: photo,
        verified:
            credentialsVerified ?? publication?.certificationVerified ?? false,
        published: published && !draftPreview,
        directoryLabel: draftPreview
            ? 'Draft — not published'
            : published
                ? 'Live in directory'
                : publication == null
                    ? 'Not published in directory'
                    : 'Inactive in directory',
        experience: fields?.yearsExperience == null
            ? null
            : '${fields!.yearsExperience}y',
        approvedCertifications: approvedCount ??
            (publication?.certificationVerified == true
                ? publication!.approvedCertificationCount
                : null),
        pendingCertifications: pendingCount,
        publicationStatus: published
            ? 'Directory: published'
            : publication == null
                ? 'Directory: not published'
                : 'Directory: inactive',
        publicationMessage: state.profile == null
            ? 'Create a profile for Admin review.'
            : published &&
                    publication?.sourceRevision == state.profile?.revision
                ? 'Current profile is published. Credentials are verified separately by Admin.'
                : 'Saved draft / pending Admin publication. Previous public content remains until Admin republishes or deactivates.',
        bio: fields?.bio,
        tags: fields?.specializationTags ?? const [],
        fee: fields?.consultationFeeMinor == null
            ? null
            : 'MYR ${(fields!.consultationFeeMinor! / 100).toStringAsFixed(2)}');
  }

  Future<void> preview(CoachProfileState state) async {
    final repository = widget.accountRepository;
    if (!widget.isCurrent() || state.profile == null) return;
    final publication = state.publication;
    final draftBytes = await photoFor(
        state.profile!.fields.photoPath, state.profile!.revision);
    if (!mounted || !widget.isCurrent()) return;
    final draft = dataFor(state, state.profile!.fields,
        draftBytes == null ? null : MemoryImage(draftBytes),
        draftPreview: true);
    CoachAccountData data = draft;
    if (publication != null) {
      Uint8List? bytes;
      try {
        bytes =
            await repository?.loadProfilePhoto(publication.fields.photoPath);
      } catch (_) {
        bytes = null;
      }
      if (!mounted || !widget.isCurrent()) return;
      data = dataFor(
          state, publication.fields, bytes == null ? null : MemoryImage(bytes));
    }
    final child = CoachAccountProfilePreview(
        data: data,
        label: publication == null
            ? 'Owner draft preview — not published'
            : publication.isPublished
                ? 'Published directory snapshot — what members can see'
                : 'Inactive directory snapshot — hidden from members',
        draft: publication != null &&
                publication.sourceRevision != state.profile!.revision
            ? draft
            : null);
    if (repository != null) {
      try {
        repository.check();
      } catch (_) {
        return;
      }
    }
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => repository == null
                ? child
                : CoachAccountSessionGuard(
                    repository: repository, child: child)));
  }

  @override
  void dispose() {
    cachedPhoto = null;
    controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<CoachProfileCubit, CoachProfileState>(
          bloc: controller,
          builder: (context, state) {
            final ready =
                state.status == CoachProfileStatus.ready && widget.isCurrent();
            return FutureBuilder<Uint8List?>(
                key: ValueKey(
                    (state.profile?.fields.photoPath, state.profile?.revision)),
                future: ready
                    ? photoFor(state.profile?.fields.photoPath,
                        state.profile?.revision ?? 0)
                    : null,
                builder: (context, snapshot) {
                  final bytes = ready &&
                          snapshot.connectionState == ConnectionState.done &&
                          !snapshot.hasError
                      ? snapshot.data
                      : null;
                  final data = dataFor(state, state.profile?.fields,
                      bytes == null ? null : MemoryImage(bytes));
                  return CoachAccountPresentation(
                      data: data,
                      loading: state.status == CoachProfileStatus.loading,
                      message: state.message,
                      onRefresh: refresh,
                      onSignOut: widget.onSignOut,
                      onPreview: ready && state.profile != null
                          ? () => preview(state)
                          : null,
                      onEdit: ready && widget.onOpenEditor != null
                          ? () => widget.onOpenEditor!(controller)
                          : null,
                      onPhoto: ready && widget.onOpenEditor != null
                          ? () => widget.onOpenEditor!(controller)
                          : null,
                      onCertifications:
                          ready && widget.accountRepository != null
                              ? () => openAccount(LiveCoachCertifications(
                                  repository: widget.accountRepository!))
                              : null,
                      onSettings: ready && widget.accountRepository != null
                          ? () => openAccount(LiveCoachAccountSettings(
                              repository: widget.accountRepository!))
                          : null);
                });
          });
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
      if (mounted &&
          (widget.controller.state.profile?.revision ?? 0) > priorRevision) {
        setState(_reset);
      }
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
