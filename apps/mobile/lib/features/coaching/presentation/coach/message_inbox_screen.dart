import 'package:flutter/material.dart';
import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show BookingException;

/// AD-M9.4 — Respond to Member Messages. Reads `coachRoster`,
/// which is now a filtered view over the same `allBookings` list members
/// read from — so a message a member sends from `MessageCoachScreen`
/// shows up here for real, and a reply sent here shows up back in the
/// member's thread. Neither side used to be able to reach the other.
class CoachMessageInboxScreen extends StatefulWidget {
  const CoachMessageInboxScreen(
      {super.key, this.bookings, this.repository, this.isCurrent});
  final List<Booking>? bookings;
  final BookingCommunicationRepository? repository;
  final bool Function()? isCurrent;

  @override
  State<CoachMessageInboxScreen> createState() =>
      _CoachMessageInboxScreenState();
}

class _CoachMessageInboxScreenState extends State<CoachMessageInboxScreen> {
  final _summaries = <String, List<BookingMessage>>{};
  bool _loading = false;
  String? _loadError;
  @override
  void initState() {
    super.initState();
    if (widget.repository != null) _refresh();
  }

  Future<void> _refresh() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _loadError = null;
    });
    for (final b in widget.bookings ?? <Booking>[]) {
      if (!mounted || !(widget.isCurrent?.call() ?? true)) return;
      try {
        final page = await widget.repository!.load(b.id);
        if (!mounted || !(widget.isCurrent?.call() ?? true)) return;
        setState(() => _summaries[b.id] = page.messages
            .map((m) => BookingMessage(
                m.senderRole == 'coach' ? 'Coach' : 'Member',
                m.text,
                DateTime.fromMillisecondsSinceEpoch(m.sentAtMillis)))
            .toList());
      } catch (_) {
        if (mounted) {
          setState(() =>
              _loadError = 'Some message previews could not be loaded. Retry.');
        }
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  List<BookingMessage> _messagesFor(Booking b) =>
      widget.repository == null ? b.messages : (_summaries[b.id] ?? []);
  @override
  Widget build(BuildContext context) {
    if (!(widget.isCurrent?.call() ?? true)) {
      return const Scaffold(
          body: Center(child: Text('Messages unavailable for this session.')));
    }
    final conversations = (widget.bookings ??
            context.read<BookingRepository>().coachRoster)
        .where((b) =>
            widget.repository != null ||
            b.messages.isNotEmpty ||
            b.status == BookingStatus.confirmed ||
            b.status == BookingStatus.pending)
        .toList()
      ..sort((a, b) {
        final am = _messagesFor(a), bm = _messagesFor(b);
        final aNeedsReply = am.isNotEmpty && am.last.senderRole == 'Member';
        final bNeedsReply = bm.isNotEmpty && bm.last.senderRole == 'Member';
        if (aNeedsReply != bNeedsReply) return aNeedsReply ? -1 : 1;
        final aTime = am.isNotEmpty ? am.last.sentAt : a.start;
        final bTime = bm.isNotEmpty ? bm.last.sentAt : b.start;
        return bTime.compareTo(aTime);
      });

    return Scaffold(
      appBar: AppBar(title: const Text('Messages'), actions: [
        if (widget.repository != null)
          IconButton(
              onPressed: _loading ? null : _refresh,
              icon: const Icon(Icons.refresh))
      ]),
      body: conversations.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.forum_outlined,
                        size: 40, color: AppColors.hairline),
                    const SizedBox(height: 14),
                    Text('No active client conversations yet.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
            )
          : PageBody(
              children: [
                if (_loading) const LinearProgressIndicator(),
                if (_loadError != null) Text(_loadError!),
                ...conversations.map((b) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ConversationTile(
                        booking: b,
                        messages: _messagesFor(b),
                        previewAvailable: widget.repository == null ||
                            _summaries.containsKey(b.id),
                        onTap: () async {
                          await Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => CoachMessageThreadScreen(
                                      booking: b,
                                      repository: widget.repository,
                                      isCurrent: widget.isCurrent)));
                          if (mounted) setState(() {});
                          if (mounted && widget.repository != null) {
                            _refresh();
                          }
                        },
                      ),
                    ))
              ],
            ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final Booking booking;
  final VoidCallback onTap;
  final List<BookingMessage> messages;
  final bool previewAvailable;
  const _ConversationTile(
      {required this.booking,
      required this.onTap,
      required this.messages,
      required this.previewAvailable});

  @override
  Widget build(BuildContext context) {
    final hasMessages = messages.isNotEmpty;
    final needsReply = hasMessages && messages.last.senderRole == 'Member';
    final preview = !previewAvailable
        ? 'Message preview unavailable'
        : hasMessages
            ? messages.last.text
            : 'No messages yet — session ${_formatDate(booking.start)}';

    return Panel(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.primaryTint,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Center(
              child: Text(
                booking.memberName
                    .trim()
                    .split(RegExp(r'\s+'))
                    .where((w) => w.isNotEmpty)
                    .map((w) => w[0])
                    .take(2)
                    .join(),
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(booking.memberName,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  preview,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: needsReply ? AppColors.ink : AppColors.inkSoft,
                      fontWeight:
                          needsReply ? FontWeight.w600 : FontWeight.w400),
                ),
              ],
            ),
          ),
          if (needsReply)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                  color: AppColors.dangerTint,
                  borderRadius: BorderRadius.circular(999)),
              child: const Text('Reply needed',
                  style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.danger)),
            )
          else
            const Icon(Icons.arrow_forward_ios_rounded,
                size: 13, color: AppColors.inkSoft),
        ],
      ),
    );
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
    return '${d.day} ${months[d.month - 1]}';
  }
}

/// The coach's side of a per-booking thread — the mirror of the member's
/// `MessageCoachScreen`, writing to the exact same `booking.messages`
/// list. 'Coach' messages render as "you" (right-aligned, primary color).
class CoachMessageThreadScreen extends StatefulWidget {
  final Booking booking;
  const CoachMessageThreadScreen(
      {super.key,
      required this.booking,
      this.repository,
      this.isCurrent,
      this.loadCoachName,
      this.responseTime = '-',
      this.ownRole = 'Coach'});
  final BookingCommunicationRepository? repository;
  final bool Function()? isCurrent;
  final String ownRole;
  final String responseTime;
  final Future<String?> Function()? loadCoachName;

  @override
  State<CoachMessageThreadScreen> createState() =>
      _CoachMessageThreadScreenState();
}

class _CoachMessageThreadScreenState extends State<CoachMessageThreadScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  List<BookingMessage> _messages = [];
  bool _busy = false;
  String? _error, _requestId, _pendingText;
  int? _before;
  bool _allowLeave = false;
  bool _historyLoaded = false;
  String? _coachName;
  String get _otherName {
    final name = widget.ownRole == 'Coach'
        ? widget.booking.memberName
        : (_coachName ?? widget.booking.coachName);
    return name.trim().isEmpty || name == '-'
        ? (widget.ownRole == 'Coach' ? 'Client' : 'Coach')
        : name;
  }

  bool get _current => widget.isCurrent?.call() ?? true;
  @override
  void initState() {
    super.initState();
    _historyLoaded = widget.repository == null;
    if (widget.ownRole == 'Member' && widget.loadCoachName != null) {
      _resolveCoachName();
    }
    if (widget.repository != null) _load();
  }

  Future<void> _resolveCoachName() async {
    try {
      final name = await widget.loadCoachName!();
      if (mounted && _current && name != null && name.trim().isNotEmpty) {
        setState(() => _coachName = name.trim());
      }
    } catch (_) {/* Keep a truthful generic counterparty label. */}
  }

  void _accept(SessionConversation page, {bool older = false}) {
    _historyLoaded = true;
    final rows = page.messages
        .map((m) => BookingMessage(m.senderRole == 'coach' ? 'Coach' : 'Member',
            m.text, DateTime.fromMillisecondsSinceEpoch(m.sentAtMillis)))
        .toList();
    _messages = older ? [...rows, ..._messages] : rows;
    _before = page.nextBeforeSequence;
  }

  Future<void> _load({bool older = false}) async {
    if (_busy || !_current) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final page = await widget.repository!
          .load(widget.booking.id, beforeSequence: older ? _before : null);
      if (mounted && _current) setState(() => _accept(page, older: older));
    } catch (_) {
      if (mounted && _current) {
        setState(
            () => _error = 'Messages could not be loaded. Retry or refresh.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_busy || !_current) return;
    final text = _pendingText ?? _controller.text.trim();
    if (text.isEmpty || text.length > 500) {
      setState(() => _error = 'Enter a message of 1–500 characters.');
      return;
    }
    if (widget.repository == null) {
      setState(() {
        widget.booking.messages
            .add(BookingMessage(widget.ownRole, text, DateTime.now()));
        _controller.clear();
      });
      _jump();
      return;
    }
    _requestId ??= 'message_${DateTime.now().microsecondsSinceEpoch}';
    _pendingText = text;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final page =
          await widget.repository!.send(widget.booking.id, _requestId!, text);
      if (!mounted || !_current) return;
      setState(() {
        _accept(page);
        _controller.clear();
        _requestId = null;
        _pendingText = null;
      });
      _jump();
    } catch (error) {
      if (mounted && _current) {
        setState(() => _error = error is BookingException &&
                error.code == 'failed-precondition'
            ? 'This booking cannot accept messages. Refresh its status; your text is retained.'
            : 'Send was not confirmed. Retry sends the same message safely.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _jump() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_current) {
      return const Scaffold(
          body: Center(child: Text('Messages unavailable for this session.')));
    }
    final messages =
        widget.repository == null ? widget.booking.messages : _messages;
    return PopScope(
        canPop: _allowLeave ||
            (!_busy && _controller.text.trim().isEmpty && _requestId == null),
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop || _busy) return;
          final discard = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                      title: const Text('Leave this message?'),
                      content: Text(_requestId == null
                          ? 'Your unsent text will be discarded.'
                          : 'The send outcome is unconfirmed. Leaving does not undo a message already saved.'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Stay')),
                        TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Leave'))
                      ]));
          if (discard == true && mounted) {
            setState(() => _allowLeave = true);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) Navigator.pop(context);
            });
          }
        },
        child: Scaffold(
          appBar: AppBar(title: Text(_otherName), actions: [
            if (widget.repository != null)
              IconButton(
                  onPressed: _busy ? null : () => _load(),
                  icon: const Icon(Icons.refresh))
          ]),
          body: Column(
            children: [
              if (_busy) const LinearProgressIndicator(),
              if (_error != null)
                Padding(
                    padding: const EdgeInsets.all(12), child: Text(_error!)),
              if (_before != null)
                TextButton(
                    onPressed: _busy ? null : () => _load(older: true),
                    child: const Text('Load earlier messages')),
              Expanded(
                child: messages.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(40),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.chat_bubble_outline_rounded,
                                  size: 40, color: AppColors.hairline),
                              const SizedBox(height: 14),
                              Text(
                                  _busy
                                      ? 'Loading messages…'
                                      : !_historyLoaded
                                          ? 'Messages unavailable. Refresh to retry.'
                                          : 'No messages yet with $_otherName.',
                                  textAlign: TextAlign.center,
                                  style:
                                      Theme.of(context).textTheme.bodyMedium),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        itemCount: messages.length,
                        itemBuilder: (ctx, i) => _Bubble(
                            message: messages[i], ownRole: widget.ownRole),
                      ),
              ),
              if (widget.ownRole == 'Member')
                Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    color: AppColors.surfaceAlt,
                    child: Row(children: [
                      const Icon(Icons.schedule_rounded,
                          size: 13, color: AppColors.inkSoft),
                      const SizedBox(width: 6),
                      Text(widget.responseTime,
                          style: const TextStyle(
                              fontSize: 11.5, color: AppColors.inkSoft))
                    ])),
              Container(
                padding: EdgeInsets.fromLTRB(
                    12, 10, 12, 10 + MediaQuery.of(context).padding.bottom),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(top: BorderSide(color: AppColors.hairline)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        onChanged: (_) => setState(() {}),
                        enabled: !_busy && _requestId == null,
                        textInputAction: TextInputAction.send,
                        maxLength: 500,
                        buildCounter: (context,
                                {required currentLength,
                                required isFocused,
                                maxLength}) =>
                            null,
                        onSubmitted: (_) => _send(),
                        decoration: const InputDecoration(
                          hintText: 'Message about this booking',
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 13),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                        onPressed: _busy ? null : _send,
                        icon: const Icon(Icons.arrow_upward_rounded)),
                  ],
                ),
              ),
            ],
          ),
        ));
  }
}

class _Bubble extends StatelessWidget {
  final BookingMessage message;
  final String ownRole;
  const _Bubble({required this.message, required this.ownRole});

  @override
  Widget build(BuildContext context) {
    final fromCoach = message.senderRole == ownRole;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment:
            fromCoach ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.78),
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
            decoration: BoxDecoration(
              color: fromCoach ? AppColors.primary : AppColors.surface,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(fromCoach ? 16 : 4),
                bottomRight: Radius.circular(fromCoach ? 4 : 16),
              ),
              border: fromCoach ? null : Border.all(color: AppColors.hairline),
            ),
            child: Text(message.text,
                style: TextStyle(
                    fontSize: 14.5,
                    height: 1.45,
                    color: fromCoach ? Colors.white : AppColors.ink)),
          ),
          const SizedBox(height: 3),
          Text(_time(message.sentAt),
              style: const TextStyle(fontSize: 10.5, color: AppColors.inkSoft)),
        ],
      ),
    );
  }

  String _time(DateTime d) {
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
