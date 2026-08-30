#!/bin/zsh

set -euo pipefail

script_directory="${0:A:h}"
repository_root="${script_directory:h:h}"
cd "$repository_root"

revision="$(git rev-parse --short HEAD)"
build_number="$(git rev-list --count HEAD)"
artifact_name="OverlayBrowser-macOS-universal-${revision}"
distribution_directory="$repository_root/dist"
staging_directory="$distribution_directory/$artifact_name"
application="$staging_directory/Overlay Browser.app"
archive="$distribution_directory/$artifact_name.zip"
arm_build_directory="$repository_root/.build/portable-arm64"
intel_build_directory="$repository_root/.build/portable-x86_64"
arm_binary="$arm_build_directory/arm64-apple-macosx/release/OverlayBrowser"
intel_binary="$intel_build_directory/x86_64-apple-macosx/release/OverlayBrowser"

swift build \
  --configuration release \
  --triple arm64-apple-macosx14.0 \
  --build-path "$arm_build_directory"
swift build \
  --configuration release \
  --triple x86_64-apple-macosx14.0 \
  --build-path "$intel_build_directory"

rm -rf "$staging_directory"
rm -f "$archive"
mkdir -p "$application/Contents/MacOS"

lipo -create "$arm_binary" "$intel_binary" \
  -output "$application/Contents/MacOS/OverlayBrowser"
chmod 755 "$application/Contents/MacOS/OverlayBrowser"
cp "$repository_root/Packaging/macOS/Info.plist" "$application/Contents/Info.plist"
plutil -replace CFBundleVersion -string "$build_number" "$application/Contents/Info.plist"
cp "$repository_root/Packaging/macOS/START-HERE.txt" "$staging_directory/START-HERE.txt"

xattr -cr "$application"
codesign --force --sign - --timestamp=none "$application"
codesign --verify --deep --strict --verbose=2 "$application"

binary_hash="$(shasum -a 256 "$application/Contents/MacOS/OverlayBrowser" | awk '{print $1}')"
print -r -- "$binary_hash  Overlay Browser.app/Contents/MacOS/OverlayBrowser" \
  > "$staging_directory/SHA256SUMS.txt"

ditto -c -k --sequesterRsrc "$staging_directory" "$archive"

archive_hash="$(shasum -a 256 "$archive" | awk '{print $1}')"
print -r -- "Archive: $archive"
print -r -- "Architectures: $(lipo -archs "$application/Contents/MacOS/OverlayBrowser")"
print -r -- "SHA-256: $archive_hash"
