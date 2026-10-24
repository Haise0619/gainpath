const fs = require('node:fs');
const path = require('node:path');
const {spawnSync} = require('node:child_process');
const root = path.resolve(__dirname, '..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8');
const mobile = 'apps/mobile/lib/';
const violations = [];
for (const file of ['main.dart', 'app/mobile_app.dart']) {
  const source = read(mobile + file);
  if (/BackendConfig|BackendMode|\bBACKEND\b/.test(source)) {
    violations.push(`${file}: normal mobile startup must not select a separate sample product`);
  }
  if (!source.includes(file === 'main.dart' ? 'initializeGainPathFirebase' : 'FlutterFirebaseAuthGateway()')) {
    violations.push(`${file}: retain connected startup and explicit dependency injection for tests`);
  }
}
for (const file of [
  'features/analytics/presentation/shared/progress_dashboard_screen.dart',
  'features/analytics/presentation/member/workout_performance_screen.dart',
  'features/analytics/presentation/member/posture_accuracy_screen.dart',
  'features/analytics/presentation/member/activity_timeline_screen.dart',
]) {
  if (/\b_buildLocal\s*\(/.test(read(mobile + file))) {
    violations.push(`${file}: measured data must use the canonical report body`);
  }
}
for (const [file, canonical] of [
  ['features/coaching/presentation/member/live_member_booking_view.dart', 'BookSessionScreen'],
  ['features/coaching/presentation/coach/live_coach_availability_view.dart', 'AvailabilityScreen'],
  ['features/coaching/presentation/coach/availability_screens.dart', 'AvailabilityPage'],
  ['features/coaching/presentation/member/book_session_screen.dart', 'BookingSelectionPage'],
]) {
  if (!new RegExp(`\\b${canonical}\\s*\\(`).test(read(mobile + file))) {
    violations.push(`${file}: must compose ${canonical}`);
  }
}
const module8 = spawnSync(process.execPath,
    [path.join(__dirname, 'check-module8-presentation.cjs')], {stdio: 'inherit'});
if (module8.status !== 0) violations.push('Module 8 presentation boundary failed');
if (violations.length) {
  console.error(violations.join('\n'));
  process.exitCode = 1;
} else {
  console.log('Mobile presentation boundary passed: connected startup, shared reports and coaching pages.');
}
