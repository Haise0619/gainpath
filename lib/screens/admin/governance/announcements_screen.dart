import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../data/mock_data.dart';
import '../../../widgets/shared.dart';

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];
String _fmt(DateTime d) => '${d.day} ${_months[d.month - 1]}';

/// AD-M11.4 — Publish Announcements. The old version was write-only: a
/// compose form that toasted "Announcement published" and forgot
/// whatever was typed, with no way to see what had gone out before or
/// whether it was still showing to members. This reads and writes the
/// real `MockData.announcements` list, and each entry's active/expired
/// state is computed from its validity window, not stored as a flag
/// that could drift out of date.
class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  bool _composing = false;
  final _title = TextEditingController();
  final _body = TextEditingController();
  DateTime _from = DateTime.now();
  DateTime _to = DateTime.now().add(const Duration(days: 7));

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _from : _to,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => isFrom ? _from = picked : _to = picked);
  }

  void _publish() {
    if (_title.text.trim().isEmpty || _body.text.trim().isEmpty) {
      showToast(context, 'Add a title and message first.');
      return;
    }
    setState(() {
      MockData.announcements.insert(
        0,
        Announcement(
          id: 'an${DateTime.now().millisecondsSinceEpoch}',
          title: _title.text.trim(),
          body: _body.text.trim(),
          validFrom: _from,
          validTo: _to,
        ),
      );
      _title.clear();
      _body.clear();
      _composing = false;
    });
    showToast(context, 'Announcement published to every member home screen.');
  }

  @override
  Widget build(BuildContext context) {
    final announcements = [...MockData.announcements]..sort((a, b) => b.validFrom.compareTo(a.validFrom));
    final activeCount = announcements.where((a) => a.isActive).length;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('$activeCount active right now, ${announcements.length} total',
                      style: Theme.of(context).textTheme.bodyLarge),
                ),
                if (!_composing)
                  FilledButton.icon(
                    onPressed: () => setState(() => _composing = true),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('New announcement'),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            if (_composing)
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('New announcement', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _title,
                        decoration: const InputDecoration(labelText: 'Title', hintText: 'Public holiday hours'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _body,
                        maxLines: 3,
                        decoration: const InputDecoration(
                            labelText: 'Message', hintText: 'What do members need to know?'),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _pickDate(true),
                              child: Text('From ${_fmt(_from)}'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _pickDate(false),
                              child: Text('Until ${_fmt(_to)}'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Panel(
                        background: AppColors.accentTint,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.campaign_rounded, size: 19, color: AppColors.warning),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'This appears at the top of every member home screen while active.',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => setState(() => _composing = false),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton(onPressed: _publish, child: const Text('Publish')),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ...announcements.map((a) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Panel(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                              color: (a.isActive ? AppColors.success : AppColors.inkSoft).withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(11)),
                          child: Icon(Icons.campaign_rounded, size: 18, color: a.isActive ? AppColors.success : AppColors.inkSoft),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(a.title, style: Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 2),
                              Text(a.body, style: Theme.of(context).textTheme.bodyMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 4),
                              Text('${_fmt(a.validFrom)} – ${_fmt(a.validTo)}',
                                  style: const TextStyle(fontSize: 11.5, color: AppColors.inkSoft)),
                            ],
                          ),
                        ),
                        statusPill(a.isActive ? 'Active' : 'Expired'),
                      ],
                    ),
                  ),
                )),
          ],
        ),
      ),
    );
  }
}
