# Recommendations Overview redesign

## Feature inventory

The Admin shell opens `RiskLeaderboardScreen` for Recommendations → Overview and Delivery Issues. Its canonical panel uses the authorized recommendation repository for `admin.queue.list` and `admin.queue.detail`. The details request revalidates the currently scoped saved record. The separate legacy queue, Exercise Guidance Insights, AI Content Planner and AI Member Outreach keep their original paths and repository behavior. The canonical Overview has no export action.

The canonical records contain tutorial, coach and routine recommendations. They carry source, generation method, target label, saved title and summary, eligibility context, goals and factors, ranking comparisons, status and timestamps, and audit metadata. Automatic records can place a context-derived reason into `summary`. Outreach stores the final saved recommendation message in that same field. The former Message and reason block both displayed `summary`. The redesigned drawer shows that exact text once, alongside the separately saved selection evidence. The delivery receipt continues to mean the existing verified delivery state.

The interface uses the GainPath theme with a filterable index table, a fixed drawer header and progressive disclosure of technical fields. Design references are [Polaris Index Table](https://shopify.dev/docs/api/app-home/latest/patterns/compositions/index-table), [Ant Design Drawer](https://ant.design/components/drawer/) and [Progressive Disclosure](https://www.nngroup.com/articles/progressive-disclosure/).

## Feature parity

| Original feature or field | New UI location | Original data source | Behavior | Test evidence | Remaining limitation |
| --- | --- | --- | --- | --- | --- |
| Total, Delivered, Delivery issues | Primary summary cards | Loaded canonical records and original delivery classifier | Counts cover currently loaded authorized rows, regardless of filters. Delivered uses the persisted status. | Six-value fixture assertions, loaded scope checks | Counts describe loaded pages. |
| Tutorials, coaches, routines | Type count strip and distribution bar | Canonical `kind` | Raw counts retained. The bar is shown for a complete nonempty breakdown. | Three type counts and all three detail captures | Loaded-page scope applies. |
| Member and content search | Compact toolbar | Existing client text match across member name/ID and saved recommendation data | Existing matches and combined filters retained. Reset clears the current filters. | Combination, long member name and historic fixture tests | Search applies to loaded pages. |
| Type, source, delivery and date filters | Toolbar | Canonical kind, source, status, and MYT timestamps | Existing presets and date picker with inclusive final day remain. Redacted records retain withheld provenance. | Type, source, status, date and redacted history tests | Records with withheld source have no source attribution. |
| Sorting, refresh, pagination | Column headers, sort menu, Refresh and Load more | Existing comparer and repository cursor | Seven original comparisons remain, including Exercise / Goal in the menu. Same stable tie-break and cursor behavior. | MYT sort, custom date and cursor regression tests | Sorting is local to loaded records. |
| Member, target, title, exercise and objective | Table and drawer | Saved fields from authorized detail | Member name and target are displayed. Tooltip and the drawer expose full content for constrained rows. | Long-name and long-content tests | Missing names show an unavailable label. The authorized ID is in Technical Details. |
| Source and AI method | Separate lines in the same table cell and drawer sections | Saved source and `aiMethodLabel` | Automatic and Outreach remain separate from Gemini, Rules and Rule fallback. | Gated Outreach render and method fixture tests | Redacted source is shown as Withheld. |
| Saved recommendation message and reasoning | Message and Why this was recommended | Exact `summary`, distinct saved explanations and factors | Duplicate `summary` removed from the visual layout. Saved factors have readable labels. | Exact-message uniqueness, wrapping and raw-factor tests | Historical records can lack factor metadata. |
| Workout context, fitness goals and supporting evidence | Context, reason and Technical Details | Authorized parsed context and evidence | Available fields remain accessible with original factor and goal values in Technical Details. | Saved-context and technical expander tests | Historic records may lack some context. |
| Delivery status and timestamps | Status badge, drawer header and Delivery information | Original status rules, creation, delivery and expiry timestamps | Prepared, expired and withdrawn retain prior meanings. Delivery Issues links to its original module. | Status, expiry, date and review safety tests | The canonical detail exposes no separate provider failure payload or opened metric. |
| Ranking, technical metadata and audit identifiers | Ranking / Recommendation selection and Technical Details | Saved candidate count, first choices, changed choice, AI metadata, record and member identifiers | Privacy-sensitive detail still requires a verified scoped read. Model and raw technical data stay collapsed initially. | Ranking and authorization regression tests | Unavailable metadata remains identified as such. |
| Session, consent, historical and stale details | Existing guarded reads and retained-page lifecycle | Same canonical repository, consent checks and generation guards | A detail request from a page that becomes inactive cannot open a drawer over another module. | Revoked detail, foreign scope, stale response and focus restoration tests | Positive live record visual acceptance uses an authorized Admin session. |
| Related navigation | Overview shortcuts and contextual Delivery Issues link | Existing Admin shell callbacks | Routes to Planner, Outreach, Delivery Issues and Exercise Guidance Insights. | Existing Admin shell and module regression coverage | Original module authorization applies. |

## Files

- `apps/admin_web/lib/features/recommendation/presentation/admin/canonical_admin_recommendation_panel.dart`
- `apps/admin_web/lib/features/recommendation/presentation/admin/recommendation_details_drawer.dart`
- `apps/admin_web/lib/features/recommendation/presentation/admin/admin_recommendation_screens.dart`
- `apps/admin_web/lib/features/recommendation/presentation/admin/recommendation_monitor.dart`
- `apps/admin_web/lib/app/shells/admin_shell.dart`
- `apps/admin_web/test/recommendations_overview_redesign_test.dart`
- `apps/admin_web/test/module13_outreach_render_test.dart`

## Visual acceptance

The eight `fixture-*.png` files in `build/recommendations-overview-redesign/` are actual Flutter widget renderings using synthetic records. The screenshots show the overview, table, filter menu, coach, tutorial, routine and rule-fallback details, and the 1024 px responsive layout. The widget tests cover 1920×1080, 1536×864, 1440×900, 1366×768, 1280×720, 1024×768 and narrower phone widths. They also cover 200% text on a narrow display using the preserved regression suite. Manual browser acceptance with a live Admin session is separate.

For manual acceptance, open [the private Admin portal](http://localhost:7359/) and choose Recommendations → Overview. Compare the three totals and three type counts with the loaded rows, combine filters and toggle the date order. Open a saved record and check that Escape returns focus to View Details. Scroll the drawer to Technical Details and open Delivery Issues from an eligible issue. Review a narrower window at its standard zoom.

## Release verification

The deterministic pre-change suite passed 60 tests. The final affected suite passed 86 tests, including the responsive layouts, focus restoration, all six metrics and the actual Flutter renders. Scoped Dart analysis reported no issues.

The private Flutter Web Release was built from a clean copy of 472 source and configuration files using the existing lockfile. The served JavaScript SHA-256 matches e9ff3c585b035c0d093519e83b8550c076a0afd25aa1eecc86b6548c496894da. The route and index return the same Admin shell. The previous local release is available for rollback.

Generation, fallback, authorization and delivery continue through the existing backend contracts. Browser acceptance with live records remains pending an authorized Admin session.
