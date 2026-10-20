const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const read = (file) => fs.readFileSync(path.join(root, file), 'utf8');
const adminWeb = 'apps/admin_web/lib/';
const violations = [];

// 1. Startup & Connected Default
for (const file of ['main.dart', 'app/admin_app.dart']) {
  const source = read(adminWeb + file);
  if (/BackendConfig\.fromEnvironment\(/.test(source)) {
    violations.push(`${file}: normal admin web startup must not select a separate sample product`);
  }
  if (!source.includes('backendConfig ?? const BackendConfig(BackendMode.firebase)')) {
    violations.push(`${file}: retain connected startup and explicit dependency injection for tests`);
  }
}

// 2. No placeholder page usage
function findDartFiles(dir, files = []) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      findDartFiles(fullPath, files);
    } else if (entry.isFile() && entry.name.endsWith('.dart')) {
      files.push(fullPath);
    }
  }
  return files;
}

const libDartFiles = findDartFiles(path.join(root, adminWeb));
for (const fullPath of libDartFiles) {
  const rel = path.relative(path.join(root, adminWeb), fullPath).replace(/\\/g, '/');
  if (rel === 'app/admin_feature_availability.dart') continue;
  const content = fs.readFileSync(fullPath, 'utf8');
  if (content.includes('AdminFeatureAvailability.page')) {
    violations.push(`${rel}: must not use AdminFeatureAvailability.page placeholder routing`);
  }
}

// 3. AdminShell mounts all 13 canonical destinations
const shellSource = read(adminWeb + 'app/shells/admin_shell.dart');
const canonicalPages = [
  'AdminDashboardScreen',
  'MembersScreen',
  'CoachesScreen',
  'ExerciseTutorialsScreen',
  'RoutineTemplatesScreen',
  'EquipmentCatalogScreen',
  'AnnouncementsScreen',
  'ChatbotDisclaimerScreen',
  'RewardCatalogScreen',
  'SystemSettingsScreen',
  'ReportsScreen',
  'RiskLeaderboardScreen',
  'RefundsScreen',
];

for (const page of canonicalPages) {
  if (!shellSource.includes(page)) {
    violations.push(`admin_shell.dart: missing canonical destination page ${page}`);
  }
}

// 4. No sample data fallback in connected repositories
const repoSource = read(adminWeb + 'app/di/app_repositories.dart');
if (repoSource.includes('MockDataSession') && repoSource.includes('return session;')) {
  violations.push('app_repositories.dart: must not return mock data session in connected mode');
}
if (repoSource.includes('NeutralAdminAccountContactRepository(')) {
  violations.push('app_repositories.dart: must not substitute neutral account repository in connected mode');
}
if (repoSource.includes('AuthStatus.signedIn') && repoSource.includes('context.read<AuthBloc?>()')) {
  violations.push('app_repositories.dart: must not fabricate signed-in AuthState when AuthBloc is missing');
}

// 5. No duplicate presentation bodies for Members and Coaches
for (const file of ['features/identity/presentation/admin/members_screen.dart', 'features/identity/presentation/admin/coaches_screen.dart']) {
  const content = read(adminWeb + file);
  if (content.includes('_LiveMembersView') || content.includes('LiveCoachDirectoryAdminView')) {
    violations.push(`${file}: must not switch to duplicate presentation body`);
  }
  // Count structural page roots rather than relying on obsolete class names.
  // Data-source adapters may rebuild the canonical page, but cannot define a second body.
  const code = content.replace(/\/\*[\s\S]*?\*\/|\/\/[^\r\n]*|"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'/g, '');
  const scaffolds = (code.match(/\bScaffold\s*\(/g) || []).length;
  const bodies = (code.match(/\bbody\s*:/g) || []).length;
  const scrollPages = (code.match(/\bSingleChildScrollView\s*\(/g) || []).length;
  if (scaffolds !== 1 || bodies !== 1 || scrollPages !== 1) {
    violations.push(`${file}: expected one canonical Scaffold/body/scroll page; found ${scaffolds}/${bodies}/${scrollPages}`);
  }

}
if (fs.existsSync(path.join(root, adminWeb, 'features/identity/presentation/admin/live_coach_directory_admin_view.dart'))) {
  violations.push('live_coach_directory_admin_view.dart: duplicate coach directory view file must be removed');
}

// 6. Reporting gateway connected to screens
const dashboardSource = read(adminWeb + 'features/analytics/presentation/admin/admin_dashboard_screens.dart');
if (!dashboardSource.includes('AdminReportingCubit') && !dashboardSource.includes('AdminReportingGateway')) {
  violations.push('admin_dashboard_screens.dart: must connect to AdminReportingGateway/Cubit');
}
const reportsSource = read(adminWeb + 'features/analytics/presentation/admin/reports_screen.dart');
if (!reportsSource.includes('AdminReportingCubit')) {
  violations.push('reports_screen.dart: must connect to AdminReportingCubit');
}

// 7. Bookings and Schedule remain in AdminShell
if (shellSource.includes('Navigator.of(context).push') && (shellSource.includes('AdminCoachScheduleRoute') || shellSource.includes('AdminBookingListRoute'))) {
  violations.push('admin_shell.dart: bookings and schedule must render inside shell content, not push standalone route');
}

// 8. Report exports disabled when unavailable
const commerceSource = read(adminWeb + 'features/analytics/presentation/admin/sections/commerce_sections.dart');
if (!commerceSource.includes('exportEnabled: !live') && !commerceSource.includes('exportRows: live ? null')) {
  violations.push('commerce_sections.dart: unsupported report exports must remain disabled in live mode');
}

if (violations.length) {
  console.error(violations.join('\n'));
  process.exitCode = 1;
} else {
  console.log('Admin presentation boundary passed: connected startup, 13 canonical pages, unified presentation bodies, in-shell coaching, reporting gateway integration, and truthful unavailable states.');
}
