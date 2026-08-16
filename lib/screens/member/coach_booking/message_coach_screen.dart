import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../data/mock_data.dart';

/// A real per-booking message thread — not a one-shot "send and forget"
/// sheet. Reads and appends directly to `booking.messages`, the same
/// `Booking` instance stored in `MockData.memberBookings`, so the
/// conversation is still there if this screen is reopened. No simulated
/// auto-reply: a human coach isn't instant, and this module is
/// deliberately a different feature from the AI chatbot, so faking a
/// canned response here would blur that distinction.
class MessageCoachScreen extends StatefulWidget {
  final Booking booking;
  const MessageCoachScreen({super.key, required this.booking});

  @override
  State<MessageCoachScreen> createState() => _MessageCoachScreenState();
}

class _MessageCoachScreenState extends State<MessageCoachScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Coach? get _coach {
    for (final c in MockData.coaches) {
      if (c.id == widget.booking.coachId) return c;
    }
    return null;
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      widget.booking.messages.add(BookingMessage('Member', text, DateTime.now()));
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
    final coach = _coach;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.booking.coachName),
        titleSpacing: 0,
      ),
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
                          Text('Ask ${widget.booking.coachName} a question about this session.',
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
                    itemBuilder: (ctx, i) => _MessageBubble(message: messages[i]),
                  ),
          ),
          if (coach != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              color: AppColors.surfaceAlt,
              child: Row(
                children: [
                  const Icon(Icons.schedule_rounded, size: 13, color: AppColors.inkSoft),
                  const SizedBox(width: 6),
                  Text(coach.responseTime,
                      style: const TextStyle(fontSize: 11.5, color: AppColors.inkSoft)),
                ],
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
                      hintText: 'Ask a question about this session',
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _send,
                  icon: const Icon(Icons.arrow_upward_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final BookingMessage message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final fromMember = message.senderRole == 'Member';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: fromMember ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
            decoration: BoxDecoration(
              color: fromMember ? AppColors.primary : AppColors.surface,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(fromMember ? 16 : 4),
                bottomRight: Radius.circular(fromMember ? 4 : 16),
              ),
              border: fromMember ? null : Border.all(color: AppColors.hairline),
            ),
            child: Text(message.text,
                style: TextStyle(
                    fontSize: 14.5,
                    height: 1.45,
                    color: fromMember ? Colors.white : AppColors.ink)),
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
