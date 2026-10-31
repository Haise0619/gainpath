import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/gamification.dart';
import 'package:gainpath_identity/gainpath_identity.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../../../media/tutorial_video.dart';
import '../../../../navigation/feature_navigation.dart';
import '../../domain/move_catch_ports.dart';
import '../../domain/reach_tap_ports.dart';
import '../../domain/mini_game_launch.dart';
import 'reach_tap_personal_best.dart';

class MiniGameDetailsScreen extends StatefulWidget {
  const MiniGameDetailsScreen(
      {super.key,
      required this.content,
      this.reader,
      this.bestScoreStore,
      this.reachTapHistory,
      this.rewardStatus,
      this.participation,
      this.competitionStatus,
      this.onLeaderboard});
  final MiniGameContent content;
  final MiniGameContentReader? reader;
  final MoveCatchBestScoreStore? bestScoreStore;
  final ReachTapHistoryStore? reachTapHistory;
  final Widget? rewardStatus, competitionStatus;
  final MiniGameParticipationRepository? participation;
  final VoidCallback? onLeaderboard;
  @override
  State<MiniGameDetailsScreen> createState() => _MiniGameDetailsScreenState();
}

class _MiniGameDetailsScreenState extends State<MiniGameDetailsScreen> {
  bool _previewOpen = false, _playing = false;
  int _bestRevision = 0;
  MiniGameParticipation? _eligibility;
  bool _eligibilityLoading = false, _eligibilityFailed = false, _earn = false;
  int _eligibilityGeneration = 0;
  @override
  void initState() {
    super.initState();
    _loadEligibility();
  }

  @override
  void didUpdateWidget(MiniGameDetailsScreen old) {
    super.didUpdateWidget(old);
    if (!identical(old.reader, widget.reader) ||
        !identical(old.participation, widget.participation)) {
      _eligibilityGeneration++;
      _eligibility = null;
      _earn = false;
      _eligibilityLoading = false;
      _eligibilityFailed = false;
      _loadEligibility();
    }
  }

  Future<void> _loadEligibility() async {
    final repo = widget.participation;
    final generation = ++_eligibilityGeneration;
    if (repo == null || !repo.current) return;
    setState(() {
      _eligibilityLoading = true;
      _eligibilityFailed = false;
    });
    try {
      final result = await repo.overview().timeout(const Duration(seconds: 12));
      if (!mounted ||
          generation != _eligibilityGeneration ||
          !_current ||
          !repo.current ||
          !identical(repo, widget.participation)) {
        return;
      }
      if (result.scope != repo.scope ||
          (widget.reader != null && result.scope != widget.reader!.scope)) {
        throw StateError('scope');
      }
      setState(() {
        _eligibility = result;
        if (!MiniGameLaunchArguments.canEarn(result, _content.gameId)) {
          _earn = false;
        }
      });
    } catch (_) {
      if (mounted && generation == _eligibilityGeneration) {
        setState(() {
          _eligibilityFailed = true;
          _eligibility = null;
          _earn = false;
        });
      }
    } finally {
      if (mounted && generation == _eligibilityGeneration) {
        setState(() => _eligibilityLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _eligibilityGeneration++;
    super.dispose();
  }

  bool get _current => widget.reader?.current ?? true;

  MiniGameContent get _content {
    final candidate = widget.content;
    final organization = widget.reader?.scope.organizationId ?? 'built-in';
    return MiniGameContent.supportedIds.contains(candidate.gameId) &&
            candidate.organizationId == organization
        ? candidate
        : MiniGameContent.defaults(organization,
            gameId: candidate.gameId == MiniGameContent.reachTapId
                ? MiniGameContent.reachTapId
                : MiniGameContent.supportedId);
  }

  Future<void> _preview() async {
    if (!_current || _previewOpen || _playing) {
      setState(() {});
      return;
    }
    final reader = widget.reader;
    final auth = context.read<AuthBloc?>();
    final url = _content.previewVideoUrl;
    setState(() => _previewOpen = true);
    final route = MaterialPageRoute<void>(
        builder: (_) => StreamBuilder<AuthState>(
            stream: auth?.stream,
            builder: (context, _) => Scaffold(
                appBar: AppBar(title: const Text('Game preview')),
                body: reader != null && !reader.current
                    ? const Center(
                        child: Text('This game guide session has ended.'))
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: TutorialVideo(url: url)))));
    await Navigator.of(context).push(route);
    // A popped preview still owns its decoder during the route transition.
    await route.completed;
    if (mounted) setState(() => _previewOpen = false);
  }

  Future<void> _start() async {
    if (!_current || _previewOpen || _playing) {
      setState(() {});
      return;
    }
    setState(() => _playing = true);
    final completed = await Navigator.of(context).pushNamed(
        _content.gameId == MiniGameContent.reachTapId
            ? FeatureNavigation.reachAndTap
            : FeatureNavigation.moveAndCatch,
        arguments: _earn
            ? MiniGameLaunchArguments(content: _content, playAndEarn: true)
            : _content);
    if (!mounted) return;
    if (completed == true && _current) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _playing = false;
      if (_current) _bestRevision++;
    });
    if (_current) await _loadEligibility();
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<AuthState>(
      stream: context.read<AuthBloc?>()?.stream,
      builder: (context, _) {
        if (!_current) {
          return Scaffold(
              appBar: AppBar(title: const Text('Game details')),
              body: const Center(
                  child: Text('This game guide session has ended.')));
        }
        final content = _content;
        final reach = content.gameId == MiniGameContent.reachTapId;
        final canEarn =
            MiniGameLaunchArguments.canEarn(_eligibility, content.gameId);
        return Scaffold(
            backgroundColor: AppColors.bg,
            appBar: AppBar(title: const Text('Game details')),
            body: SafeArea(
                top: false,
                child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: AspectRatio(
                                  aspectRatio: 16 / 10,
                                  child: MiniGameCover(
                                      content: content, fit: BoxFit.contain))),
                          const SizedBox(height: 22),
                          Text(content.title,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(
                                      color: AppColors.ink,
                                      fontWeight: FontWeight.w800)),
                          const SizedBox(height: 12),
                          Text(content.introduction,
                              style: Theme.of(context).textTheme.bodyLarge),
                          const SizedBox(height: 16),
                          const Wrap(spacing: 8, runSpacing: 8, children: [
                            _DetailLabel(Icons.timer_outlined, '40 seconds'),
                            _DetailLabel(Icons.videocam_outlined, 'Camera'),
                            _DetailLabel(Icons.accessibility_new, 'All levels'),
                          ]),
                          const SizedBox(height: 20),
                          if (reach)
                            ReachTapPersonalBest(
                                reader: widget.reader,
                                store: widget.reachTapHistory ??
                                    context.read<ReachTapHistoryStore?>(),
                                revision: _bestRevision)
                          else
                            MiniGamePersonalBest(
                                reader: widget.reader,
                                store: widget.bestScoreStore,
                                revision: _bestRevision),
                          if (content.previewVideoUrl.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            OutlinedButton.icon(
                                onPressed:
                                    _previewOpen || _playing ? null : _preview,
                                icon: const Icon(Icons.video_library_outlined),
                                label: const Text('Watch preview')),
                          ],
                          const SizedBox(height: 26),
                          _heading(context, 'How to play'),
                          const SizedBox(height: 12),
                          for (var i = 0; i < content.instructions.length; i++)
                            Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Text(
                                    '${i + 1}. ${content.instructions[i]}')),
                          const SizedBox(height: 14),
                          _heading(context, 'How to score'),
                          const SizedBox(height: 12),
                          _InfoPanel(
                              icon: Icons.stars_rounded,
                              title: reach
                                  ? '+10 per confirmed hit'
                                  : '+10 per star',
                              body: reach
                                  ? 'Move a visible hand onto each fixed target and hold briefly. Each confirmed hit adds 10 local Game Score; a new target then appears.'
                                  : 'Catch stars with your basket. Obstacles subtract 5; your score never goes below 0.'),
                          const SizedBox(height: 16),
                          (!reach ||
                                      _eligibility?.gameId ==
                                          MiniGameContent.reachTapId
                                  ? widget.rewardStatus
                                  : null) ??
                              _InfoPanel(
                                  icon: Icons.redeem_outlined,
                                  title: reach
                                      ? 'Reward Points'
                                      : 'Game rewards · Not active',
                                  body: reach
                                      ? 'Choose Play & Earn when available. Game Score stays separate from Reward Points.'
                                      : 'Game scores are separate from reward points. Playing does not award points.'),
                          const SizedBox(height: 16),
                          _InfoPanel(
                              icon: Icons.accessibility_new_rounded,
                              title: 'Make room to move',
                              body: reach
                                  ? 'Make room to step sideways and reach high or low. Some points may need a small jump. Keep your body in the camera view; align steadily before the automatic countdown.'
                                  : 'Clear the floor around you. Stand facing the camera with your shoulders and hips visible. Lean gently; no jumping needed. Stop if you feel uncomfortable.'),
                          const SizedBox(height: 16),
                          const _InfoPanel(
                              icon: Icons.lock_outline_rounded,
                              title: 'Private, on-device play',
                              body:
                                  'Camera and movement stay on this device. No video is saved. Your personal best stays on this device for your account.'),
                          const SizedBox(height: 16),
                          if (widget.competitionStatus != null)
                            widget.competitionStatus!,
                          if (widget.onLeaderboard != null)
                            OutlinedButton.icon(
                                onPressed: widget.onLeaderboard,
                                icon: const Icon(Icons.leaderboard_outlined),
                                label: const Text('View leaderboard')),
                          Text('Choose how to play',
                              style: const TextStyle(
                                  color: AppColors.ink,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          Wrap(spacing: 8, runSpacing: 8, children: [
                            ChoiceChip(
                                label: const Text('Play for fun'),
                                selected: !_earn,
                                onSelected: _playing
                                    ? null
                                    : (_) => setState(() => _earn = false)),
                            if (canEarn)
                              ChoiceChip(
                                  label: const Text('Play & Earn'),
                                  selected: _earn,
                                  onSelected: _playing
                                      ? null
                                      : (_) => setState(() => _earn = true)),
                          ]),
                          if (_earn)
                            const Text(
                                'Complete a round to check Reward Points. Only round timing is sent; camera, pose and Game Score stay on-device.'),
                          if (_eligibilityLoading)
                            const Text('Checking earning availability…'),
                          if (_eligibilityFailed)
                            TextButton(
                                onPressed: _loadEligibility,
                                child: const Text(
                                    'Earning status unavailable · Retry')),
                          if (!_earn &&
                              !canEarn &&
                              !_eligibilityLoading &&
                              !_eligibilityFailed)
                            const Text(
                                'Rewards unavailable for this round. Play for your personal best.'),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                              style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 16)),
                              onPressed:
                                  _previewOpen || _playing ? null : _start,
                              icon: const Icon(Icons.play_arrow_rounded),
                              label: const Text('Start playing')),
                        ]))));
      });

  Widget _heading(BuildContext context, String title) => Text(title,
      style: Theme.of(context)
          .textTheme
          .titleLarge
          ?.copyWith(fontWeight: FontWeight.w800));
}

class _DetailLabel extends StatelessWidget {
  const _DetailLabel(this.icon, this.label);
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
          color: AppColors.primaryTint,
          borderRadius: BorderRadius.circular(12)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 6),
        Flexible(
            child: Text(label,
                style: const TextStyle(
                    color: AppColors.primary, fontWeight: FontWeight.w700))),
      ]));
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel(
      {required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title, body;
  @override
  Widget build(BuildContext context) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.hairline),
          borderRadius: BorderRadius.circular(18)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: AppColors.primary),
        const SizedBox(height: 10),
        Text(title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(body),
      ]));
}

/// Shared presentation of the scoped, device-local score. No reader means no
/// authenticated scope; it must never be presented as a synthetic zero.
class MiniGamePersonalBest extends StatefulWidget {
  const MiniGamePersonalBest(
      {super.key, this.reader, this.store, this.revision = 0});
  final MiniGameContentReader? reader;
  final MoveCatchBestScoreStore? store;
  final int revision;
  @override
  State<MiniGamePersonalBest> createState() => _MiniGamePersonalBestState();
}

class _MiniGamePersonalBestState extends State<MiniGamePersonalBest> {
  int? _best;
  int _generation = 0;
  bool _loading = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant MiniGamePersonalBest oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.reader, widget.reader) ||
        !identical(oldWidget.store, widget.store) ||
        oldWidget.revision != widget.revision) {
      _load();
    }
  }

  Future<void> _load() async {
    final reader = widget.reader, store = widget.store;
    final generation = ++_generation;
    _best = null;
    _loading = reader != null && reader.current && store != null;
    if (!_loading) return;
    int? best;
    try {
      best = await store!.load(reader!.scope);
    } catch (_) {
      // A storage failure is unavailable, not a zero score.
    }
    if (!mounted || generation != _generation || !reader!.current) return;
    setState(() {
      _best = best;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.reader != null && !widget.reader!.current) {
      return const SizedBox();
    }
    return _InfoPanel(
        icon: Icons.emoji_events_outlined,
        title: _loading
            ? 'Personal best · Loading…'
            : _best == null
                ? 'Personal best · Unavailable'
                : 'Personal best · $_best',
        body: 'On this device · Game score');
  }
}

/// Uses only the managed cover; the built-in art also covers image failures.
class MiniGameCover extends StatelessWidget {
  const MiniGameCover(
      {super.key, required this.content, this.fit = BoxFit.cover});
  final MiniGameContent content;
  final BoxFit fit;
  @override
  Widget build(BuildContext context) => ColoredBox(
      color: AppColors.primaryTint,
      child: content.coverUrl.isEmpty
          ? _GameArt(reach: content.gameId == MiniGameContent.reachTapId)
          : Image.network(content.coverUrl,
              fit: fit,
              semanticLabel: '${content.title} cover',
              errorBuilder: (_, __, ___) => _GameArt(
                  reach: content.gameId == MiniGameContent.reachTapId)));
}

class _GameArt extends StatelessWidget {
  const _GameArt({this.reach = false});
  final bool reach;
  @override
  Widget build(BuildContext context) => reach
      ? const DecoratedBox(
          decoration: BoxDecoration(gradient: AppColors.heroGradient),
          child: Stack(children: [
            Align(
                alignment: Alignment(-.65, -.55),
                child: Icon(Icons.adjust_rounded,
                    color: Color(0xFFFFD76E), size: 62)),
            Align(
                alignment: Alignment(.65, .45),
                child: Icon(Icons.adjust_rounded,
                    color: Color(0xFFBDA8EE), size: 54)),
            Center(
                child: Icon(Icons.touch_app_outlined,
                    color: Color(0xFFF0E8FF), size: 84)),
          ]))
      : const DecoratedBox(
          decoration: BoxDecoration(gradient: AppColors.heroGradient),
          child: Stack(children: [
            Align(
                alignment: Alignment(-.68, -.6),
                child: Icon(Icons.star_rounded,
                    color: Color(0xFFFFD76E), size: 46)),
            Align(
                alignment: Alignment(.68, -.35),
                child: Icon(Icons.star_rounded,
                    color: Color(0xFFFFE9A8), size: 32)),
            Align(
                alignment: Alignment(.25, -.75),
                child: Icon(Icons.diamond_outlined,
                    color: Color(0xFFBDA8EE), size: 30)),
            Align(
                alignment: Alignment(0, -.6),
                child: Icon(Icons.sports_esports_rounded,
                    color: Color(0xFFF0E8FF), size: 84)),
            Align(
                alignment: Alignment(0, .72),
                child: Icon(Icons.shopping_basket_rounded,
                    color: Color(0xFFBDA8EE), size: 28)),
          ]));
}
