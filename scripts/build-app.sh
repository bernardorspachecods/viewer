#!/bin/zsh

set -euo pipefail

repo_root="$(cd -- "$(dirname -- "$0")/.." && pwd)"
configuration="${1:-debug}"

if [[ "$configuration" != "debug" && "$configuration" != "release" ]]; then
    print -u2 "Uso: $0 [debug|release]"
    exit 2
fi

swift build --configuration "$configuration" --product Viewer
binary_directory="$(swift build --configuration "$configuration" --show-bin-path)"
app_bundle="$repo_root/.build/$configuration/Viewer.app"
legacy_app_bundle="$repo_root/.build/$configuration/viewer.app"
bundle_identifier="com.bernardopacheco.viewer"
signing_identity="${VIEWER_CODESIGN_IDENTITY:-Apple Development: bernardopinvesfore@gmail.com (YA46UAZ7YP)}"

rm -rf "$app_bundle"
if [[ "$legacy_app_bundle" != "$app_bundle" ]]; then
    rm -rf "$legacy_app_bundle"
fi
mkdir -p "$app_bundle/Contents/MacOS" "$app_bundle/Contents/Resources"
cp "$binary_directory/Viewer" "$app_bundle/Contents/MacOS/Viewer"
cp "$repo_root/Resources/Viewer-Info.plist" "$app_bundle/Contents/Info.plist"
# The app shows a DEV label unless this channel is exactly "release". Written
# before codesigning, so the signature covers it. The source plist is untouched.
if [[ "$configuration" == "release" ]]; then
    build_channel="release"
else
    build_channel="dev"
fi
/usr/libexec/PlistBuddy -c "Add :ViewerBuildChannel string $build_channel" "$app_bundle/Contents/Info.plist"
# Dev builds get the orange icon so they are told apart from the installed app.
# Both icons are produced from the SVGs by scripts/generate-icons.sh.
if [[ "$configuration" == "release" ]]; then
    app_icon="Viewer.icns"
else
    app_icon="Viewer-dev.icns"
fi
cp "$repo_root/Resources/$app_icon" "$app_bundle/Contents/Resources/Viewer.icns"

# Resource bundles of the dependencies (highlight.js for code blocks, SwiftMath fonts). Their
# SwiftPM accessors look in Contents/Resources of the app, and fall back to the build folder,
# which does not exist on another machine or after the build folder is cleaned.
for resource_bundle in "$binary_directory"/*.bundle(N); do
    cp -R "$resource_bundle" "$app_bundle/Contents/Resources/"
done

# Use the existing stable Apple Development identity so macOS can associate
# Accessibility permission with this app across rebuilds. Never fall back to
# ad-hoc signing, which changes the app identity and causes a permission loop.
codesign --force --sign "$signing_identity" \
    --identifier "$bundle_identifier" \
    "$app_bundle/Contents/MacOS/Viewer"
codesign --force --sign "$signing_identity" \
    --identifier "$bundle_identifier" \
    "$app_bundle"
codesign --verify --deep --strict "$app_bundle"

print "Created: $app_bundle"
print "Open file: open -a '$app_bundle' /path/to/main.tex"
