import 'package:flutter/material.dart';
import 'package:gainpath_identity/gainpath_identity.dart';
import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'coach_account_presentation.dart';
import 'certifications_screen.dart';
import 'coach_settings_screen.dart';
import 'live_coach_profile_views.dart';
import '../../application/coach_profile_cubit.dart';
import 'edit_coach_profile_screen.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../infrastructure/firebase/firebase_coach_account_repository.dart';

/// AD-M8.3 — Coach Account & Profile Management hub. Deliberately framed
/// as a *professional identity* screen, not a personal one: where the
/// member profile leads with body stats and a "Premium member" badge,
/// this leads with directory status, verification, and business metrics —
/// what a coach running a practice actually cares about. Renamed from the
/// old `CoachProfileScreen` so it no longer collides with the
/// member-facing public coach page, which this screen can now open as a
/// live preview.
class CoachAccountScreen extends StatefulWidget {
  const CoachAccountScreen(
      {super.key,
      this.liveRepository,
      this.isCurrent,
      this.onOpenLiveEditor,
      this.accountRepository});
  final FirebaseCoachAccountRepository? accountRepository;
  final CoachProfileRepository? liveRepository;
  final bool Function()? isCurrent;
  final void Function(CoachProfileCubit)? onOpenLiveEditor;

  @override
  State<CoachAccountScreen> createState() => _CoachAccountScreenState();
}

class _CoachAccountScreenState extends State<CoachAccountScreen> {
  Future<void> _open(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    if (mounted) setState(() {}); // refresh cert counts / edited bio on return
  }

  @override
  Widget build(BuildContext context) {
    if (widget.liveRepository != null) {
      return LiveCoachAccountView(
          accountRepository: widget.accountRepository,
          repository: widget.liveRepository!,
          isCurrent: widget.isCurrent!,
          onSignOut: _signOut,
          onOpenEditor: widget.onOpenLiveEditor);
    }
    final coach = context.read<CoachRepository>().currentCoach;
    final verifiedCerts = context
        .read<CoachRepository>()
        .coachCertifications
        .where((c) => c.status == CertificationStatus.verified)
        .length;
    final pendingCerts = context
        .read<CoachRepository>()
        .coachCertifications
        .where((c) => c.status == CertificationStatus.pendingReview)
        .length;

    final data = CoachAccountData(
        name: coach.name,
        specialty: coach.specialty,
        photo: NetworkImage(coach.imageUrl),
        verified: coach.verified,
        published: true,
        directoryLabel: 'Live in directory',
        branch: coach.branch,
        rating: '${coach.rating}',
        sessions: '${coach.sessionsCompleted}',
        experience: '${coach.yearsExperience}y',
        reviews: '${coach.reviews}',
        approvedCertifications: verifiedCerts,
        pendingCertifications: pendingCerts,
        bio: coach.bio,
        tags: coach.specializationTags,
        fee: 'MYR ${coach.fee.toStringAsFixed(2)}');
    return CoachAccountPresentation(
        data: data,
        onSignOut: _signOut,
        onPreview: () => _open(CoachAccountProfilePreview(
            data: data, label: 'Public profile preview')),
        onEdit: () => _open(const EditCoachProfileScreen()),
        onCertifications: () => _open(const CertificationsScreen()),
        onPhoto: () =>
            showToast(context, 'Photo upload is not part of this prototype.'),
        onSettings: () => _open(const CoachSettingsScreen()));
  }

  Future<void> _signOut() async {
    final ok = await confirmSheet(context,
        title: 'Sign out?',
        message: 'You will need to sign in again next time.',
        confirmLabel: 'Sign out',
        destructive: true);
    if (ok && mounted) {
      context.read<AuthBloc>().add(const LoggedOut());
    }
  }
}
