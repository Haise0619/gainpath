# AI Chatbot Module Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the AI Chatbot module's decorative skeleton features into real ones (live bookmarking, computed progress audit), add the two missing pieces (FAQ prompt chips, an on-demand help entry point), and fix the button-asymmetry bug at its root in the shared `confirmSheet` widget rather than patching chatbot's own call site.

**Architecture:** New folder `lib/screens/member/chatbot/` (mirroring `membership/` and `progress/`), splitting the current single `chatbot_screens.dart` into `chatbot_screen.dart`, `saved_advice_screen.dart`, and `widgets/chatbot_about_sheet.dart`. `MockData.savedAdvice` becomes a genuinely mutable shared list — the first in-place-mutated `MockData` collection in the codebase — so bookmarking in chat and removing in the library both operate on the same instance. `lib/widgets/shared.dart`'s `confirmSheet` gets its button row fixed once, which automatically repairs all 13 screens that call it.

**Tech Stack:** Flutter/Dart, no new dependencies.

## Global Constraints

- Full design rationale and root-cause analysis lives in `docs/superpowers/specs/2026-08-16-chatbot-module-redesign-design.md` — read it if a task here is ambiguous.
- No backend — every screen reads from `MockData` (`lib/data/mock_data.dart`), the project's single source of truth.
- No widget/unit test suite exists in this project (same as every other module built this session). Verification per task is `flutter analyze` (must return to the current baseline: 9 pre-existing info-level lints, 0 errors, 0 warnings) plus a final `flutter build web --release`. Do not write fabricated widget tests to satisfy a generic TDD template.
- No `git commit` per task — this session's established convention is to leave work uncommitted until the user explicitly asks.
- No worktree/branch isolation — work happens directly on `main`, matching every other module built this session.
- Free-text chat input outside the 5 FAQ prompts keeps using the existing single generic canned reply — no NLP is added. This is intentional, not a gap.
- No changes to any of the other 12 files that call `confirmSheet` beyond what they automatically inherit from the shared-widget fix.

---

### Task 1: Extend mock_data.dart — mutable bookmarks, FAQ prompts, computed audit reply

**Files:**
- Modify: `lib/data/mock_data.dart` (Module 6 section, currently lines 428-440, plus the `ChatMessage` class definition around line 119-123)

**Interfaces:**
- Produces: `MockData.savedAdvice` as a mutable `List<String>` (same API surface, callers just gain the ability to `.add()`/`.remove()` on the live instance instead of copying it); `FaqPrompt(String question, String reply)` class; `MockData.faqPrompts` (`List<FaqPrompt>`, 5 entries); `MockData.buildProgressAuditReply()` (`static String`, no args) — consumed by Task 4.

- [ ] **Step 1: Add the `FaqPrompt` class next to `ChatMessage`**

Find the existing `ChatMessage` class (around line 119):
```dart
class ChatMessage {
  final String text;
  final bool fromUser;
  const ChatMessage(this.text, this.fromUser);
}
```
Insert directly after it:
```dart
class FaqPrompt {
  final String question;
  final String reply;
  const FaqPrompt(this.question, this.reply);
}
```

- [ ] **Step 2: Make `savedAdvice` mutable and add `faqPrompts`**

Replace the existing Module 6 block:
```dart
  static const savedAdvice = <String>[
    'Widen your stance slightly and push the knees out on the descent.',
    'Aim for a neutral spine on deadlifts, brace before the pull.',
    'Progressive overload works best in small weekly increments.',
  ];
```
with:
```dart
  static final savedAdvice = <String>[
    'Widen your stance slightly and push the knees out on the descent.',
    'Aim for a neutral spine on deadlifts, brace before the pull.',
    'Progressive overload works best in small weekly increments.',
  ];

  static const faqPrompts = <FaqPrompt>[
    FaqPrompt(
      'How do I fix my squat depth?',
      'Depth usually gets limited by tight ankles or hips rather than weak '
      'legs. Try elevating your heels slightly on a small plate and pause '
      'for two seconds at the bottom of each rep to build control there.\n\n'
      'This is general educational guidance, not medical advice.',
    ),
    FaqPrompt(
      'What should I eat after a workout?',
      'Aim for a mix of protein and carbs within a couple of hours of '
      'training — think grilled chicken with rice, or a protein shake with '
      'a banana. Protein supports muscle repair, carbs refill the energy '
      'you just used.\n\n'
      'This is general nutrition guidance, not a personalised meal plan.',
    ),
    FaqPrompt(
      'How many rest days do I need per week?',
      'Most people training 4-5 days a week do well with at least 1-2 full '
      'rest days, plus lighter days for any muscle group you hit hard. '
      'Watch for ongoing soreness or dropping performance — that is '
      'usually a sign to add another rest day.\n\n'
      'This is general guidance, not medical advice.',
    ),
    FaqPrompt(
      'Why do my knees hurt during lunges?',
      'Knee discomfort in lunges is often about tracking — check that your '
      'front knee stays roughly over your ankle rather than drifting '
      'inward or past your toes, and shorten your stride if it still '
      'bothers you.\n\n'
      'If the pain is sharp or persistent, stop and see a physiotherapist '
      'rather than pushing through it.',
    ),
    FaqPrompt(
      'How do I know when to increase my weights?',
      'A good rule of thumb: if you can complete all your sets and reps '
      'with good form and have 2+ reps left in the tank, add a small '
      'amount of weight next session. Keep increases small and consistent '
      'rather than jumping up all at once.\n\n'
      'This is general programming guidance, not personalised coaching.',
    ),
  ];
```
(`static const` → `static final` on `savedAdvice` is required — Dart forbids calling `.add()`/`.remove()` on a `const` list at runtime.)

- [ ] **Step 3: Add the computed progress-audit reply**

Directly after the `faqPrompts` block from Step 2, add:
```dart
  static String buildProgressAuditReply() {
    final formChange = postureTrend.last - postureTrend.first;
    final volumeChangePct =
        ((volumeTrend.last - volumeTrend.first) / volumeTrend.first * 100).round();
    final weakest = history.reduce((a, b) => a.accuracy < b.accuracy ? a : b);
    return 'Over the last ${postureTrend.length} sessions your average form score '
        'is up $formChange points, and lifting volume has grown about '
        '$volumeChangePct% over that span. ${weakest.exercise} is currently your '
        'lowest-scoring lift at ${weakest.accuracy}%, so that is the best place to '
        'focus next.\n\n'
        'This is general educational guidance, not medical advice.';
  }
```
This reads `postureTrend`, `volumeTrend`, and `history` — all already defined earlier in the same Module 5 block above Module 6, so no new imports are needed. (`history` is `List<WorkoutRecord>`, which already has `.exercise` (`String`) and `.accuracy` (`int`) fields.)

- [ ] **Step 4: Verify**

Run: `flutter analyze lib/data/mock_data.dart`
Expected: no new errors. (`savedAdvice` changing from `const` to `final` is source-compatible with every existing reader — nothing currently mutates it, so no other file breaks.)

---

### Task 2: Fix the shared `confirmSheet` button-symmetry bug

**Files:**
- Modify: `lib/widgets/shared.dart:388-437` (the `confirmSheet` function)

**Interfaces:**
- Consumes: nothing new.
- Produces: no signature change — `confirmSheet(context, {title, message, confirmLabel, destructive})` keeps returning `Future<bool>`. All 13 existing call sites (`profile_screens.dart`, `membership/membership_dashboard_screen.dart`, `gamification_screens.dart`, `workout_screens.dart`, `admin_settings_screens.dart`, `admin_shell.dart`, `coach_profile_screens.dart`, `admin_users_screens.dart`, `roster_screens.dart`, `availability_screens.dart`, `coach_booking_screens.dart`, `chatbot_screens.dart`/its Task-6 successor) need zero changes.

- [ ] **Step 1: Replace the stacked buttons with a symmetric side-by-side row**

Find this block (the last part of `confirmSheet`'s `Column`, currently lines 419-432):
```dart
          const SizedBox(height: 22),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: destructive
                ? FilledButton.styleFrom(backgroundColor: AppColors.danger)
                : null,
            child: Text(confirmLabel),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Not now'),
          ),
```
Replace it with:
```dart
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: destructive
                      ? FilledButton.styleFrom(backgroundColor: AppColors.danger)
                      : null,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(confirmLabel, maxLines: 1),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('Not now', maxLines: 1),
                  ),
                ),
              ),
            ],
          ),
```
Root cause (see spec for full detail): `FilledButton`/`TextButton` inside a `Column(crossAxisAlignment: start)` have no width constraint, so each sizes to its own text and left-aligns instead of matching the sheet's full-width title/body text above it. Wrapping both in `Expanded` inside a `Row` forces equal width; `FittedBox(fit: scaleDown)` is the same safety net already used in `lib/screens/member/membership/membership_dashboard_screen.dart`'s `_ActionButtonLabel`, applied here so a future long `confirmLabel` can't re-break symmetry.

- [ ] **Step 2: Verify**

Run: `flutter analyze lib/widgets/shared.dart`
Expected: no new errors.

Run: `flutter analyze`
Expected: back to the 9-issue baseline — this confirms none of the 13 call sites broke from the internal-only layout change.

---

### Task 3: Extract the About/disclaimer sheet into its own reusable widget

**Files:**
- Create: `lib/screens/member/chatbot/widgets/chatbot_about_sheet.dart`

**Interfaces:**
- Consumes: `MockData.faqPrompts` (Task 1), `AppColors` (`lib/app/theme.dart`).
- Produces: `showChatbotAboutSheet(BuildContext context, {bool dismissible = true})` (`Future<void>`) — consumed by Task 4 for both the forced first-open path and the on-demand Help button.

- [ ] **Step 1: Write the sheet**

```dart
import 'package:flutter/material.dart';
import '../../../../app/theme.dart';
import '../../../../data/mock_data.dart';

/// The AI coach's About/disclaimer sheet, shared between the forced
/// first-open path (`dismissible: false` — the member must tap "Got
/// it") and the on-demand Help (?) button, which reopens the same
/// content as a normal, dismissible sheet since nothing needs to be
/// acknowledged again on that path.
Future<void> showChatbotAboutSheet(BuildContext context, {bool dismissible = true}) {
  return showModalBottomSheet(
    context: context,
    isDismissible: dismissible,
    enableDrag: dismissible,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(ctx).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: AppColors.hairline,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const Icon(Icons.info_rounded, color: AppColors.primary, size: 28),
          const SizedBox(height: 14),
          Text('About this assistant', style: Theme.of(ctx).textTheme.titleLarge),
          const SizedBox(height: 10),
          Text(
            'The AI coach gives general fitness and technique guidance only. '
            'It cannot diagnose injuries, prescribe treatment, or replace advice '
            'from a doctor or physiotherapist.\n\n'
            'If something hurts, stop and speak to a qualified professional.',
            style: Theme.of(ctx).textTheme.bodyLarge,
          ),
          const SizedBox(height: 18),
          Text('Try asking about', style: Theme.of(ctx).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...MockData.faqPrompts.map(
            (p) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 7),
                    child: Icon(Icons.circle, size: 5, color: AppColors.inkSoft),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(p.question, style: Theme.of(ctx).textTheme.bodyMedium),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Got it'),
            ),
          ),
        ],
      ),
    ),
  );
}
```

- [ ] **Step 2: Verify**

Run: `flutter analyze lib/screens/member/chatbot/widgets/chatbot_about_sheet.dart`
Expected: no new errors.

---

### Task 4: Build the main chat screen with FAQ chips, real bookmarking, computed audit, and the Help button

**Files:**
- Create: `lib/screens/member/chatbot/chatbot_screen.dart`

**Interfaces:**
- Consumes: `MockData.chatSeed`, `MockData.faqPrompts`, `MockData.savedAdvice`, `MockData.buildProgressAuditReply()` (Task 1), `showChatbotAboutSheet` (Task 3), `confirmSheet`/`showToast`/`PageBody` (`lib/widgets/shared.dart`).
- Produces: `ChatbotScreen` — consumed by Task 6 (`home_screen.dart`) and by this same file's own `SavedAdviceScreen` navigation call.

- [ ] **Step 1: Write the screen**

```dart
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
```

- [ ] **Step 2: Verify**

Run: `flutter analyze lib/screens/member/chatbot/chatbot_screen.dart`
Expected: this will show unresolved-import errors for `saved_advice_screen.dart` until Task 5 exists — that's expected at this point; re-run after Task 5.

---

### Task 5: Build the Saved Advice library screen against the live shared list

**Files:**
- Create: `lib/screens/member/chatbot/saved_advice_screen.dart`

**Interfaces:**
- Consumes: `MockData.savedAdvice` (Task 1, mutable).
- Produces: `SavedAdviceScreen` — consumed by Task 4 (already written) and Task 6 (`home_screen.dart`).

- [ ] **Step 1: Write the screen**

```dart
import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../data/mock_data.dart';
import '../../../widgets/shared.dart';

/// AD-M6.2 — View Bookmarked Advice Library. Reads and mutates
/// `MockData.savedAdvice` directly (not a local copy) so a bookmark
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
    final items = MockData.savedAdvice;
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
                                    setState(() => MockData.savedAdvice.remove(t));
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
```

- [ ] **Step 2: Verify**

Run: `flutter analyze lib/screens/member/chatbot/`
Expected: no errors across all three new files now that the folder is complete (Tasks 3-5).

---

### Task 6: Wire home_screen.dart, delete the old file, full-project verification

**Files:**
- Modify: `lib/screens/member/home_screen.dart` (import line 9, no other changes — `ChatbotScreen`/`SavedAdviceScreen` class names and usages at lines 101 and 779 are unchanged)
- Delete: `lib/screens/member/chatbot_screens.dart`

**Interfaces:**
- Consumes: `ChatbotScreen` (Task 4), `SavedAdviceScreen` (Task 5).

- [ ] **Step 1: Confirm the blast radius before deleting anything**

Run:
```bash
grep -rn "chatbot_screens" lib/
```
Expected: only `lib/screens/member/chatbot_screens.dart` itself and the one `import 'chatbot_screens.dart';` line in `home_screen.dart` — already confirmed during brainstorming, re-checked here before the destructive step.

- [ ] **Step 2: Repoint home_screen.dart's import**

In `lib/screens/member/home_screen.dart`, replace:
```dart
import 'chatbot_screens.dart';
```
with:
```dart
import 'chatbot/chatbot_screen.dart';
import 'chatbot/saved_advice_screen.dart';
```
No other line changes — `ChatbotScreen` and `SavedAdviceScreen` keep their exact class names, so the existing usages at `_go(const ChatbotScreen())` (line 101) and `onSelect(const SavedAdviceScreen())` (line 779) need no edits.

- [ ] **Step 3: Delete the old monolith**

```bash
rm lib/screens/member/chatbot_screens.dart
```

- [ ] **Step 4: Full-project verification**

Run: `flutter analyze`
Expected: back to the exact baseline — 9 pre-existing info-level lints, 0 errors, 0 new issues from any of the 6 tasks in this plan.

Run: `flutter build web --release`
Expected: `√ Built build\web` with no compile errors.

---

## Self-review notes

- **Spec coverage:** every section of `docs/superpowers/specs/2026-08-16-chatbot-module-redesign-design.md` maps to a task — data model (Task 1), `confirmSheet` fix (Task 2), About sheet (Task 3), chat screen incl. FAQ chips/bookmark toggle/computed audit/help button (Task 4), Saved Advice screen (Task 5), file structure + wiring + verification (Task 6).
- **Type consistency checked:** `FaqPrompt(question, reply)` constructor shape matches between Task 1 (definition) and Tasks 3-4 (usage: `p.question`, `p.reply`). `MockData.buildProgressAuditReply()` returns `String`, used directly as a `ChatMessage` constructor arg in Task 4 without `const` (correct — it's a runtime call, not a compile-time constant, unlike the sibling `ChatMessage('Give me a summary...', true)` which stays `const`). `_Bubble`'s `onBookmark` parameter is fully replaced by `isBookmarked`/`onToggleBookmark` in the same file (Task 4) — no stale references to the old parameter name remain anywhere in this plan.
- **No placeholders:** all 5 FAQ replies, the full `confirmSheet` diff, and the full text of every new file are written out in complete, real form above.
