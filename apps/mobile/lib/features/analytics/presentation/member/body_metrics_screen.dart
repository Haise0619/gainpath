import 'package:flutter/material.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_identity/gainpath_identity.dart';
import '../../../../infrastructure/firebase/member_profile_repositories.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/analytics.dart';
import 'package:gainpath_domain/workout.dart';

/// New Progress sub-report on body composition: a weight trend line (the
/// natural chart shape for "one number over time") and a BMI range
/// gauge, whose coloured clinical bands are a shape none of the other
/// reports need.
class BodyMetricsScreen extends StatelessWidget {
  const BodyMetricsScreen(
      {super.key, this.live = false, this.weightKg, this.heightCm});
  final bool live;
  final double? weightKg;
  final double? heightCm;

  static Widget connected(BuildContext context) =>
      BlocBuilder<AuthBloc, AuthState>(builder: (context, state) {
        final session = state.session;
        if (session == null ||
            !AuthRolePolicy.canEnter(state, allowed: const {AppRole.member})) {
          return const Scaffold(
              body: Center(child: Text('Sign in to view body metrics.')));
        }
        final auth = context.read<AuthBloc>();
        bool current() => identical(auth.state.session, session);
        return ProfileBodyMetricsScreen(
            key: ObjectKey(session),
            repository:
                createReportFitnessProfileRepository(session.scope, current),
            current: current);
      });

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static String _shortDate(DateTime d) => '${d.day} ${_months[d.month - 1]}';

  @override
  Widget build(BuildContext context) {
    final history = live
        ? <WeightEntry>[]
        : context.read<AnalyticsRepository>().weightHistory;
    final current =
        live ? weightKg : (history.isEmpty ? null : history.last.weightKg);
    final heightM = live
        ? (heightCm ?? 0) / 100
        : context.read<WorkoutRepository>().heightCm / 100;
    final bmi = current == null || current <= 0 || heightM <= 0
        ? null
        : current / (heightM * heightM);
    final weights = history.map((e) => e.weightKg).toList();
    final points = history
        .map((e) => _WeightPoint(_shortDate(e.date), e.weightKg))
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Weight & BMI')),
      body: PageBody(
        children: [
          Row(
            children: [
              Expanded(
                  child: StatTile(
                      current == null
                          ? '-'
                          : '${current.toStringAsFixed(1)} kg',
                      'Current weight')),
              const SizedBox(width: 10),
              Expanded(child: StatTile(bmi?.toStringAsFixed(1) ?? '-', 'BMI')),
            ],
          ),
          const SizedBox(height: 20),
          if (live)
            const Text(
                'Current Module 1 profile · self-reported · measurement date unknown. No dated weight history is available.'),
          if (!live) ...[
            const Eyebrow('Weight trend (last 7 weeks)'),
            Panel(
              child: SizedBox(
                height: 190,
                child: SfCartesianChart(
                  plotAreaBorderWidth: 0,
                  primaryXAxis: const CategoryAxis(
                    majorGridLines: MajorGridLines(width: 0),
                    axisLine: AxisLine(width: 0),
                    labelStyle:
                        TextStyle(fontSize: 9.5, color: AppColors.inkSoft),
                  ),
                  primaryYAxis: NumericAxis(
                    minimum: weights.isEmpty
                        ? null
                        : (weights.reduce((a, b) => a < b ? a : b) - 1)
                            .floorToDouble(),
                    maximum: weights.isEmpty
                        ? null
                        : (weights.reduce((a, b) => a > b ? a : b) + 1)
                            .ceilToDouble(),
                    majorGridLines: const MajorGridLines(
                        width: 0.6, color: AppColors.hairline),
                    axisLine: const AxisLine(width: 0),
                    labelStyle:
                        const TextStyle(fontSize: 10, color: AppColors.inkSoft),
                  ),
                  trackballBehavior: TrackballBehavior(
                      enable: true, activationMode: ActivationMode.singleTap),
                  series: <CartesianSeries<_WeightPoint, String>>[
                    SplineSeries<_WeightPoint, String>(
                      dataSource: points,
                      xValueMapper: (d, _) => d.label,
                      yValueMapper: (d, _) => d.weightKg,
                      color: AppColors.primary,
                      width: 2.4,
                      markerSettings: const MarkerSettings(
                          isVisible: true, height: 6, width: 6),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          const Eyebrow('BMI range'),
          Panel(
            child: Column(
              children: [
                SizedBox(
                  height: 90,
                  child: SfLinearGauge(
                    minimum: 15,
                    maximum: 35,
                    showLabels: true,
                    showTicks: false,
                    axisTrackStyle: const LinearAxisTrackStyle(thickness: 14),
                    ranges: const [
                      LinearGaugeRange(
                          startValue: 15,
                          endValue: 18.5,
                          color: AppColors.info,
                          startWidth: 14,
                          endWidth: 14),
                      LinearGaugeRange(
                          startValue: 18.5,
                          endValue: 25,
                          color: AppColors.success,
                          startWidth: 14,
                          endWidth: 14),
                      LinearGaugeRange(
                          startValue: 25,
                          endValue: 30,
                          color: AppColors.warning,
                          startWidth: 14,
                          endWidth: 14),
                      LinearGaugeRange(
                          startValue: 30,
                          endValue: 35,
                          color: AppColors.danger,
                          startWidth: 14,
                          endWidth: 14),
                    ],
                    markerPointers: [
                      if (bmi != null)
                        LinearShapePointer(
                          // `num.clamp()` returns `num`, not `double` â€” Dart
                          // won't implicitly downcast that into a `double`
                          // parameter.
                          value: bmi.clamp(15, 35).toDouble(),
                          shapeType: LinearShapePointerType.invertedTriangle,
                          color: AppColors.ink,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  bmi == null
                      ? '-'
                      : '${bmi.toStringAsFixed(1)} falls in the ${_bmiLabel(bmi)} range.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _bmiLabel(double bmi) {
    if (bmi < 18.5) return 'underweight';
    if (bmi < 25) return 'normal';
    if (bmi < 30) return 'overweight';
    return 'obese';
  }
}

class _WeightPoint {
  final String label;
  final double weightKg;
  const _WeightPoint(this.label, this.weightKg);
}

class ProfileBodyMetricsScreen extends StatefulWidget {
  const ProfileBodyMetricsScreen(
      {super.key, required this.repository, required this.current});
  final FitnessProfileRepository repository;
  final bool Function() current;
  @override
  State<ProfileBodyMetricsScreen> createState() =>
      ProfileBodyMetricsScreenState();
}

class ProfileBodyMetricsScreenState extends State<ProfileBodyMetricsScreen> {
  late final Future<FitnessProfile?> _profile = widget.repository.load();
  @override
  Widget build(BuildContext context) => FutureBuilder<FitnessProfile?>(
      future: _profile,
      builder: (context, snapshot) {
        if (!widget.current()) {
          return const Scaffold(
              body: Center(child: Text('Sign in to view body metrics.')));
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return const Scaffold(
              body: Center(
                  child: Text(
                      'Profile measurements unavailable. Reopen to retry.')));
        }
        return BodyMetricsScreen(
            live: true,
            weightKg: snapshot.data?.weightKg.toDouble(),
            heightCm: snapshot.data?.heightCm.toDouble());
      });
}
