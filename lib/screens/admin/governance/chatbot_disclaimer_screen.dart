import 'package:flutter/material.dart';
import '../../../widgets/shared.dart';

/// AD-M11.4 — Update the AI Chatbot Disclaimer (`ChatbotDisclaimerConfig`).
/// Distinct from the compliance/privacy document managed under System
/// Settings: this is only the text shown before a member's first AI
/// coach message each day.
class ChatbotDisclaimerScreen extends StatefulWidget {
  const ChatbotDisclaimerScreen({super.key});

  @override
  State<ChatbotDisclaimerScreen> createState() => _ChatbotDisclaimerScreenState();
}

class _ChatbotDisclaimerScreenState extends State<ChatbotDisclaimerScreen> {
  late final _controller = TextEditingController(
    text: 'The AI coach gives general fitness and technique guidance only. It cannot diagnose '
        'injuries, prescribe treatment, or replace advice from a doctor or physiotherapist.\n\n'
        'If something hurts, stop and speak to a qualified professional.',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 40),
        child: SizedBox(
          width: 640,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Shown once per day before a member sends their first message.',
                        style: Theme.of(context).textTheme.bodyLarge),
                  ),
                  statusPill('v3 live'),
                ],
              ),
              const SizedBox(height: 18),
              const Eyebrow('Disclaimer text'),
              TextField(
                controller: _controller,
                maxLines: 8,
                decoration: const InputDecoration(hintText: 'What members see before their first message'),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => showToast(context, 'Disclaimer updated to v4.'),
                child: const Text('Publish new version'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
