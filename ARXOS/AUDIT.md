# Plexo: ArxOS community build audit

Upstream: https://github.com/anmolkapil/plexo (MIT). Audited at `main` `2e44a2f3e9dbe92ccc5ae8778e4175f889d624d3`
(2026-11-06, version 1.0.0-rc.15). Electron 44.4.4, TypeScript, React renderer.

This fork builds Plexo for ArxOS. The application code is upstream's; this repository adds only the
ArxOS build (workflow, install script) and the small patches listed under "Changes in this build".
Every upstream change is reviewed and security-checked before a build is published.

## Scope of the review

| Surface | What was checked | Result |
|---|---|---|
| Network endpoints | every URL in main, preload, renderer, extension | only `getplexo.app` (update page); no telemetry, no analytics, no third-party endpoints |
| Self-update | `electron-updater` in `src/main/updater.ts` | downloads and installs builds from upstream releases; **removed in this build** (updates arrive only through the reviewed ArxOS build) |
| Window security | `webPreferences`, CSP, raw HTML, navigation | preload only on Electron's secure defaults (context isolation, sandbox, no Node in the page); CSP `script-src 'self'`; no `innerHTML`/`dangerouslySetInnerHTML`; no in-app links that navigate; drops cancelled window-wide. No `will-navigate` guard: added here as defence in depth |
| IPC | `src/main/ipc/handlers.ts` | typed handlers, ids rather than paths for existing downloads; no sender check: added here as defence in depth |
| Browser bridge | `src/main/browserBridge.ts` (HTTP on 127.0.0.1) | Host check blocks DNS rebinding; only extension origins; JSON-only POST forces a CORS preflight web pages fail; `/add` only offers, the user confirms. Low: an Origin-less `GET /ping` (an `<img>` on any page) reaches it, so a page can tell Plexo runs and flips the "keep running for the browser" setting |
| Native calls | `koffi` | Linux: `libc.so.6` for `SO_BINDTODEVICE` (binding a download to a chosen network). Windows: `kernel32.dll` sparse files. Nothing else |
| Shell | `child_process` | one fixed string (`gnome-control-center network || nm-connection-editor`), `execFile` for interface listing; no input reaches a shell |
| Secrets | Telegram session (`telegram` / gramjs) | the user's own api_id/api_hash, Saved Messages only; sealed with Electron `safeStorage` and refused when Linux offers only `basic_text` |
| Dependency patches | `patches/*.patch` | simple-peer: use the runtime's WebRTC instead of a native polyfill; webtorrent: route peers through the per-network binding and a second "twin" connection per peer. Benign |
| Torrents | `webtorrent` | peer traffic leaves the anonymity of Tor if run beside it: listed in AnonKit's close-apps set |

## Changes in this build

1. Self-update off: the updater is never started and its menu entry is gone; ArxOS delivers updates.
2. `will-navigate` denies every navigation away from the app page.
3. IPC handlers answer only the app's own page.
4. The browser bridge ignores a request without an extension Origin for anything that changes state
   (`/ping` still answers, without recording the extension as used).

## Not yet covered

- Full dependency tree: checked on every build by `npm audit` and Dependabot in this repository.
- Runtime behaviour: the release build is started in a throwaway ArxOS VM with all its traffic
  captured before it is published.

## Built tags

The first build is the release tag `v1.0.0-rc.15` (`28273bf`), 48 commits behind the audited `main`;
the four patches apply to both. From then on every new upstream release is compared with the last
audited tag by `ARXOS/review.sh`; anything on the surfaces above stops the build until a person
approves it (the workflow opens an issue with the report).
