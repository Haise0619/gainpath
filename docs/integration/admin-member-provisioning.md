# Admin member provisioning

Admin Web opens Add Member from Users & Coaches → Members. The home branch comes from the existing organization branch directory. The operator supplies a name, email and optional phone number. Firebase Auth receives a server-generated random password and the member receives setup links to choose their own. The callable checks App Check, a verified Firebase Auth session and active canonical Admin authority in the requested organization.

The backend reserves a deterministic UID per organization and normalized email and creates the Auth identity disabled. It links the UID to `users/{uid}` and `orgs/{organizationId}/members/{uid}` in a Firestore transaction using the self-registration record builder. The selected branch is the initial home and primary branch and is the only initial branch assignment. The member’s selected branch preference is set separately by the existing app flow. The account is enabled after the canonical records exist. An incomplete setup can be recovered using the same email and exact form details. An email used by another account is rejected. Free is derived by the existing membership policy when there is no paid membership account.

The welcome email contains Firebase’s native password setup and email verification links. It includes HTML and text bodies. Emails are first recorded as pending, then shown as accepted by Brevo or failed. The directory displays Pending setup until the verified member signs in. Admins can retry delivery for pending accounts after a 60-second cooldown, with up to three attempts per hour per member and a global setup cap of 40 attempts within a rolling hour-bucket window. Firestore receipts and quota are server-only. Setup links are neither stored in Firestore nor returned to the Admin Web.

## Production configuration and release

- Firebase project `gainpath-0619`, region `asia-southeast1`, Node.js 22, callable `adminMemberProvisioning`.
- `BREVO_API_KEY` and `BREVO_SENDER_EMAIL` reuse the password recovery configuration. `PASSWORD_RECOVERY_LOGO_URL` can point to approved public GainPath artwork. The current production email displays the GainPath wordmark because no logo URL is configured.
- The existing runtime service account must have Firebase Auth user management and Firestore access and read access to the specific Brevo Secret. The callable uses the standard callable transport entry point with application-layer App Check and Admin checks.
- The private Admin bundle is served on `http://localhost:7359/`. The previous bundle is saved under `build/admin-member-provisioning/admin-before`. Keep the deployment archive and production verification alongside the scoped release artifacts. For a UI rollback, restore the previous private Admin bundle. Any backend rollback that changes production access should be scoped to this callable.

## Verification and acceptance

Run `npm run build` from `functions/`. Run the provisioning scenario against the Auth and Firestore emulators using project `demo-gainpath`, config `firebase/coach-availability.emulator.test.json`, and script `functions/emulator/admin-member-provisioning.cjs`. The scenario uses a mock mail provider and Firebase native action codes.

For acceptance, sign in as a canonical Admin, open Members, choose Add Member and enter a controlled recipient and an active Home Branch. Confirm the row appears under the matching branch filter with Free membership and Pending setup. Check the recipient inbox and spam folder. Open Set your password, use Verify your email if needed, sign in to the Member App and refresh the Admin list to confirm activation. Resend is available from the creation page and member row while setup remains pending. Perform a real account or mail test only with the owner’s authorization.

The production release can be verified without creating an account by checking the deployed region, runtime, source archive and request rejection without App Check. A real invitation and signed-in acceptance are separate checks.
