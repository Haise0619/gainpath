import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/chatbot.dart';
import '../../application/chat_bloc.dart';
import 'assistant_reply_view.dart';
import 'assistant_reply_view_model.dart';

/// Advice library shared with the active chat, with a standalone mock route.
class SavedAdviceScreen extends StatefulWidget {
  const SavedAdviceScreen({super.key, this.connected = false});
  final bool connected;

  @override
  State<SavedAdviceScreen> createState() => _SavedAdviceScreenState();
}

class _SavedAdviceScreenState extends State<SavedAdviceScreen> {
  @override
  Widget build(BuildContext context) {
    ChatBloc? bloc;
    try {
      bloc = context.read<ChatBloc>();
    } catch (_) {/* Standalone mock library. */}
    if (bloc != null) {
      return BlocBuilder<ChatBloc, ChatState>(
          builder: (context, state) =>
              _build(context, state.savedAdvice, bloc, state));
    }
    return _build(context, context.read<ChatRepository>().savedAdvice, null);
  }

  Widget _build(BuildContext context, List<String> items, ChatBloc? bloc,
      [ChatState? state]) {
    return Scaffold(
      appBar: AppBar(title: const Text('Saved advice')),
      body: Column(children: [
        if (state?.isLoading == true || state?.pendingAdvice.isNotEmpty == true)
          const LinearProgressIndicator(),
        if (state?.error != null)
          Padding(
              padding: const EdgeInsets.all(16),
              child: AssistantReplyView(
                  reply: AssistantReplyViewModel.error(state!.error!,
                      retryLabel: 'Retry',
                      title: 'Saved advice was not updated'),
                  onRetry: () => bloc!.add(const ChatRetried()))),
        Expanded(
            child: items.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.bookmark_border_rounded,
                              size: 40, color: AppColors.hairline),
                          const SizedBox(height: 14),
                          Text(
                              'Nothing saved yet. Bookmark a reply to keep it here.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium),
                        ],
                      ),
                    ),
                  )
                : PageBody(
                    children: items
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
                                      child: SelectableText(t,
                                          style: const TextStyle(
                                              fontSize: 14.5, height: 1.45)),
                                    ),
                                    IconButton(
                                      tooltip: 'Remove saved advice',
                                      icon: const Icon(
                                          Icons.delete_outline_rounded,
                                          size: 19),
                                      onPressed: bloc?.state.pendingAdvice
                                                  .contains(t) ==
                                              true
                                          ? null
                                          : () async {
                                              final ok = await confirmSheet(
                                                  context,
                                                  title: 'Remove this tip?',
                                                  message:
                                                      'It will be deleted from your saved library.',
                                                  confirmLabel: 'Remove',
                                                  destructive: true);
                                              if (ok) {
                                                if (!mounted) return;
                                                if (bloc != null) {
                                                  bloc.add(
                                                      AdviceBookmarkToggled(t));
                                                } else {
                                                  await context
                                                      .read<ChatRepository>()
                                                      .setBookmarked(t, false);
                                                  if (mounted) setState(() {});
                                                }
                                              }
                                            },
                                    ),
                                  ],
                                ),
                              ),
                            ))
                        .toList(),
                  )),
      ]),
    );
  }
}
