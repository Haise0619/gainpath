import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';

class AiWorkoutPointsFeedback extends StatefulWidget {
  const AiWorkoutPointsFeedback({
    super.key,
    required this.synced,
    required this.claim,
  });

  final bool synced;
  final Future<int> Function() claim;

  @override
  State<AiWorkoutPointsFeedback> createState() =>
      _AiWorkoutPointsFeedbackState();
}

class _AiWorkoutPointsFeedbackState extends State<AiWorkoutPointsFeedback> {
  Future<int>? _receipt;

  @override
  void initState() {
    super.initState();
    if (widget.synced) _receipt = Future<int>.microtask(widget.claim);
  }

  @override
  void didUpdateWidget(covariant AiWorkoutPointsFeedback oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.synced && !oldWidget.synced && _receipt == null) {
      _receipt = Future<int>.microtask(widget.claim);
    }
  }

  @override
  Widget build(BuildContext context) => Panel(
        child: FutureBuilder<int>(
          future: _receipt,
          builder: (context, result) {
            final amount = result.data;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AI workout points',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                Semantics(
                  liveRegion: true,
                  child:
                      Text(switch ((widget.synced, result.hasError, amount)) {
                    (false, _, _) =>
                      'Sync this workout to confirm your points.',
                    (true, true, _) => 'Could not confirm your points.',
                    (true, false, null) => 'Checking workout points…',
                    (true, false, 0) =>
                      'No additional points for this workout. Each exercise can earn points once a day.',
                    (true, false, final points?) => '+$points points confirmed',
                  }),
                ),
                if (widget.synced && result.hasError)
                  TextButton(
                    onPressed: () => setState(() => _receipt = widget.claim()),
                    child: const Text('Retry'),
                  ),
              ],
            );
          },
        ),
      );
}
