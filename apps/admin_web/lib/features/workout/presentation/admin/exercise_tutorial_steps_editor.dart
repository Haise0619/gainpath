import 'package:flutter/material.dart';
import 'package:gainpath_domain/workout.dart';
import 'package:gainpath_ui/gainpath_ui.dart';

class ExerciseTutorialStepsEditor extends StatefulWidget {
  const ExerciseTutorialStepsEditor(
      {super.key, required this.initialSteps, required this.onChanged});
  final List<ExerciseTutorialStep> initialSteps;
  final ValueChanged<List<ExerciseTutorialStep>> onChanged;
  @override
  State<ExerciseTutorialStepsEditor> createState() => _StepsEditorState();
}

class _StepDraft {
  _StepDraft(ExerciseTutorialStep step)
      : title = TextEditingController(text: step.title),
        description = TextEditingController(text: step.description),
        image = TextEditingController(text: step.imageUrl);
  final TextEditingController title, description, image;
  ExerciseTutorialStep get value => ExerciseTutorialStep(
      title: title.text, description: description.text, imageUrl: image.text);
  void dispose() {
    title.dispose();
    description.dispose();
    image.dispose();
  }
}

class _StepsEditorState extends State<ExerciseTutorialStepsEditor> {
  late final _steps = widget.initialSteps.map(_StepDraft.new).toList();
  void _emit() => widget.onChanged(_steps.map((s) => s.value).toList());
  void _move(int from, int to) {
    setState(() {
      final step = _steps.removeAt(from);
      _steps.insert(to, step);
    });
    _emit();
  }

  @override
  void dispose() {
    for (final step in _steps) {
      step.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Eyebrow('Step-by-step tutorial'),
        const Text(
            'Add up to 12 steps. Each step needs a title and description; an image is optional.'),
        const SizedBox(height: 12),
        for (var i = 0; i < _steps.length; i++)
          Padding(
            key: ObjectKey(_steps[i]),
            padding: const EdgeInsets.only(bottom: 12),
            child: Panel(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                  Row(children: [
                    Expanded(
                        child: Text('Step ${i + 1}',
                            style: Theme.of(context).textTheme.titleSmall)),
                    IconButton(
                        tooltip: 'Move step ${i + 1} up',
                        onPressed: i == 0 ? null : () => _move(i, i - 1),
                        icon: const Icon(Icons.arrow_upward_rounded)),
                    IconButton(
                        tooltip: 'Move step ${i + 1} down',
                        onPressed: i == _steps.length - 1
                            ? null
                            : () => _move(i, i + 1),
                        icon: const Icon(Icons.arrow_downward_rounded)),
                    IconButton(
                        tooltip: 'Remove step ${i + 1}',
                        onPressed: () {
                          final removed = _steps[i];
                          setState(() => _steps.removeAt(i));
                          _emit();
                          removed.dispose();
                        },
                        icon: const Icon(Icons.delete_outline_rounded)),
                  ]),
                  TextFormField(
                      controller: _steps[i].title,
                      decoration:
                          const InputDecoration(labelText: 'Step title'),
                      maxLength: 80,
                      onChanged: (_) => _emit(),
                      validator: (v) => (v?.trim().isEmpty ?? true)
                          ? 'Add a step title'
                          : null),
                  const SizedBox(height: 8),
                  TextFormField(
                      controller: _steps[i].description,
                      decoration:
                          const InputDecoration(labelText: 'Step description'),
                      minLines: 2,
                      maxLines: 5,
                      maxLength: 1200,
                      onChanged: (_) => _emit(),
                      validator: (v) => (v?.trim().isEmpty ?? true)
                          ? 'Describe this step'
                          : null),
                  const SizedBox(height: 8),
                  TextFormField(
                      controller: _steps[i].image,
                      decoration: const InputDecoration(
                          labelText: 'Step image URL (optional)',
                          helperText: 'HTTPS image or signed storage URL'),
                      onChanged: (_) => _emit(),
                      validator: (v) => v == null ||
                              v.trim().isEmpty ||
                              exerciseImageUri(v) != null
                          ? null
                          : 'Use an HTTPS image URL'),
                ])),
          ),
        OutlinedButton.icon(
            onPressed: _steps.length >= ExerciseTutorialDetails.maxSteps
                ? null
                : () {
                    setState(() => _steps.add(_StepDraft(
                        const ExerciseTutorialStep(
                            title: '', description: ''))));
                    _emit();
                  },
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add tutorial step')),
      ]);
}
