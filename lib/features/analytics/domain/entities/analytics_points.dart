class WeightEntry {
  final DateTime date;
  final double weightKg;
  const WeightEntry(this.date, this.weightKg);
}

class MuscleGroupShare {
  final String label;
  final double ratio;
  const MuscleGroupShare(this.label, this.ratio);
}

/// One labelled slice for a donut/pie chart — reused across the admin
/// Reports sections (risk distribution, reward mix, streak buckets)
/// instead of each section inventing its own tuple shape.
class ChartSlice {
  final String label;
  final double value;
  const ChartSlice(this.label, this.value);
}
