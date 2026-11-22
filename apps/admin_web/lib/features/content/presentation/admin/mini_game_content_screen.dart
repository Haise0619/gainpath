import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/gamification.dart';
import 'package:gainpath_domain/workout.dart';
import 'package:gainpath_ui/gainpath_ui.dart';

import '../../../../navigation/admin_breadcrumb.dart';
import '../../../../media/video_preview.dart';
import 'mini_game_reward_policy_panel.dart';
import 'mini_game_standings_screen.dart';
import '../../../../infrastructure/firebase/firebase_mini_game_competition_repository.dart';

String _gameName(String id) =>
    id == MiniGameContent.reachTapId ? 'Reach & Tap' : 'Move & Catch';

List<MiniGameContent> _knownContent(
        List<MiniGameContent> items, String organizationId) =>
    [
      for (final id in MiniGameContent.supportedIds)
        items
                .where((item) =>
                    item.gameId == id && item.organizationId == organizationId)
                .firstOrNull ??
            MiniGameContent.defaults(organizationId, gameId: id),
    ];

String _newId() {
  final random = Random.secure();
  return List.generate(
      16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
}

Widget _cover(String url, {Uint8List? bytes, BoxFit fit = BoxFit.contain}) {
  const fallback = ColoredBox(
      color: AppColors.primaryTint,
      child: Center(
          child: Icon(Icons.sports_esports_outlined,
              size: 44, color: AppColors.primary)));
  return AspectRatio(
      aspectRatio: 16 / 9,
      child: bytes != null
          ? Image.memory(bytes,
              fit: fit, errorBuilder: (_, __, ___) => fallback)
          : url.isEmpty
              ? fallback
              : Image.network(url,
                  fit: fit,
                  webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
                  errorBuilder: (_, __, ___) => fallback));
}

/// Authoring for system-supported games. Registry and gameplay stay managed.
class MiniGameContentScreen extends StatefulWidget {
  const MiniGameContentScreen({
    super.key,
    this.repository,
    this.imagePicker,
    this.videoPicker,
    this.competitionRepository,
    this.rewardRepository,
  });

  final MiniGameContentRepository? repository;
  final MiniGameCompetitionRepository? competitionRepository;
  final MiniGameRewardConfigurationRepository? rewardRepository;
  final EquipmentImagePicker? imagePicker;
  final EquipmentVideoPicker? videoPicker;

  @override
  State<MiniGameContentScreen> createState() => _MiniGameContentScreenState();
}

class _MiniGameContentScreenState extends State<MiniGameContentScreen> {
  late MiniGameContentRepository _repository;
  List<MiniGameContent>? _items;
  MiniGameContent? _editing;
  String? _error;
  int _generation = 0;
  bool _loading = false;

  // Hub tabs: 'library', 'leaderboards', 'rewards'
  String _activeTab = 'library';
  String _selectedLeaderboardGame = 'move-catch-v1';

  // Library filters
  String _query = '';
  String _mediaFilter = 'all';

  bool get _expandedRegistryAvailable =>
      _repository is! MiniGameContentRegistryStatus ||
      (_repository as MiniGameContentRegistryStatus).expandedRegistryAvailable;

  bool _editable(MiniGameContent content) =>
      content.gameId != MiniGameContent.reachTapId ||
      _expandedRegistryAvailable;

  @override
  void initState() {
    super.initState();
    _repository =
        widget.repository ?? context.read<MiniGameContentRepository>();
    _load();
  }

  @override
  void didUpdateWidget(MiniGameContentScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final repository =
        widget.repository ?? context.read<MiniGameContentRepository>();
    if (!identical(repository, _repository)) {
      _repository = repository;
      _editing = null;
      _items = null;
      _load();
    }
  }

  Future<void> _load() async {
    final generation = ++_generation;
    final repository = _repository;
    if (!repository.current) return;
    setState(() {
      _loading = true;
      _error = null;
      _editing = null;
    });
    try {
      final items = await repository.load();
      if (!mounted || generation != _generation || !repository.current) return;
      setState(() {
        _items = _knownContent(items, repository.scope.organizationId);
        _editing = null;
      });
    } catch (_) {
      if (mounted && generation == _generation && repository.current) {
        setState(() => _error =
            'Could not load mini-game content. Check Admin access and retry.');
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_repository.current) return const _SessionUnavailable();

    if (_editing != null) {
      return _ContentEditor(
        key: ObjectKey(_editing),
        repository: _repository,
        content: _editing!,
        imagePicker: widget.imagePicker,
        videoPicker: widget.videoPicker,
        onCancel: () => setState(() => _editing = null),
        onReload: _load,
        onSaved: (items) => setState(() {
          _items = items;
          _editing = null;
        }),
      );
    }

    final isMobile = MediaQuery.sizeOf(context).width < 600;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          isMobile ? 16 : 28,
          28,
          isMobile ? 16 : 28,
          36,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page Header
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Mini-games',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                          letterSpacing: -0.3,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Manage game content, leaderboards and reward policies.',
                        style: TextStyle(
                          fontSize: 13.5,
                          color: AppColors.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
                // Reload Action
                OutlinedButton.icon(
                  onPressed: _loading ? null : _load,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Reload'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.ink,
                    side: const BorderSide(color: AppColors.hairline),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Sub-navigation Tabs
            _buildTabs(),
            const SizedBox(height: 24),

            // Tab Content Body
            if (_loading)
              const LinearProgressIndicator(
                color: AppColors.primary,
                backgroundColor: AppColors.surfaceAlt,
              )
            else if (_error != null)
              Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_error!,
                        style: const TextStyle(color: AppColors.danger)),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              )
            else if (_items != null) ...[
              if (_activeTab == 'library')
                _buildLibraryTab(context)
              else if (_activeTab == 'leaderboards')
                _buildLeaderboardsTab(context)
              else
                _buildRewardPolicyTab(context),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTabs() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.hairline, width: 1)),
        ),
        child: Row(
          children: [
            _buildTabItem(
              id: 'library',
              label: 'Game library',
              icon: Icons.sports_esports_rounded,
            ),
            const SizedBox(width: 24),
            _buildTabItem(
              id: 'leaderboards',
              label: 'Leaderboards',
              icon: Icons.leaderboard_rounded,
            ),
            const SizedBox(width: 24),
            _buildTabItem(
              id: 'rewards',
              label: 'Reward policy',
              icon: Icons.card_giftcard_rounded,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabItem({
    required String id,
    required String label,
    required IconData icon,
  }) {
    final active = _activeTab == id;
    return InkWell(
      onTap: () => setState(() => _activeTab = id),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: active ? AppColors.primary : Colors.transparent,
              width: 2.5,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: active ? AppColors.primary : AppColors.inkSoft,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active ? AppColors.primary : AppColors.inkSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLibraryTab(BuildContext context) {
    final items = _items!.where((item) {
      final search = '${_gameName(item.gameId)} ${item.title} ${item.gameId}'
          .toLowerCase();
      final hasMedia =
          item.coverUrl.isNotEmpty || item.previewVideoUrl.isNotEmpty;
      return search.contains(_query.toLowerCase().trim()) &&
          (_mediaFilter == 'all' ||
              (_mediaFilter == 'with' ? hasMedia : !hasMedia));
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Summary & Compact Toolbar
        LayoutBuilder(
          builder: (context, constraints) {
            final summary = Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _buildSummaryBadge(
                  '${_items!.length} implemented games',
                  AppColors.ink,
                ),
                _buildSummaryBadge(
                  '${_items!.where((item) => !item.isBuiltIn).length} saved content overrides',
                  AppColors.primary,
                ),
                _buildSummaryBadge(
                  '${_items!.where((item) => item.coverUrl.isNotEmpty || item.previewVideoUrl.isNotEmpty).length} with media',
                  AppColors.success,
                ),
              ],
            );

            final search = SizedBox(
              width: 280,
              child: TextField(
                key: const Key('mini-game-search'),
                decoration: InputDecoration(
                  hintText: 'Search games or ID...',
                  prefixIcon:
                      const Icon(Icons.search_rounded, size: 18, color: AppColors.inkSoft),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 16),
                          onPressed: () => setState(() => _query = ''),
                        )
                      : null,
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.hairline),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.hairline),
                  ),
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
            );

            final mediaFilter = SizedBox(
              width: 170,
              child: DropdownButtonFormField<String>(
                key: const Key('mini-game-media-filter'),
                initialValue: _mediaFilter,
                isExpanded: true,
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.hairline),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.hairline),
                  ),
                ),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All media')),
                  DropdownMenuItem(value: 'with', child: Text('With media')),
                  DropdownMenuItem(value: 'without', child: Text('No media')),
                ],
                onChanged: (value) =>
                    setState(() => _mediaFilter = value ?? 'all'),
              ),
            );

            if (constraints.maxWidth < 800) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  summary,
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(child: search),
                      const SizedBox(width: 10),
                      mediaFilter,
                    ],
                  ),
                ],
              );
            }

            return Row(
              children: [
                Expanded(child: summary),
                const SizedBox(width: 16),
                search,
                const SizedBox(width: 10),
                mediaFilter,
              ],
            );
          },
        ),
        const SizedBox(height: 20),

        if (!_expandedRegistryAvailable) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.hairline),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 18, color: AppColors.inkSoft),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Reach & Tap is showing its built-in guide. Editing is unavailable on the connected server. Reload after the expanded content registry is released.',
                    style: TextStyle(fontSize: 12.5, color: AppColors.inkSoft),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Games Grid Container with key for test compliance
        SizedBox(
          key: const Key('mini-game-registry-table'),
          width: double.infinity,
          child: items.isEmpty
              ? Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.hairline),
                  ),
                  child: const Center(
                    child: Text(
                      'No games match these filters.',
                      style: TextStyle(fontSize: 14, color: AppColors.inkSoft),
                    ),
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth >= 900 && items.length >= 2) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildGameCard(context, items[0])),
                          const SizedBox(width: 20),
                          Expanded(child: _buildGameCard(context, items[1])),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        for (var i = 0; i < items.length; i++) ...[
                          _buildGameCard(context, items[i]),
                          if (i < items.length - 1) const SizedBox(height: 16),
                        ],
                      ],
                    );
                  },
                ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.hairline),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline_rounded,
                  size: 16, color: AppColors.inkSoft),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Move & Catch uses the existing mini-game reward policy. Reach & Tap reward points are inactive.',
                  style: TextStyle(fontSize: 12.5, color: AppColors.inkSoft),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildGameCard(BuildContext context, MiniGameContent item) {
    final hasVideo = item.previewVideoUrl.isNotEmpty;
    final isMoveCatch = item.gameId == 'move-catch-v1';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.hairline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 16:9 Cover Image
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
            child: Stack(
              children: [
                _cover(item.coverUrl),
                if (hasVideo)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.play_circle_fill_rounded,
                              size: 14, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            'Video Preview',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Content Body
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title & Status Badges Row
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_gameName(item.gameId)} · ${item.gameId}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.inkSoft,
                          ),
                        ),
                      ],
                    ),
                    // Content Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: item.isBuiltIn
                            ? AppColors.surfaceAlt
                            : AppColors.primaryTint,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        item.isBuiltIn ? 'Built-in guide' : 'Saved content',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: item.isBuiltIn
                              ? AppColors.inkSoft
                              : AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Introduction Snippet
                Text(
                  item.introduction,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.inkSoft,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 14),

                // Status Metadata Row
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.bg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Wrap(
                    spacing: 16,
                    runSpacing: 10,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // Content status detail
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Content revision',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.inkSoft,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.isBuiltIn
                                ? 'No saved override'
                                : 'Revision ${item.revision}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.ink,
                            ),
                          ),
                        ],
                      ),
                      // Media state
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Media assets',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.inkSoft,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.coverUrl.isEmpty
                                ? 'No cover image'
                                : 'Cover image saved',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.ink,
                            ),
                          ),
                          Text(
                            item.previewVideoUrl.isEmpty
                                ? 'No preview video'
                                : 'Preview video saved',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.inkSoft,
                            ),
                          ),
                        ],
                      ),
                      // Rewards eligibility
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isMoveCatch
                              ? AppColors.success.withValues(alpha: 0.1)
                              : AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isMoveCatch ? 'Rewards active' : 'Rewards inactive',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isMoveCatch
                                ? AppColors.success
                                : AppColors.inkSoft,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                const Divider(height: 1, color: AppColors.hairline),
                const SizedBox(height: 14),

                // Card Footer Actions
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      key: Key('edit-${item.gameId}'),
                      onPressed: !_editable(item)
                          ? null
                          : () {
                              if (_repository.current) {
                                setState(() => _editing = item);
                              }
                            },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.hairline),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(Icons.edit_outlined, size: 15),
                      label: const Text('Edit content'),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _selectedLeaderboardGame = item.gameId;
                          _activeTab = 'leaderboards';
                        });
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.ink,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                      icon: const Icon(Icons.leaderboard_outlined, size: 15),
                      label: const Text('View leaderboard'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardsTab(BuildContext context) {
    final competitionRepo = widget.competitionRepository ??
        FirebaseAdminMiniGameCompetitionRepository(
          scope: _repository.scope,
          isCurrent: () => _repository.current,
        );

    return MiniGameStandingsScreen(
      repository: competitionRepo,
      embedded: true,
      initialGameId: _selectedLeaderboardGame,
    );
  }

  Widget _buildRewardPolicyTab(BuildContext context) {
    final configuration = widget.rewardRepository ??
        (context.read<MiniGameRewardConfigurationRepository?>());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Reward Status Cards Row
        Row(
          children: [
            Expanded(
              child: _buildRewardStatusCard(
                title: 'Move & Catch',
                id: 'move-catch-v1',
                active: true,
                description:
                    'Participates in mini-game rewards. Members earn points for completed eligible rounds.',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildRewardStatusCard(
                title: 'Reach & Tap',
                id: 'reach-tap-v1',
                active: false,
                description:
                    'Reward points are currently inactive for this game mode.',
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Reward Policy Panel
        if (configuration != null)
          MiniGameRewardPolicyPanel(
            repository: configuration,
            initiallyExpanded: true,
          )
        else
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.hairline),
            ),
            child: const Text(
              'Reward policy configuration is not available for this session.',
              style: TextStyle(fontSize: 13.5, color: AppColors.inkSoft),
            ),
          ),
      ],
    );
  }

  Widget _buildRewardStatusCard({
    required String title,
    required String id,
    required bool active,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.hairline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: active
                      ? AppColors.success.withValues(alpha: 0.1)
                      : AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  active ? 'Active' : 'Inactive',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: active ? AppColors.success : AppColors.inkSoft,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            id,
            style: const TextStyle(fontSize: 12, color: AppColors.inkSoft),
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.inkSoft,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionUnavailable extends StatelessWidget {
  const _SessionUnavailable();
  @override
  Widget build(BuildContext context) => const Center(
      child: Text('Mini-game content unavailable for this session.'));
}

class _ContentEditor extends StatefulWidget {
  const _ContentEditor({
    super.key,
    required this.repository,
    required this.content,
    required this.onCancel,
    required this.onReload,
    required this.onSaved,
    this.imagePicker,
    this.videoPicker,
  });

  final MiniGameContentRepository repository;
  final MiniGameContent content;
  final EquipmentImagePicker? imagePicker;
  final EquipmentVideoPicker? videoPicker;
  final VoidCallback onCancel;
  final Future<void> Function() onReload;
  final ValueChanged<List<MiniGameContent>> onSaved;

  @override
  State<_ContentEditor> createState() => _ContentEditorState();
}

class _ContentEditorState extends State<_ContentEditor> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _title, _introduction;
  late final List<TextEditingController> _instructions;
  late String _coverUrl, _videoUrl;
  EquipmentImage? _image;
  EquipmentVideo? _video;
  Uint8List? _imageBytes;
  String? _coverUploadId, _videoUploadId, _saveId, _error, _mediaError;
  bool _coverUploaded = false, _videoUploaded = false;
  bool _saving = false,
      _picking = false,
      _reloadRequired = false,
      _sessionLost = false;

  bool get _busy => _saving || _picking;
  bool get _current => mounted && !_sessionLost && widget.repository.current;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.content.title);
    _introduction = TextEditingController(text: widget.content.introduction);
    _instructions = widget.content.instructions
        .map((value) => TextEditingController(text: value))
        .toList();
    _coverUrl = widget.content.coverUrl;
    _videoUrl = widget.content.previewVideoUrl;
  }

  @override
  void dispose() {
    _title.dispose();
    _introduction.dispose();
    for (final controller in _instructions) {
      controller.dispose();
    }
    super.dispose();
  }

  void _changed() => setState(() => _saveId = null);

  Future<void> _chooseCover() async {
    if (!_current || _busy) return;
    setState(() {
      _picking = true;
      _mediaError = null;
    });
    try {
      final value =
          await (widget.imagePicker ?? context.read<EquipmentImagePicker>())
              .pick();
      if (!_current || value == null) return;
      setState(() {
        _image = value;
        _imageBytes = value.copyBytes();
        _coverUploadId = _newId();
        _coverUploaded = false;
        _saveId = null;
      });
    } on FormatException catch (error) {
      if (_current) setState(() => _mediaError = error.message);
    } catch (_) {
      if (_current) {
        setState(
            () => _mediaError = 'Could not select the cover image. Try again.');
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _chooseVideo() async {
    if (!_current || _busy) return;
    setState(() {
      _picking = true;
      _mediaError = null;
    });
    try {
      final value =
          await (widget.videoPicker ?? context.read<EquipmentVideoPicker>())
              .pick();
      if (!_current || value == null) return;
      if (value.bytes.length > MiniGameContent.maxPreviewBytes) {
        throw const FormatException(
            'Choose an MP4 preview no larger than 20 MB.');
      }
      setState(() {
        _video = value;
        _videoUploadId = _newId();
        _videoUploaded = false;
        _saveId = null;
      });
    } on FormatException catch (error) {
      if (_current) setState(() => _mediaError = error.message);
    } catch (_) {
      if (_current) {
        setState(() =>
            _mediaError = 'Could not select the preview video. Try again.');
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _save() async {
    if (!_current || _busy || _reloadRequired) return;
    if (!_form.currentState!.validate()) return;
    final repository = widget.repository;
    _saveId ??= _newId();
    setState(() {
      _saving = true;
      _error = null;
      _mediaError = null;
    });
    try {
      if (_image != null && !_coverUploaded) {
        if (!_current) return;
        final url = await repository.upload(
            gameId: widget.content.gameId,
            kind: 'cover',
            uploadId: _coverUploadId!,
            bytes: _image!.copyBytes(),
            contentType: _image!.contentType);
        if (!_current) return;
        _coverUrl = url;
        _coverUploaded = true;
      }
      if (_video != null && !_videoUploaded) {
        if (!_current) return;
        final url = await repository.upload(
            gameId: widget.content.gameId,
            kind: 'preview',
            uploadId: _videoUploadId!,
            bytes: _video!.copyBytes(),
            contentType: 'video/mp4');
        if (!_current) return;
        _videoUrl = url;
        _videoUploaded = true;
      }
      if (!_current) return;
      final content = widget.content.copyWith(
          title: _title.text.trim(),
          introduction: _introduction.text.trim(),
          instructions: _instructions.map((c) => c.text.trim()).toList(),
          coverUrl: _coverUrl,
          previewVideoUrl: _videoUrl);
      final saved = await repository.save(
          requestId: _saveId!,
          baseRevision: widget.content.revision,
          content: content);
      if (!_current) return;
      final items = await repository.load();
      if (!_current) return;
      final scoped = items
          .where((item) =>
              MiniGameContent.supportedIds.contains(item.gameId) &&
              item.organizationId == repository.scope.organizationId)
          .toList();
      if (!scoped.any((item) =>
          item.gameId == saved.gameId && item.revision >= saved.revision)) {
        throw const MiniGameContentUnavailable();
      }
      widget.onSaved(_knownContent(scoped, repository.scope.organizationId));
    } on MiniGameContentConflict {
      if (_current) {
        setState(() {
          _reloadRequired = true;
          _error =
              'This content changed elsewhere. Reload before editing again.';
        });
      }
    } on MiniGameContentSessionChanged {
      if (mounted) setState(() => _sessionLost = true);
    } on MiniGameContentUploadFailed catch (error) {
      if (_current) setState(() => _error = error.message);
    } catch (_) {
      if (_current) {
        setState(() => _error =
            'Save was not confirmed. Retry with these edits or reload.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _requiredText(String? value, int max, String empty) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return empty;
    if (text.length > max) return 'Use $max characters or fewer.';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_sessionLost || !widget.repository.current) {
      return const _SessionUnavailable();
    }
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            MediaQuery.sizeOf(context).width < 600 ? 16 : 28,
            24,
            MediaQuery.sizeOf(context).width < 600 ? 16 : 28,
            40,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: PageBreadcrumb(
                  crumbs: [
                    PageCrumb('Mini-games', () {
                      if (!_busy) widget.onCancel();
                    }),
                    const PageCrumb('Edit content'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final titleCol = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Edit mini-game content',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_gameName(widget.content.gameId)} · Member introduction and how to play',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.inkSoft,
                        ),
                      ),
                    ],
                  );

                  if (constraints.maxWidth < 600) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        titleCol,
                        const SizedBox(height: 14),
                        _editorActions(),
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: titleCol),
                      _editorActions(),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              LayoutBuilder(
                builder: (context, constraints) {
                  final form = _formPanel(context);
                  final preview = _preview(context);
                  if (constraints.maxWidth >= 900) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: form),
                        const SizedBox(width: 24),
                        Expanded(flex: 2, child: preview),
                      ],
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      form,
                      const SizedBox(height: 24),
                      preview,
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _editorActions() => Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          OutlinedButton(
            onPressed: _busy ? null : widget.onCancel,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.ink,
              side: const BorderSide(color: AppColors.hairline),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: _busy || _reloadRequired ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(_saving
                ? 'Saving…'
                : _error != null && !_reloadRequired
                    ? 'Retry save'
                    : 'Save changes'),
          ),
          if (_error != null || _reloadRequired)
            TextButton(
              onPressed: _busy ? null : widget.onReload,
              child: const Text('Discard edits and reload'),
            ),
        ],
      );

  Widget _formPanel(BuildContext context) => Form(
        key: _form,
        onChanged: _changed,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Content details',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.hairline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    key: const Key('mini-game-title'),
                    controller: _title,
                    enabled: !_busy && !_reloadRequired,
                    maxLength: 80,
                    decoration: const InputDecoration(
                      labelText: 'Display title',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        _requiredText(v, 80, 'Enter a display title.'),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    key: const Key('mini-game-introduction'),
                    controller: _introduction,
                    enabled: !_busy && !_reloadRequired,
                    minLines: 3,
                    maxLines: 8,
                    maxLength: 2000,
                    decoration: const InputDecoration(
                      labelText: 'Introduction',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        _requiredText(v, 2000, 'Enter an introduction.'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            const Text(
              'How to play',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.hairline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Add 1–8 numbered instructions for members.',
                    style: TextStyle(fontSize: 12.5, color: AppColors.inkSoft),
                  ),
                  const SizedBox(height: 14),
                  for (var i = 0; i < _instructions.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextFormField(
                              key: Key('mini-game-instruction-$i'),
                              controller: _instructions[i],
                              enabled: !_busy && !_reloadRequired,
                              minLines: 2,
                              maxLines: 5,
                              maxLength: 500,
                              decoration: InputDecoration(
                                labelText: 'Instruction ${i + 1}',
                                border: const OutlineInputBorder(),
                              ),
                              validator: (v) =>
                                  _requiredText(v, 500, 'Enter an instruction.'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            tooltip: 'Remove instruction',
                            onPressed: _busy ||
                                    _reloadRequired ||
                                    _instructions.length <= 1
                                ? null
                                : () {
                                    final removed = _instructions.removeAt(i);
                                    _changed();
                                    WidgetsBinding.instance
                                        .addPostFrameCallback(
                                            (_) => removed.dispose());
                                  },
                            icon: const Icon(
                              Icons.remove_circle_outline,
                              color: AppColors.danger,
                            ),
                          ),
                        ],
                      ),
                    ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: _busy ||
                              _reloadRequired ||
                              _instructions.length >= 8
                          ? null
                          : () {
                              _instructions.add(TextEditingController());
                              _changed();
                            },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.hairline),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: const Text('Add instruction'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            const Text(
              'Media management',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.hairline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Cover image',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    _image != null
                        ? 'New cover selected'
                        : _coverUrl.isNotEmpty
                            ? 'Saved cover image'
                            : 'No cover image selected',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.inkSoft,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      OutlinedButton.icon(
                        onPressed:
                            _busy || _reloadRequired ? null : _chooseCover,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.ink,
                          side: const BorderSide(color: AppColors.hairline),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(Icons.add_photo_alternate_outlined,
                            size: 16),
                        label: Text(_image != null || _coverUrl.isNotEmpty
                            ? 'Replace cover image'
                            : 'Choose cover image'),
                      ),
                      if (_image != null || _coverUrl.isNotEmpty)
                        TextButton(
                          onPressed: _busy || _reloadRequired
                              ? null
                              : () => setState(() {
                                    _image = null;
                                    _imageBytes = null;
                                    _coverUrl = '';
                                    _coverUploadId = null;
                                    _coverUploaded = false;
                                    _saveId = null;
                                  }),
                          child: const Text('Remove cover'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'JPG, PNG or WebP · up to 5 MB',
                    style: TextStyle(fontSize: 11.5, color: AppColors.inkSoft),
                  ),
                  const SizedBox(height: 22),
                  const Divider(height: 1, color: AppColors.hairline),
                  const SizedBox(height: 20),

                  const Text('Preview video',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    _video != null
                        ? 'New preview selected'
                        : _videoUrl.isNotEmpty
                            ? 'Saved preview video'
                            : 'No preview video selected',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.inkSoft,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      OutlinedButton.icon(
                        onPressed:
                            _busy || _reloadRequired ? null : _chooseVideo,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.ink,
                          side: const BorderSide(color: AppColors.hairline),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(Icons.video_library_outlined, size: 16),
                        label: Text(_video != null || _videoUrl.isNotEmpty
                            ? 'Replace preview video'
                            : 'Choose preview video'),
                      ),
                      if (_video != null || _videoUrl.isNotEmpty)
                        TextButton(
                          onPressed: _busy || _reloadRequired
                              ? null
                              : () => setState(() {
                                    _video = null;
                                    _videoUrl = '';
                                    _videoUploadId = null;
                                    _videoUploaded = false;
                                    _saveId = null;
                                  }),
                          child: const Text('Remove video'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'MP4 · up to 20 MB. Files upload when you save.',
                    style: TextStyle(fontSize: 11.5, color: AppColors.inkSoft),
                  ),
                  if (_mediaError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        _mediaError!,
                        style: const TextStyle(color: AppColors.danger),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            if (_saving) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: 12),
              const Text('Uploading media and verifying saved content…'),
              const SizedBox(height: 12),
            ],
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _error!,
                  style: const TextStyle(color: AppColors.danger),
                ),
              ),
          ],
        ),
      );

  Widget _preview(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Member preview',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.hairline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(11)),
                  child: _cover(_coverUrl, bytes: _imageBytes),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _title.text.trim().isEmpty
                            ? _gameName(widget.content.gameId)
                            : _title.text.trim(),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _introduction.text.trim(),
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.inkSoft,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'How to play',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (var i = 0; i < _instructions.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: AppColors.primaryTint,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Center(
                                  child: Text(
                                    '${i + 1}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _instructions[i].text.trim(),
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: AppColors.ink,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (_video != null || _videoUrl.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        ContentVideoPreview(
                          semanticsLabel: 'Mini-game preview video',
                          url: _videoUrl,
                          bytes: _video?.bytes,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      );
}
