import 'package:flutter/material.dart';
import 'package:gainpath/app/theme/theme.dart';
import 'package:gainpath/shared/shared.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath/features/chatbot/domain/repositories/chat_repository.dart';

/// AD-M6.2 — View Bookmarked Advice Library. Reads and mutates
/// `savedAdvice` directly (not a local copy) so a bookmark
/// added from the chat screen shows up here immediately, and removing
/// a tip here is reflected back in the chat bubbles' bookmark icons.
class SavedAdviceScreen extends StatefulWidget {
  const SavedAdviceScreen({super.key});

  @override
  State<SavedAdviceScreen> createState() => _SavedAdviceScreenState();
}

class _SavedAdviceScreenState extends State<SavedAdviceScreen> {
  @override
  Widget build(BuildContext context) {
    final items = context.read<ChatRepository>().savedAdvice;
    return Scaffold(
      appBar: AppBar(title: const Text('Saved advice')),
      body: items.isEmpty
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
                                  if (ok) {
                                    setState(() => context.read<ChatRepository>().savedAdvice.remove(t));
                                  }
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
