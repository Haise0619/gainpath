import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../app/theme.dart';

/// Small uppercase label used to head a group of content.
class Eyebrow extends StatelessWidget {
  final String text;
  const Eyebrow(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall),
      );
}

/// Bordered white container used for nearly every grouped block.
class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? background;

  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.background,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: background ?? AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.hairline),
        boxShadow: kIsWeb
            ? [
                BoxShadow(
                  color: AppColors.ink.withValues(alpha: 0.04),
                  blurRadius: 14,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: child,
    );
    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: content,
    );
  }
}

/// Headline figure with a caption underneath.
class StatTile extends StatelessWidget {
  final String value;
  final String label;
  final String? delta;
  final Color? valueColor;

  const StatTile(this.value, this.label, {super.key, this.delta, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(color: valueColor ?? AppColors.ink)),
          const SizedBox(height: 2),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          if (delta != null) ...[
            const SizedBox(height: 6),
            Text(delta!,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.success)),
          ],
        ],
      ),
    );
  }
}

/// Coloured status pill.
class StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final Color background;
  const StatusChip(this.label,
      {super.key, this.color = AppColors.primary, this.background = AppColors.primaryTint});


  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11.5, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

Widget statusPill(String status) {
  Color fg;
  Color bg;
  switch (status.toLowerCase()) {
    case 'confirmed':
    case 'active':
    case 'verified':
    case 'cleared':
    case 'completed':
      fg = AppColors.success;
      bg = AppColors.primaryTint;
      break;
    case 'pending':
    case 'pending review':
      fg = AppColors.warning;
      bg = AppColors.accentTint;
      break;
    case 'suspended':
    case 'cancelled':
    case 'high':
      fg = AppColors.danger;
      bg = AppColors.dangerTint;
      break;
    default:
      fg = AppColors.inkSoft;
      bg = AppColors.surfaceAlt;
  }
  return StatusChip(status, color: fg, background: bg);
}

/// Row of label and value, used inside detail panels.
class DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const DetailRow(this.label, this.value, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: Text(label,
                style: Theme.of(context).textTheme.bodyMedium),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 14.5, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

/// Simple bar chart with no external dependency.
class BarChart extends StatelessWidget {
  final List<int> values;
  final List<String>? labels;
  final Color color;
  final double height;

  const BarChart(this.values,
      {super.key, this.labels, this.color = AppColors.primary, this.height = 140});

  @override
  Widget build(BuildContext context) {
    final maxValue =
        values.isEmpty ? 1 : values.reduce((a, b) => a > b ? a : b);
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(values.length, (i) {
          final ratio = maxValue == 0 ? 0.0 : values[i] / maxValue;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    height: (height - 22) * ratio.clamp(0.02, 1.0),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4)),
                    ),
                  ),
                  if (labels != null && i < labels!.length) ...[
                    const SizedBox(height: 6),
                    Text(labels![i],
                        style: const TextStyle(
                            fontSize: 9.5, color: AppColors.inkSoft)),
                  ],
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// Line-style trend chart drawn with CustomPaint.
class TrendChart extends StatelessWidget {
  final List<int> values;
  final Color color;
  const TrendChart(this.values, {super.key, this.color = AppColors.primary});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 130,
      width: double.infinity,
      child: CustomPaint(painter: _TrendPainter(values, color)),
    );
  }
}

class _TrendPainter extends CustomPainter {
  final List<int> values;
  final Color color;
  _TrendPainter(this.values, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final maxV = values.reduce((a, b) => a > b ? a : b).toDouble();
    final minV = values.reduce((a, b) => a < b ? a : b).toDouble();
    final range = (maxV - minV) == 0 ? 1 : (maxV - minV);

    final path = Path();
    final fill = Path();
    for (var i = 0; i < values.length; i++) {
      final x = size.width * (i / (values.length - 1));
      final y = size.height -
          ((values[i] - minV) / range) * (size.height - 16) -
          8;
      if (i == 0) {
        path.moveTo(x, y);
        fill.moveTo(x, size.height);
        fill.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fill.lineTo(x, y);
      }
    }
    fill.lineTo(size.width, size.height);
    fill.close();

    canvas.drawPath(
        fill,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [color.withValues(alpha: 0.20), color.withValues(alpha: 0.0)],
          ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)));

    canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round);

    for (var i = 0; i < values.length; i++) {
      final x = size.width * (i / (values.length - 1));
      final y = size.height -
          ((values[i] - minV) / range) * (size.height - 16) -
          8;
      canvas.drawCircle(Offset(x, y), 3.5, Paint()..color = Colors.white);
      canvas.drawCircle(
          Offset(x, y),
          3.5,
          Paint()
            ..color = color
            ..strokeWidth = 2
            ..style = PaintingStyle.stroke);
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter old) => old.values != values;
}

/// Horizontal progress bar with label.
class ProgressRow extends StatelessWidget {
  final String label;
  final double ratio;
  final String trailing;
  final Color color;
  const ProgressRow(this.label, this.ratio, this.trailing,
      {super.key, this.color = AppColors.primary});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600)),
              Text(trailing,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.inkSoft)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: ratio.clamp(0.0, 1.0),
              minHeight: 7,
              backgroundColor: AppColors.surfaceAlt,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }
}

/// Standard page body padding.
class PageBody extends StatelessWidget {
  final List<Widget> children;
  const PageBody({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: children,
    );
  }
}

void showToast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.ink,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
}

Future<bool> confirmSheet(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  bool destructive = false,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, 20 + MediaQuery.of(ctx).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
                color: AppColors.hairline,
                borderRadius: BorderRadius.circular(999)),
          ),
          Text(title, style: Theme.of(ctx).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(message, style: Theme.of(ctx).textTheme.bodyLarge),
          const SizedBox(height: 22),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: destructive
                ? FilledButton.styleFrom(backgroundColor: AppColors.danger)
                : null,
            child: Text(confirmLabel),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Not now'),
          ),
        ],
      ),
    ),
  );
  return result ?? false;
}

/// Selectable list-style card: icon, label, optional description, trailing
/// check. Covers both a plain single-line choice (e.g. gender) and a
/// choice-with-detail (e.g. activity level) from one component, used across
/// the onboarding wizard and the profile-edit screens that revisit the same
/// choices later.
class SelectableListCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? description;
  final bool selected;
  final VoidCallback onTap;

  const SelectableListCard({
    super.key,
    required this.icon,
    required this.label,
    this.description,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasDescription = description != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: EdgeInsets.symmetric(horizontal: hasDescription ? 14 : 18, vertical: hasDescription ? 14 : 16),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryTint : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? AppColors.primary : AppColors.hairline, width: selected ? 1.6 : 1),
        ),
        child: Row(
          children: [
            Container(
              width: hasDescription ? 42 : 44,
              height: hasDescription ? 42 : 44,
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: selected ? Colors.white : AppColors.inkSoft, size: hasDescription ? 21 : 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: hasDescription
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(color: selected ? AppColors.primary : AppColors.ink)),
                        Text(description!, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12.5)),
                      ],
                    )
                  : Text(label,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(color: selected ? AppColors.primary : AppColors.ink)),
            ),
            Icon(selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                color: selected ? AppColors.primary : AppColors.hairline, size: hasDescription ? 20 : 22),
          ],
        ),
      ),
    );
  }
}

/// Stepper-and-slider numeric picker used for age, height, and weight,
/// during onboarding and again whenever those fields are edited later.
class NumberDial extends StatelessWidget {
  final double value;
  final double min;
  final double max;
  final String suffix;
  final String display;
  final String captionUnit;
  final ValueChanged<double> onChanged;

  const NumberDial({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.suffix,
    required this.display,
    required this.captionUnit,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Panel(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _stepper(Icons.remove_rounded, () => onChanged((value - 1).clamp(min, max))),
              SizedBox(
                width: 150,
                child: Column(
                  children: [
                    Text(
                      '$display$suffix',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w800, color: AppColors.primary),
                    ),
                    Text(captionUnit, style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
              _stepper(Icons.add_rounded, () => onChanged((value + 1).clamp(min, max))),
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.primary,
              inactiveTrackColor: AppColors.hairline,
              thumbColor: AppColors.primary,
              overlayColor: AppColors.primary.withValues(alpha: 0.12),
            ),
            child: Slider(value: value, min: min, max: max, onChanged: onChanged),
          ),
        ],
      ),
    );
  }

  Widget _stepper(IconData icon, VoidCallback onTap) {
    return SizedBox(
      width: 44,
      height: 44,
      child: IconButton.filled(
        onPressed: onTap,
        style: IconButton.styleFrom(
          backgroundColor: AppColors.surfaceAlt,
          foregroundColor: AppColors.ink,
        ),
        icon: Icon(icon, size: 20),
      ),
    );
  }
}

/// Square icon-and-label chip that toggles selected/unselected, used for
/// multi-select choices such as training motivations.
class ToggleChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const ToggleChip({super.key, required this.icon, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryTint : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? AppColors.primary : AppColors.hairline, width: selected ? 1.6 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: selected ? AppColors.primary : AppColors.inkSoft, size: 22),
                if (selected) const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 18),
              ],
            ),
            const Spacer(),
            Text(label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: selected ? AppColors.primary : AppColors.ink,
                  height: 1.2,
                )),
          ],
        ),
      ),
    );
  }
}

/// 0 (empty) to 3 (strong). Shared by every "set a password" surface so the
/// bar and its thresholds always mean the same thing.
int passwordStrengthOf(String password) {
  if (password.isEmpty) return 0;
  var score = 0;
  if (password.length >= 8) score++;
  if (RegExp(r'[0-9]').hasMatch(password) && RegExp(r'[A-Za-z]').hasMatch(password)) score++;
  if (password.length >= 12 || RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-]').hasMatch(password)) score++;
  return score;
}

class PasswordStrengthMeter extends StatelessWidget {
  final int strength;
  const PasswordStrengthMeter({super.key, required this.strength});

  @override
  Widget build(BuildContext context) {
    const labels = ['Too short', 'Weak', 'Good', 'Strong'];
    const colors = [AppColors.danger, AppColors.danger, AppColors.warning, AppColors.success];
    final label = labels[strength];
    final color = colors[strength];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(3, (i) {
            final filled = i < strength;
            return Expanded(
              child: Container(
                height: 4,
                margin: EdgeInsets.only(right: i == 2 ? 0 : 5),
                decoration: BoxDecoration(
                  color: filled ? color : AppColors.hairline,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 5),
        Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }
}
