#!/usr/bin/env bash
# ArxOS community build of Plexo: install the audited release binary built by this repository's
# workflow. The release workflow pins VERSION, SHA256 and URL below; nothing else is downloaded,
# and a checksum mismatch is refused. As root it installs for everyone (/opt/plexo); as a user,
# for that user (~/.local). Run by `arx pub install plexo`.
set -euo pipefail
VERSION="__VERSION__"
SHA256="__SHA256__"
URL="__URL__"
[ "$VERSION" != "__VERSION__" ] || { echo "plexo: no audited build has been published yet" >&2; exit 1; }
if [ "$(id -u)" -eq 0 ]; then
  PREFIX=/opt/plexo; BIN=/usr/local/bin; APPS=/usr/share/applications
else
  PREFIX="$HOME/.local/opt/plexo"; BIN="$HOME/.local/bin"; APPS="$HOME/.local/share/applications"
fi
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
curl -fsSL --proto '=https' --tlsv1.2 --retry 3 -o "$tmp/plexo.tar.zst" "$URL"
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
