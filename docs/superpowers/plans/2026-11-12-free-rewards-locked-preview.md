# Free Rewards locked previews

The requested design is implemented within the existing Flutter Rewards dashboard. Known Free membership receives a visible, dimmed Mini Games preview and a real published-product reward-goal preview. The purple lock badge and concise upgrade CTA sit over the preview surface; underlying content cannot receive pointer, keyboard or accessibility actions. Existing Basic/Premium content and all backend authorization remain unchanged. Unknown/error membership retains verification/retry UI.

Use natural-height overlay content, 48px minimum actions and readable lavender/ivory surfaces. Keep game covers visible above the overlay. Avoid fixed overlay heights; 200% text must grow and scroll. Use one short fade respecting disabled animations; no repeating shimmer/pulse or new assets. Reward preview uses the saved or first available published item, never invented stock, price, balance or progress. Empty catalog has honest generic gift artwork. Free can browse existing locked shop cards; redemption stays server-gated.

1. Add red tests for inert previews, Free-only gate behavior, paid/unknown preservation and real reward preview data.
2. Add the shared locked-preview widget and scoped gate slot; integrate the arcade and goal card using existing assets/navigation.
3. Add actual renders at 320/360/390 and 100/150/200% text, inspect representative outputs and verify no overflow, hidden paid controls or animation leaks.
4. Run affected Rewards/check-in/goal/membership tests and analysis, review, commit only scoped files and record verified results. Preserve unrelated dirty Coach/home/workout files. No backend deployment or real account/data mutation is needed.
