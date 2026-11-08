import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show BookingException;
import 'package:gainpath_ui/gainpath_ui.dart';
import 'member_coach_presentation.dart';

String _date(DateTime d) {
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
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}

String _clock(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// A conversation belongs to the relationship; bookings only grant access and
/// provide session context. The server remains authoritative for sending.
class PairChatScreen extends StatefulWidget {
  const PairChatScreen(
      {super.key,
      required this.repository,
      required this.isCurrent,
      required this.ownRole,
      this.bookingId,
      this.peerId,
      this.initialName,
      this.onBookAgain});
  final PairConversationRepository repository;
  final bool Function() isCurrent;
  final String ownRole;
  final String? bookingId, peerId, initialName;
  final void Function(String peerId)? onBookAgain;
  @override
  State<PairChatScreen> createState() => _PairChatScreenState();
}

class _PairChatScreenState extends State<PairChatScreen>
    with WidgetsBindingObserver {
  final _text = TextEditingController(), _scroll = ScrollController();
  final _messages = <String, PairChatMessage>{};
  PairChatPage? _page;
  Timer? _timer;
  bool _loading = false,
      _sending = false,
      _older = false,
      _leaving = false,
      _newMessages = false;
  bool _foreground = true;
  String? _error, _before, _request, _pending;
  int _generation = 0, _accepted = 0;
  bool get _current => mounted && widget.isCurrent();
  bool get _nearBottom =>
      !_scroll.hasClients || _scroll.position.extentAfter < 100;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_foreground &&
          _current &&
          !_sending &&
          (ModalRoute.of(context)?.isCurrent ?? true)) {
        _load();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground && _current) _load();
  }

  void _accept(PairChatPage page, int generation, {bool older = false}) {
    final wasEmpty = _page == null, bottom = _nearBottom;
    final oldIds = _messages.keys.toSet();
    for (final message in page.messages) {
      _messages[message.id] = message;
    }
    if (generation >= _accepted) {
      _page = page;
      _accepted = generation;
    }
    // A latest-page poll must not reopen exhausted history. A completely
    // disjoint latest page can indicate a gap after returning from offline.
    if (older ||
        wasEmpty ||
        (page.nextBefore != null &&
            page.messages.isNotEmpty &&
            page.messages.every((m) => !oldIds.contains(m.id)))) {
      _before = page.nextBefore;
    }
    if (!older &&
        !wasEmpty &&
        !bottom &&
        page.messages.any((m) => !oldIds.contains(m.id))) {
      _newMessages = true;
    }
    if (!older && (wasEmpty || bottom)) _jump();
  }

  Future<void> _load({bool older = false}) async {
    if (!_current || _loading || _older) return;
    final generation = ++_generation;
    final extent = _scroll.hasClients ? _scroll.position.maxScrollExtent : 0.0;
    final offset = _scroll.hasClients ? _scroll.offset : 0.0;
    setState(() {
      if (older) {
        _older = true;
      } else {
        _loading = true;
      }
    });
    try {
      final page = await widget.repository.loadConversation(
          bookingId: _page == null ? widget.bookingId : null,
          peerId: _page?.peerId ??
              (widget.bookingId == null ? widget.peerId : null),
          before: older ? _before : null,
          markRead: !older && _nearBottom);
      if (!_current) return;
      setState(() {
        _accept(page, generation, older: older);
        if (_request == null) _error = null;
      });
      if (older) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_current && _scroll.hasClients) {
            _scroll.jumpTo((offset + _scroll.position.maxScrollExtent - extent)
                .clamp(0, _scroll.position.maxScrollExtent));
          }
        });
      }
    } catch (error) {
      if (_current) {
        setState(() {
          if (error is BookingException && error.code == 'permission-denied') {
            _messages.clear();
            _page = null;
          }
          _error = _page == null
              ? 'Conversation unavailable. Confirm a session or refresh to retry.'
              : 'Could not refresh messages. Your conversation is retained.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          if (older) {
            _older = false;
          } else {
            _loading = false;
          }
        });
      }
    }
  }

  Future<void> _send() async {
    if (!_current ||
        _sending ||
        _page == null ||
        (_pending == null && !_page!.canSend)) {
      return;
    }
    final text = _pending ?? _text.text.trim();
    if (text.isEmpty || text.length > 500) return;
    final generation = ++_generation;
    _request ??= 'pair_${DateTime.now().microsecondsSinceEpoch}';
    _pending = text;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final page = await widget.repository.sendConversation(
          peerId: _page!.peerId, requestId: _request!, text: text);
      if (!_current) return;
      setState(() {
        _accept(page, generation);
        _text.clear();
        _request = null;
        _pending = null;
        _newMessages = false;
      });
      _jump();
    } catch (error) {
      if (!_current) return;
      final definite = error is BookingException &&
          [
            'failed-precondition',
            'permission-denied',
            'invalid-argument',
            'already-exists'
          ].contains(error.code);
      setState(() {
        _error = definite
            ? 'This message was not accepted. Your text is retained; refresh the conversation status.'
            : 'Send not confirmed. Retry safely sends the same message.';
        if (definite) {
          _request = null;
          _pending = null;
        }
        if (error is BookingException && error.code == 'permission-denied') {
          _messages.clear();
          _page = null;
        }
      });
      if (definite && _page != null) await _load();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _jump() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_current && _scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _leave(bool didPop) async {
    if (didPop || _sending) return;
    final leave = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
                title: const Text('Leave conversation?'),
                content: Text(_request == null
                    ? 'Your unsent text will be discarded.'
                    : 'The send outcome is unconfirmed. Leaving does not undo a message already saved.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('Stay')),
                  TextButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('Leave'))
                ]));
    if (leave == true && mounted) {
      setState(() => _leaving = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isCurrent()) {
      return const Scaffold(
          body: Center(child: Text('Messages unavailable for this session.')));
    }
    final page = _page;
    final rows = _messages.values.toList()
      ..sort((a, b) => a.sentAtMillis.compareTo(b.sentAtMillis) != 0
          ? a.sentAtMillis.compareTo(b.sentAtMillis)
          : (a.orderKey ?? a.id).compareTo(b.orderKey ?? b.id));
    final canType = page?.canSend == true;
    return PopScope(
        canPop: _leaving ||
            (!_sending && _text.text.trim().isEmpty && _request == null),
        onPopInvokedWithResult: (didPop, _) => _leave(didPop),
        child: Scaffold(
          appBar: AppBar(
              title: Text(page?.peerName ??
                  widget.initialName ??
                  (widget.ownRole == 'member' ? 'Coach' : 'Member')),
              actions: [
                IconButton(
                    tooltip: 'Refresh conversation',
                    onPressed: _loading ? null : _load,
                    icon: const Icon(Icons.refresh))
              ]),
          body: Column(children: [
            if (page?.context != null) PairSessionCard(session: page!.context!),
            if ((_loading && page == null) || _sending)
              const LinearProgressIndicator(),
            if (_error != null)
              Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Column(children: [
                    Text(_error!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                    if (_request != null)
                      TextButton(
                          onPressed: _sending ? null : _send,
                          child: const Text('Retry'))
                    else
                      TextButton(
                          onPressed: _loading ? null : _load,
                          child: const Text('Refresh'))
                  ])),
            if (_before != null)
              TextButton(
                  onPressed: _older ? null : () => _load(older: true),
                  child: Text(_older
                      ? 'Loading earlier messages…'
                      : 'Load earlier messages')),
            Expanded(
                child: rows.isEmpty
                    ? Center(
                        child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                                _loading
                                    ? 'Loading conversation…'
                                    : page == null
                                        ? 'Your conversation is unavailable.'
                                        : 'No messages yet. Discuss your session here.',
                                textAlign: TextAlign.center)))
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.all(16),
                        itemCount: rows.length,
                        itemBuilder: (context, i) {
                          final message = rows[i],
                              date = DateTime.fromMillisecondsSinceEpoch(
                                  rows[i].sentAtMillis);
                          final previous = i == 0
                              ? null
                              : DateTime.fromMillisecondsSinceEpoch(
                                  rows[i - 1].sentAtMillis);
                          final divider = previous == null ||
                              (previous.year != date.year ||
                                  previous.month != date.month ||
                                  previous.day != date.day);
                          final own = message.senderRole == widget.ownRole;
                          return Column(
                              crossAxisAlignment: own
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.start,
                              children: [
                                if (divider)
                                  Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                      child: Center(
                                          child: Text(_date(date),
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .labelSmall))),
                                if (message.sourceBookingId != null)
                                  Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Text(
                                          message.sourceBookingLabel == null
                                              ? 'Earlier booking conversation'
                                              : 'Session · ${message.sourceBookingLabel}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelSmall)),
                                if (message.senderRole == 'system')
                                  Center(
                                      child: Padding(
                                          padding: const EdgeInsets.all(12),
                                          child: Text(
                                              message.text.replaceFirst(
                                                  '[Automated Notice]: ', ''),
                                              textAlign: TextAlign.center)))
                                else
                                  Container(
                                      constraints: BoxConstraints(
                                          maxWidth:
                                              MediaQuery.sizeOf(context).width *
                                                  .8),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 10),
                                      decoration: BoxDecoration(
                                          color: own
                                              ? Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                              : Theme.of(context)
                                                  .colorScheme
                                                  .surface,
                                          border: own ? null : Border.all(color: AppColors.hairline),
                                          borderRadius: BorderRadius.circular(16)),
                                      child: SelectableText(message.text, style: memberCoachTypography(context).bodyMedium?.copyWith(color: own ? Theme.of(context).colorScheme.onPrimary : null))),
                                Padding(
                                    padding: const EdgeInsets.only(
                                        top: 4, bottom: 12),
                                    child: Text(_clock(date),
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall)),
                              ]);
                        })),
            if (_newMessages)
              TextButton.icon(
                  onPressed: () {
                    setState(() => _newMessages = false);
                    _jump();
                  },
                  icon: const Icon(Icons.arrow_downward),
                  label: const Text('New messages')),
            if (page != null && !canType)
              SafeArea(
                  top: false,
                  child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(page.reason, textAlign: TextAlign.center),
                        if (widget.ownRole == 'member' &&
                            widget.onBookAgain != null)
                          Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: FilledButton(
                                  onPressed: () =>
                                      widget.onBookAgain!(page.peerId),
                                  child: const Text('Book another session')))
                      ]))),
            if (canType)
              SafeArea(
                  top: false,
                  child: Container(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                      decoration: const BoxDecoration(
                          color: AppColors.surface,
                          border: Border(
                              top: BorderSide(color: AppColors.hairline))),
                      child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                                child: TextField(
                                    controller: _text,
                                    enabled: !_sending && _request == null,
                                    onChanged: (_) => setState(() {}),
                                    minLines: 1,
                                    maxLines: 4,
                                    maxLength: 500,
                                    textInputAction: TextInputAction.newline,
                                    decoration: const InputDecoration(
                                        hintText: 'Message…', counterText: ''),
                                    buildCounter: (_,
                                            {required currentLength,
                                            required isFocused,
                                            maxLength}) =>
                                        currentLength < 450
                                            ? null
                                            : Text('$currentLength / 500'))),
                            const SizedBox(width: 8),
                            IconButton.filled(
                                tooltip: 'Send message',
                                onPressed: _sending ||
                                        _request != null ||
                                        _text.text.trim().isEmpty
                                    ? null
                                    : _send,
                                icon: const Icon(Icons.arrow_upward_rounded))
                          ]))),
          ]),
        ));
  }
}

class PairSessionCard extends StatelessWidget {
  const PairSessionCard({super.key, required this.session});
  final PairSessionContext session;
  @override
  Widget build(BuildContext context) {
    final title = switch (session.kind) {
      'current' => 'Current session',
      'next' => 'Next session',
      _ => 'Recent session · Follow-up'
    };
    final date = session.dateLabel ??
        '${MaterialLocalizations.of(context).formatMediumDate(DateTime.fromMillisecondsSinceEpoch(session.startAtMillis, isUtc: true))} · ${_clock(DateTime.fromMillisecondsSinceEpoch(session.startAtMillis, isUtc: true))} UTC';
    return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Material(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: .07),
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => showModalBottomSheet<void>(
                    context: context,
                    showDragHandle: true,
                    isScrollControlled: true,
                    builder: (c) => SafeArea(
                        child: SingleChildScrollView(
                            child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('Session details',
                                          style: memberCoachTypography(c)
                                              .titleLarge),
                                      const SizedBox(height: 16),
                                      Text(date),
                                      const SizedBox(height: 8),
                                      Text(
                                          '1-on-1 Consultation · ${session.durationMinutes} min'),
                                      const SizedBox(height: 8),
                                      Text('Timezone: ${session.timeZone}'),
                                      if (session.followUpLabel != null)
                                        Padding(
                                            padding:
                                                const EdgeInsets.only(top: 8),
                                            child: Text(
                                                'Follow-up until ${session.followUpLabel}')),
                                      const SizedBox(height: 16),
                                      TextButton(
                                          onPressed: () => Navigator.pop(c),
                                          child: const Text(
                                              'Back to conversation'))
                                    ]))))),
                child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(children: [
                      Icon(
                          session.kind == 'follow_up'
                              ? Icons.chat_bubble_outline
                              : Icons.event_outlined,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(title,
                                style:
                                    memberCoachTypography(context).labelLarge),
                            Text(date,
                                style: memberCoachTypography(context)
                                    .bodySmall
                                    ?.copyWith(color: AppColors.inkSoft)),
                            if (session.followUpLabel != null)
                              Text('Until ${session.followUpLabel}',
                                  style: memberCoachTypography(context)
                                      .bodySmall
                                      ?.copyWith(color: AppColors.inkSoft))
                          ])),
                      const SizedBox(width: 8),
                      const Icon(Icons.chevron_right)
                    ])))));
  }
}

class PairChatInboxScreen extends StatefulWidget {
  const PairChatInboxScreen(
      {super.key,
      required this.repository,
      required this.isCurrent,
      required this.ownRole,
      this.onBookAgain});
  final PairConversationRepository repository;
  final bool Function() isCurrent;
  final String ownRole;
  final void Function(String)? onBookAgain;
  @override
  State<PairChatInboxScreen> createState() => _PairChatInboxScreenState();
}

class _PairChatInboxScreenState extends State<PairChatInboxScreen> {
  final _rows = <String, PairChatSummary>{};
  bool _busy = false;
  String? _cursor, _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool more = false}) async {
    if (_busy || !widget.isCurrent()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final page =
          await widget.repository.loadInbox(cursor: more ? _cursor : null);
      if (!mounted || !widget.isCurrent()) return;
      setState(() {
        if (!more) _rows.clear();
        for (final row in page.conversations) {
          _rows[row.peerId] = row;
        }
        _cursor = page.nextCursor;
      });
    } catch (_) {
      if (mounted && widget.isCurrent()) {
        setState(
            () => _error = 'Could not load conversations. Refresh to retry.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isCurrent()) {
      return const Scaffold(
          body: Center(child: Text('Messages unavailable for this session.')));
    }
    final rows = _rows.values.toList()
      ..sort(
          (a, b) => (b.updatedAtMillis ?? 0).compareTo(a.updatedAtMillis ?? 0));
    return Scaffold(
        appBar: AppBar(title: const Text('Messages'), actions: [
          IconButton(
              tooltip: 'Refresh conversations',
              onPressed: _busy ? null : _load,
              icon: const Icon(Icons.refresh))
        ]),
        body: Column(children: [
          if (_busy) const LinearProgressIndicator(),
          Expanded(
              child: ListView(padding: const EdgeInsets.all(16), children: [
            Text('One conversation for all your sessions',
                style: memberCoachTypography(context)
                    .bodySmall
                    ?.copyWith(color: AppColors.inkSoft)),
            const SizedBox(height: 16),
            if (_error != null) Text(_error!),
            if (!_busy && rows.isEmpty && _error == null)
              const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                      'No conversations yet. A confirmed session opens a conversation.',
                      textAlign: TextAlign.center)),
            for (final row in rows)
              Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Panel(
                      onTap: () async {
                        await Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                                builder: (_) => PairChatScreen(
                                    repository: widget.repository,
                                    isCurrent: widget.isCurrent,
                                    ownRole: widget.ownRole,
                                    peerId: row.peerId,
                                    initialName: row.name,
                                    onBookAgain: widget.onBookAgain)));
                        if (mounted) _load();
                      },
                      child: Row(children: [
                        CircleAvatar(
                            child: Text(row.name.isEmpty
                                ? '?'
                                : row.name.characters.first)),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(row.name,
                                  style: memberCoachTypography(context)
                                      .titleMedium),
                              const SizedBox(height: 4),
                              Text(
                                  row.preview ??
                                      'View your session conversation',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis)
                            ])),
                        if (row.unreadCount > 0)
                          Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Semantics(
                                  label: '${row.unreadCount} unread messages',
                                  child:
                                      Badge(label: Text('${row.unreadCount}'))))
                        else
                          const Icon(Icons.chevron_right)
                      ]))),
            if (_cursor != null)
              TextButton(
                  onPressed: _busy ? null : () => _load(more: true),
                  child: const Text('Load more conversations'))
          ]))
        ]));
  }
}
