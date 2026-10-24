import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/identity.dart';
import '../../application/coach_review_alerts_cubit.dart';

class CoachReviewNotificationButton extends StatefulWidget {
  const CoachReviewNotificationButton({super.key, required this.onOpenCoach});
  final ValueChanged<String> onOpenCoach;
  @override
  State<CoachReviewNotificationButton> createState() =>
      _CoachReviewNotificationButtonState();
}

class _CoachReviewNotificationButtonState
    extends State<CoachReviewNotificationButton> {
  CoachReviewAlertsCubit? _cubit;
  Timer? _timer;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final repo = context.read<CoachProfileAdminRepository>();
    if (_cubit?.repository == repo) return;
    _timer?.cancel();
    _cubit?.close();
    _cubit = CoachReviewAlertsCubit(repo)..refresh();
    _timer =
        Timer.periodic(const Duration(seconds: 60), (_) => _cubit?.refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _cubit?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<CoachReviewAlertsCubit, CoachReviewAlertsState>(
        bloc: _cubit!,
        builder: (context, state) => PopupMenuButton<String>(
          tooltip: 'Coach profile updates',
          onOpened: () => _cubit!.refresh(),
          onSelected: (id) {
            if (id == '__retry') {
              _cubit!.refresh();
            } else {
              widget.onOpenCoach(id);
            }
          },
          itemBuilder: (_) => [
            if (state.error != null)
              PopupMenuItem(value: '__retry', child: Text(state.error!))
            else if (state.items.isEmpty)
              PopupMenuItem<String>(
                  enabled: false,
                  child: Text(state.loading
                      ? 'Checking Coach updates…'
                      : 'No Coach profiles awaiting review'))
            else
              for (final item in state.items)
                PopupMenuItem(
                    value: item.coachId,
                    child: SizedBox(
                        width: 280,
                        child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(item.name),
                            subtitle: const Text(
                                'Profile changes awaiting Admin publication')))),
            const PopupMenuItem(
                value: '__retry', child: Text('Refresh Coach updates')),
          ],
          icon: Badge(
            isLabelVisible: state.items.isNotEmpty || state.error != null,
            label: Text(state.error != null ? '!' : '${state.items.length}'),
            child: const Icon(Icons.notifications_outlined),
          ),
        ),
      );
}
