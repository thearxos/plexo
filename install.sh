#!/usr/bin/env bash
# ArxOS community build of Plexo: install the audited release binary built by this repository's
# workflow. The release workflow pins VERSION, SHA256 and URL below; nothing else is downloaded,
# and a checksum mismatch is refused. As root it installs for everyone (/opt/plexo); as a user,
# for that user (~/.local). Run by `arx pub install plexo`.
set -euo pipefail
VERSION="1.0.0-rc.15"
SHA256="f0d703a42e29ea0f1f4e03d2d58f8feb3698c89a3cab0199f3564de48340b7a5"
URL="https://github.com/thearxos/plexo/releases/download/arxos-v1.0.0-rc.15/plexo-1.0.0-rc.15-arxos-x86_64.tar.zst"
[ "$VERSION" != "__VERSION__" ] || { echo "plexo: no audited build has been published yet" >&2; exit 1; }
if [ "$(id -u)" -eq 0 ]; then
  PREFIX=/opt/plexo; BIN=/usr/local/bin; APPS=/usr/share/applications
else
  PREFIX="$HOME/.local/opt/plexo"; BIN="$HOME/.local/bin"; APPS="$HOME/.local/share/applications"
fi
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
# Download with resume: a connection reset mid-transfer is common on slow or busy links and curl's
# --retry does not resume one, so retry and continue from where it stopped. A partial or altered
# file still fails the hash check below.
ok=0
for attempt in 1 2 3 4 5 6; do
  if curl -fsSL --proto '=https' --tlsv1.2 --retry 3 --retry-all-errors -C - -o "$tmp/plexo.tar.zst" "$URL"; then ok=1; break; fi
  echo "plexo: download interrupted (attempt $attempt), resuming" >&2; sleep $((attempt * 3))
done
[ "$ok" = 1 ] || { echo "plexo: download failed after 6 attempts" >&2; exit 1; }
echo "$SHA256  $tmp/plexo.tar.zst" | sha256sum -c - >/dev/null 2>&1 || { echo "plexo: checksum mismatch, refusing to install" >&2; exit 1; }
mkdir -p "$BIN" "$APPS"
rm -rf "$PREFIX.new"; mkdir -p "$PREFIX.new"
tar --zstd -xf "$tmp/plexo.tar.zst" -C "$PREFIX.new" --no-same-owner
# Chromium's sandbox helper must be root-owned and setuid to be used; without it, the app relies on
# user namespaces. Only a system-wide install can set it.
if [ "$(id -u)" -eq 0 ] && [ -f "$PREFIX.new/chrome-sandbox" ]; then
  chown root:root "$PREFIX.new/chrome-sandbox"; chmod 4755 "$PREFIX.new/chrome-sandbox"
fi
[ -d "$PREFIX" ] && { rm -rf "$PREFIX.old"; mv "$PREFIX" "$PREFIX.old"; }
mv "$PREFIX.new" "$PREFIX"; rm -rf "$PREFIX.old"
ln -sfn "$PREFIX/plexo" "$BIN/plexo"
icon="$PREFIX/resources/icon.png"; [ -f "$icon" ] || icon=download
cat > "$APPS/plexo.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=Plexo
Comment=Download manager (ArxOS community build)
Exec=$PREFIX/plexo %U
Icon=$icon
Categories=Network;FileTransfer;
MimeType=x-scheme-handler/magnet;application/x-bittorrent;
DESKTOP
echo "plexo $VERSION installed (ArxOS community build) in $PREFIX"
