import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_domain/identity.dart' show MemberProfileRepository;
import 'package:gainpath_identity/gainpath_identity.dart';

import 'profile_setup_screen.dart';

/// Loads the account-owned profile before building connected member content.
class FitnessProfileGate extends StatefulWidget {
  const FitnessProfileGate(
      {super.key,
      required this.session,
      required this.repository,
      required this.readyBuilder});
  final AuthSession session;
  final FitnessProfileRepository repository;
  final Widget Function(BuildContext context, FitnessProfile profile)
      readyBuilder;

  @override
  State<FitnessProfileGate> createState() => _FitnessProfileGateState();
}

class _FitnessProfileGateState extends State<FitnessProfileGate> {
  late FitnessProfileCubit _cubit;

  @override
  void initState() {
    super.initState();
    _createCubit();
  }

  void _createCubit() {
    if (widget.repository.scope != widget.session.scope) {
      throw ArgumentError(
          'Profile repository must belong to the signed-in account.');
    }
    _cubit = FitnessProfileCubit(widget.repository)..load();
  }

  @override
  void didUpdateWidget(FitnessProfileGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.repository, widget.repository) ||
        !identical(oldWidget.session, widget.session)) {
      _cubit.close();
      _createCubit();
    }
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  void _signOut() => context.read<AuthBloc>().add(const LoggedOut());

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<FitnessProfileCubit, FitnessProfileState>(
        bloc: _cubit,
        builder: (context, state) {
          if (state.status == FitnessProfileStatus.missing ||
              (state.status == FitnessProfileStatus.saving &&
                  state.profile == null)) {
            return ProfileSetupScreen(
              initialProfile: state.profile,
              onExit: _signOut,
              onReload: _cubit.load,
              onSave: (profile) async {
                await _cubit.save(profile);
              },
            );
          }
          if (state.status == FitnessProfileStatus.ready ||
              (state.status == FitnessProfileStatus.saving &&
                  state.profile != null)) {
            return RepositoryProvider<MemberProfileRepository>.value(
              value: _LiveMemberProfileRepository(widget.session, _cubit),
              child: BlocProvider.value(
                value: _cubit,
                child: Builder(
                  builder: (context) =>
                      widget.readyBuilder(context, state.profile!),
                ),
              ),
            );
          }
          return Scaffold(
            appBar: AppBar(title: const Text('My fitness profile'), actions: [
              TextButton(onPressed: _signOut, child: const Text('Sign out')),
            ]),
            body: switch (state.status) {
              FitnessProfileStatus.loading =>
                const Center(child: CircularProgressIndicator()),
              FitnessProfileStatus.loadFailure => Center(
                    child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(state.error!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(
                        onPressed: _cubit.load, child: const Text('Retry')),
                  ]),
                )),
              _ => const Center(child: CircularProgressIndicator()),
            },
          );
        },
      );
}

class _LiveMemberProfileRepository implements MemberProfileRepository {
  _LiveMemberProfileRepository(this.session, this.cubit);
  final AuthSession session;
  final FitnessProfileCubit cubit;
  FitnessProfile get profile => cubit.state.profile!;

  @override
  String get memberName => session.displayName?.trim().isNotEmpty == true
      ? session.displayName!.trim()
      : session.email.split('@').first;
  @override
  String get memberEmail => session.email;
  @override
  String get memberTier => 'Not linked';
  @override
  String get memberGender => profile.gender.label;
  @override
  int? get memberAge => profile.age;
  @override
  int get memberHeight => profile.heightCm;
  @override
  int get memberWeight => profile.weightKg;
  @override
  String get memberExperience => profile.experience.label;
  @override
  String get memberActivityLevel => profile.activity.label;
  @override
  List<String> get memberTrainingFocus =>
      profile.goals.map((goal) => goal.label).toList();
}
