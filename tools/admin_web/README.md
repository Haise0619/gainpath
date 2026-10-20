# Main GainPath Admin Web

Stable local Firebase entry: **http://localhost:7359/**. This builds and serves the existing `apps/admin_web` application with every completed Admin feature. Module/commit URLs redirect to the main entry; old artifacts may remain on disk for recovery but are not served as acceptance environments.

Build: `node tools/admin_web/build.cjs`

Serve: `node tools/admin_web/serve.cjs`

The build reads the existing approved private local App Check fixture. Set `GAINPATH_ADMIN_APP_CHECK_FIXTURE` to a different **already registered** private fixture path if needed; this tool never registers credentials. Build inputs/logs/artifacts stay under ignored `build/`. Do not publish this local debug build as production Hosting. Rebuild this same entry for subsequent modules instead of creating module routes or separate applications.

The server binds only loopback, sends no-store responses and exposes only the current built application. Its Flutter bootstrap does not register a service worker, preventing stale acceptance builds. Firebase project remains `gainpath-0619`; no Firebase deployment occurs in either command.
