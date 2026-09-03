#!/bin/zsh

set -euo pipefail

script_directory="${0:A:h}"
repository_root="${script_directory:h:h}"
install_directory="${HOME}/Applications"
application="${install_directory}/Overlay Browser.app"
bundle_identifier="com.igor.safescreen.overlay-browser"
launch_after_install=false

usage() {
  print -r -- "Usage: ${0:t} [--launch]"
}

while (( $# > 0 )); do
  case "$1" in
    --launch)
      launch_after_install=true
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      print -u2 -r -- "Unknown argument: $1"
      usage >&2
      exit 2
      ;;
  esac
  shift
done

cd "$repository_root"

print -r -- "Building OverlayBrowser..."
swift build --configuration debug --product OverlayBrowser
binary_directory="$(swift build --configuration debug --show-bin-path)"
binary="${binary_directory}/OverlayBrowser"

if [[ ! -x "$binary" ]]; then
  print -u2 -r -- "Built executable not found: $binary"
  exit 1
fi

mkdir -p "$install_directory"
staging_directory="$(mktemp -d "${install_directory}/.overlay-browser-install.XXXXXX")"
staging_application="${staging_directory}/Overlay Browser.app"
trap 'rm -rf "$staging_directory"' EXIT

mkdir -p "$staging_application/Contents/MacOS" "$staging_application/Contents/Resources"
cp "$binary" "$staging_application/Contents/MacOS/OverlayBrowser"
chmod 755 "$staging_application/Contents/MacOS/OverlayBrowser"
cp "$repository_root/Packaging/macOS/Info.plist" "$staging_application/Contents/Info.plist"
cp "$repository_root/Packaging/macOS/AppIcon.icns" \
  "$staging_application/Contents/Resources/AppIcon.icns"

build_number="$(date -u +%Y%m%d%H%M%S)"
source_revision="$(git rev-parse --short HEAD)"
if [[ -n "$(git status --short)" ]]; then
  source_revision="${source_revision}-dirty"
fi
plutil -replace CFBundleVersion -string "$build_number" "$staging_application/Contents/Info.plist"
plutil -insert OverlayBrowserSourceRevision -string "$source_revision" \
  "$staging_application/Contents/Info.plist"

xattr -cr "$staging_application"
codesign --force --sign - --timestamp=none "$staging_application"
codesign --verify --deep --strict "$staging_application"

icon_changed=true
installed_icon="$application/Contents/Resources/AppIcon.icns"
staged_icon="$staging_application/Contents/Resources/AppIcon.icns"
if [[ -f "$installed_icon" ]] && cmp -s "$installed_icon" "$staged_icon"; then
  icon_changed=false
fi

running_pids=()
while IFS= read -r pid; do
  [[ -n "$pid" ]] || continue
  command="$(ps -p "$pid" -o command= 2>/dev/null || true)"
  if [[ "$command" == *"/Overlay Browser.app/Contents/MacOS/OverlayBrowser"* ]]; then
    running_pids+=("$pid")
    kill -TERM "$pid" 2>/dev/null || true
  fi
done < <(pgrep -x OverlayBrowser 2>/dev/null || true)

for pid in "${running_pids[@]}"; do
  for _ in {1..50}; do
    kill -0 "$pid" 2>/dev/null || break
    sleep 0.1
  done
  if kill -0 "$pid" 2>/dev/null; then
    print -u2 -r -- "OverlayBrowser process did not stop: $pid"
    exit 1
  fi
done

rm -rf "$application"
mv "$staging_application" "$application"

launch_services_register="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
"$launch_services_register" -f "$application"

dock_preferences="${HOME}/Library/Preferences/com.apple.dock.plist"
dock_changed=false
if ! /usr/libexec/PlistBuddy -c "Print :persistent-apps" "$dock_preferences" 2>/dev/null \
  | grep -Fq "$bundle_identifier"; then
  application_url="file://${application// /%20}/"
  dock_tile="<dict><key>tile-data</key><dict><key>bundle-identifier</key><string>${bundle_identifier}</string><key>file-data</key><dict><key>_CFURLString</key><string>${application_url}</string><key>_CFURLStringType</key><integer>15</integer></dict><key>file-label</key><string>Overlay Browser</string></dict><key>tile-type</key><string>file-tile</string></dict>"
  defaults write com.apple.dock persistent-apps -array-add "$dock_tile"
  dock_changed=true
fi

if [[ "$dock_changed" == true || "$icon_changed" == true ]]; then
  killall Dock >/dev/null 2>&1 || true
fi
if [[ "$dock_changed" == true ]]; then
  print -r -- "Pinned Overlay Browser to the Dock."
fi
if [[ "$icon_changed" == true ]]; then
  print -r -- "Refreshed the Overlay Browser Dock icon."
fi

if [[ "$launch_after_install" == true ]]; then
  open -n "$application"
fi

print -r -- "Installed: $application"
print -r -- "Source: $source_revision"
if [[ "$launch_after_install" == true ]]; then
  print -r -- "Launched the installed application."
else
  print -r -- "Open it from the Dock or run: open \"$application\""
fi
