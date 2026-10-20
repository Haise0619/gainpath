import 'package:flutter/material.dart';
import 'dart:math';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../application/booking_bloc.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:gainpath_domain/coaching.dart';

/// Shared editor for injected prototype data and trusted connected notes.
class ConsultationNotesScreen extends StatefulWidget {
  final Booking booking;
  final ConsultationNotesRepository? repository;
  final bool Function()? isCurrent;
  const ConsultationNotesScreen(
      {super.key, required this.booking, this.repository, this.isCurrent});

  @override
  State<ConsultationNotesScreen> createState() =>
      _ConsultationNotesScreenState();
}

class _ConsultationNotesScreenState extends State<ConsultationNotesScreen> {
  late final TextEditingController _controller;
  String? _error;
  ConsultationNotesResult? _result;
  bool _busy = false;
  String _baseline = '';
  String? _requestId, _pendingText;
  bool get _current => mounted && (widget.isCurrent?.call() ?? true);
  bool get _published => widget.repository != null && _result?.text != null;
  bool get _dirty => _controller.text != _baseline;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.booking.notes ?? '');
    _baseline = _controller.text;
    if (widget.repository != null) _load();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.repository!.load(widget.booking.id);
      if (!_current) return;
      setState(() {
        _result = result;
        if (result.text != null) {
          _controller.text = result.text!;
          _baseline = result.text!;
          _requestId = null;
          _pendingText = null;
        }
      });
    } catch (_) {
      if (_current) {
        setState(() => _error = 'Could not load notes. Retry when connected.');
      }
    } finally {
      if (_current) setState(() => _busy = false);
    }
  }

  Future<void> _close() async {
    if (_busy) return;
    if (_dirty && !_published) {
      final discard = await confirmSheet(context,
          title: 'Leave consultation notes?',
          message: _requestId == null
              ? 'Your unpublished notes will be discarded.'
              : 'The publish outcome may be unknown. Leaving does not cancel a server save; reopen this session to check.',
          confirmLabel: 'Leave notes');
      if (!discard || !_current) return;
    }
    if (_current) Navigator.pop(context, _published);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _generateDraft() {
    setState(() {
      _controller.text = 'Session focus:\n\n'
          'Coach observations:\n\n'
          'Technique cues covered:\n\n'
          'Next session recommendations:\n';
      _error = null;
    });
  }

  Future<void> _publish() async {
    if (_busy || !_current) return;
    if (_controller.text.trim().isEmpty ||
        _controller.text.trim().length > 5000) {
      setState(() => _error = 'Add some notes before publishing.');
      return;
    }
    if (widget.repository != null) {
      _requestId ??=
          'notes_${DateTime.now().microsecondsSinceEpoch}_${Random.secure().nextInt(1 << 30)}';
      _pendingText ??= _controller.text.trim();
      setState(() {
        _busy = true;
        _error = null;
      });
      try {
        final result = await widget.repository!
            .publish(widget.booking.id, _requestId!, _pendingText!);
        if (!_current) return;
        if (result.text == null ||
            result.status != 'completed' ||
            result.text != _pendingText) {
          throw const FormatException('Unconfirmed notes');
        }
        setState(() {
          _result = result;
          _controller.text = result.text!;
          _baseline = result.text!;
          _requestId = null;
          _pendingText = null;
        });
      } catch (_) {
        if (_current) {
          setState(() => _error =
              'Publish was not confirmed. Your text is retained. Retry publish or reload notes to check server status.');
        }
      } finally {
        if (_current) setState(() => _busy = false);
      }
      return;
    }
    context
        .read<BookingBloc>()
        .add(BookingNotesPublished(widget.booking.id, _controller.text.trim()));
    Navigator.pop(context);
    showToast(context, 'Notes published. Session marked complete.');
  }

  @override
  Widget build(BuildContext context) {
    if (!(widget.isCurrent?.call() ?? true)) {
      return const Scaffold(
          body: Center(child: Text('Notes unavailable for this session.')));
    }
    final connected = widget.repository != null;
    final canEdit = !_busy &&
        !_published &&
        _requestId == null &&
        (!connected || _result?.canPublish == true);
    return PopScope(
        canPop: !_busy && (!_dirty || _published),
        onPopInvokedWithResult: (didPop, _) async {
          if (!didPop) await _close();
        },
        child: Scaffold(
          appBar: AppBar(
              title: const Text('Consultation notes'),
              leading: IconButton(
                  tooltip: 'Back',
                  onPressed: _busy ? null : _close,
                  icon: const Icon(Icons.arrow_back))),
          body: PageBody(
            children: [
              if (_busy) const LinearProgressIndicator(),
              if (connected) ...[
                if (_published) const Text('Published notes'),
                if (_published)
                  const Text('Session completed. These notes are read-only.'),
                if (!_published && _result != null && !_result!.canPublish)
                  const Text(
                      'Only the assigned Coach can publish after a confirmed session ends.'),
                if (_error != null)
                  Text(_error!,
                      style: const TextStyle(color: AppColors.danger)),
                TextButton(
                    onPressed: _busy ? null : _load,
                    child: const Text('Reload notes')),
              ],
              Panel(
                child: Column(
                  children: [
                    DetailRow('Client', widget.booking.memberName),
                    const Divider(height: 20),
                    DetailRow('Session', _formatDate(widget.booking.start)),
                    const Divider(height: 20),
                    DetailRow(
                        'Fee',
                        connected
                            ? '—'
                            : 'RM ${widget.booking.fee.toStringAsFixed(2)}'),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Eyebrow('Your notes'),
                  TextButton.icon(
                    onPressed: canEdit ? _generateDraft : null,
                    icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                    label: const Text('Insert outline'),
                  ),
                ],
              ),
              TextField(
                controller: _controller,
                readOnly: !canEdit,
                maxLength: 5000,
                maxLines: 10,
                onChanged: (_) {
                  setState(() => _error = null);
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
                    const Icon(Icons.info_outline_rounded,
                        size: 18, color: AppColors.inkSoft),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Publishing these notes marks the session as complete and makes '
                        'the saved notes available to the member.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              if (!_published)
                FilledButton(
                  onPressed: !_busy && (canEdit || _requestId != null)
                      ? _publish
                      : null,
                  child: Text(
                      _requestId == null ? 'Publish notes' : 'Retry publish'),
                ),
            ],
          ),
        ));
  }

  String _formatDate(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '${d.day} ${months[d.month - 1]}  ·  $h:$m';
  }
}
