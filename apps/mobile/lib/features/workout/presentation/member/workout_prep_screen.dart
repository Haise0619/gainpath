import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
  const WorkoutPrepScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final routine = context.read<WorkoutRepository>().routine;
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
            titleTextStyle:
                Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white, fontSize: 18),
            title: const Text('Workout'),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  networkHero(routineHeroImage),
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
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text('TODAY\'S ROUTINE',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.1)),
                          ),
                          const SizedBox(height: 10),
                          Text('Lower Body Strength',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(color: Colors.white, fontSize: 24)),
                          const SizedBox(height: 6),
                          Text(
                            '${routine.length} exercises  ·  $totalSets sets  ·  about 45 min',
                            style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.85)),
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
                _DetourCard(
                  icon: Icons.play_circle_fill_rounded,
                  iconColor: AppColors.primary,
                  title: 'Watch tutorial',
                  subtitle: 'See proper form for ${routine.first.name}',
                  image: routine.first.imageUrl,
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => ExerciseTutorialScreen(exercise: routine.first))),
                ),
                const SizedBox(height: 12),
                _DetourCard(
                  icon: Icons.list_alt_rounded,
                  iconColor: AppColors.info,
                  title: 'View routine',
                  subtitle: 'Full exercise list, sets, and rest intervals',
                  onTap: () =>
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const RoutineScreen())),
                ),
                const SizedBox(height: 12),
                _DetourCard(
                  icon: Icons.videocam_rounded,
                  iconColor: AppColors.accentDark,
                  title: 'Review camera setup',
                  subtitle: 'Get the right distance and angle before you start',
                  onTap: () => Navigator.push(
                      context, MaterialPageRoute(builder: (_) => const CameraSetupScreen())),
                ),
                const SizedBox(height: 12),
                _DetourCard(
                  icon: Icons.qr_code_scanner_rounded,
                  iconColor: AppColors.primarySoft,
                  title: 'Scan equipment',
                  subtitle: 'Point your camera at a machine for how-to and safety tips',
                  onTap: () => Navigator.push(
                      context, MaterialPageRoute(builder: (_) => const EquipmentScannerScreen())),
                ),
                const SizedBox(height: 28),
                TextButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const LiveWorkoutScreen())),
                  child: const Text('Preview original workout UI (demo only)'),
                ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(minimumSize: const Size(0, 54)),
                    onPressed: () => _startSession(context),
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
  final VoidCallback onTap;

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
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
              child: SizedBox(
                width: 78,
                height: 78,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    networkHero(image!),
                    DecoratedBox(decoration: BoxDecoration(color: AppColors.ink.withValues(alpha: 0.28))),
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
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12.5)),
                ],
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(right: 16),
            child: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.inkSoft),
          ),
        ],
      ),
    );
  }
}

class _ConsentSheet extends StatefulWidget {
  const _ConsentSheet();

  @override
  State<_ConsentSheet> createState() => _ConsentSheetState();
}

class _ConsentSheetState extends State<_ConsentSheet> {
  bool _checked = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
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
            'GainPath reads your body position from the camera to check your form '
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
                _point(context, 'Only your movement scores are saved.'),
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
          FilledButton(
            onPressed: _checked ? () => Navigator.pop(context, true) : null,
            child: const Text('Accept and start'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not now'),
          ),
        ],
      ),
    );
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
