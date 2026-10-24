import 'dart:math';
import 'package:flutter/material.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_ui/gainpath_ui.dart';

class MemberBookingChangeScreen extends StatefulWidget {
  const MemberBookingChangeScreen(
      {super.key,
      required this.repository,
      required this.booking,
      required this.reschedule,
      required this.isCurrent});
  final MemberBookingChangeRepository repository;
  final PersistedBookingRecord booking;
  final bool reschedule;
  final bool Function() isCurrent;
  @override
  State<MemberBookingChangeScreen> createState() => _ChangeState();
}

class _ChangeState extends State<MemberBookingChangeScreen> {
  final _reason = TextEditingController();
  BookingOptionsContext? _options;
  BookingOption? _selected;
  MemberBookingChangeRequest? _request;
  bool _busy = false, _leaveAllowed = false;
  String? _message;
  @override
  void initState() {
    super.initState();
    if (widget.reschedule) _load();
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  bool get _current => mounted && widget.isCurrent();
  Future<void> _load([String? date]) async {
    if (!_current || _busy || _request != null) return;
    setState(() {
      _busy = true;
      _message = null;
      _selected = null;
    });
    try {
      final value = await widget.repository
          .loadReplacementOptions(widget.booking, localDate: date);
      if (_current) setState(() => _options = value);
    } catch (e) {
      if (_current) setState(() => _message = _error(e));
    } finally {
      if (_current) setState(() => _busy = false);
    }
  }

  String _error(Object e) {
    final code = e is BookingException ? e.code : '';
    return switch (code) {
      'failed-precondition' =>
        'This session is no longer eligible or its payment needs Admin review. Cancellation needs 12 hours and rescheduling needs 24 hours before start. Refresh My bookings.',
      'aborted' =>
        'The booking or selected slot changed. Refresh My bookings before choosing again.',
      'resource-exhausted' =>
        'A Member or Coach daily booking limit was reached. Choose another date.',
      'permission-denied' ||
      'unauthenticated' =>
        'Your session cannot change this booking. Sign in again.',
      'not-found' =>
        'The booking-change service or booking is unavailable. Retry after activation or refresh My bookings.',
      'invalid-argument' =>
        'Check the selected time and enter a reason of 1–500 characters.',
      _ =>
        'The outcome could not be confirmed. Retry the same request or check My bookings before another change.',
    };
  }

  Future<void> _pickDate() async {
    final value = _options;
    if (value == null || _busy || _request != null) return;
    final date = await showDatePicker(
        context: context,
        initialDate: DateTime.parse(value.localDate),
        firstDate: DateTime.parse(value.todayLocalDate),
        lastDate: DateTime.parse(value.throughLocalDate));
    if (date != null && _current) {
      await _load(
          '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}');
    }
  }

  Future<void> _submit() async {
    if (!_current || _busy) return;
    if (_request == null) {
      if (_reason.text.trim().isEmpty ||
          widget.reschedule && _selected == null) {
        setState(() => _message =
            'Select a replacement time when rescheduling and enter a reason.');
        return;
      }
      final confirmed = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
                title: Text(widget.reschedule
                    ? 'Confirm new session time?'
                    : 'Cancel confirmed session?'),
                content: Text(
                    'Current: ${widget.booking.localDate}, ${widget.booking.startLabel} – ${widget.booking.endLabel} (${widget.booking.timeZone}).\n\n${widget.reschedule ? 'New: ${_options!.localDate}, ${_selected!.startLabel} – ${_selected!.endLabel}. Same Coach, branch and ${widget.booking.durationMinutes}-minute duration. The original paid price stays unchanged; no new charge.' : 'This releases the session. A refund request goes to Admin review; no refund is guaranteed or issued by this action.'}'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('Keep current booking')),
                  FilledButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: Text(widget.reschedule
                          ? 'Confirm reschedule'
                          : 'Confirm cancellation'))
                ],
              ));
      if (confirmed != true || !_current) return;
      _request = MemberBookingChangeRequest(
          booking: widget.booking,
          action: widget.reschedule ? 'reschedule' : 'cancel',
          requestId: List.generate(
              16,
              (_) => Random.secure()
                  .nextInt(256)
                  .toRadixString(16)
                  .padLeft(2, '0')).join(),
          reason: _reason.text,
          newStartAtMillis:
              widget.reschedule ? _selected!.startAtMillis : null);
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final result = await widget.repository.change(_request!);
      if (!_current) return;
      setState(() => _leaveAllowed = true);
      showToast(
          context,
          result.cancelled
              ? 'Session cancelled. Refund is pending Admin review.'
              : 'Session rescheduled. Your original paid price is unchanged.');
      Navigator.pop(context, true);
    } catch (e) {
      if (!_current) return;
      final definite = e is BookingException &&
          [
            'aborted',
            'failed-precondition',
            'permission-denied',
            'unauthenticated',
            'invalid-argument',
            'resource-exhausted',
            'not-found'
          ].contains(e.code);
      setState(() {
        _message = _error(e);
        if (definite) _request = null;
      });
    } finally {
      if (_current) setState(() => _busy = false);
    }
  }

  Future<void> _leave() async {
    if (_busy || !mounted) return;
    final discard = await confirmSheet(context,
        title: _request != null
            ? 'Change outcome is unknown'
            : 'Discard this change?',
        message: _request != null
            ? 'Leaving does not undo a possible server change. Check My bookings before submitting another change.'
            : 'Your proposed change has not been submitted.',
        confirmLabel: 'Leave and check bookings');
    if (discard && mounted) {
      setState(() => _leaveAllowed = true);
      Navigator.pop(context, _request != null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isCurrent()) {
      return const Scaffold(
          body: Center(child: Text('Sign in again to view this booking.')));
    }
    return PopScope(
        canPop:
            _leaveAllowed || !_busy && _request == null && _reason.text.isEmpty,
        onPopInvokedWithResult: (popped, _) async {
          if (!popped) await _leave();
        },
        child: Scaffold(
          appBar: AppBar(
              title: Text(
                  widget.reschedule ? 'Reschedule session' : 'Cancel session')),
          body: PageBody(children: [
            Panel(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('Current confirmed session',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                      '${widget.booking.localDate}\n${widget.booking.startLabel} – ${widget.booking.endLabel}\n${widget.booking.timeZone}'),
                  const SizedBox(height: 8),
                  Text(widget.reschedule
                      ? 'Reschedule at least 24 hours before start. Your original slot stays reserved until the replacement is secured.'
                      : 'Cancel at least 12 hours before start. Paid cancellations require Admin/provider refund review.'),
                ])),
            if (_busy) const LinearProgressIndicator(),
            if (widget.reschedule) ...[
              const Eyebrow('Choose a replacement'),
              OutlinedButton.icon(
                  onPressed: _options == null || _busy || _request != null
                      ? null
                      : _pickDate,
                  icon: const Icon(Icons.calendar_month_outlined),
                  label:
                      Text(_options?.localDate ?? 'Loading eligible dates…')),
              if (_options != null && _options!.options.isEmpty)
                const Text(
                    'No eligible replacement times on this date. Choose another date.'),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final option in _options?.options ?? <BookingOption>[])
                  ChoiceChip(
                      label: Text('${option.startLabel} – ${option.endLabel}'),
                      selected: _selected == option,
                      onSelected: _busy || _request != null
                          ? null
                          : (_) => setState(() => _selected = option))
              ]),
              const SizedBox(height: 12),
              const Text(
                  'Same Coach, branch and duration. Original paid price retained. No second payment.'),
            ],
            const SizedBox(height: 16),
            TextField(
                controller: _reason,
                enabled: !_busy && _request == null,
                maxLength: 500,
                maxLines: 3,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                    labelText: 'Reason for this change',
                    border: OutlineInputBorder())),
            if (_message != null)
              Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(_message!,
                      style: const TextStyle(color: AppColors.danger))),
            if (widget.reschedule && _options == null && !_busy)
              TextButton(
                  onPressed: _load, child: const Text('Retry loading times')),
            FilledButton(
                onPressed: _busy || widget.reschedule && _selected == null
                    ? null
                    : _submit,
                child: Text(_busy
                    ? 'Confirming change…'
                    : _request != null
                        ? 'Retry same change'
                        : widget.reschedule
                            ? 'Review reschedule'
                            : 'Review cancellation')),
          ]),
        ));
  }
}
