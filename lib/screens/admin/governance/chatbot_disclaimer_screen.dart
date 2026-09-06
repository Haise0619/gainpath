import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../widgets/shared.dart';

/// AD-M11.4 — Update the AI Chatbot Disclaimer (`ChatbotDisclaimerConfig`).
/// Distinct from the compliance/privacy document managed under System
/// Settings: this is only the text shown before a member's first AI
/// coach message each day. Paired with a live member-facing preview and
/// version history on the right, instead of a lone text field floating
/// on an otherwise empty page.
class ChatbotDisclaimerScreen extends StatefulWidget {
  const ChatbotDisclaimerScreen({super.key});

  @override
  State<ChatbotDisclaimerScreen> createState() => _ChatbotDisclaimerScreenState();
}

class _ChatbotDisclaimerScreenState extends State<ChatbotDisclaimerScreen> {
  static const _history = [
    ['v3', 'Current — added "stop and speak to a professional" guidance'],
    ['v2', 'Clarified this is not medical advice'],
    ['v1', 'Initial disclaimer at chatbot launch'],
  ];

  late final _controller = TextEditingController(
    text: 'The AI coach gives general fitness and technique guidance only. It cannot diagnose '
        'injuries, prescribe treatment, or replace advice from a doctor or physiotherapist.\n\n'
        'If something hurts, stop and speak to a qualified professional.',
  )..addListener(_repaint);

  void _repaint() => setState(() {});

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _publish() {
    if (_controller.text.trim().isEmpty) {
      showToast(context, 'Disclaimer text cannot be empty.');
      return;
    }
    showToast(context, 'Disclaimer updated to v4.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 40),
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
            const SizedBox(height: 20),
            LayoutBuilder(builder: (context, constraints) {
              final wide = constraints.maxWidth >= 900;
              final form = _form(context);
              final rail = _rail(context);
              return wide
                  ? IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 3, child: form),
                          const SizedBox(width: 20),
                          Expanded(flex: 2, child: rail),
                        ],
                      ),
                    )
                  : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [form, const SizedBox(height: 20), rail]);
            }),
          ],
        ),
      ),
    );
  }

  Widget _form(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Eyebrow('Disclaimer text'),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _controller,
                maxLines: 8,
                decoration: const InputDecoration(hintText: 'What members see before their first message'),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Text('${_controller.text.length} characters',
                    style: const TextStyle(fontSize: 11.5, color: AppColors.inkSoft)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        FilledButton(onPressed: _publish, child: const Text('Publish new version')),
      ],
    );
  }

  Widget _rail(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Eyebrow('Member preview'),
        Panel(
          background: AppColors.surfaceAlt,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(gradient: AppColors.heroGradient, shape: BoxShape.circle),
                    child: const Icon(Icons.smart_toy_rounded, size: 15, color: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  Text('AI coach', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 13)),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.hairline),
                ),
                child: Text(
                  _controller.text.isEmpty ? 'Nothing to preview yet.' : _controller.text,
                  style: const TextStyle(fontSize: 13, height: 1.45),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Panel(
          background: AppColors.primaryTint,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Publishing shows this to every member again on their next visit, even if they dismissed an earlier version today.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const Eyebrow('Version history'),
        Panel(
          padding: EdgeInsets.zero,
          child: Column(
            children: List.generate(_history.length, (i) {
              final h = _history[i];
              return Column(
                children: [
                  if (i > 0) const Divider(height: 1, indent: 16),
                  ListTile(
                    dense: true,
                    leading: statusPill(h[0]),
                    title: Text(h[1], style: const TextStyle(fontSize: 12.5)),
                  ),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }
}
