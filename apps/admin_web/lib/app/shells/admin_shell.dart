import '../routing/admin_console_navigation.dart';
import '../di/canonical_admin_recommendation_factory.dart';
import 'package:gainpath_data/gainpath_data.dart'
    show FypDatasetTransportFactory;
import '../../infrastructure/firebase/firebase_fyp_dataset.dart';
import '../../infrastructure/firebase/firebase_unified_admin.dart';
import '../../infrastructure/firebase/firebase_demo_recommendation.dart';
import '../../features/gamification/reward_fulfilment_repository.dart';
import '../../features/gamification/presentation/admin/reward_fulfilment_panel.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'dart:convert';
import 'package:file_selector/file_selector.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:gainpath_identity/gainpath_identity.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../features/analytics/presentation/admin/admin_dashboard_screens.dart';
import '../../features/recommendation/presentation/admin/admin_recommendation_screens.dart';
import '../../features/identity/presentation/admin/admin_settings_screens.dart';
import '../../features/identity/presentation/admin/admin_account_avatar.dart';
import '../../features/workout/presentation/admin/exercise_tutorials_screen.dart';
import '../../features/workout/presentation/admin/routine_templates_screen.dart';
import '../../features/workout/presentation/admin/workout_programs_screen.dart';
import '../../features/workout/presentation/admin/equipment_catalog_screen.dart';
import '../../features/gamification/presentation/admin/reward_catalog_screen.dart';
import '../../features/content/presentation/admin/announcements_screen.dart';
import '../../features/content/presentation/admin/mini_game_content_screen.dart';
import '../../infrastructure/local/equipment_video_picker.dart';
import 'package:gainpath_domain/gamification.dart' show MiniGameContent;
import '../../features/chatbot/presentation/admin/chatbot_disclaimer_screen.dart';
import '../../features/membership/presentation/admin/refunds_screen.dart';
import '../../features/analytics/presentation/admin/reports_screen.dart';
import '../../features/content/presentation/admin/system_settings_screen.dart';
import '../../features/identity/presentation/admin/members_screen.dart';
import '../../features/identity/presentation/admin/member_provision_page.dart'
    show MemberSetupRequest;
import '../../features/identity/presentation/admin/coaches_screen.dart';
import '../../features/identity/presentation/admin/coach_review_discard_guard.dart';
import '../../features/identity/presentation/admin/coach_review_notification_button.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_domain/gainpath_domain.dart'
    show AppRole, AuthSession, BookingListRepository;
import '../../features/operations_calendar/operations_calendar_data.dart';
import '../../features/operations_calendar/operations_calendar_screen.dart';
import 'package:gainpath_domain/coaching.dart' show CoachAvailabilityRepository;
import '../di/coach_availability_factory.dart';
import '../di/booking_factory.dart';
import 'gainpath_logo_data.dart';
import '../../features/recommendation/application/admin_ai_repository.dart';
import '../../features/recommendation/presentation/admin/admin_ai_pages.dart';
import '../../features/recommendation/presentation/admin/recommendation_monitor.dart';
import '../di/payment_review_factory.dart';
import '../routing/app_routes.dart';

/// A single directly-selectable sidebar destination.
class _NavPage {
  final IconData icon;
  final IconData iconFilled;
  final String label;
  final String subtitle;
  final Widget page;
  const _NavPage(
      this.icon, this.iconFilled, this.label, this.subtitle, this.page);
}

/// A sidebar destination that expands in place to reveal its children —
/// Content and Governance, per the console's structure. Never itself
/// selectable: it holds no page of its own, only a submenu.
class _NavGroup {
  final IconData icon;
  final IconData iconFilled;
  final String label;
  final List<_NavPage> children;
  final bool opensFirstChild;
  const _NavGroup(this.icon, this.iconFilled, this.label, this.children,
      {this.opensFirstChild = false});
}

/// Persistent left-sidebar shell for the Admin / Staff Web Console, per
/// design doc Section 7.1: desktop-width administrative software favours a
/// sidebar over a bottom bar, and dense data over card-first mobile layout.
/// A shared top bar owns page chrome (title, search, notifications, the
/// signed-in admin) so every section reads as one console rather than
/// independent mobile screens dropped into a sidebar frame — no section
/// ever pushes a new screen or shows a back button; the sidebar is the
/// only way to move between areas, exactly like a real admin website.
class AdminShell extends StatefulWidget {
  const AdminShell(
      {super.key,
      this.liveSession,
      this.datasetTransportFactory,
      this.coachBranchRequest,
      this.memberSetupRequest,
      this.branchRequest,
      this.branchCoverPicker,
      this.canonicalRecommendationFactory,
      this.allowContentRemoval =
          const bool.fromEnvironment('ADMIN_CONTENT_REMOVAL_ENABLED')});
  final CanonicalAdminRecommendationFactory? canonicalRecommendationFactory;
  final bool allowContentRemoval;
  final AuthSession? liveSession;
  final FypDatasetTransportFactory? datasetTransportFactory;
  final Future<Map<String, dynamic>> Function(Map<String, Object?>)?
      coachBranchRequest;
  final BranchRequest? branchRequest;
  final MemberSetupRequest? memberSetupRequest;
  final Future<String?> Function()? branchCoverPicker;

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  final _announcementsKey = GlobalKey<AnnouncementsScreenState>();
  Future<Map<String, ({String name, bool active})>>
      _announcementBranches() async {
    final scope = widget.liveSession!.scope;
    final callable = FirebaseFunctions.instanceFor(region: 'asia-southeast1')
        .httpsCallable('branchManagementCommand');
    final branches = <String, ({String name, bool active})>{};
    final cursors = <String>{};
    String? cursor;
    do {
      final response = await callable.call({
        'action': 'list',
        'organizationId': scope.organizationId,
        if (cursor != null) 'afterId': cursor,
      });
      if (!mounted || widget.liveSession?.scope != scope) {
        throw StateError('Admin session changed.');
      }
      final result = response.data as Map;
      for (final branch in (result['records'] as List).cast<Map>()) {
        branches[branch['branchId'] as String] = (
          name: branch['displayName'] as String,
          active: branch['status'] == 'active',
        );
      }
      cursor = result['nextAfterId'] as String?;
      if (cursor != null && !cursors.add(cursor)) {
        throw StateError('Branch directory pagination did not advance.');
      }
    } while (cursor != null);
    return branches;
  }

  static const _calendarPath = '/console/operations-calendar';
  static const _announcementsPath = '/console/announcements';
  static final _routeId = RegExp(r'^[A-Za-z0-9_-]{1,128}$');
  late final _calendarRepository =
      FirebaseOperationsCalendarRepository(_requestBranch);
  String? _calendarBranch;
  String? _announcementDrillDownId;
  String? _focusedBookingId;
  String? _focusedCoachBranch;
  String? _focusedScheduleDate;
  DateTime? _reportDrillDownDate;
  String? _reportDrillDownBranch;

  bool get _calendarEnabled {
    final session = widget.liveSession;
    return session != null &&
        session.role == AppRole.admin &&
        session.datasetScope == null &&
        !session.needsVerification &&
        session.accountLifecycleState == 'active';
  }

  String? _routeIdentifier(String? value) =>
      value != null && _routeId.hasMatch(value) ? value : null;

  DateTime? _parseCivilDate(String? value) {
    if (value == null || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
      return null;
    }
    final result = DateTime.tryParse('${value}T00:00:00Z');
    return result != null && _dateKey(result) == value ? result : null;
  }

  String _dateKey(DateTime day) => day.toIso8601String().split('T').first;

  void _openCalendarSource(OperationsEvent event) {
    if (event.type == CalendarEventType.announcement) {
      _select(_indexOfLabel('Announcements'), announcementId: event.sourceId);
      return;
    }
    if (event.coachId == null) return;
    final day = event.start.toUtc().add(const Duration(hours: 8));
    _select(
      _indexOfLabel('Coaches'),
      coachId: event.coachId,
      coachBranch: event.branchId,
      bookingId:
          event.type == CalendarEventType.booking ? event.sourceId : null,
      scheduleDate:
          event.type == CalendarEventType.availability ? _dateKey(day) : null,
    );
  }

  void _openCalendarCoach(OperationsEvent event) {
    if (event.coachId != null) {
      _select(_indexOfLabel('Coaches'), coachId: event.coachId);
    }
  }

  String? _coachDrillDownBranch;
  late final AdminAiRepository? _adminAi = widget.liveSession == null
      ? null
      : AdminAiRepository(
          organizationId: widget.liveSession!.scope.organizationId,
          isCurrent: () =>
              mounted &&
              context.read<AuthBloc>().state.session?.scope ==
                  widget.liveSession!.scope,
        );
  late final FirebaseDemoAdminRepositories? _fypRecommendations = widget
              .liveSession ==
          null
      ? null
      : widget.liveSession!.datasetScope == null
          ? FirebaseDemoAdminRepositories(
              (widget.datasetTransportFactory ??
                      ((scope, current) => UnifiedAdminTransport(
                          scope: scope, isCurrent: current)))(
                  widget.liveSession!.scope,
                  () =>
                      mounted &&
                      context.read<AuthBloc>().state.session ==
                          widget.liveSession),
              readOnly: true)
          : FirebaseDemoAdminRepositories(
              (widget.datasetTransportFactory ?? firebaseFypDatasetTransport)(
                  widget.liveSession!.scope,
                  () =>
                      mounted &&
                      context.read<AuthBloc>().state.session ==
                          widget.liveSession));
  late final _canonicalRecommendations = widget.liveSession == null
      ? null
      : (widget.canonicalRecommendationFactory ??
              createCanonicalAdminRecommendations)(
          widget.liveSession!,
          () =>
              mounted &&
              context.read<AuthBloc>().state.session == widget.liveSession);
  static const _addMemberPath = '/console/members/add';
  bool _addingMember = false;
  String? _memberProvisionBranch;
  Future<bool> Function()? _canLeaveMemberProvisioning;
  static const _addCoachPath = '/console/coaches/add';
  static const _coachesPath = '/console/coaches';
  BranchAdminRoute _branchRoute = const BranchAdminRoute();
  Future<bool> Function()? _canLeaveBranchEditor;
  final _coachReviewGuard = CoachReviewDiscardGuard();
  bool _addingCoach = false;
  Future<bool> Function()? _canLeaveCoachProvisioning;
  int _index = 0;
  String? _scopedCoachIdForBookings;
  String? _scopedCoachIdForSchedule;
  String? _scopedCoachIdForReview;
  String? _notificationCoachId;
  int _notificationReviewGeneration = 0;
  final Set<int> _visited = {0};
  final Set<String> _expanded = {'Users & Coaches', 'Payments'};
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  AdminConsoleNavigation? _consoleRoutes;
  ReportsCategory _lastReportCategory = ReportsCategory.overview;
  int get _reportsIndex => _firstChildIndexOfGroup('Reports');
  bool get _inReports => _groupLabelFor(_index) == 'Reports';
  ReportsCategory get _reportCategory =>
      ReportsCategory.values[_index - _reportsIndex];
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final routes = AdminConsoleNavigation.maybeOf(context);
    if (!identical(routes, _consoleRoutes)) {
      _consoleRoutes?.removeListener(_readConsoleRoute);
      _consoleRoutes = routes;
      _readConsoleRoute();
      routes?.addListener(_readConsoleRoute);
    }
  }

  void _readConsoleRoute() {
    final uri = _consoleRoutes?.uri;
    final segments = uri?.pathSegments ?? const <String>[];
    if (segments.length >= 2 &&
        segments[0] == 'console' &&
        segments[1] == 'branches') {
      final index = _indexOfLabel('Branches');
      final route = BranchAdminRoute.parse(segments.sublist(2));
      if (index != _index || route != _branchRoute) {
        _select(index, updateHistory: false, branchRoute: route);
      }
    } else if (uri?.path == _calendarPath && _calendarEnabled) {
      final index = _indexOfLabel('Operations Calendar');
      final branch = _routeIdentifier(uri!.queryParameters['branch']);
      if (index != _index || branch != _calendarBranch) {
        _select(index, updateHistory: false, calendarBranch: branch);
      }
    } else if (uri?.path == _coachesPath &&
        _calendarEnabled &&
        uri!.queryParameters.containsKey('coach')) {
      final coachId = _routeIdentifier(uri.queryParameters['coach']);
      final bookingId = _routeIdentifier(uri.queryParameters['booking']);
      final date = _parseCivilDate(uri.queryParameters['date']);
      final scheduleDate = date == null ? null : _dateKey(date);
      final branch = _routeIdentifier(uri.queryParameters['branch']);
      final index = _indexOfLabel('Coaches');
      final currentCoach = _scopedCoachIdForBookings ??
          _scopedCoachIdForSchedule ??
          _scopedCoachIdForReview;
      if (coachId != null &&
          (index != _index ||
              coachId != currentCoach ||
              bookingId != _focusedBookingId ||
              scheduleDate != _focusedScheduleDate ||
              branch != _focusedCoachBranch)) {
        _select(index,
            updateHistory: false,
            coachId: coachId,
            coachBranch: branch,
            bookingId: bookingId,
            scheduleDate: scheduleDate);
      }
    } else if (uri?.path == _announcementsPath &&
        _calendarEnabled &&
        uri!.queryParameters.containsKey('announcement')) {
      final id = _routeIdentifier(uri.queryParameters['announcement']);
      final index = _indexOfLabel('Announcements');
      if (id != null && (index != _index || id != _announcementDrillDownId)) {
        _select(index, updateHistory: false, announcementId: id);
      }
    } else if (uri?.path == _addMemberPath) {
      final branch = uri!.queryParameters['branch'];
      final branchId =
          branch != null && RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(branch)
              ? branch
              : null;
      if (_addingMember && _memberProvisionBranch == branchId) return;
      _select(_indexOfLabel('Members'),
          updateHistory: false,
          addMember: _memberSetupEnabled,
          memberBranch: branchId);
    } else if (uri?.path == _addCoachPath) {
      if (_addingCoach) return;
      final session = widget.liveSession;
      _select(_indexOfLabel('Coaches'),
          updateHistory: false,
          addCoach: session != null && session.datasetScope == null);
    } else if (segments.isNotEmpty && segments.first == 'reports') {
      final name = segments.length > 1 ? segments[1] : 'overview';
      final category =
          ReportsCategory.values.where((c) => c.name == name).firstOrNull ??
              ReportsCategory.overview;
      final branch = category == ReportsCategory.branches
          ? uri?.queryParameters['branch']
          : null;
      final date = category == ReportsCategory.branches
          ? _parseCivilDate(uri?.queryParameters['date'])
          : null;
      if (!_inReports ||
          _reportCategory != category ||
          _reportDrillDownBranch != branch ||
          _reportDrillDownDate != date) {
        _select(_reportsIndex + category.index,
            updateHistory: false, reportBranch: branch, reportDate: date);
      }
    } else if (segments.length == 2 && segments.first == 'console') {
      final index =
          _flatPages.indexWhere((page) => _pageSlug(page) == segments[1]);
      if (index >= 0 &&
          (index != _index ||
              _addingCoach ||
              _addingMember ||
              (_flatPages[index].label == 'Coaches' &&
                  (_focusedBookingId != null ||
                      _focusedScheduleDate != null ||
                      _scopedCoachIdForReview != null)) ||
              (_flatPages[index].label == 'Announcements' &&
                  _announcementDrillDownId != null))) {
        _select(index, updateHistory: false);
      }
    } else if (segments.isEmpty || _inReports) {
      _select(0, updateHistory: false);
    }
  }

  String _pageSlug(_NavPage page) => page.label == 'Overview'
      ? 'recommendations'
      : page.label.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
  @override
  void dispose() {
    _consoleRoutes?.removeListener(_readConsoleRoute);
    super.dispose();
  }

  void _openRewardCollection() {
    final source = context.read<AdminMemberDirectoryRepository>();
    if (source is! RewardFulfilmentRepository) return;
    final auth = context.read<AuthBloc>();
    showDialog<void>(
        context: context,
        builder: (_) => Dialog(
            child: SizedBox(
                width: 520,
                child: BlocBuilder<AuthBloc, AuthState>(
                    bloc: auth,
                    builder: (_, __) => SingleChildScrollView(
                        child: RewardFulfilmentPanel(
                            repository:
                                source as RewardFulfilmentRepository))))));
  }

  /// Built once (not `const`) so the Dashboard's refund-alert callback can
  /// close over `this` — rebuilding this list on every `setState` would
  /// otherwise recreate every page widget and reset their internal state.
  late final List<Object> _destinations = <Object>[
    _NavPage(
        Icons.dashboard_outlined,
        Icons.dashboard_rounded,
        'Dashboard',
        'How the facility is doing today',
        AdminDashboardScreen(
            live: widget.liveSession != null,
            liveSession: widget.liveSession,
            onOpenRefunds: () => _select(_indexOfLabel('Refund Requests')),
            onOpenCoaches: () => _select(_indexOfLabel('Coaches')),
            onProcessVoucher: _openRewardCollection)),
    _NavGroup(
        Icons.people_outline_rounded, Icons.people_rounded, 'Users & Coaches', [
      _NavPage(Icons.groups_outlined, Icons.groups_rounded, 'Members',
          'Search, filter, and view member accounts', const MembersScreen()),
      _NavPage(
          Icons.sports_outlined,
          Icons.sports_rounded,
          'Coaches',
          'Provision, verify, and manage coaches by branch',
          CoachesScreen(
              live: widget.liveSession != null,
              discardGuard: _coachReviewGuard)),
    ]),
    if (widget.liveSession != null)
      _NavPage(
        Icons.location_on_outlined,
        Icons.location_on,
        'Branches',
        'Manage gym locations',
        const SizedBox.shrink(),
      ),
    if (_calendarEnabled)
      const _NavPage(
        Icons.calendar_month_outlined,
        Icons.calendar_month_rounded,
        'Operations Calendar',
        '',
        SizedBox.shrink(),
      ),
    _NavGroup(Icons.auto_awesome_outlined, Icons.auto_awesome_rounded,
        'Recommendations', [
      _NavPage(
          Icons.dashboard_outlined,
          Icons.dashboard_rounded,
          'Overview',
          'Monitor recommendations and delivery outcomes',
          RiskLeaderboardScreen(
              live: widget.liveSession != null,
              insightsRepository: _fypRecommendations?.insights,
              queueRepository: _fypRecommendations?.queue,
              canonicalRepository: _canonicalRecommendations,
              relatedLinks: {
                for (final destination in const [
                  'AI Content Planner',
                  'AI Member Outreach',
                  'Delivery Issues',
                  'Exercise Guidance Insights',
                ])
                  destination: () => _select(_indexOfLabel(destination)),
              })),
      _NavPage(
          Icons.auto_awesome_outlined,
          Icons.auto_awesome,
          'AI Content Planner',
          'Discover and draft new fitness content',
          AiContentPlannerPage(repository: _adminAi)),
      _NavPage(
          Icons.people_alt_outlined,
          Icons.people_alt,
          'AI Member Outreach',
          'Analyze active members and send personalized suggestions',
          AiMemberOutreachPage(repository: _adminAi)),
      _NavPage(
          Icons.error_outline,
          Icons.error,
          'Delivery Issues',
          'Review recommendation delivery outcomes',
          RiskLeaderboardScreen(
              live: widget.liveSession != null,
              canonicalRepository: _canonicalRecommendations,
              initialTab: RecommendationMonitorTab.attention)),
      _NavPage(
          Icons.insights_outlined,
          Icons.insights,
          'Exercise Guidance Insights',
          'Review exercise guidance coverage',
          RiskLeaderboardScreen(
              live: widget.liveSession != null,
              insightsRepository: _fypRecommendations?.insights,
              initialInsights: true)),
    ]),
    _NavGroup(Icons.payments_outlined, Icons.payments_rounded, 'Payments', [
      _NavPage(
          Icons.receipt_long_outlined,
          Icons.receipt_long_rounded,
          'Transactions',
          'Track membership and coaching payments',
          widget.liveSession == null
              ? PaymentsScreen(
                  key: const ValueKey('payments-transactions'),
                  mode: PaymentsMode.transactions,
                  onNavigateMode: _navigateToPaymentMode)
              : AdminPaymentReviewRoute(
                  key: const ValueKey('payments-transactions'),
                  session: widget.liveSession!,
                  mode: PaymentsMode.transactions,
                  onNavigateMode: _navigateToPaymentMode)),
      _NavPage(
          Icons.assignment_return_outlined,
          Icons.assignment_return_rounded,
          'Refund Requests',
          'Review and manage member refund requests',
          widget.liveSession == null
              ? PaymentsScreen(
                  key: const ValueKey('payments-refunds'),
                  mode: PaymentsMode.refunds,
                  onNavigateMode: _navigateToPaymentMode)
              : AdminPaymentReviewRoute(
                  key: const ValueKey('payments-refunds'),
                  session: widget.liveSession!,
                  mode: PaymentsMode.refunds,
                  onNavigateMode: _navigateToPaymentMode)),
      _NavPage(
          Icons.troubleshoot_outlined,
          Icons.troubleshoot_rounded,
          'Reconciliation',
          'Investigate uncertain payments and resolve processing exceptions',
          widget.liveSession == null
              ? PaymentsScreen(
                  key: const ValueKey('payments-reconciliation'),
                  mode: PaymentsMode.reconciliation,
                  onNavigateMode: _navigateToPaymentMode)
              : AdminPaymentReviewRoute(
                  key: const ValueKey('payments-reconciliation'),
                  session: widget.liveSession!,
                  mode: PaymentsMode.reconciliation,
                  onNavigateMode: _navigateToPaymentMode)),
    ]),
    _NavGroup(Icons.folder_outlined, Icons.folder_rounded, 'Content', [
      _NavPage(
          Icons.video_library_outlined,
          Icons.video_library_rounded,
          'Exercise Catalog',
          'Manage the tutorial video library',
          const ExerciseTutorialsScreen()),
      _NavPage(
          Icons.list_alt_outlined,
          Icons.list_alt_rounded,
          'Routine Templates',
          'Author and assign workout blueprints',
          RoutineTemplatesScreen(allowRemoval: widget.allowContentRemoval)),
      _NavPage(
          Icons.calendar_month_outlined,
          Icons.calendar_month,
          'Workout Programs',
          'Manage training levels and weekly schedules',
          WorkoutProgramsScreen(
              onOpenRoutineBuilder: () =>
                  _select(_indexOfLabel('Routine Templates')))),
      _NavPage(
          Icons.sports_esports_outlined,
          Icons.sports_esports_rounded,
          'Mini-games',
          'Edit introductions, instructions and media for supported games',
          MiniGameContentScreen(
              videoPicker: LocalEquipmentVideoPicker(
                  maxBytes: MiniGameContent.maxPreviewBytes))),
    ]),
    _NavPage(
        Icons.fitness_center_outlined,
        Icons.fitness_center_rounded,
        'Equipment Catalog',
        'Publish and retire gym-floor machines',
        const EquipmentCatalogScreen()),
    _NavGroup(Icons.gavel_outlined, Icons.gavel_rounded, 'Governance', [
      _NavPage(
          Icons.card_giftcard_outlined,
          Icons.card_giftcard_rounded,
          'Reward Catalog',
          widget.liveSession != null
              ? 'Manage the reward shop, reward details and voucher collection'
              : 'Points-shop inventory and stock',
          RewardCatalogScreen(live: widget.liveSession != null)),
      _NavPage(Icons.campaign_outlined, Icons.campaign_rounded, 'Announcements',
          'Manage updates across gym locations', const SizedBox.shrink()),
      _NavPage(
          Icons.smart_toy_outlined,
          Icons.smart_toy_rounded,
          'AI Chatbot Disclaimer',
          'The safety notice shown before first use',
          ChatbotDisclaimerScreen(live: widget.liveSession != null)),
    ]),
    _NavGroup(
        Icons.bar_chart_outlined,
        Icons.bar_chart_rounded,
        'Reports',
        [
          for (final category in ReportsCategory.values)
            _NavPage(Icons.analytics_outlined, Icons.analytics_rounded,
                category.label, '', const SizedBox.shrink()),
        ],
        opensFirstChild: true),
    _NavPage(
        Icons.tune_outlined,
        Icons.tune_rounded,
        'System Settings',
        'General, reward conversion, legal & compliance',
        SystemSettingsScreen(live: widget.liveSession != null)),
  ];

  List<_NavPage> get _flatPages {
    final pages = <_NavPage>[];
    for (final d in _destinations) {
      if (d is _NavPage) pages.add(d);
      if (d is _NavGroup) pages.addAll(d.children);
    }
    return pages;
  }

  Widget _branchDirectory({required bool active}) => BranchDirectoryPage(
        admin: true,
        adminVisible: active,
        adminRoute: _branchRoute,
        onAdminNavigate: (route, {required bool replace}) => _select(
          _indexOfLabel('Branches'),
          branchRoute: route,
          replaceBranchRoute: replace,
        ),
        onEditorLeaveCheckChanged: (route, check) {
          if (_branchRoute == route) _canLeaveBranchEditor = check;
        },
        adminOperation: _buildBranchOperation,
        onOpenCalendar: !_calendarEnabled
            ? null
            : (branchId) {
                _select(_indexOfLabel('Operations Calendar'),
                    calendarBranch: branchId);
              },
        onOpenReports: (branchId) {
          _select(_reportsIndex + ReportsCategory.branches.index,
              reportBranch: branchId);
        },
        onOpenCoaches: (branchId) {
          final index = _indexOfLabel('Coaches');
          if (index < 0) return;
          setState(() => _coachDrillDownBranch = branchId);
          _select(index);
        },
        pickCover: widget.branchCoverPicker ?? _pickBranchCover,
        openDirections: (uri) => launchUrl(uri, webOnlyWindowName: '_blank'),
        request: _requestBranch,
      );

  Future<String?> _pickBranchCover() async {
    final file = await openFile(acceptedTypeGroups: const [
      XTypeGroup(label: 'Images', extensions: ['jpg', 'jpeg', 'png']),
    ]);
    if (file == null) return null;
    if (await file.length() > 2 * 1024 * 1024) {
      throw StateError('Cover images must be 2 MB or less.');
    }
    return base64Encode(await file.readAsBytes());
  }

  Future<Map<String, dynamic>> _requestBranch(
      Map<String, Object?> input) async {
    final override = widget.branchRequest;
    if (override != null) return override(input);
    final session = widget.liveSession!;
    final auth = context.read<AuthBloc>();
    if (auth.state.session?.scope != session.scope) {
      throw StateError('Admin session changed.');
    }
    try {
      final result =
          await FirebaseFunctions.instanceFor(region: 'asia-southeast1')
              .httpsCallable('branchManagementCommand')
              .call({...input, 'organizationId': session.scope.organizationId});
      if (!mounted || auth.state.session?.scope != session.scope) {
        throw StateError('Admin session changed.');
      }
      return Map<String, dynamic>.from(result.data as Map);
    } on FirebaseFunctionsException catch (error) {
      if (input['action'] == 'save') {
        throw BranchSaveException(code: error.code);
      }
      rethrow;
    }
  }

  bool get _memberSetupEnabled =>
      widget.liveSession != null && widget.liveSession!.datasetScope == null;

  Future<Map<String, dynamic>> _requestMemberSetup(
      Map<String, Object?> input) async {
    if (widget.memberSetupRequest case final request?) return request(input);
    final session = widget.liveSession!;
    final auth = context.read<AuthBloc>();
    if (auth.state.session?.scope != session.scope) {
      throw StateError('Admin session changed.');
    }
    final reply = await FirebaseFunctions.instanceFor(region: 'asia-southeast1')
        .httpsCallable('adminMemberProvisioning')
        .call({...input, 'organizationId': session.scope.organizationId});
    if (!mounted || auth.state.session?.scope != session.scope) {
      throw StateError('Admin session changed.');
    }
    return Map<String, dynamic>.from(reply.data as Map);
  }

  Widget _buildBranchOperation(BranchAdminRoute route) {
    if (route.section == BranchAdminSection.members) {
      return MembersScreen(
          live: true,
          branchId: route.id,
          branchRequest: _requestBranch,
          memberSetup: _memberSetupEnabled ? _requestMemberSetup : null,
          onOpenAddMember: () => _select(_indexOfLabel('Members'),
              addMember: true, memberBranch: route.id));
    }
    return AdminBookingListRoute(
      session: widget.liveSession!,
      repository: context.read<BookingListRepository>(),
      branchId: route.id,
    );
  }

  void _navigateToPaymentMode(PaymentsMode mode) {
    final label = switch (mode) {
      PaymentsMode.transactions => 'Transactions',
      PaymentsMode.refunds => 'Refund Requests',
      PaymentsMode.reconciliation => 'Reconciliation',
    };
    _select(_indexOfLabel(label));
  }

  int _indexOfLabel(String label) {
    final index = _flatPages.indexWhere((p) => p.label == label);
    if (index != -1) return index;
    if (label == 'Refunds') {
      final refundReqIndex =
          _flatPages.indexWhere((p) => p.label == 'Refund Requests');
      if (refundReqIndex != -1) return refundReqIndex;
      return _flatPages.indexWhere((p) => p.label == 'Transactions');
    }
    if (label == 'Payments') {
      final txIndex = _flatPages.indexWhere((p) => p.label == 'Transactions');
      if (txIndex != -1) return txIndex;
      return _flatPages.indexWhere((p) => p.label == 'Refund Requests');
    }
    return -1;
  }

  String? _groupLabelFor(int flatIndex) {
    var cursor = 0;
    for (final d in _destinations) {
      if (d is _NavPage) {
        if (cursor == flatIndex) return null;
        cursor++;
      } else if (d is _NavGroup) {
        if (flatIndex >= cursor && flatIndex < cursor + d.children.length) {
          return d.label;
        }
        cursor += d.children.length;
      }
    }
    return null;
  }

  int _firstChildIndexOfGroup(String label) {
    var cursor = 0;
    for (final d in _destinations) {
      if (d is _NavPage) {
        cursor++;
      } else if (d is _NavGroup) {
        if (d.label == label) return cursor;
        cursor += d.children.length;
      }
    }
    return 0;
  }

  /// `Home` alone for the Dashboard, `Home > Group > Page` (or
  /// `Home > Page` for a flat top-level item) everywhere else — every
  /// page in this console can point to where it sits.
  List<_Crumb> _breadcrumbs() {
    final crumbs = <_Crumb>[
      _Crumb(
          'Home',
          _index == 0 &&
                  _scopedCoachIdForBookings == null &&
                  _scopedCoachIdForSchedule == null &&
                  _scopedCoachIdForReview == null
              ? null
              : () => _select(0))
    ];
    if (_index == 0 &&
        _scopedCoachIdForBookings == null &&
        _scopedCoachIdForSchedule == null &&
        _scopedCoachIdForReview == null) {
      return crumbs;
    }
    final group = _groupLabelFor(_index);
    if (group != null) {
      crumbs.add(_Crumb(group, () => _select(_firstChildIndexOfGroup(group))));
    }
    if (_branchRoute.section != BranchAdminSection.directory &&
        _flatPages[_index].label == 'Branches') {
      crumbs.add(_Crumb('Branches', () => _select(_index)));
      if (_branchRoute.id case final String id) {
        final overview = _branchRoute.section == BranchAdminSection.overview;
        crumbs.add(_Crumb(
          id,
          overview
              ? null
              : () => _select(_index,
                  branchRoute:
                      BranchAdminRoute(BranchAdminSection.overview, id)),
        ));
      }
      if (_branchRoute.section != BranchAdminSection.overview) {
        crumbs.add(_Crumb(_branchRoute.label, null));
      }
    } else if (_addingMember) {
      crumbs.add(_Crumb('Members', _returnToMemberList));
      crumbs.add(const _Crumb('Add Member', null));
    } else if (_addingCoach) {
      crumbs.add(_Crumb('Coaches', () => _select(_index)));
      crumbs.add(const _Crumb('Add Coach', null));
    } else if (_scopedCoachIdForBookings != null) {
      crumbs.add(_Crumb(_flatPages[_index].label, () => _select(_index)));
      crumbs.add(const _Crumb('Coach Bookings', null));
    } else if (_scopedCoachIdForSchedule != null) {
      crumbs.add(_Crumb(_flatPages[_index].label, () => _select(_index)));
      crumbs.add(const _Crumb('Coach Schedule', null));
    } else if (_scopedCoachIdForReview != null) {
      crumbs.add(_Crumb(_flatPages[_index].label, () async {
        if (!await _coachReviewGuard.canLeave() || !mounted) return;
        setState(() => _scopedCoachIdForReview = null);
      }));
      crumbs.add(const _Crumb('Coach Profile Review', null));
    } else {
      crumbs.add(_Crumb(_flatPages[_index].label, null));
    }
    return crumbs;
  }

  Future<void> _select(int flatIndex,
      {bool updateHistory = true,
      String? reportBranch,
      DateTime? reportDate,
      String? calendarBranch,
      String? coachId,
      String? coachBranch,
      String? bookingId,
      String? scheduleDate,
      String? announcementId,
      bool addCoach = false,
      bool addMember = false,
      String? memberBranch,
      bool replaceMemberRoute = false,
      BranchAdminRoute branchRoute = const BranchAdminRoute(),
      bool replaceBranchRoute = false}) async {
    if (flatIndex < 0) return;
    final requestedUri = _consoleRoutes?.uri;
    final previousBranch = _branchRoute;
    if (previousBranch != branchRoute &&
        !replaceBranchRoute &&
        !await _mayLeaveBranchEditor()) {
      if (mounted && !updateHistory && _consoleRoutes?.uri == requestedUri) {
        _consoleRoutes?.go(context, previousBranch.uri);
      }
      return;
    }
    final leavingAddMember =
        _addingMember && (!addMember || memberBranch != _memberProvisionBranch);
    if (leavingAddMember && !await _canLeaveAddMember()) {
      if (mounted && !updateHistory && _consoleRoutes?.uri == requestedUri) {
        _consoleRoutes?.go(context, _memberAddUri(_memberProvisionBranch));
      }
      return;
    }
    final leavingAddCoach = _addingCoach && !addCoach;
    if (leavingAddCoach && !await _canLeaveAddCoach()) {
      if (mounted && !updateHistory && _consoleRoutes?.uri == requestedUri) {
        _consoleRoutes?.go(context, Uri.parse(_addCoachPath));
      }
      return;
    }
    if (flatIndex != _index && !await _coachReviewGuard.canLeave()) return;
    if (_flatPages[_index].label == 'Announcements' &&
        (flatIndex != _index || announcementId != _announcementDrillDownId)) {
      if (await _announcementsKey.currentState?.canLeave() == false) {
        if (!updateHistory && mounted && _consoleRoutes?.uri == requestedUri) {
          _consoleRoutes?.go(
              context,
              Uri(
                  path: _announcementsPath,
                  queryParameters: _announcementDrillDownId == null
                      ? null
                      : {'announcement': _announcementDrillDownId!}));
        }
        return;
      }
    }
    if (!mounted || (!updateHistory && _consoleRoutes?.uri != requestedUri)) {
      return;
    }
    final replace = leavingAddCoach && flatIndex == _index;
    final owner = _groupLabelFor(flatIndex);
    if (previousBranch != branchRoute) _canLeaveBranchEditor = null;
    setState(() {
      _index = flatIndex;
      _addingCoach = addCoach;
      _addingMember = addMember;
      _memberProvisionBranch = addMember ? memberBranch : null;
      _branchRoute = branchRoute;
      _reportDrillDownBranch = reportBranch;
      _reportDrillDownDate = reportDate;
      if (_flatPages[flatIndex].label == 'Operations Calendar') {
        _calendarBranch = calendarBranch;
      }
      _announcementDrillDownId = announcementId;
      _focusedBookingId = bookingId;
      _focusedScheduleDate = scheduleDate;
      _focusedCoachBranch = coachBranch;
      _scopedCoachIdForBookings = bookingId == null ? null : coachId;
      _scopedCoachIdForSchedule = scheduleDate == null ? null : coachId;
      _scopedCoachIdForReview =
          bookingId == null && scheduleDate == null ? coachId : null;
      _visited.add(flatIndex);
      if (owner != null) _expanded.add(owner);
    });
    if (owner == 'Reports') _lastReportCategory = _reportCategory;
    if (updateHistory) {
      final page = _flatPages[flatIndex];
      final Uri uri;
      if (owner == 'Reports') {
        uri = Uri(
          path: '/reports/${_reportCategory.name}',
          queryParameters: reportBranch == null && reportDate == null
              ? null
              : {
                  if (reportBranch != null) 'branch': reportBranch,
                  if (reportDate != null) 'date': _dateKey(reportDate),
                },
        );
      } else if (page.label == 'Branches') {
        uri = branchRoute.uri;
      } else if (page.label == 'Operations Calendar') {
        uri = Uri(
          path: _calendarPath,
          queryParameters:
              calendarBranch == null ? null : {'branch': calendarBranch},
        );
      } else if (coachId != null) {
        uri = Uri(path: _coachesPath, queryParameters: {
          'coach': coachId,
          if (coachBranch != null) 'branch': coachBranch,
          if (bookingId != null) 'booking': bookingId,
          if (scheduleDate != null) 'date': scheduleDate,
        });
      } else if (announcementId != null) {
        uri = Uri(
            path: _announcementsPath,
            queryParameters: {'announcement': announcementId});
      } else if (addMember) {
        uri = _memberAddUri(memberBranch);
      } else {
        uri = Uri.parse(addCoach
            ? _addCoachPath
            : flatIndex == 0
                ? '/'
                : '/console/${_pageSlug(page)}');
      }
      _consoleRoutes?.go(context, uri,
          replace: replace || replaceBranchRoute || replaceMemberRoute);
    }
  }

  Uri _memberAddUri(String? branch) => Uri(
        path: _addMemberPath,
        queryParameters: branch == null ? null : {'branch': branch},
      );

  Future<bool> _canLeaveAddMember() async =>
      await _canLeaveMemberProvisioning?.call() ?? true;

  Future<void> _returnToMemberList() {
    final homeBranch = _memberProvisionBranch;
    return homeBranch == null
        ? _select(_indexOfLabel('Members'), replaceMemberRoute: true)
        : _select(_indexOfLabel('Branches'),
            replaceMemberRoute: true,
            branchRoute:
                BranchAdminRoute(BranchAdminSection.members, homeBranch));
  }

  Future<void> _closeAddMember() async {
    _canLeaveMemberProvisioning = null;
    await _returnToMemberList();
  }

  Future<bool> _mayLeaveBranchEditor() async =>
      await _canLeaveBranchEditor?.call() ?? true;

  Future<bool> _canLeaveAddCoach() async =>
      await _canLeaveCoachProvisioning?.call() ?? true;

  void _closeAddCoach() {
    setState(() => _addingCoach = false);
    _consoleRoutes?.go(context, Uri.parse(_coachesPath), replace: true);
  }

  void _toggleGroup(String label) {
    setState(() {
      if (_expanded.contains(label)) {
        _expanded.remove(label);
      } else {
        _expanded.add(label);
      }
    });
  }

  Future<void> _openCoachAlert(String coachId) async {
    if (!await _mayLeaveBranchEditor() ||
        !await _canLeaveAddCoach() ||
        !await _canLeaveAddMember() ||
        !await _coachReviewGuard.canLeave() ||
        !mounted) {
      return;
    }
    if (_addingCoach) _closeAddCoach();
    final fromAddMember = _addingMember;
    final fromBranches = _flatPages[_index].label == 'Branches';
    final fromCalendar = _flatPages[_index].label == 'Operations Calendar' ||
        _focusedBookingId != null ||
        _focusedScheduleDate != null ||
        _announcementDrillDownId != null;
    final index = _indexOfLabel('Coaches');
    setState(() {
      _index = index;
      _visited.add(index);
      _expanded.add('Users & Coaches');
      _scopedCoachIdForBookings = null;
      _scopedCoachIdForSchedule = null;
      _scopedCoachIdForReview = coachId;
      _notificationCoachId = coachId;
      _focusedBookingId = null;
      _focusedCoachBranch = null;
      _focusedScheduleDate = null;
      _announcementDrillDownId = null;
      _addingMember = false;
      _memberProvisionBranch = null;
      _branchRoute = const BranchAdminRoute();
      _canLeaveBranchEditor = null;
      _notificationReviewGeneration++;
    });
    if (fromBranches || fromAddMember || fromCalendar) {
      _consoleRoutes?.go(context, Uri.parse(_coachesPath));
    }
  }

  Future<void> _signOut() async {
    if (!await _mayLeaveBranchEditor() ||
        !await _canLeaveAddCoach() ||
        !await _canLeaveAddMember() ||
        !await _coachReviewGuard.canLeave() ||
        !mounted) {
      return;
    }
    final ok = await confirmDialog(context,
        title: 'Sign out of the console?',
        message: 'You will need to sign in again next time.',
        confirmLabel: 'Sign out',
        destructive: true);
    if (ok && mounted) {
      context.read<AuthBloc>().add(const LoggedOut());
      if (widget.liveSession == null) {
        Navigator.pushNamedAndRemoveUntil(context,
            kIsWeb ? AppRoutes.adminLogin : AppRoutes.roleSelect, (r) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final flatPages = _flatPages;
    final current = flatPages[_index];
    final useDrawer = MediaQuery.sizeOf(context).width < 1100 ||
        MediaQuery.textScalerOf(context).scale(1) > 1.5;
    final navigation = _Sidebar(
      liveSession: widget.liveSession,
      collapsed: false,
      selectedIndex: _index,
      expandedGroups: _expanded,
      destinations: _destinations,
      onSelect: (index) {
        if (useDrawer) _scaffoldKey.currentState?.closeDrawer();
        _select(index);
      },
      onToggleGroup: _toggleGroup,
    );
    return Scaffold(
      key: _scaffoldKey,
      drawer: useDrawer
          ? Drawer(width: 300, child: SafeArea(child: navigation))
          : null,
      backgroundColor: AppColors.bg,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Row(
            children: [
              if (!useDrawer) navigation,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _TopBar(
                        onOpenNavigation: useDrawer
                            ? () => _scaffoldKey.currentState?.openDrawer()
                            : null,
                        onOpenCoachAlert: _openCoachAlert,
                        liveSession: widget.liveSession,
                        breadcrumbs: _breadcrumbs(),
                        subtitle: current.label == 'Branches'
                            ? ''
                            : _addingCoach
                                ? 'Create a coach account and assign branches'
                                : _inReports
                                    ? ''
                                    : current.subtitle,
                        onSignOut: _signOut),
                    Expanded(
                      child: IndexedStack(
                        sizing: StackFit.expand,
                        index: _inReports ? _reportsIndex : _index,
                        children: flatPages.asMap().entries.map((entry) {
                          final session = widget.liveSession, d = entry.value;
                          if (_groupLabelFor(entry.key) == 'Reports') {
                            if (entry.key != _reportsIndex ||
                                !_visited.any(
                                    (i) => _groupLabelFor(i) == 'Reports')) {
                              return const SizedBox.shrink();
                            }
                            return ReportsScreen(
                                key: const ValueKey('retained-reports'),
                                live: session != null,
                                initialBranchId: _reportDrillDownBranch,
                                initialDate: _reportDrillDownDate,
                                branchRequest:
                                    session == null ? null : _requestBranch,
                                active: _inReports,
                                category: _lastReportCategory,
                                onCategoryChanged: (category) =>
                                    _select(_reportsIndex + category.index));
                          }
                          if (session != null &&
                              !_visited.contains(entry.key)) {
                            return const SizedBox.shrink();
                          }
                          if (session != null && d.label == 'Branches') {
                            return _branchDirectory(
                                active: entry.key == _index);
                          }
                          if (d.label == 'Operations Calendar') {
                            return OperationsCalendarScreen(
                              key: ValueKey(session?.scope),
                              repository: _calendarRepository,
                              initialBranchId: _calendarBranch,
                              onOpenSource: _openCalendarSource,
                              onOpenCoach: _openCalendarCoach,
                              onOpenReport: (branch, day) => _select(
                                _reportsIndex + ReportsCategory.branches.index,
                                reportBranch: branch,
                                reportDate: day,
                              ),
                            );
                          }
                          if (d.label == 'Announcements') {
                            return AnnouncementsScreen(
                              key: _announcementsKey,
                              loadBranches: session == null
                                  ? null
                                  : _announcementBranches,
                              initialAnnouncementId: _announcementDrillDownId,
                            );
                          }
                          if (session != null && d.label == 'Members') {
                            return MembersScreen(
                              live: true,
                              branchRequest: _requestBranch,
                              memberSetup: _memberSetupEnabled
                                  ? _requestMemberSetup
                                  : null,
                              addingMember: _addingMember,
                              provisionBranchId: _memberProvisionBranch,
                              onOpenAddMember: () =>
                                  _select(entry.key, addMember: true),
                              onCloseAddMember: _closeAddMember,
                              onProvisionLeaveCheckChanged: (check) =>
                                  _canLeaveMemberProvisioning = check,
                            );
                          }
                          if (session != null && d.label == 'Coaches') {
                            if (_scopedCoachIdForBookings != null) {
                              final repository =
                                  context.read<BookingListRepository>();
                              return AdminBookingListRoute(
                                  session: session,
                                  repository: repository,
                                  key: ValueKey(_focusedBookingId),
                                  branchId: _focusedCoachBranch,
                                  bookingId: _focusedBookingId,
                                  loadBranches: _focusedBookingId == null
                                      ? null
                                      : _announcementBranches,
                                  coachId: _scopedCoachIdForBookings!);
                            }
                            if (_scopedCoachIdForSchedule != null) {
                              final repository =
                                  context.read<CoachAvailabilityRepository>();
                              return AdminCoachScheduleRoute(
                                  session: session,
                                  repository: repository,
                                  key: ValueKey((
                                    _scopedCoachIdForSchedule,
                                    _focusedScheduleDate,
                                    _focusedCoachBranch
                                  )),
                                  initialBranchId: _focusedCoachBranch,
                                  initialLocalDate: _focusedScheduleDate,
                                  coachId: _scopedCoachIdForSchedule!);
                            }
                            return CoachesScreen(
                                key: ValueKey(_notificationReviewGeneration),
                                initialBranchId: _coachDrillDownBranch,
                                initialCoachId: _scopedCoachIdForReview ??
                                    _notificationCoachId,
                                discardGuard: _coachReviewGuard,
                                live: true,
                                branchRequest: widget.coachBranchRequest,
                                addingCoach: _addingCoach,
                                onOpenAddCoach: () =>
                                    _select(entry.key, addCoach: true),
                                onCloseAddCoach: _closeAddCoach,
                                onProvisionLeaveCheckChanged: (check) =>
                                    _canLeaveCoachProvisioning = check,
                                onOpenBookings: (id) => setState(() {
                                      _scopedCoachIdForBookings = id;
                                      _scopedCoachIdForSchedule = null;
                                    }),
                                onOpenSchedule: (id) => setState(() {
                                      _scopedCoachIdForSchedule = id;
                                      _scopedCoachIdForBookings = null;
                                    }),
                                onReviewChanged: (id) => setState(() {
                                      _scopedCoachIdForReview = id;
                                    }));
                          }
                          if (d.label == 'Transactions') {
                            return session == null
                                ? PaymentsScreen(
                                    key:
                                        const ValueKey('payments-transactions'),
                                    mode: PaymentsMode.transactions,
                                    onNavigateMode: _navigateToPaymentMode)
                                : AdminPaymentReviewRoute(
                                    key:
                                        const ValueKey('payments-transactions'),
                                    session: session,
                                    mode: PaymentsMode.transactions,
                                    onNavigateMode: _navigateToPaymentMode);
                          }
                          if (d.label == 'Refund Requests') {
                            return session == null
                                ? PaymentsScreen(
                                    key: const ValueKey('payments-refunds'),
                                    mode: PaymentsMode.refunds,
                                    onNavigateMode: _navigateToPaymentMode)
                                : AdminPaymentReviewRoute(
                                    key: const ValueKey('payments-refunds'),
                                    session: session,
                                    mode: PaymentsMode.refunds,
                                    onNavigateMode: _navigateToPaymentMode);
                          }
                          if (d.label == 'Reconciliation') {
                            return session == null
                                ? PaymentsScreen(
                                    key: const ValueKey(
                                        'payments-reconciliation'),
                                    mode: PaymentsMode.reconciliation,
                                    onNavigateMode: _navigateToPaymentMode)
                                : AdminPaymentReviewRoute(
                                    key: const ValueKey(
                                        'payments-reconciliation'),
                                    session: session,
                                    mode: PaymentsMode.reconciliation,
                                    onNavigateMode: _navigateToPaymentMode);
                          }
                          if (d.page is RiskLeaderboardScreen) {
                            return RecommendationMonitorActivity(
                              active: entry.key == _index,
                              child: d.page,
                            );
                          }
                          return d.page;
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// One segment of the top bar's breadcrumb — `onTap` is null for the
/// current (last) segment, which reads as the active page rather than a
/// link back to itself.
class _Crumb {
  final String label;
  final VoidCallback? onTap;
  const _Crumb(this.label, this.onTap);
}

class _TopBar extends StatelessWidget {
  final ValueChanged<String> onOpenCoachAlert;
  final List<_Crumb> breadcrumbs;
  final String subtitle;
  final VoidCallback onSignOut;
  final AuthSession? liveSession;
  final VoidCallback? onOpenNavigation;
  const _TopBar(
      {this.onOpenNavigation,
      required this.breadcrumbs,
      required this.onOpenCoachAlert,
      required this.subtitle,
      this.liveSession,
      required this.onSignOut});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 64),
      padding: EdgeInsets.symmetric(
          horizontal: onOpenNavigation == null ? 24 : 12, vertical: 8),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.hairline)),
      ),
      child: Row(
        children: [
          if (onOpenNavigation != null) ...[
            IconButton(
                tooltip: 'Open navigation',
                onPressed: onOpenNavigation,
                icon: const Icon(Icons.menu_rounded)),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    for (var i = 0; i < breadcrumbs.length; i++) ...[
                      if (i > 0)
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6),
                          child: Icon(Icons.chevron_right_rounded,
                              size: 16, color: AppColors.inkSoft),
                        ),
                      Flexible(
                          child: _BreadcrumbSegment(crumb: breadcrumbs[i])),
                    ],
                  ],
                ),
                if (subtitle.isNotEmpty) const SizedBox(height: 2),
                if (subtitle.isNotEmpty)
                  Text(subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(fontSize: 12)),
              ],
            ),
          ),
          if (MediaQuery.sizeOf(context).width >= 1280 &&
              MediaQuery.textScalerOf(context).scale(1) <= 1.5)
            const Padding(
                padding: EdgeInsets.only(left: 24),
                child: Text('GAINPATH / ADMIN',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.inkSoft))),
          const SizedBox(width: 14),
          if (liveSession == null) const _NotificationButton(),
          if (liveSession != null)
            CoachReviewNotificationButton(onOpenCoach: onOpenCoachAlert),
          const SizedBox(width: 6),
          _ProfileMenu(onSignOut: onSignOut, liveSession: liveSession),
        ],
      ),
    );
  }
}

class _BreadcrumbSegment extends StatelessWidget {
  final _Crumb crumb;
  const _BreadcrumbSegment({required this.crumb});

  @override
  Widget build(BuildContext context) {
    final current = crumb.onTap == null;
    final text = Text(
      crumb.label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontSize: 16,
            color: current ? AppColors.ink : AppColors.inkSoft,
            fontWeight: current ? FontWeight.w700 : FontWeight.w600,
          ),
    );
    if (current) return text;
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: crumb.onTap,
      child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2), child: text),
    );
  }
}

class _NotificationButton extends StatelessWidget {
  const _NotificationButton();

  @override
  Widget build(BuildContext context) => PopupMenuButton<int>(
      tooltip: 'Notifications',
      offset: const Offset(0, 46),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      itemBuilder: (context) => const [
            PopupMenuItem<int>(
                enabled: false, child: Text('No notifications available')),
          ],
      child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.notifications_outlined,
              size: 19, color: AppColors.ink)));
}

class _ProfileMenu extends StatelessWidget {
  final VoidCallback onSignOut;
  final AuthSession? liveSession;
  const _ProfileMenu({required this.onSignOut, this.liveSession});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Account',
      offset: const Offset(0, 46),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onSelected: (v) {
        if (v == 'signout') onSignOut();
        if (v == 'account') {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => AdminSettingsScreen(
                      liveSession: liveSession,
                      onSaved: liveSession == null
                          ? null
                          : () => context
                              .read<AuthBloc>()
                              .add(const AuthRestoreRequested()))));
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          enabled: false,
          child: SizedBox(
            width: 200,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                    liveSession?.displayName ??
                        liveSession?.email ??
                        context.read<UserAccountRepository>().adminName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13)),
                Text(
                    liveSession?.email ??
                        context.read<UserAccountRepository>().adminEmail,
                    style: const TextStyle(
                        fontSize: 11.5, color: AppColors.inkSoft)),
              ],
            ),
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'account',
          child: Row(
            children: [
              Icon(Icons.account_circle_outlined,
                  size: 18, color: AppColors.inkSoft),
              SizedBox(width: 10),
              Text('My account'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'signout',
          child: Row(
            children: [
              Icon(Icons.logout_rounded, size: 18, color: AppColors.danger),
              SizedBox(width: 10),
              Text('Sign out', style: TextStyle(color: AppColors.danger)),
            ],
          ),
        ),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AdminAccountAvatar(live: liveSession != null),
          const SizedBox(width: 6),
          const Icon(Icons.expand_more_rounded,
              size: 18, color: AppColors.inkSoft),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  final AuthSession? liveSession;
  final bool collapsed;
  final int selectedIndex;
  final Set<String> expandedGroups;
  final List<Object> destinations;
  final ValueChanged<int> onSelect;
  final ValueChanged<String> onToggleGroup;

  const _Sidebar({
    this.liveSession,
    required this.collapsed,
    required this.selectedIndex,
    required this.expandedGroups,
    required this.destinations,
    required this.onSelect,
    required this.onToggleGroup,
  });

  @override
  Widget build(BuildContext context) {
    var flatCursor = 0;
    final items = <Widget>[];
    for (final d in destinations) {
      if (d is _NavPage) {
        final index = flatCursor++;
        items.add(_navTile(context,
            icon: d.icon,
            iconFilled: d.iconFilled,
            label: d.label,
            selected: index == selectedIndex,
            onTap: () => onSelect(index)));
      } else if (d is _NavGroup) {
        final firstChildIndex = flatCursor;
        final childIndices =
            List.generate(d.children.length, (i) => flatCursor + i);
        flatCursor += d.children.length;
        final expanded = expandedGroups.contains(d.label);
        final groupSelected = childIndices.contains(selectedIndex);

        if (collapsed) {
          // No room for a flyout in the narrow rail — jump straight to the
          // group's first child, same as tapping any other icon.
          items.add(_navTile(context,
              icon: d.icon,
              iconFilled: d.iconFilled,
              label: d.label,
              selected: groupSelected,
              onTap: () => onSelect(firstChildIndex)));
          continue;
        }

        items.add(_navTile(context,
            icon: d.icon,
            iconFilled: d.iconFilled,
            label: d.label,
            selected: groupSelected && !expanded,
            trailing: Icon(
                expanded
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
                size: 18,
                color: AppColors.inkSoft),
            onTap: () => d.opensFirstChild
                ? onSelect(firstChildIndex)
                : onToggleGroup(d.label)));

        if (expanded) {
          for (var i = 0; i < d.children.length; i++) {
            final child = d.children[i];
            final index = childIndices[i];
            items.add(Padding(
              padding: const EdgeInsets.only(left: 20),
              child: _navTile(context,
                  icon: child.icon,
                  iconFilled: child.iconFilled,
                  label: child.label,
                  selected: index == selectedIndex,
                  dense: true,
                  onTap: () => onSelect(index)),
            ));
          }
        }
      }
    }

    return Container(
      width: collapsed ? 72 : 224,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(right: BorderSide(color: AppColors.hairline)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            constraints: const BoxConstraints(minHeight: 64),
            padding: EdgeInsets.symmetric(
              horizontal: collapsed ? 0 : 18,
              vertical: 10,
            ),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.hairline)),
            ),
            child: Row(
              mainAxisAlignment: collapsed
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                Image.asset(
                  'assets/images/gainpath_logo.png',
                  width: 38,
                  height: 38,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => Image.memory(
                    kGainPathLogoBytes,
                    width: 38,
                    height: 38,
                    fit: BoxFit.contain,
                  ),
                ),
                if (!collapsed) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'GainPath',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                    color: AppColors.ink,
                                    letterSpacing: -0.2,
                                    height: 1.15,
                                  ),
                        ),
                        Text(
                          'Admin Console',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontSize: 11.5,
                                    color: AppColors.inkSoft,
                                    height: 1.15,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(horizontal: collapsed ? 10 : 10),
              children: items,
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: EdgeInsets.all(collapsed ? 12 : 14),
            child: Row(
              mainAxisAlignment: collapsed
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                AdminAccountAvatar(live: liveSession != null),
                if (!collapsed) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                            liveSession?.displayName ??
                                liveSession?.email ??
                                context.read<UserAccountRepository>().adminName,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontSize: 13.5)),
                        Text(
                            liveSession?.email ??
                                context
                                    .read<UserAccountRepository>()
                                    .adminEmail,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(fontSize: 11.5)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _navTile(
    BuildContext context, {
    required IconData icon,
    required IconData iconFilled,
    required String label,
    required bool selected,
    required VoidCallback onTap,
    Widget? trailing,
    bool dense = false,
  }) {
    final item = Material(
      color: selected ? AppColors.primaryTint : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: collapsed ? 0 : 12, vertical: 8),
              child: Row(
                mainAxisAlignment: collapsed
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.start,
                children: [
                  Icon(selected ? iconFilled : icon,
                      size: dense ? 17 : 19,
                      color: selected ? AppColors.primary : AppColors.inkSoft),
                  if (!collapsed) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: dense ? 12.5 : 13,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                          color: selected ? AppColors.primary : AppColors.ink,
                        ),
                      ),
                    ),
                    if (trailing != null) trailing,
                  ],
                ],
              ),
            )),
      ),
    );
    return Semantics(
        selected: selected,
        button: true,
        label: collapsed ? label : null,
        child: Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: collapsed ? Tooltip(message: label, child: item) : item));
  }
}
