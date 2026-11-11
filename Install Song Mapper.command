#!/bin/bash
# Compatible with Apple's Bash 3.2. No Python, Homebrew, or administrator access.
set -euo pipefail
SOURCE_DIR=$(cd "$(dirname "$0")" && pwd -P)
APP=/Applications/REAPER.app
RESOURCE="$HOME/Library/Application Support/REAPER"
TARGET_ARCH=$(uname -m)
DRY_RUN=0
LAUNCH=1
WORK=
LOCK=
BACKUP=
DEST=
COMMITTED=0
OLD_MOVED=0
NEW_MOVED=0
NEW_NATIVE=
NEW_SHIM=
fail() { echo "Installation stopped: $*" >&2; exit 1; }
cleanup() {
  result=$?
  if [ "$COMMITTED" = 0 ]; then
    if [ "$NEW_MOVED" = 1 ]; then rm -rf "$DEST"; fi
    if [ "$OLD_MOVED" = 1 ]; then mv "$BACKUP/runtime" "$DEST"; fi
    if [ -n "$NEW_NATIVE" ]; then rm -f "$NEW_NATIVE"; fi
    if [ -n "$NEW_SHIM" ]; then rm -f "$NEW_SHIM"; fi
  fi
  if [ -n "$WORK" ]; then rm -rf "$WORK"; fi
  if [ -n "$LOCK" ]; then rmdir "$LOCK" 2>/dev/null || true; fi
  if [ "$result" != 0 ]; then echo 'Nothing is registered in REAPER. See the message above and the installation guide.' >&2; fi
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
while [ "$#" -gt 0 ]; do
  case "$1" in
    --resource-path|--reaper-app|--arch)
      [ "$#" -ge 2 ] || fail "Missing value for $1"
      case "$1" in
        --resource-path) RESOURCE=$2 ;;
        --reaper-app) APP=$2 ;;
        --arch) TARGET_ARCH=$2 ;;
      esac
      shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --no-launch) LAUNCH=0; shift ;;
    --help)
      echo 'Usage: bash "Install Song Mapper.command" [--dry-run] [--no-launch]'
      echo '       [--reaper-app /Applications/REAPER.app] [--resource-path PATH] [--arch arm64|x86_64]'
      exit 0 ;;
    *) fail "Unknown option: $1" ;;
  esac
done
[ "$(uname -s)" = Darwin ] || fail 'This installer is for macOS. Use the README for manual installation on other systems.'
case "$TARGET_ARCH" in arm64|x86_64) ;; *) fail 'Only 64-bit Intel and Apple Silicon REAPER are supported.' ;; esac
[ -d "$APP" ] || fail 'Install REAPER 7.82 or newer first, launch it once, then quit it. See https://www.reaper.fm/download.php'
[ -f "$RESOURCE/reaper.ini" ] || fail "No initialized REAPER resource folder at $RESOURCE. Launch REAPER once or supply --resource-path."
RESOURCE=$(cd "$RESOURCE" && pwd -P)
APP=$(cd "$APP" && pwd -P)
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")
[[ "$VERSION" =~ ^([0-9]+)\.([0-9]+) ]] || fail 'Cannot determine the installed REAPER version.'
MAJOR=$((10#${BASH_REMATCH[1]}))
MINOR=$((10#${BASH_REMATCH[2]}))
[ "$MAJOR" -gt 7 ] || { [ "$MAJOR" = 7 ] && [ "$MINOR" -ge 82 ]; } || fail 'Please update REAPER to 7.82 or newer first.'
BINARY="$APP/Contents/MacOS/REAPER"
[ -x "$BINARY" ] || fail 'The selected app has no REAPER executable.'
/usr/bin/file -b "$BINARY" | /usr/bin/grep -q "$TARGET_ARCH" || fail "This REAPER app does not contain the $TARGET_ARCH architecture. Try --arch x86_64 for Intel REAPER."
for entry in 'Song Mapper.lua' song_mapper/model.lua song_mapper/codec.lua song_mapper/project.lua song_mapper/session.lua song_mapper/ui.lua song_mapper/compat.lua installer/register.lua; do
  [ -f "$SOURCE_DIR/$entry" ] || fail "Incomplete download: missing $entry. Extract the entire repository ZIP first."
done
DEST="$RESOURCE/Scripts/Song Mapper"
API_DIR="$RESOURCE/Scripts/ReaTeam Extensions/API"
NATIVE="$RESOURCE/UserPlugins/reaper_imgui-$TARGET_ARCH.dylib"
FOUND=0
for native in "$RESOURCE"/UserPlugins/reaper_imgui*.dylib; do
  [ -e "$native" ] || continue
  FOUND=$((FOUND + 1))
done
[ "$FOUND" -le 1 ] || fail 'Multiple ReaImGui extensions exist. Resolve them through ReaPack/manual setup first; none will be overwritten.'
if [ "$FOUND" = 1 ]; then
  [ -f "$NATIVE" ] && [ ! -L "$NATIVE" ] || fail "An existing ReaImGui uses another architecture or a custom path. Use manual setup; it will not be replaced."
  [ -f "$API_DIR/imgui.lua" ] || fail 'Existing ReaImGui is incomplete. Repair it through ReaPack first.'
  echo 'Reusing existing ReaImGui. REAPER will verify API compatibility before registration.'
else
  [ ! -e "$API_DIR/imgui.lua" ] || fail 'Found an orphaned ReaImGui Lua shim. Repair the existing installation first.'
fi
[ ! -L "$DEST" ] || fail 'The Song Mapper destination is a symbolic link. Use manual installation to preserve it.'
if [ -e "$DEST" ] && [ ! -f "$DEST/.song-mapper-install" ]; then
  fail "An unmanaged Song Mapper folder already exists at $DEST. Move it aside or use the documented manual update procedure."
fi
# Refuse symlinked dependency directories rather than writing outside the selected resource tree.
for dir in "$RESOURCE/Scripts" "$RESOURCE/UserPlugins" "$RESOURCE/Scripts/ReaTeam Extensions" "$API_DIR"; do
  [ ! -L "$dir" ] || fail "A dependency directory is a symbolic link: $dir. Use manual installation."
done
echo "REAPER: $VERSION ($TARGET_ARCH)"
echo "Resource folder: $RESOURCE"
echo "Song Mapper: $DEST"
if [ "$DRY_RUN" = 1 ]; then
  echo "Dry run: would install/update Song Mapper; ReaImGui download needed: $((1 - FOUND)). No files changed."
  exit 0
fi
PROCESS_STATUS=0
pgrep -x REAPER >/dev/null 2>&1 || PROCESS_STATUS=$?
[ "$PROCESS_STATUS" -le 1 ] || fail "Cannot determine whether REAPER is running. Please retry outside a restricted environment."
if [ "$PROCESS_STATUS" = 0 ]; then
  fail 'REAPER is running. Save your work, quit REAPER completely, then run this installer again.'
fi
# Atomic directory creation prevents concurrent installers using the same resource folder.
if ! mkdir "$RESOURCE/.song-mapper-install-lock" 2>/dev/null; then
  fail 'An installer lock exists. If no installer is running, remove .song-mapper-install-lock from the resource folder and retry.'
fi
LOCK="$RESOURCE/.song-mapper-install-lock"
WORK=$(mktemp -d "${TMPDIR:-/tmp}/song-mapper.XXXXXX")
fetch() {
  curl --fail --location --silent --show-error --retry 2 --connect-timeout 20 --max-time 180 \
    --proto '=https' --proto-redir '=https' "$1" -o "$2" || fail 'Download failed. Check your connection and try again. Older Macs may need current system certificates.'
  ACTUAL=$(shasum -a 256 "$2"); ACTUAL=${ACTUAL%% *}
  [ "$ACTUAL" = "$3" ] || fail 'Dependency checksum mismatch. Nothing will be installed; please report this error.'
}
if [ "$FOUND" = 0 ]; then
  case "$TARGET_ARCH" in
    arm64) HASH=1f90cf004c0bbada45358609c943f601b2cb0e625ecf7739ae5df8708ab705ae ;;
    x86_64) HASH=2209fec3eae03f22fe94b9d2681b04e21f41c7d4587cb0d69e4eb72e39a64e65 ;;
  esac
  echo 'Downloading verified ReaImGui 0.10.0.5 from its official release...'
  fetch "https://codeberg.org/cfillion/reaimgui/releases/download/v0.10.0.5/reaper_imgui-$TARGET_ARCH.dylib" "$WORK/imgui.dylib" "$HASH"
  fetch 'https://codeberg.org/cfillion/reaimgui/raw/v0.10.0.5/shims/imgui.lua' "$WORK/imgui.lua" b73dac959d973e2d8fb47ea73588e84f81d4a3c7fb962c327d08427c2454b093
  /usr/bin/file -b "$WORK/imgui.dylib" | /usr/bin/grep -q "$TARGET_ARCH" || fail 'Downloaded extension has an unexpected architecture.'
fi
# Stage the complete runtime before replacing any existing files.
mkdir "$WORK/runtime"
cp "$SOURCE_DIR/Song Mapper.lua" "$WORK/runtime/"
cp -R "$SOURCE_DIR/song_mapper" "$WORK/runtime/"
cp "$SOURCE_DIR/installer/register.lua" "$WORK/runtime/Finish Installation.lua"
echo 'Song Mapper installer v1' > "$WORK/runtime/.song-mapper-install"
mkdir -p "$RESOURCE/Scripts" "$RESOURCE/UserPlugins" "$API_DIR"
if [ -d "$DEST" ] && /usr/bin/diff -qr "$WORK/runtime" "$DEST" >/dev/null 2>&1; then
  echo 'Song Mapper files already match this version; skipping runtime replacement.'
else
  BACKUP=$(mktemp -d "$RESOURCE/Scripts/.song-mapper-backup.XXXXXX")
  if [ -d "$DEST" ]; then mv "$DEST" "$BACKUP/runtime"; OLD_MOVED=1; fi
  mv "$WORK/runtime" "$DEST"
  NEW_MOVED=1
fi
if [ "$FOUND" = 0 ]; then
  NEW_NATIVE=$NATIVE; NEW_SHIM="$API_DIR/imgui.lua"
  cp "$WORK/imgui.dylib" "$NATIVE"
  cp "$WORK/imgui.lua" "$API_DIR/imgui.lua"
fi
COMMITTED=1
echo 'Files verified and installed.'
if [ -n "$BACKUP" ] && [ -d "$BACKUP/runtime" ]; then echo "Previous runtime backup: $BACKUP/runtime"; fi
echo 'Dependencies already installed by ReaPack were preserved.'
if [ "$LAUNCH" = 1 ]; then
  # REAPER accepts a ReaScript on its command line. Do not force-close any process.
  /usr/bin/arch "-$TARGET_ARCH" "$BINARY" "$DEST/Finish Installation.lua" >/dev/null 2>&1 &
  echo 'REAPER is opening to verify dependencies and register Song Mapper.'
else
  echo "Launch REAPER and load $DEST/Finish Installation.lua from Actions to finish registration."
fi
echo 'If REAPER does not open, launch it normally and follow the preceding registration step.'
