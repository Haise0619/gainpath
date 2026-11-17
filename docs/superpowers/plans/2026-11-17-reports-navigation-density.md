# Reports navigation and density implementation plan

Goal: apply the owner's screenshot-based specification using existing Flutter components only.
Architecture: one retained ReportsScreen with a public category controller; the existing Sidebar renders five report destinations. Platform route information synchronizes report category URLs with browser history. Keep reporting gateways, auth, queries, lazy sections and 30-second freshness unchanged.

- [x] Add regression tests for sidebar category selection, direct report routes, retained page state and compact page chrome.
- [x] Implement Reports submenu, category URLs, breadcrumbs and retained single screen. Keep the existing independently scrolling sidebar and fixed profile.
- [x] Replace hero/tabs with a category heading; compact the toolbar and collapse explanations. Balance KPI rows, shorten chart date labels and expose human exercise/group labels with full technical details available.
- [x] Verify 1440/1024/768 widths and 200% text, run reporting/shell tests, analysis and release build; capture actual Flutter Web renders with data provenance identified.
- [x] Review the scoped diff and commit frontend changes only. No Functions deployment, Firestore data or Rules changes.

Review focus: browser Back/Forward, direct URL after authentication, unchanged cache/request counts, overflow at large text and fixed sidebar profile when submenu scrolls.
