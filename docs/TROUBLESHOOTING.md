# ODS Troubleshooting

Painful-to-rediscover gotchas, captured as we find them. Each entry
is a short "symptom / cause / fix." If a gotcha becomes a recurring
source of bugs, promote it to an ADR or bake a fix into the code
with a test that protects it.

---

## Flutter

### Widget tests hang indefinitely on Windows

**Symptom.** Running `flutter test test/widget/` on Windows: the first
widget test either never completes or dies after ~10 minutes with a
`TimeoutException`. The rest of the suite (engine / models / parser /
integration) runs fine.

**Cause.** `flutter_tools` creates temporary directories under `%TEMP%`
and occasionally races with Windows Defender / OneDrive / other
watchers that delete files mid-run. The widget-test harness is more
sensitive to this than the unit-test harness. Moving the project off
OneDrive didn't fix it — the race is with Windows filesystem
observers more broadly.

**Fix.** Every widget test's `group()` is wrapped with
`skip: Platform.isWindows ? '...' : null`. Tests run cleanly on
Linux/macOS, which is also where CI should run them. See
[Frameworks/flutter-local/test/widget/page_renderer_test.dart](../Frameworks/flutter-local/test/widget/page_renderer_test.dart)
for the canonical skip pattern.

**Long-term.** Migrate to `package:integration_test` (uses a real
device/emulator, doesn't hit the temp-dir race) — tracked in
[TODO.md](../TODO.md).

### `Color` APIs expect floats, not ints

**Symptom.** Color comparisons silently wrong; WCAG contrast
calculations off by 255×.

**Cause.** Modern Flutter `Color` APIs use floats (`0.0`–`1.0`), not
the legacy `0`–`255` int range. Easy to mix up.

**Fix.** Always verify value ranges in contrast helpers and color
comparisons. The `alpha` property is deprecated — use
`(color.a * 255.0).round().clamp(0, 255)`. Already captured in
[CLAUDE.md](../CLAUDE.md); mentioned here for discoverability.

### Windows Documents is OneDrive-redirected

**Symptom.** `getApplicationDocumentsDirectory()` returns a path
under `C:\Users\<name>\OneDrive - ...\Documents\`, so app data
silently ends up syncing.

**Cause.** Windows-with-OneDrive redirects the user's Documents folder
as a default sync target. Flutter's `path_provider` honors the
system default.

**Fix.** ODS uses a bootstrap mechanism: a tiny `ods_bootstrap.json`
in `getApplicationSupportDirectory()` (which is under AppData, *not*
OneDrive-redirected) points to the user's chosen data folder. First
run prompts; Framework Settings offers a "Move Data" flow that
copies + retargets. See
[Frameworks/flutter-local/lib/engine/settings_store.dart](../Frameworks/flutter-local/lib/engine/settings_store.dart)
(`getOdsDirectory`, `readBootstrapStorageFolder`).

---

## React Web / PocketBase

### Sign-up silently fails on a fresh PocketBase install

**Symptom.** User clicks "Create Account" in the ODS login screen;
nothing happens. Sometimes a generic "Failed to create account" banner
appears; sometimes nothing visible at all.

**Cause.** PocketBase's `users` auth collection is *not* created by
`pocketbase superuser upsert`. On a fresh install there's literally
nowhere for a user record to land, so the SDK call 404s and the
LoginScreen shows a generic failure message (which also happens to be
the duplicate-email case — indistinguishable).

**Fix.** [AuthService.ensureUsersCollection](../Frameworks/react-web/src/engine/auth-service.ts)
creates the users collection on first admin login, wired into
[AdminGuard.tsx](../Frameworks/react-web/src/screens/AdminGuard.tsx).
Fresh PB → admin logs in once → users collection exists → any
subsequent sign-up works.

### Sign-up succeeds but the user stays on the sign-up form

**Symptom.** After clicking "Create Account" a valid user gets
created and auto-logged-in per server logs, but the UI stays on the
sign-up form.

**Cause.** `LoginScreen.handleSignUp` originally only cleared
`needsLogin`; the orthogonal `needsAdminSetup` gate stayed `true` when
no admin existed in the system. AppLoader rendered LoginScreen as
long as either gate was truthy.

**Fix.** Clear both gates after a successful self-registration. See
[LoginScreen.tsx:115-121](../Frameworks/react-web/src/screens/LoginScreen.tsx#L115-L121).

### Admin session disappears on every page navigation

**Symptom.** Log in via `/admin` → click a link → land back on the
login card. Repeat forever.

**Cause.** `src/lib/pocketbase.ts` used to call `pb.authStore.clear()`
at module load with a comment "Force fresh login on every page load —
no persisted sessions." That fired on every `goto()` (Playwright +
real users), nuking the session that had just been established.

**Fix.** Removed the `clear()` call. Sessions now persist until
explicit logout (standard PB SDK behavior). There's a TODO
([TODO.md](../TODO.md) → Next) for a regression test that pins
this.

### Guest page gets 401 when an app has local data sources

**Symptom.** Navigate to `/my-app` as an unauthenticated user.
Instead of rendering, the page fails with a 401 on a request like
`POST /api/collections`.

**Cause.** When a framework loads an app with `local://<table>` data
sources, it calls `DataService.ensureCollection` on first access.
Creating a PB collection requires superadmin auth — which a guest
doesn't have.

**Fix.** The seed helper used by E2E tests pre-creates data-source
collections as part of `seedApp`. In production, the admin loads the
app once (under admin auth) which provisions collections; subsequent
guest access only reads/writes records, which is permitted by the
collection's rules. See
[tests/e2e/helpers/app-seed.ts](../Frameworks/react-web/tests/e2e/helpers/app-seed.ts).

### Playwright widget tests "pass" but browser console is full of warnings

**Symptom.** Tests green, but the Playwright trace shows React
warnings / hydration mismatches / PB request errors.

**Cause.** Tests often assert positive conditions (element visible,
text present) without asserting the *absence* of console errors.

**Fix.** Critical-path tests already include
`expect(...).toHaveCount(0)` for error strings like `/failed to load|
something went wrong/`. Widen this on new tests when in doubt.

---

## Test infrastructure

### Batch 9 perf tests flake on slow machines

**Symptom.** 5 performance tests in
[Frameworks/flutter-local/test/integration/batch9_performance_test.dart](../Frameworks/flutter-local/test/integration/batch9_performance_test.dart)
occasionally exceed their budgets (e.g., "insert 10,000 rows under
150s" takes 160s).

**Cause.** Windows file I/O + sqflite is slower than Linux; the
budgets were calibrated on a different machine.

**Fix.** Documented in
[REGRESSION_LOG.md](../REGRESSION_LOG.md) as a known flake, not a
correctness regression. Long-term fix in [TODO.md](../TODO.md):
tag with `@slow` and move to a separate CI job.

### PocketBase binary isn't on the PATH in dev

**Symptom.** Trying to run PB manually for debugging: `pocketbase:
command not found`.

**Cause.** ODS doesn't require PB to be installed system-wide — the
E2E suite downloads its own binary to
`Frameworks/react-web/tests/e2e/.pb-e2e/`.

**Fix.** For manual PB runs, either: (a) reuse the E2E binary —
`./tests/e2e/.pb-e2e/pocketbase.exe serve` from `Frameworks/react-web/`,
or (b) download separately from <https://pocketbase.io/> to somewhere
convenient.

---

## Workflow

### `c:\Apps\One-does-simply` instead of the OneDrive path

**Symptom.** Old docs, bash history, or stashed scripts reference
`C:\Users\<user>\OneDrive - <Company>\Apps\One-does-simply\`.

**Cause.** The workspace migrated off OneDrive on 2026-04-18 to dodge
the file-system watcher race (see Flutter widget tests above). Paths
throughout the codebase (`publish.sh`, `.vscode/settings.json`,
`.claude/settings.json`) were updated.

**Fix.** Use `c:\Apps\One-does-simply\` everywhere. If something
references an old OneDrive path, it's either stale or a bug — grep
and fix.

---

## How to add a new entry

Each entry uses the same shape: **Symptom / Cause / Fix** plus an
optional "Long-term" note. Keep them terse — this is a lookup table,
not an essay. When an entry becomes load-bearing enough to deserve
real justification, promote it to an ADR.
