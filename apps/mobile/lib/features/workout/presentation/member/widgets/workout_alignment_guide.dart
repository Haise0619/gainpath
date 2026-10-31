import 'package:flutter/material.dart';

/// A positioning aid over the live preview. The outline does not crop model
/// input or assert anatomical scale/accuracy; calibration remains engine-owned.
class WorkoutAlignmentGuide extends StatefulWidget {
  const WorkoutAlignmentGuide(
      {super.key,
      required this.canConfirm,
      required this.onConfirm,
      this.instruction});
  final String? instruction;
  final bool canConfirm;
  final VoidCallback onConfirm;
  @override
  State<WorkoutAlignmentGuide> createState() => _WorkoutAlignmentGuideState();
}

class _WorkoutAlignmentGuideState extends State<WorkoutAlignmentGuide> {
  double _width = .65;
  Alignment _alignment = Alignment.center;
  @override
  Widget build(BuildContext context) => ColoredBox(
      color: Colors.black38,
      child: Padding(
          padding: const EdgeInsets.all(12),
          child: LayoutBuilder(builder: (context, bounds) {
            final compact = bounds.maxHeight < 460 ||
                MediaQuery.textScalerOf(context).scale(16) > 22;
            final content = Column(children: [
              const Text('Reposition camera · counting paused',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center),
              Text(
                  widget.instruction ??
                      'Stand side-on with your whole body visible. Drag the outline or adjust its width.',
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center),
              if (compact)
                SizedBox(height: 160, child: _outline())
              else
                Expanded(child: _outline()),
              Slider(
                  value: _width,
                  min: .4,
                  max: .9,
                  label: 'Outline width',
                  semanticFormatterCallback: (value) =>
                      '${(value * 100).round()} percent of preview',
                  onChanged: (value) => setState(() => _width = value)),
              FilledButton(
                  onPressed: widget.canConfirm ? widget.onConfirm : null,
                  child: Text(widget.canConfirm
                      ? 'Use this position'
                      : 'Move fully into view')),
            ]);
            return compact ? SingleChildScrollView(child: content) : content;
          })));

  Widget _outline() => LayoutBuilder(
      builder: (context, bounds) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanUpdate: (details) => setState(() => _alignment = Alignment(
              (_alignment.x + details.delta.dx * 2 / bounds.maxWidth)
                  .clamp(-1, 1),
              (_alignment.y + details.delta.dy * 2 / bounds.maxHeight)
                  .clamp(-1, 1))),
          child: Align(
              alignment: _alignment,
              child: FractionallySizedBox(
                  widthFactor: _width,
                  heightFactor: .85,
                  child: DecoratedBox(
                      decoration:
                          BoxDecoration(border: Border.all(color: Colors.white, width: 2), borderRadius: BorderRadius.circular(16)),
                      child: const Center(child: Icon(Icons.accessibility_new, color: Colors.white, size: 48)))))));
}
