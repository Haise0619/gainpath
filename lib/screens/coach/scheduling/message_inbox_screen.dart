import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../data/mock_data.dart';
import '../../../widgets/shared.dart';

/// AD-M9.4 — Respond to Member Messages. Reads `MockData.coachRoster`,
/// which is now a filtered view over the same `allBookings` list members
/// read from — so a message a member sends from `MessageCoachScreen`
/// shows up here for real, and a reply sent here shows up back in the
/// member's thread. Neither side used to be able to reach the other.
class CoachMessageInboxScreen extends StatefulWidget {
  const CoachMessageInboxScreen({super.key});

  @override
  State<CoachMessageInboxScreen> createState() => _CoachMessageInboxScreenState();
}

class _CoachMessageInboxScreenState extends State<CoachMessageInboxScreen> {
  @override
  Widget build(BuildContext context) {
    final conversations = MockData.coachRoster
        .where((b) =>
            b.messages.isNotEmpty || b.status == 'Confirmed' || b.status == 'Pending')
        .toList()
      ..sort((a, b) {
        final aNeedsReply = a.messages.isNotEmpty && a.messages.last.senderRole == 'Member';
        final bNeedsReply = b.messages.isNotEmpty && b.messages.last.senderRole == 'Member';
        if (aNeedsReply != bNeedsReply) return aNeedsReply ? -1 : 1;
        final aTime = a.messages.isNotEmpty ? a.messages.last.sentAt : a.start;
        final bTime = b.messages.isNotEmpty ? b.messages.last.sentAt : b.start;
        return bTime.compareTo(aTime);
      });

    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: conversations.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.forum_outlined, size: 40, color: AppColors.hairline),
                    const SizedBox(height: 14),
                    Text('No active client conversations yet.',
                        textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
            )
          : PageBody(
              children: conversations
                  .map((b) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _ConversationTile(
                          booking: b,
                          onTap: () async {
                            await Navigator.push(context,
                                MaterialPageRoute(builder: (_) => CoachMessageThreadScreen(booking: b)));
                            if (mounted) setState(() {});
                          },
                        ),
                      ))
                  .toList(),
            ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final Booking booking;
  final VoidCallback onTap;
  const _ConversationTile({required this.booking, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasMessages = booking.messages.isNotEmpty;
    final needsReply = hasMessages && booking.messages.last.senderRole == 'Member';
    final preview = hasMessages
        ? booking.messages.last.text
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
                booking.memberName.split(' ').map((w) => w[0]).take(2).join(),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.primary),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(booking.memberName, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  preview,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: needsReply ? AppColors.ink : AppColors.inkSoft,
                      fontWeight: needsReply ? FontWeight.w600 : FontWeight.w400),
                ),
              ],
            ),
          ),
          if (needsReply)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(color: AppColors.dangerTint, borderRadius: BorderRadius.circular(999)),
              child: const Text('Reply needed',
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.danger)),
            )
          else
            const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: AppColors.inkSoft),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${d.day} ${months[d.month - 1]}';
  }
}

/// The coach's side of a per-booking thread — the mirror of the member's
/// `MessageCoachScreen`, writing to the exact same `booking.messages`
/// list. 'Coach' messages render as "you" (right-aligned, primary color).
class CoachMessageThreadScreen extends StatefulWidget {
  final Booking booking;
  const CoachMessageThreadScreen({super.key, required this.booking});

  @override
  State<CoachMessageThreadScreen> createState() => _CoachMessageThreadScreenState();
}

class _CoachMessageThreadScreenState extends State<CoachMessageThreadScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      widget.booking.messages.add(BookingMessage('Coach', text, DateTime.now()));
      _controller.clear();
    });
    _jump();
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
    final messages = widget.booking.messages;
    return Scaffold(
      appBar: AppBar(title: Text(widget.booking.memberName)),
      body: Column(
        children: [
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
                          Text('No messages yet with ${widget.booking.memberName}.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    itemCount: messages.length,
                    itemBuilder: (ctx, i) => _Bubble(message: messages[i]),
                  ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(12, 10, 12, 10 + MediaQuery.of(context).padding.bottom),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.hairline)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    textInputAction: TextInputAction.send,
                    maxLength: 500,
                    buildCounter: (context,
                            {required currentLength, required isFocused, maxLength}) =>
                        null,
                    onSubmitted: (_) => _send(),
                    decoration: const InputDecoration(
                      hintText: 'Reply to your client',
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(onPressed: _send, icon: const Icon(Icons.arrow_upward_rounded)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final BookingMessage message;
  const _Bubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final fromCoach = message.senderRole == 'Coach';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: fromCoach ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
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
                    fontSize: 14.5, height: 1.45, color: fromCoach ? Colors.white : AppColors.ink)),
          ),
          const SizedBox(height: 3),
          Text(_time(message.sentAt), style: const TextStyle(fontSize: 10.5, color: AppColors.inkSoft)),
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
