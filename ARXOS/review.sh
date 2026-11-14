#!/usr/bin/env bash
# review.sh <upstream-clone> <audited-tag> <new-tag>: what changed upstream since the audited tag on
# the surfaces that decide whether Plexo can hurt the person running it. Prints every finding with
# its file and the added line; the last line is CLEAN (nothing risky changed) or REVIEW (a person
# must read the diff before this tag is built). Never runs upstream code.
set -uo pipefail
repo=$1 old=$2 new=$3
here=$(cd "$(dirname "$0")" && pwd)
git -C "$repo" rev-parse -q --verify "$old^{commit}" >/dev/null || { echo "unknown audited tag $old"; echo REVIEW; exit 0; }
git -C "$repo" rev-parse -q --verify "$new^{commit}" >/dev/null || { echo "unknown tag $new"; echo REVIEW; exit 0; }
echo "upstream $old -> $new: $(git -C "$repo" rev-list --count "$old..$new") commits, $(git -C "$repo" diff --name-only "$old" "$new" | wc -l) files"
risky=0
flag() { echo "  REVIEW  $1"; risky=1; }
# added lines in shipped code (main, preload, renderer, extension), not tests or docs
added=$(git -C "$repo" diff -U0 "$old" "$new" -- src extension electron-builder.yml electron.vite.config.ts | grep -E '^\+[^+]' || true)
check() { # name, pattern
  local hits; hits=$(printf '%s\n' "$added" | grep -E -- "$2" | head -5)
  [ -n "$hits" ] && { flag "$1:"; printf '%s\n' "$hits" | sed 's/^/          /'; }
}
check "shell and process execution" 'child_process|execFile|execSync|spawn\(|exec\('
check "native calls" 'koffi|ffi-napi|process\.dlopen'
check "self-update" 'autoUpdater|electron-updater|quitAndInstall'
check "window security" 'nodeIntegration|contextIsolation|sandbox:|webSecurity|allowRunningInsecureContent|webviewTag'
check "IPC surface" 'ipcMain\.|contextBridge|exposeInMainWorld'
check "local servers" 'createServer|\.listen\(|BRIDGE_PORTS'
check "opening external things" 'shell\.openExternal|shell\.openPath|openExternal'
check "credentials and storage" 'safeStorage|keytar|api_hash|apiHash'
# new network hosts in shipped code
hosts=$(printf '%s\n' "$added" | grep -Eo 'https?://[A-Za-z0-9.-]+(/[A-Za-z0-9._/-]*)?' | sed -E 's#https?://##' | sort -u)
while read -r h; do
  [ -z "$h" ] && continue
  grep -qxF -- "${h%%/*}" "$here/hosts.allow" || grep -qxF -- "$h" "$here/hosts.allow" || flag "new network host: $h"
done <<< "$hosts"
# dependencies, install scripts, upstream's own patches to dependencies
if ! git -C "$repo" diff --quiet "$old" "$new" -- package.json; then
  deps=$(git -C "$repo" diff -U0 "$old" "$new" -- package.json | grep -E '^[+-] +"' | grep -vE '"version"|"(lint|format|typecheck|test)' || true)
  [ -n "$deps" ] && { flag "package.json changed:"; printf '%s\n' "$deps" | head -20 | sed 's/^/          /'; }
fi
git -C "$repo" diff --quiet "$old" "$new" -- patches || flag "upstream's patches to its dependencies changed: $(git -C "$repo" diff --name-only "$old" "$new" -- patches | tr '\n' ' ')"
# a package under an accepted advisory changed: the exception must be read again
for pkg in $(grep -v '^#' "$here/audit-exceptions.txt" | awk 'NF {print $2}') webtorrent torrent-discovery bittorrent-tracker; do
  git -C "$repo" diff -U0 "$old" "$new" -- package-lock.json | grep -qE "\"node_modules/([^\"]*/)?$pkg\"" \
    && flag "a package in an accepted advisory's chain changed: $pkg (reread ARXOS/audit-exceptions.txt)"
done
[ "$risky" = 0 ] && echo CLEAN || echo REVIEW
