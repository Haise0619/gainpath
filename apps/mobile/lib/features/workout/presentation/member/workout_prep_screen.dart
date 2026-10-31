import 'dart:async';
import '../../domain/exercise_tracker_dispatcher.dart';
import '../../domain/published_routine_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_identity/gainpath_identity.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:gainpath_domain/workout.dart';
import 'equipment_scanner_screen.dart';
import 'camera_setup_screen.dart';
import 'exercise_tutorial_screen.dart';
import '../../../../navigation/workout_navigation.dart';
import 'routine_screen.dart';
import 'live_workout_screen.dart';
import 'widgets/workout_media.dart';

class WorkoutPrepScreen extends StatelessWidget {
  const WorkoutPrepScreen(
      {super.key,
      this.live = false,
      this.publishedRoutine,
      this.routineLoadFailed = false,
      this.routineStatusMessage,
      this.routineCatalogControls,
      this.onOpenEquipment,
      this.onOpenPrograms,
      this.trackers = const ExerciseTrackerDispatcher(),
      this.routes = const WorkoutPrepRoutes()});
  final bool live;
  final PublishedRoutine? publishedRoutine;
  final bool routineLoadFailed;
  final String? routineStatusMessage;
  final Widget? routineCatalogControls;
  final VoidCallback? onOpenEquipment;
  final VoidCallback? onOpenPrograms;
  final WorkoutPrepRoutes routes;
  final ExerciseTrackerDispatcher trackers;

  @override
  Widget build(BuildContext context) {
    final routine = live
        ? publishedRoutine?.exercises ?? <Exercise>[]
        : context.read<WorkoutRepository>().routine;
    final totalSets = routine.fold<int>(0, (sum, e) => sum + e.sets);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 200,
            backgroundColor: AppColors.primaryDark,
            foregroundColor: Colors.white,
            elevation: 0,
            titleTextStyle: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(color: Colors.white, fontSize: 18),
            title: const Text('Workout'),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  networkHero(live
                      ? (routine.isEmpty ? '' : routine.first.imageUrl)
                      : routineHeroImage),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.ink.withValues(alpha: 0.15),
                          AppColors.ink.withValues(alpha: 0.82),
                        ],
                      ),
                    ),
                  ),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                                live ? 'AVAILABLE ROUTINE' : 'TODAY\'S ROUTINE',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.1)),
                          ),
                          const SizedBox(height: 10),
                          Text(
                              live
                                  ? publishedRoutine?.title ??
                                      routineStatusMessage ??
                                      'No published routine yet'
                                  : 'Lower Body Strength',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(
                                      color: Colors.white, fontSize: 24)),
                          const SizedBox(height: 6),
                          Text(
                            live
                                ? publishedRoutine == null
                                    ? routineLoadFailed
                                        ? 'Could not load routines. Check your connection.'
                                        : 'Exercises, sets and duration unavailable'
                                    : '${routine.length} exercises  ·  $totalSets sets  ·  about ${publishedRoutine!.estimatedMinutes} min'
                                : '${routine.length} exercises  ·  $totalSets sets  ·  about 45 min',
                            style: TextStyle(
                                fontSize: 13,
                                color: Colors.white.withValues(alpha: 0.85)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
            sliver: SliverList.list(
              children: [
                if (onOpenPrograms != null) ...[
                  _DetourCard(
                      icon: Icons.calendar_month,
                      iconColor: AppColors.primary,
                      title: "Today's Workout",
                      subtitle:
                          'Your program, weekly schedule and saved progress',
                      onTap: onOpenPrograms!),
                  const SizedBox(height: 12),
                ],
                if (routineCatalogControls != null) ...[
                  routineCatalogControls!,
                  const SizedBox(height: 12),
                ],
                _DetourCard(
                  icon: Icons.play_circle_fill_rounded,
                  iconColor: AppColors.primary,
                  title: 'Watch tutorial',
                  subtitle: live
                      ? routine.isEmpty
                          ? 'No published exercise is available'
                          : 'Review the published tutorial for ${routine.first.name}'
                      : 'See proper form for ${routine.first.name}',
                  image: routine.isEmpty ? '' : routine.first.imageUrl,
                  onTap: live
                      ? () {
                          final builder = routes.tutorialBuilder;
                          if (routine.isEmpty || builder == null) {
                            showUnavailable(context);
                            return;
                          }
                          final row = publishedRoutine!.exercises.first;
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (ctx) => builder(ctx, row)));
                        }
                      : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => ExerciseTutorialScreen(
                                  exercise: routine.first))),
                ),
                const SizedBox(height: 12),
                _DetourCard(
                  icon: Icons.list_alt_rounded,
                  iconColor: AppColors.info,
                  title: 'View routine',
                  subtitle: live
                      ? publishedRoutine == null
                          ? 'No published routine is available yet'
                          : 'Full exercise list and set targets'
                      : 'Full exercise list, sets, and rest intervals',
                  onTap: live
                      ? publishedRoutine == null
                          ? () => showUnavailable(context)
                          : routes.journeyBuilder != null
                              ? () => _openRoutineJourney(context)
                              : () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => RoutineScreen(
                                          publishedRoutine: publishedRoutine,
                                          tutorialBuilder:
                                              routes.tutorialBuilder)))
                      : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const RoutineScreen())),
                ),
                const SizedBox(height: 12),
                _DetourCard(
                  icon: Icons.videocam_rounded,
                  iconColor: AppColors.accentDark,
                  title: 'Review camera setup',
                  subtitle: 'Get the right distance and angle before you start',
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const CameraSetupScreen())),
                ),
                const SizedBox(height: 12),
                _DetourCard(
                  icon: Icons.qr_code_scanner_rounded,
                  iconColor: AppColors.primarySoft,
                  title: 'Scan equipment',
                  subtitle:
                      'Point your camera at a machine for how-to and safety tips',
                  onTap: live
                      ? onOpenEquipment ?? () => showUnavailable(context)
                      : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const EquipmentScannerScreen())),
                ),
                const SizedBox(height: 28),
                if (live)
                  TextButton(
                      onPressed: () {
                        final auth = context.read<AuthBloc>();
                        final scope = auth.state.session?.scope;
                        if (scope == null) return;
                        final destination = routes.savedSessionsBuilder;
                        if (destination == null) {
                          showUnavailable(context);
                          return;
                        }
                        Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                                builder: (_) => BlocProvider.value(
                                    value: auth,
                                    child: Builder(
                                        builder: (context) =>
                                            destination(context, scope)))));
                      },
                      child: const Text('Saved squat sessions')),
                if (const bool.fromEnvironment('GAINPATH_POSE_PREVIEW'))
                  TextButton(
                      onPressed: () => _startPosePreview(context),
                      child: const Text('Try live camera preview')),
                TextButton(
                  onPressed: live
                      ? () => _startRealSession(context)
                      : () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                              builder: (_) => const LiveWorkoutScreen())),
                  child: const Text('Workout session'),
                ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style:
                        FilledButton.styleFrom(minimumSize: const Size(0, 54)),
                    onPressed: live
                        ? () => _startRealSession(context)
                        : () => _startSession(context),
                    icon: const Icon(Icons.bolt_rounded),
                    label: const Text('Start guided session'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startSession(BuildContext context) async {
    // UC-2.5 — biometric consent gate on first camera use.
    final consented = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => const _ConsentSheet(),
    );
    if (consented == true && context.mounted) {
      Navigator.pushNamed(context, WorkoutNavigation.guided);
    }
  }

  Future<void> _startRealSession(BuildContext context) async {
    if (routes.journeyBuilder != null) {
      _openRoutineJourney(context);
      return;
    }
    final auth = context.read<AuthBloc>();
    final scope = auth.state.session?.scope;
    if (scope == null) {
      showUnavailable(context);
      return;
    }
    final candidates = publishedRoutine?.exercises
            .where((e) =>
                trackers
                    .resolve(
                        organizationId: scope.organizationId,
                        exerciseId: e.exerciseId)
                    .tracker !=
                null)
            .toList() ??
        [];
    if (candidates.isEmpty) {
      final exercises = publishedRoutine?.exercises;
      final tutorial = routes.tutorialBuilder;
      if (exercises != null && exercises.isNotEmpty && tutorial != null) {
        await Navigator.push<void>(
            context,
            MaterialPageRoute(
              builder: (context) => BlocProvider.value(
                value: auth,
                child: Builder(
                    builder: (context) => tutorial(context, exercises.first)),
              ),
            ));
        return;
      }
      showUnavailable(context);
      return;
    }
    final exercise = candidates.first;
    var uploadRequested = false;
    final tracker = trackers
        .resolve(
            organizationId: scope.organizationId,
            exerciseId: exercise.exerciseId)
        .tracker;
    final consented = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        builder: (_) => _ConsentSheet(
            realWorkout: true,
            allowUpload: tracker == ExerciseTracker.sideViewSquat,
            exerciseInstruction: switch (tracker) {
              ExerciseTracker.frontViewLateralRaise =>
                lateralRaiseCaptureInstruction,
              ExerciseTracker.frontViewShoulderPress =>
                shoulderPressCaptureInstruction,
              ExerciseTracker.sideViewCurl => curlCaptureInstruction,
              ExerciseTracker.sideViewRow => rowCaptureInstruction,
              ExerciseTracker.sideViewReverseLunge =>
                reverseLungeCaptureInstruction,
              ExerciseTracker.sideViewCalfRaise => calfRaiseCaptureInstruction,
              ExerciseTracker.sideViewWallPushUp =>
                wallPushUpCaptureInstruction,
              _ => null,
            },
            setupConfirmationLabel: tracker ==
                    ExerciseTracker.sideViewWallPushUp
                ? wallPushUpSetupConfirmation
                : tracker == ExerciseTracker.frontViewLateralRaise
                    ? lateralRaiseSetupConfirmation
                    : tracker == ExerciseTracker.frontViewShoulderPress
                        ? shoulderPressSetupConfirmation
                        : tracker == ExerciseTracker.sideViewRow
                            ? rowSetupConfirmation
                            : tracker == ExerciseTracker.sideViewReverseLunge
                                ? reverseLungeSetupConfirmation
                                : null,
            onUploadChanged: (value) => uploadRequested = value));
    if (consented != true ||
        !context.mounted ||
        auth.state.session?.scope != scope) {
      return;
    }
    final destination = routes.realSessionBuilder;
    if (destination == null) {
      showUnavailable(context);
      return;
    }
    final launch = RealWorkoutLaunch(
        scope: scope,
        routineId: publishedRoutine!.id,
        exercise: exercise,
        consented: true,
        requestServerUpload: uploadRequested,
        setupConfirmed: true);
    Navigator.push(
        context,
        MaterialPageRoute<void>(
            builder: (_) => BlocProvider.value(
                value: auth,
                child: Builder(
                    builder: (context) => destination(context, launch)))));
  }

  void _openRoutineJourney(BuildContext context) {
    final routine = publishedRoutine, destination = routes.journeyBuilder;
    if (routine == null || destination == null) {
      showUnavailable(context);
      return;
    }
    final auth = context.read<AuthBloc>();
    if (auth.state.session == null) {
      showUnavailable(context);
      return;
    }
    Navigator.push(
        context,
        MaterialPageRoute<void>(
            builder: (_) => BlocProvider.value(
                value: auth,
                child: Builder(
                    builder: (context) => destination(context, routine)))));
  }

  Future<void> _startPosePreview(BuildContext context) async {
    final consented = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        builder: (_) => const _ConsentSheet(previewOnly: true));
    if (consented == true && context.mounted) {
      final destination = routes.posePreviewBuilder;
      if (destination == null) {
        showUnavailable(context);
        return;
      }
      final auth = context.read<AuthBloc>();
      Navigator.push(
          context,
          MaterialPageRoute<void>(
              builder: (_) => BlocProvider.value(
                  value: auth, child: Builder(builder: destination))));
    }
  }
}

/// A rich, image-or-icon tappable card for the staging menu's three
/// detours — deliberately heavier than a plain ListTile so the hub reads
/// as a set of deliberate choices rather than a settings list.
class _DetourCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String? image;
  final VoidCallback? onTap;

  const _DetourCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.image,
  });

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Row(
        children: [
          if (image != null)
            ClipRRect(
              borderRadius:
                  const BorderRadius.horizontal(left: Radius.circular(16)),
              child: SizedBox(
                width: 78,
                height: 78,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    networkHero(image!),
                    DecoratedBox(
                        decoration: BoxDecoration(
                            color: AppColors.ink.withValues(alpha: 0.28))),
                    Center(child: Icon(icon, color: Colors.white, size: 26)),
                  ],
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: iconColor, size: 23),
              ),
            ),
          const SizedBox(width: 4),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(fontSize: 12.5)),
                ],
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(right: 16),
            child: Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: AppColors.inkSoft),
          ),
        ],
      ),
    );
  }
}

Future<bool?> showWorkoutCaptureConsent(BuildContext context,
        {required ValueChanged<bool> onUploadChanged,
        bool allowUpload = true,
        String? exerciseInstruction,
        String? setupConfirmationLabel}) =>
    showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        builder: (_) => _ConsentSheet(
            realWorkout: true,
            onUploadChanged: onUploadChanged,
            allowUpload: allowUpload,
            exerciseInstruction: exerciseInstruction,
            setupConfirmationLabel: setupConfirmationLabel));

const curlCaptureInstruction =
    'Choose both arms, left only or right only before the camera starts. Reps are per selected arm per set. Keep the selected arm closest to the camera, lower it to calibrate, and switch only when prompted. Keep the shoulder, elbow, wrist and hip visible. Results stay on this device; upload and rewards are unavailable.';

const reverseLungeCaptureInstruction =
    'Choose the front leg that stays planted before opening the camera. The other foot steps backward. Reps apply only to the selected front leg for every set; do not alternate within a set. Put a stable side camera on the selected front-leg side, with its knee and heel-to-toe outline, your torso, both hips and both ankles visible. The verified camera hold and 3-second countdown start automatically; no touch is needed. The far knee bend is not measured. Stand tall with a small comfortable gap so both ankles stay visible, then step back, lower with control and return both feet to the same standing position between reps. Balance, load, floor contact and three-dimensional alignment are not assessed. No form score, verified upload or workout rewards are available.';
const reverseLungeSetupConfirmation =
    'My phone is stable at my side, both legs and feet stay visible, and I have clear space to step backward with the other leg.';

const rowCaptureInstruction =
    'Choose the arm to train before opening the camera. Reps apply to that selected arm only. Support the other hand and knee on a stable bench, keep your torso nearly horizontal and let the working arm hang to calibrate. Place the camera side-on with the working shoulder, elbow, wrist and hip visible. Pull the elbow toward your hip and lower with control. Bench contact, weight, spinal shape and three-dimensional rotation are not assessed. No form score, verified upload or workout rewards are available.';
const rowSetupConfirmation =
    'I have a stable bench, the selected arm faces the side camera, and I can keep my shoulder, elbow, wrist and hip visible.';

const shoulderPressCaptureInstruction =
    'Face the camera with both shoulders, elbows, wrists and hips visible. Leave space above your hands. Hold both hands above bent elbows at shoulder height to calibrate. Press overhead together and return with control; both arms together count as one rep. Weight, spinal alignment and three-dimensional shoulder mechanics are not assessed. No form score, verified upload or workout rewards are available.';
const shoulderPressSetupConfirmation =
    'I face the camera with both arms and hips visible and enough space above my hands.';

const calfRaiseCaptureInstruction =
    'Stand side-on on level ground, with both feet flat to calibrate. Keep your hips, knees, heels and toes fully visible. Raise both heels, hold briefly, then lower with control; do not jump. Only the visible leg is measured; equal work on both legs, balance and load are not assessed. Results stay on this device; upload and rewards are unavailable.';

const wallPushUpCaptureInstruction =
    'Face a wall with palms at chest height, then extend your arms to start. Place the phone at your side and keep your shoulder, elbow, wrist, hip and knee visible. Bend toward the wall with your body in line, then push back with control. Keep palms in place. Wall contact is user-confirmed; force, load and equal work by both arms are not assessed. Results stay on this device; upload and rewards are unavailable.';
const wallPushUpSetupConfirmation =
    'My palms are on the wall at chest height, my body is side-on to the camera, and my shoulder, elbow, wrist, hip and knee are visible.';

class _ConsentSheet extends StatefulWidget {
  const _ConsentSheet(
      {this.previewOnly = false,
      this.realWorkout = false,
      this.allowUpload = true,
      this.exerciseInstruction,
      this.setupConfirmationLabel,
      this.onUploadChanged});
  final bool allowUpload;
  final String? exerciseInstruction;
  final String? setupConfirmationLabel;
  final ValueChanged<bool>? onUploadChanged;
  final bool previewOnly;
  final bool realWorkout;

  @override
  State<_ConsentSheet> createState() => _ConsentSheetState();
}

class _ConsentSheetState extends State<_ConsentSheet> {
  bool _checked = false;
  bool _setupChecked = false;
  bool _uploadChecked = false;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
        child: Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, 20 + MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                  color: AppColors.hairline,
                  borderRadius: BorderRadius.circular(999)),
            ),
          ),
          Text('Before we turn on the camera',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Text(
            widget.previewOnly
                ? 'GainPath uses your camera to display your body landmarks on this device.'
                : 'GainPath reads your body position from the camera to check your form '
                    'and count your reps.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 14),
          Panel(
            background: AppColors.primaryTint,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _point(context, 'Everything is processed on this device.'),
                _point(context, 'No video is recorded, stored, or uploaded.'),
                _point(
                    context,
                    widget.previewOnly
                        ? 'This preview does not save activity or count reps.'
                        : 'Only your movement scores are saved.'),
                if (widget.realWorkout)
                  _point(
                      context,
                      widget.exerciseInstruction ??
                          'This session tracks only the supported squat. Results are saved on this device. Upload is optional and awards no rewards.'),
                if (widget.realWorkout)
                  _point(context,
                      'Form guidance is provisional. Use a side view with the camera upright and stationary, and keep your full body in view.'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: () => setState(() => _checked = !_checked),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Checkbox(
                    value: _checked,
                    onChanged: (v) => setState(() => _checked = v ?? false),
                  ),
                  Expanded(
                    child: Text(
                      'I agree to camera-based movement tracking as described above.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (widget.realWorkout)
            CheckboxListTile(
                value: _setupChecked,
                onChanged: (value) =>
                    setState(() => _setupChecked = value ?? false),
                title: Text(widget.setupConfirmationLabel ??
                    'My full body is visible from the side and the camera is upright and stationary.'),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero),
          FilledButton(
            // Camera consent and setup are required; server upload is optional.
            onPressed: _checked && (!widget.realWorkout || _setupChecked)
                ? () => Navigator.pop(context, true)
                : null,
            child: const Text('Accept and start'),
          ),
          if (widget.realWorkout && widget.allowUpload)
            CheckboxListTile(
                value: _uploadChecked,
                onChanged: (value) {
                  setState(() => _uploadChecked = value ?? false);
                  widget.onUploadChanged?.call(_uploadChecked);
                },
                title: const Text(
                    'Also allow this measured summary to be uploaded.'),
                subtitle: const Text(
                    'Requires server consent before capture. Only counts, score, measured time and version identifiers are sent. No video or landmarks. Acceptance remains disabled until physical model validation.'),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not now'),
          ),
        ],
      ),
    ));
  }

  Widget _point(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.check_circle_rounded,
                size: 17, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(
                child: Text(text,
                    style: const TextStyle(fontSize: 14, height: 1.4))),
          ],
        ),
      );
}

/// AD-M2.2 detour — View Routine. The full exercise list with thumbnails,
/// set/rep targets, and rest intervals; tapping an exercise hands off into
/// its tutorial. Reviewing and returning is the whole point of this screen
/// living outside the main staging menu.

const lateralRaiseCaptureInstruction =
    'Front view: show both shoulders, elbows, wrists and hips with space on both sides. Hold arms at your sides until Ready, then raise both arms out to shoulder height and lower fully. One bilateral cycle is one rep. Counts are provisional; no form score or load assessment.';
const lateralRaiseSetupConfirmation =
    'I can face the camera with both arms visible throughout the raise. I will hold my arms at my sides for automatic readiness.';
