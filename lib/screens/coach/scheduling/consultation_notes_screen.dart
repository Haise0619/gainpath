import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../data/mock_data.dart';
import '../../../widgets/shared.dart';

/// AD-M9.2 — Generate Post-Workout Consultation Notes. Two real fixes
/// over the old version: publishing actually writes to `booking.notes`
/// (it used to just toast and discard whatever was typed — the note
/// vanished the moment you left the screen), and "Generate draft" gives
/// a real starting scaffold to edit rather than a blank box, matching
/// what "generate" in the module name actually asked for.
class ConsultationNotesScreen extends StatefulWidget {
  final Booking booking;
  const ConsultationNotesScreen({super.key, required this.booking});

  @override
  State<ConsultationNotesScreen> createState() => _ConsultationNotesScreenState();
}

class _ConsultationNotesScreenState extends State<ConsultationNotesScreen> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.booking.notes ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _generateDraft() {
    final name = widget.booking.memberName;
    setState(() {
      _controller.text = 'Session focus: technique and controlled tempo.\n\n'
          '$name showed good effort and engagement throughout. Note specific '
          'form cues covered today, any exercises to progress or regress next '
          'session, and one thing to watch for going forward.\n\n'
          'Next session: continue building on today\'s work.';
      _error = null;
    });
  }

  void _publish() {
    if (_controller.text.trim().isEmpty) {
      setState(() => _error = 'Add some notes before publishing.');
      return;
    }
    widget.booking.notes = _controller.text.trim();
    widget.booking.status = 'Completed';
    Navigator.pop(context);
    showToast(context, 'Notes published. Session marked complete.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Consultation notes')),
      body: PageBody(
        children: [
          Panel(
            child: Column(
              children: [
                DetailRow('Client', widget.booking.memberName),
                const Divider(height: 20),
                DetailRow('Session', _formatDate(widget.booking.start)),
                const Divider(height: 20),
                DetailRow('Fee', 'RM ${widget.booking.fee.toStringAsFixed(2)}'),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Eyebrow('Your notes'),
              TextButton.icon(
                onPressed: _generateDraft,
                icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                label: const Text('Generate draft'),
              ),
            ],
          ),
          TextField(
            controller: _controller,
            maxLines: 10,
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            decoration: InputDecoration(
              hintText:
                  'How did the session go? Note any technique changes or things to watch next time.',
              errorText: _error,
            ),
          ),
          const SizedBox(height: 10),
          Panel(
            background: AppColors.surfaceAlt,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.inkSoft),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Publishing these notes marks the session as complete and lets '
                    'the member leave a review.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _publish,
            child: const Text('Publish notes'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '${d.day} ${months[d.month - 1]}  ·  $h:$m';
  }
}
