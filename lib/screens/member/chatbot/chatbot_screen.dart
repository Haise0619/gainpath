import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../data/mock_data.dart';
import '../../../widgets/shared.dart';
import 'saved_advice_screen.dart';
import 'widgets/chatbot_about_sheet.dart';

/// AD-M6.1 — Consult AI Fitness Coach.
class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  static const _genericReply =
      'Good question. Focus on controlling the eccentric, keep your core '
      'braced, and add weight only once the movement feels repeatable.\n\n'
      'This is general educational guidance, not medical advice.';

  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final List<ChatMessage> _messages = [...MockData.chatSeed];
  bool _disclaimerShown = false;
  bool _thinking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showFirstOpenDisclaimer());
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _showFirstOpenDisclaimer() async {
    if (_disclaimerShown) return;
    _disclaimerShown = true;
    await showChatbotAboutSheet(context, dismissible: false);
  }

  void _sendMessage(String userText, String reply) {
    setState(() {
      _messages.add(ChatMessage(userText, true));
      _thinking = true;
    });
    _jump();
    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      setState(() {
        _thinking = false;
        _messages.add(ChatMessage(reply, false));
      });
      _jump();
    });
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    _sendMessage(text, _genericReply);
  }

  void _sendPrompt(FaqPrompt prompt) {
    _sendMessage(prompt.question, prompt.reply);
  }

  void _toggleBookmark(String text) {
    setState(() {
      if (MockData.savedAdvice.contains(text)) {
        MockData.savedAdvice.remove(text);
      } else {
        MockData.savedAdvice.add(text);
      }
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
            icon: const Icon(Icons.help_outline_rounded),
            tooltip: 'About this assistant',
            onPressed: () => showChatbotAboutSheet(context),
          ),
          IconButton(
            icon: const Icon(Icons.auto_awesome_rounded),
            tooltip: 'Progress audit',
            onPressed: () {
              setState(() {
                _messages.add(const ChatMessage(
                    'Give me a summary of my progress.', true));
                _messages.add(ChatMessage(MockData.buildProgressAuditReply(), false));
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
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.chat_bubble_outline_rounded,
                              size: 40, color: AppColors.hairline),
                          const SizedBox(height: 14),
                          Text('Ask about form, programming, or nutrition.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium),
                          const SizedBox(height: 20),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: MockData.faqPrompts
                                .map((p) => ActionChip(
                                      label: Text(p.question),
                                      backgroundColor: AppColors.primaryTint,
                                      side: BorderSide.none,
                                      labelStyle: const TextStyle(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12.5),
                                      onPressed: () => _sendPrompt(p),
                                    ))
                                .toList(),
                          ),
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
                      final isBookmarked =
                          !m.fromUser && MockData.savedAdvice.contains(m.text);
                      return _Bubble(
                        text: m.text,
                        fromUser: m.fromUser,
                        isBookmarked: isBookmarked,
                        onToggleBookmark:
                            m.fromUser ? null : () => _toggleBookmark(m.text),
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
  final bool isBookmarked;
  final VoidCallback? onToggleBookmark;
  const _Bubble({
    required this.text,
    required this.fromUser,
    this.isBookmarked = false,
    this.onToggleBookmark,
  });

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
          if (onToggleBookmark != null)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4),
              child: Row(
                children: [
                  _tinyAction(
                    isBookmarked
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    isBookmarked ? 'Saved' : 'Save',
                    onToggleBookmark!,
                  ),
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
