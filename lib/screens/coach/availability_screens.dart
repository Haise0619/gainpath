import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../data/mock_data.dart';
import '../../widgets/shared.dart';

/// AD-M10.1 — View Availability Calendar.
class AvailabilityScreen extends StatefulWidget {
  const AvailabilityScreen({super.key});

  @override
  State<AvailabilityScreen> createState() => _AvailabilityScreenState();
}

class _AvailabilityScreenState extends State<AvailabilityScreen> {
  late final List<List<String>> _hours =
      MockData.workingHours.map((e) => [...e]).toList();
  late final List<List<String>> _blocks =
      MockData.blockedSlots.map((e) => [...e]).toList();

  int _dailyCap = 4;
  int _lookAhead = 30;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Availability')),
      body: PageBody(
        children: [
          const Eyebrow('Weekly working hours'),
          Panel(
            padding: EdgeInsets.zero,
            child: Column(
              children: List.generate(_hours.length, (i) {
                final row = _hours[i];
                final active = row[3] == 'true';
                return Column(
                  children: [
                    if (i > 0) const Divider(height: 1),
                    SwitchListTile(
                      value: active,
                      onChanged: (v) =>
                          setState(() => _hours[i][3] = v.toString()),
                      title: Text(row[0],
                          style: Theme.of(context).textTheme.titleMedium),
                      subtitle: Text(
                          active ? '${row[1]} to ${row[2]}' : 'Not working',
                          style: Theme.of(context).textTheme.bodyMedium),
                    ),
                  ],
                );
              }),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Eyebrow('Time off and breaks'),
              TextButton.icon(
                onPressed: _addBlock,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add'),
              ),
            ],
          ),
          if (_blocks.isEmpty)
            Panel(
              child: Text('Nothing blocked out right now.',
                  style: Theme.of(context).textTheme.bodyMedium),
            )
          else
            ..._blocks.map((b) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Panel(
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.dangerTint,
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: const Icon(Icons.event_busy_rounded,
                              size: 19, color: AppColors.danger),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(b[0],
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium),
                              Text('${b[1]}  ·  ${b[2]}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium),
                            ],
                          ),
                        ),
                        IconButton(
                          icon:
                              const Icon(Icons.delete_outline_rounded, size: 19),
                          onPressed: () async {
                            final ok = await confirmSheet(context,
                                title: 'Remove this block?',
                                message:
                                    'That time reopens for members to book.',
                                confirmLabel: 'Remove',
                                destructive: true);
                            if (ok) setState(() => _blocks.remove(b));
                          },
                        ),
                      ],
                    ),
                  ),
                )),
          const SizedBox(height: 20),
          const Eyebrow('Booking limits'),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Maximum sessions per day',
                    style: Theme.of(context).textTheme.titleMedium),
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: _dailyCap.toDouble(),
                        min: 1,
                        max: 10,
                        divisions: 9,
                        label: '$_dailyCap',
                        onChanged: (v) =>
                            setState(() => _dailyCap = v.round()),
                      ),
                    ),
                    SizedBox(
                      width: 34,
                      child: Text('$_dailyCap',
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const Divider(height: 20),
                Text('How far ahead members can book',
                    style: Theme.of(context).textTheme.titleMedium),
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: _lookAhead.toDouble(),
                        min: 7,
                        max: 60,
                        divisions: 53,
                        label: '$_lookAhead days',
                        onChanged: (v) =>
                            setState(() => _lookAhead = v.round()),
                      ),
                    ),
                    SizedBox(
                      width: 62,
                      child: Text('$_lookAhead days',
                          style: const TextStyle(
                              fontSize: 13.5, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: () => showToast(context, 'Availability saved.'),
            child: const Text('Save changes'),
          ),
        ],
      ),
    );
  }

  void _addBlock() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Block out time', style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 16),
            const TextField(
              decoration: InputDecoration(
                  labelText: 'Reason', hintText: 'Medical leave, holiday, break'),
            ),
            const SizedBox(height: 12),
            Row(
              children: const [
                Expanded(
                    child: TextField(
                        decoration: InputDecoration(labelText: 'From'))),
                SizedBox(width: 10),
                Expanded(
                    child:
                        TextField(decoration: InputDecoration(labelText: 'To'))),
              ],
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () {
                setState(() =>
                    _blocks.add(['Personal leave', 'Next week', 'Full day']));
                Navigator.pop(ctx);
                showToast(context, 'Time blocked out.');
              },
              child: const Text('Block this time'),
            ),
          ],
        ),
      ),
    );
  }
}
