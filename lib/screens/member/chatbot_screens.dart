import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../data/mock_data.dart';
import '../../widgets/shared.dart';

/// AD-M6.1 — Consult AI Fitness Coach.
class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final List<ChatMessage> _messages = [...MockData.chatSeed];
  bool _disclaimerShown = false;
  bool _thinking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showDisclaimer());
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _showDisclaimer() async {
    if (_disclaimerShown) return;
    _disclaimerShown = true;
    await showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, 20 + MediaQuery.of(ctx).padding.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_rounded, color: AppColors.primary, size: 28),
            const SizedBox(height: 14),
            Text('About this assistant',
                style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 10),
            Text(
              'The AI coach gives general fitness and technique guidance only. '
              'It cannot diagnose injuries, prescribe treatment, or replace advice '
              'from a doctor or physiotherapist.\n\n'
              'If something hurts, stop and speak to a qualified professional.',
              style: Theme.of(ctx).textTheme.bodyLarge,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('I understand'),
            ),
          ],
        ),
      ),
    );
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add(ChatMessage(text, true));
      _controller.clear();
      _thinking = true;
    });
    _jump();
    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      setState(() {
        _thinking = false;
        _messages.add(const ChatMessage(
            'Good question. Focus on controlling the eccentric, keep your core '
            'braced, and add weight only once the movement feels repeatable.\n\n'
            'This is general educational guidance, not medical advice.',
            false));
      });
      _jump();
    });
  }

  void _jump() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI coach'),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome_rounded),
            tooltip: 'Progress audit',
            onPressed: () {
              setState(() {
                _messages.add(const ChatMessage(
                    'Give me a summary of my progress.', true));
                _messages.add(const ChatMessage(
                    'Over the last 7 sessions your average form score rose from '
                    '64% to 84%, and weekly volume is up about 40%. Squat depth is '
                    'your strongest area. Romanian deadlifts are still your lowest '
                    'scoring lift at 71%, so that is the best place to focus next.',
                    false));
              });
              _jump();
            },
          ),
          IconButton(
            icon: const Icon(Icons.bookmark_border_rounded),
            tooltip: 'Saved advice',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SavedAdviceScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'Clear chat',
            onPressed: () async {
              final ok = await confirmSheet(context,
                  title: 'Clear this conversation?',
                  message:
                      'Messages disappear from this screen. Anything you bookmarked stays saved.',
                  confirmLabel: 'Clear',
                  destructive: true);
              if (ok) setState(() => _messages.clear());
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.chat_bubble_outline_rounded,
                              size: 40, color: AppColors.hairline),
                          const SizedBox(height: 14),
                          Text('Ask about form, programming, or nutrition.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    itemCount: _messages.length + (_thinking ? 1 : 0),
                    itemBuilder: (ctx, i) {
                      if (i == _messages.length) {
                        return const _Bubble(
                            text: 'Thinking...', fromUser: false);
                      }
                      final m = _messages[i];
                      return _Bubble(
                        text: m.text,
                        fromUser: m.fromUser,
                        onBookmark: m.fromUser
                            ? null
                            : () => showToast(context, 'Saved to your library.'),
                      );
                    },
                  ),
          ),
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
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: const InputDecoration(
                      hintText: 'Ask a question',
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 16, vertical: 13),
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

class _Bubble extends StatelessWidget {
  final String text;
  final bool fromUser;
  final VoidCallback? onBookmark;
  const _Bubble({required this.text, required this.fromUser, this.onBookmark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment:
            fromUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.80),
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
            decoration: BoxDecoration(
              color: fromUser ? AppColors.primary : AppColors.surface,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(fromUser ? 16 : 4),
                bottomRight: Radius.circular(fromUser ? 4 : 16),
              ),
              border: fromUser
                  ? null
                  : Border.all(color: AppColors.hairline),
            ),
            child: Text(text,
                style: TextStyle(
                    fontSize: 14.5,
                    height: 1.45,
                    color: fromUser ? Colors.white : AppColors.ink)),
          ),
          if (onBookmark != null)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4),
              child: Row(
                children: [
                  _tinyAction(Icons.bookmark_border_rounded, 'Save', onBookmark!),
                  const SizedBox(width: 12),
                  _tinyAction(Icons.thumb_up_outlined, 'Helpful',
                      () => showToast(context, 'Thanks for the feedback.')),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _tinyAction(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          children: [
            Icon(icon, size: 14, color: AppColors.inkSoft),
            const SizedBox(width: 4),
            Text(label,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.inkSoft)),
          ],
        ),
      ),
    );
  }
}

/// AD-M6.2 — View Bookmarked Advice Library.
class SavedAdviceScreen extends StatefulWidget {
  const SavedAdviceScreen({super.key});

  @override
  State<SavedAdviceScreen> createState() => _SavedAdviceScreenState();
}

class _SavedAdviceScreenState extends State<SavedAdviceScreen> {
  late final List<String> _items = [...MockData.savedAdvice];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Saved advice')),
      body: _items.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bookmark_border_rounded,
                        size: 40, color: AppColors.hairline),
                    const SizedBox(height: 14),
                    Text('Nothing saved yet. Bookmark a reply to keep it here.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
            )
          : PageBody(
              children: _items
                  .map((t) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Panel(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.bookmark_rounded,
                                  size: 18, color: AppColors.primary),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(t,
                                    style: const TextStyle(
                                        fontSize: 14.5, height: 1.45)),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded,
                                    size: 19),
                                onPressed: () async {
                                  final ok = await confirmSheet(context,
                                      title: 'Remove this tip?',
                                      message:
                                          'It will be deleted from your saved library.',
                                      confirmLabel: 'Remove',
                                      destructive: true);
                                  if (ok) setState(() => _items.remove(t));
                                },
                              ),
                            ],
                          ),
                        ),
                      ))
                  .toList(),
            ),
    );
  }
}
