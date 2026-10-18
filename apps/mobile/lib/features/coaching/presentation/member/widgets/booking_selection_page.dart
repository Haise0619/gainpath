import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';

class BookingDayOption {
  const BookingDayOption(
      {required this.date, required this.selected, this.onTap});
  final DateTime date;
  final bool selected;
  final VoidCallback? onTap;
}

class BookingTimeOption {
  const BookingTimeOption(
      {required this.label,
      required this.selected,
      this.unavailable = false,
      this.onTap});
  final String label;
  final bool selected, unavailable;
  final VoidCallback? onTap;
}

/// Original booking layout used by every booking data source.
class BookingSelectionPage extends StatelessWidget {
  const BookingSelectionPage(
      {super.key,
      required this.days,
      required this.times,
      required this.details,
      this.header = const [],
      this.footer = const [],
      this.actions,
      this.duration});
  final List<BookingDayOption> days;
  final List<BookingTimeOption> times;
  final List<Widget> details, header, footer;
  final List<Widget>? actions;
  final Widget? duration;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Book a session'), actions: actions),
        body: PageBody(children: [
          ...header,
          const Eyebrow('Pick a day'),
          SizedBox(
              height: 78,
              child: ListView(scrollDirection: Axis.horizontal, children: [
                for (final day in days)
                  GestureDetector(
                    onTap: day.onTap,
                    child: Container(
                        width: 62,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                            color: day.selected
                                ? AppColors.primary
                                : AppColors.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: day.selected
                                    ? AppColors.primary
                                    : AppColors.hairline)),
                        child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                  [
                                    'Mon',
                                    'Tue',
                                    'Wed',
                                    'Thu',
                                    'Fri',
                                    'Sat',
                                    'Sun'
                                  ][day.date.weekday - 1],
                                  style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: day.selected
                                          ? Colors.white70
                                          : AppColors.inkSoft)),
                              const SizedBox(height: 4),
                              Text('${day.date.day}',
                                  style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: day.selected
                                          ? Colors.white
                                          : AppColors.ink)),
                            ])),
                  )
              ])),
          if (days.isEmpty) const Text('-'),
          const SizedBox(height: 20),
          if (duration != null) duration!,
          const Eyebrow('Available times'),
          Wrap(spacing: 10, runSpacing: 10, children: [
            for (final time in times)
              GestureDetector(
                onTap: time.onTap,
                child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 13),
                    decoration: BoxDecoration(
                        color: time.unavailable
                            ? AppColors.surfaceAlt
                            : time.selected
                                ? AppColors.primary
                                : AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: time.selected
                                ? AppColors.primary
                                : AppColors.hairline)),
                    child: Text(time.label,
                        style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: time.unavailable
                                ? AppColors.inkSoft
                                : time.selected
                                    ? Colors.white
                                    : AppColors.ink,
                            decoration: time.unavailable
                                ? TextDecoration.lineThrough
                                : null))),
              )
          ]),
          if (times.isEmpty) const Text('-'),
          const SizedBox(height: 24),
          Panel(
              child: Column(children: [
            for (var i = 0; i < details.length; i++) ...[
              if (i > 0) const Divider(height: 20),
              details[i]
            ]
          ])),
          const SizedBox(height: 18),
          ...footer,
        ]),
      );
}
