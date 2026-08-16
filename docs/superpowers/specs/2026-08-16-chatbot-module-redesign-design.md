# AI Chatbot Module Redesign — Design Spec

**Date:** 2026-08-16
**Status:** Approved by user, ready for implementation planning.

## Goal

Redesign GainPath's AI Chatbot module (`lib/screens/member/chatbot_screens.dart`) so its existing skeleton features become genuinely functional, add the two pieces that were missing (FAQ prompts, an on-demand help entry point), and fix a real layout bug (asymmetric buttons in bottom sheets) at its root — the shared `confirmSheet` widget, not just the chatbot's own call sites.

This is a Flutter, frontend-only prototype (no backend). Every "make it real" requirement below means real within a single app session, backed by mutable in-memory `MockData` — not persisted across app restarts, consistent with how every other piece of state in this app already behaves.

## Background: what's broken today

Read directly from the current code (`lib/screens/member/chatbot_screens.dart`, `lib/widgets/shared.dart`, `lib/data/mock_data.dart`):

1. **Bookmark is decorative.** The Save action on an AI reply bubble (`_tinyAction(Icons.bookmark_border_rounded, 'Save', onBookmark!)`) only calls `showToast(context, 'Saved to your library.')`. Nothing is added anywhere. `SavedAdviceScreen` reads `MockData.savedAdvice`, a 3-item `static const` seed list, and never changes regardless of what gets "bookmarked" in chat.
2. **Progress audit is a fixed string.** The sparkle app-bar icon injects one hardcoded canned reply every time, regardless of what the mock data actually says.
3. **No FAQ / prompt-starters exist anywhere in the module.**
4. **No way to re-read the disclaimer.** `_showDisclaimer()` runs once via `WidgetsBinding.instance.addPostFrameCallback` on first build (`_disclaimerShown` guard) and there is no button to reopen it.
5. **Button asymmetry — root cause identified.** `lib/app/theme.dart`'s `filledButtonTheme` sets `minimumSize: const Size(0, 52)` — no forced width. Inside `confirmSheet` (`lib/widgets/shared.dart:388-437`), the `FilledButton` and `TextButton` sit in a `Column(crossAxisAlignment: CrossAxisAlignment.start)` with no width constraint of their own, so each button sizes to its own text and left-aligns — while the title/body `Text` widgets above them span the sheet's full width. That mismatch is the "not symmetry" the user is seeing. The same bug affects the chatbot's own single-button disclaimer sheet (`_showDisclaimer`), which additionally lacks the drag-handle treatment `confirmSheet` uses, making it visually inconsistent with every other bottom sheet in the app.
6. **Blast radius of the `confirmSheet` bug:** `grep confirmSheet(` matches 13 files — `profile_screens.dart`, `membership/membership_dashboard_screen.dart`, `gamification_screens.dart`, `workout_screens.dart`, `admin_settings_screens.dart`, `admin_shell.dart`, `coach_profile_screens.dart`, `admin_users_screens.dart`, `roster_screens.dart`, `availability_screens.dart`, `coach_booking_screens.dart`, `chatbot_screens.dart`, plus the definition itself in `shared.dart`. Fixing the shared widget fixes all 13 call sites at once with zero changes to any of them (the function signature — `title`, `message`, `confirmLabel`, `destructive` — does not change).
7. **Blast radius of the chatbot module rename/split:** `grep "chatbot_screens|ChatbotScreen|SavedAdviceScreen"` — only `home_screen.dart` references this module (imports `chatbot_screens.dart`, uses `ChatbotScreen` at line 101 and `SavedAdviceScreen` at line 779). No other file touches it.

## Decisions made during brainstorming

| Question | Decision |
|---|---|
| Progress audit | Make it real: compute the reply from `MockData.postureTrend`, `volumeTrend`, and the lowest-accuracy entry in `MockData.history`, mirroring the Progress dashboard's highlight-card pattern (computed, not asserted). |
| Bookmark persistence | Make it real: bookmarking a live AI reply actually adds it to the Saved Advice library; un-bookmarking removes it. |
| `confirmSheet` fix scope | Fix the shared widget in `lib/widgets/shared.dart` once, so all 13 call sites inherit the fix automatically. |
| FAQ + Help placement | FAQ: a row of tappable suggestion chips shown in the chat's empty state, above the input box, that send as real questions. Help: a `(?)` app-bar icon that reopens the About/disclaimer sheet on demand. |

## Data model changes (`lib/data/mock_data.dart`, Module 6 section)

1. `savedAdvice` changes from `static const <String>[...]` to `static final <String>[...]` — same 3 seed strings, but now a genuinely mutable list. Both the chat screen and `SavedAdviceScreen` read and mutate this *same instance* (`.add()` / `.remove()`, never reassigned), which is what makes bookmarking cross-screen without introducing any state-management dependency. This is the first place in the codebase where a `MockData` collection is mutated in place rather than only copied into a local `_items` list — every other module's "changes" (plan switch, auto-renew toggle, reward redemption) stay local-only and reset on navigation; this one is intentionally different because the feature explicitly requires cross-screen visibility within the session.

2. New class:
   ```dart
   class FaqPrompt {
     final String question;
     final String reply;
     const FaqPrompt(this.question, this.reply);
   }
   ```

3. New constant, 5 entries spanning form / nutrition / recovery / injury-caution / programming, each with its own tailored reply (not the one generic reply reused for everything), matching `chatSeed`'s existing tone and disclaimer convention:
   ```dart
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

4. Progress-audit reply becomes a **function**, not a stored string, e.g. `String buildProgressAuditReply()` living in `mock_data.dart` alongside the other Module 6 data (or as a static method on `MockData`) — computes from `postureTrend.first`/`.last`, `volumeTrend` percent change, and the lowest-`accuracy` entry in `history`. Free text typed by the user (outside the FAQ list) keeps using the existing single generic canned reply — no NLP is added; this is stated explicitly so it isn't mistaken for a scope gap later.

## `confirmSheet` fix (`lib/widgets/shared.dart`)

Keep the exact same function signature (`title`, `message`, `confirmLabel`, `destructive`) — zero changes needed at any of the 13 call sites. `confirmSheet` already has the drag-handle bar; that part is untouched. The fix is entirely in the button layout:
- Wrap the confirm/cancel button pair in a `Row` with `Expanded` around each, so both buttons render at equal width side-by-side — the same pattern already used to fix "Renew now"/"Change plan" in `lib/screens/member/membership/membership_dashboard_screen.dart`. Reuse that same `FittedBox(fit: BoxFit.scaleDown, maxLines: 1)` label-shrink wrapper unconditionally on both button labels, the same way that screen applies it to both of its buttons — it costs nothing and guarantees symmetry holds even if a future call site passes a longer `confirmLabel`.
- Confirm and "Not now" swap from stacked-and-both-shrink-wrapped-left (today's actual layout — neither button is full width, per the root cause above) to side-by-side equal-width — destructive styling (red background) stays on the confirm button when `destructive: true`, exactly as today.

## About/disclaimer sheet

Extract the current `_showDisclaimer()` body into a standalone, reusable function/widget (e.g. `showChatbotAboutSheet(BuildContext context)` in the new `widgets/chatbot_about_sheet.dart`) so it can be invoked both:
- automatically, once, on first entering the chat screen (same `_disclaimerShown`-style guard, `isDismissible: false` / `enableDrag: false` for that first forced view), and
- manually, any time, via the new `(?)` help icon (this second path should be dismissible/draggable like a normal sheet, since the user is choosing to reopen it, not being forced to acknowledge it).

Content changes:
- Add the same drag-handle bar `confirmSheet` uses, for visual consistency across every bottom sheet in the app.
- Add a short "Try asking about…" section listing the same topics as the FAQ chips (reusing `MockData.faqPrompts` question text), so the sheet also serves as first-run orientation.
- The "I understand" / "Got it" button becomes full-width (`SizedBox(width: double.infinity)`), fixing the same left-hugging bug described above.

## Chat screen (`chatbot_screen.dart`, formerly `chatbot_screens.dart`'s `ChatbotScreen`)

- **App bar actions**, left to right: `(?)` Help (opens the About sheet manually) → Progress audit (sparkle, unchanged icon/position, now computed reply) → Saved advice (bookmark, unchanged) → Clear chat (delete, unchanged, now gets the `confirmSheet` fix automatically).
- **Empty state**: keep the existing icon + "Ask about form, programming, or nutrition." text, add a `Wrap` of tappable chips below it built from `MockData.faqPrompts` (question text as chip label). Tapping a chip runs the same send flow as typing (`_messages.add(ChatMessage(question, true))` → "Thinking…" delay → reply), except the reply used is that specific `FaqPrompt.reply`, not the generic one.
- **Bookmark toggle on AI bubbles**: replace the current one-shot `onBookmark` callback with a live-computed `isBookmarked = MockData.savedAdvice.contains(m.text)` check done in the parent's `build()` (so it reacts correctly if the same text is un-bookmarked from `SavedAdviceScreen` and the user navigates back). Tapping toggles: `MockData.savedAdvice.add(m.text)` or `.remove(m.text)`, then local `setState`. Icon/label swap: `bookmark_rounded` + "Saved" when true, `bookmark_border_rounded` + "Save" when false. The "Helpful" thumbs-up action is unchanged (toast-only; it was never part of this module's requested feature list).
- **Progress audit button**: injected reply text now comes from `MockData.buildProgressAuditReply()` (or equivalent) instead of the fixed string currently inline in the `onPressed` handler.

## Saved Advice screen (`saved_advice_screen.dart`, formerly `SavedAdviceScreen`)

Functionally almost unchanged — it already read from `MockData.savedAdvice` correctly. The only required change is that its local `_items` copy (`late final List<String> _items = [...MockData.savedAdvice]`) must be replaced with direct reads of `MockData.savedAdvice` itself (or refreshed on each build), otherwise a bookmark added from the chat screen after this screen was already constructed once wouldn't show until an app restart. Its own remove-tip flow already correctly calls `MockData.savedAdvice`-adjacent local list removal — needs to become `MockData.savedAdvice.remove(t)` directly so removal here is also reflected back in the chat bubbles' bookmark icons.

## File structure

New folder `lib/screens/member/chatbot/`, matching the `membership/` and `progress/` precedent already established this session:
- `chatbot_screen.dart` — `ChatbotScreen` + private `_Bubble`, FAQ chip row.
- `saved_advice_screen.dart` — `SavedAdviceScreen`.
- `widgets/chatbot_about_sheet.dart` — `showChatbotAboutSheet()`.

Delete `lib/screens/member/chatbot_screens.dart`. Update `lib/screens/member/home_screen.dart`'s one import line and its two usages (`ChatbotScreen`, `SavedAdviceScreen` — class names are unchanged, so only the import path moves).

## Explicitly out of scope

- No real NLP/AI. Free-text questions outside the 5 FAQ prompts keep receiving the existing single generic reply, exactly as today.
- No changes to any of the other 12 files that call `confirmSheet` — they inherit the fix automatically, nothing in them is touched.
- No persistence of bookmarks or chat history across app restarts — consistent with every other piece of "state" in this prototype (plan switches, auto-renew toggle, reward redemption all already reset on relaunch).
- No changes to the "Helpful" thumbs-up feedback action beyond what already exists (toast-only) — it wasn't part of the requested feature list.

## Verification plan

Same standard used for every module this session: `flutter analyze` must return to the current baseline (9 pre-existing info-level lints, 0 errors, 0 new issues) after each task, and `flutter build web --release` must succeed at the end. No browser-based visual verification is available for Member-role screens this session (the web build target routes straight to the Admin console; Member/Coach screens are Windows-desktop/mobile-only), so this stays code-review-verified and is disclosed as such, not claimed as visually confirmed.
