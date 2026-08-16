import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../data/mock_data.dart';
import '../../../widgets/shared.dart';

/// AD-M8.3 — Manage Professional Profile. Publishing actually writes back
/// to `MockData.currentCoach`, so a coach's edits here show up on the very
/// same public directory card members browse (verify via the account
/// hub's "Preview public profile"). A short suggestion chip set makes
/// adding specialties tap-to-add rather than free-typing from scratch.
class EditCoachProfileScreen extends StatefulWidget {
  const EditCoachProfileScreen({super.key});

  @override
  State<EditCoachProfileScreen> createState() => _EditCoachProfileScreenState();
}

class _EditCoachProfileScreenState extends State<EditCoachProfileScreen> {
  static const _suggestions = [
    'Strength Training',
    'Powerlifting',
    'Hypertrophy',
    'Mobility',
    'Injury Recovery',
    'Nutrition Coaching',
    'Beginner Friendly',
    'Calisthenics',
    'Weight Loss',
    'Sports Performance',
  ];

  late final TextEditingController _bio;
  late final TextEditingController _fee;
  late List<String> _tags;

  @override
  void initState() {
    super.initState();
    final coach = MockData.currentCoach;
    _bio = TextEditingController(text: coach.bio);
    _fee = TextEditingController(text: coach.fee.toStringAsFixed(0));
    _tags = [...coach.specializationTags];
  }

  @override
  void dispose() {
    _bio.dispose();
    _fee.dispose();
    super.dispose();
  }

  void _addTag(String tag) {
    if (_tags.contains(tag)) return;
    setState(() => _tags.add(tag));
  }

  void _publish() {
    final coach = MockData.currentCoach;
    coach.bio = _bio.text.trim();
    coach.specializationTags = [..._tags];
    final parsedFee = double.tryParse(_fee.text.trim());
    if (parsedFee != null && parsedFee > 0) coach.fee = parsedFee;
    Navigator.pop(context);
    showToast(context, 'Profile published to the directory.');
  }

  @override
  Widget build(BuildContext context) {
    final available = _suggestions.where((s) => !_tags.contains(s)).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: PageBody(
        children: [
          const Eyebrow('Bio'),
          TextField(
            controller: _bio,
            maxLines: 6,
            maxLength: 1000,
            decoration: const InputDecoration(
                hintText: 'Tell members about your coaching approach'),
          ),
          const SizedBox(height: 10),
          const Eyebrow('Specialties'),
          if (_tags.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('Add at least one so members can find you.',
                  style: Theme.of(context).textTheme.bodyMedium),
            ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _tags
                .map((t) => Chip(
                      label: Text(t),
                      backgroundColor: AppColors.primaryTint,
                      labelStyle: const TextStyle(
                          color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 12.5),
                      deleteIconColor: AppColors.primary,
                      onDeleted: () => setState(() => _tags.remove(t)),
                    ))
                .toList(),
          ),
          if (available.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text('Suggestions', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: available
                  .map((s) => ActionChip(
                        avatar: const Icon(Icons.add_rounded, size: 16, color: AppColors.inkSoft),
                        label: Text(s),
                        backgroundColor: AppColors.surface,
                        side: const BorderSide(color: AppColors.hairline),
                        labelStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                        onPressed: () => _addTag(s),
                      ))
                  .toList(),
            ),
          ],
          const SizedBox(height: 20),
          const Eyebrow('Consultation fee'),
          TextField(
            controller: _fee,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              prefixText: 'RM ',
              suffixText: 'per session',
              hintText: '120',
            ),
          ),
          const SizedBox(height: 20),
          const Eyebrow('Branch'),
          Panel(
            background: AppColors.surfaceAlt,
            child: Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 18, color: AppColors.inkSoft),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(MockData.currentCoach.branch,
                      style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
                ),
                Text('Set by gym staff', style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _tags.isEmpty ? null : _publish,
            child: const Text('Publish changes'),
          ),
        ],
      ),
    );
  }
}
