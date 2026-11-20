# GainPath announcements

Admin authors continue to write one canonical record per announcement under `orgs/{organizationId}/announcements`. Optimistic revision checks, server audit timestamps and readback remain in the existing repository. The optional audience, category and priority fields retain the legacy defaults of all branches, general and normal. The Rules verify target IDs against the same organization. The editor supports up to eight unique branches per record, bounded by Firestore Rules document lookups.

The existing Singapore `branchManagementCommand` provides the App Check enforced `memberAnnouncements` read. It checks verified Firebase identity and active membership, looks up the saved home branch (with the primary branch fallback) and validates the saved selected branch. Published records use the server clock with an inclusive start and exclusive end. Each record is evaluated once even when both branch preferences match. Older Member clients that query Firestore directly need the new reader when the Rules change is activated.

## Manual acceptance with fixtures

1. In **Governance → Announcements**, check the four totals, search by title and message, and switch between status and audience filters. A record targeting two locations should appear in either location filter.
2. Open **New announcement**. Change the title, message, category and priority. Select **Specific branches**, choose two active locations and check both names in the live preview. Check that publishing with zero targets fails. Save an incomplete draft and reopen it.
3. Publish a fixture immediately or schedule it for a future date in Malaysia Time. The start takes effect at midnight MYT for a chosen date and the selected end date is exclusive. Exercise View, Edit, Deactivate and Republish through the row menu.
4. In Member Home, use fixture accounts with matching and nonmatching preferences. Verify that selecting a different location changes the feed, Important appears first and Home displays at most two cards. Open **View all** and **Read more**. Before start, at the exclusive end and after deactivation, the record should be absent.

The PNGs in `build/announcements/screenshots` are Flutter widget captures using fictional branches and the repository's offline Barlow font. They document layout and interactions with fixture data. Production account, device and App Check behavior require signed-in acceptance.

## Release and recovery

Production runs the source-only update of `asia-southeast1/branchManagementCommand` on the existing Node.js 22 service. The deployment readback verifies the source SHA-256, runtime configuration, unchanged IAM and unauthenticated rejection. The published Firestore Rules were assembled from the deployed baseline and differ only in the announcement match. The exact production Rules overlay passed the announcement Firestore Emulator suite.

Private rollback artifacts and verification records are under `build/announcements`. Keep the scoped read protection in place when rolling back a client or function after publishing any branch-targeted record. The old Rules permitted organization-wide direct reads of published records.
