import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_identity/gainpath_identity.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../application/coach_profile_cubit.dart';
import '../../application/coach_account_gateway.dart';
import 'coach_account_presentation.dart';
import 'coach_account_session_guard.dart';
import 'edit_coach_profile_screen.dart';
import 'coach_settings_screen.dart';
import 'certifications_screen.dart';

/// Canonical Coach account screen. Backends supply the same application contracts.
class CoachAccountScreen extends StatefulWidget {
  const CoachAccountScreen(
      {super.key,
      required this.profileRepository,
      required this.accountRepository,
      this.isCurrent,
      this.onSignOut});
  final CoachProfileRepository profileRepository;
  final CoachAccountGateway accountRepository;
  final bool Function()? isCurrent;
  final VoidCallback? onSignOut;
  @override
  State<CoachAccountScreen> createState() => _CoachAccountScreenState();
}

class _CoachAccountScreenState extends State<CoachAccountScreen> {
  late final controller = CoachProfileCubit(
      repository: widget.profileRepository, isCurrent: current)
    ..reload();
  bool current() => (widget.isCurrent ?? widget.accountRepository.isCurrent)();
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
    if (!current()) return;
    try {
      final response = await repository.loadCertificationSummary();
      if (!mounted || !current()) return;
      setState(() {
        approvedCount = response.approved;
        credentialsVerified = response.verified;
        pendingCount = response.pending;
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
    if (!current()) return;
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => CoachAccountSessionGuard(
                repository: repository, child: child)));
    if (mounted && current()) {
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
          : (widget.accountRepository.loadProfilePhoto(path))
              .catchError((_) => null);
    }
    return cachedPhoto!;
  }

  CoachAccountData dataFor(CoachProfileState state,
      CoachProfessionalFields? fields, ImageProvider? photo,
      {bool draftPreview = false}) {
    final publication = state.publication;
    final verified =
        credentialsVerified ?? publication?.certificationVerified ?? false;
    final published = publication?.isPublished == true && verified;
    final metrics = widget.accountRepository.metrics;
    return CoachAccountData(
        name: fields?.displayName ?? '-',
        specialty: fields?.specialty ?? '-',
        photo: photo ??
            (fields?.photoPath == null &&
                    widget.accountRepository.publicAvatarUrl != null
                ? NetworkImage(widget.accountRepository.publicAvatarUrl!)
                : null),
        branch: metrics.branch,
        rating: metrics.rating?.toString(),
        sessions: metrics.sessions?.toString(),
        reviews: metrics.reviews?.toString(),
        verified: verified,
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
    if (!current() || state.profile == null) return;
    final publication = state.publication;
    final draftBytes = await photoFor(
        state.profile!.fields.photoPath, state.profile!.revision);
    if (!mounted || !current()) return;
    final draft = dataFor(state, state.profile!.fields,
        draftBytes == null ? null : MemoryImage(draftBytes),
        draftPreview: true);
    CoachAccountData data = draft;
    if (publication != null) {
      Uint8List? bytes;
      try {
        bytes = await repository.loadProfilePhoto(publication.fields.photoPath);
      } catch (_) {
        bytes = null;
      }
      if (!mounted || !current()) return;
      data = dataFor(
          state, publication.fields, bytes == null ? null : MemoryImage(bytes));
    }
    final child = CoachAccountProfilePreview(
        data: data,
        label: publication == null
            ? 'Owner draft preview — not published'
            : publication.isPublished
                ? data.verified
                    ? 'Published directory snapshot — verified directory access'
                    : 'Directory snapshot — awaiting credential verification'
                : 'Inactive directory snapshot — hidden from members',
        draft: publication != null &&
                publication.sourceRevision != state.profile!.revision
            ? draft
            : null);
    try {
      repository.check();
    } catch (_) {
      return;
    }
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => CoachAccountSessionGuard(
                repository: repository, child: child)));
  }

  Future<void> openEditor() async {
    await openAccount(EditCoachProfileScreen(
        controller: controller, accountRepository: widget.accountRepository));
  }

  Future<void> signOut() async {
    final confirmed = await confirmSheet(context,
        title: 'Sign out?',
        message: 'You will need to sign in again next time.',
        confirmLabel: 'Sign out',
        destructive: true);
    if (confirmed && mounted) {
      if (widget.onSignOut != null) {
        widget.onSignOut!();
      } else {
        context.read<AuthBloc>().add(const LoggedOut());
      }
    }
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
            final ready = state.status == CoachProfileStatus.ready && current();
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
                      onSignOut: signOut,
                      onPreview: ready && state.profile != null
                          ? () => preview(state)
                          : null,
                      onEdit: ready ? openEditor : null,
                      onPhoto: ready ? openEditor : null,
                      onCertifications: ready
                          ? () => openAccount(CertificationsScreen(
                              repository: widget.accountRepository))
                          : null,
                      onSettings: ready
                          ? () => openAccount(CoachSettingsScreen(
                              repository: widget.accountRepository))
                          : null);
                });
          });
}
