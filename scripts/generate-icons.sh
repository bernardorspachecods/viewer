#!/bin/zsh
# Renders the app icons from their SVG sources and writes the .icns files:
#   Resources/Viewer-logo.svg     -> Resources/Viewer.icns      (release, black rounded square)
#   Resources/Viewer-logo-dev.svg -> Resources/Viewer-dev.icns  (debug/dev, orange rounded square)
#
# Uses only macOS tools: a Swift script (run with `swift -`) draws each SVG with
# AppKit at the exact pixel size of every iconset entry, then `iconutil` packs them.
# Scratch files go to a temporary directory that is removed on exit.
#
#   scripts/generate-icons.sh
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "$0")/.." && pwd)"
work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT

# Renders one SVG into an .iconset folder with the standard macOS file names.
render_iconset() {
    local svg="$1"
    local iconset="$2"
    mkdir -p "$iconset"
    swift - "$svg" "$iconset" <<'SWIFT'
import AppKit

// Draws the SVG vector at each pixel size; the bitmap starts transparent, so
// the corners outside the rounded square stay transparent.
let arguments = CommandLine.arguments
let svgURL = URL(fileURLWithPath: arguments[1])
let iconsetURL = URL(fileURLWithPath: arguments[2])
guard let svg = NSImage(contentsOf: svgURL) else {
    FileHandle.standardError.write("Cannot read SVG: \(svgURL.path)\n".data(using: .utf8)!)
    exit(1)
}

let entries: [(name: String, pixels: Int)] = [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024),
]

for entry in entries {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: entry.pixels,
        pixelsHigh: entry.pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        exit(1)
    }
    bitmap.size = NSSize(width: entry.pixels, height: entry.pixels)
    NSGraphicsContext.saveGraphicsState()
    guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else { exit(1) }
    NSGraphicsContext.current = context
    context.imageInterpolation = .high
    svg.draw(in: NSRect(x: 0, y: 0, width: entry.pixels, height: entry.pixels),
             from: .zero, operation: .copy, fraction: 1.0)
    context.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()
    guard let png = bitmap.representation(using: .png, properties: [:]) else { exit(1) }
    try png.write(to: iconsetURL.appendingPathComponent(entry.name))
}
SWIFT
}

build_icns() {
    local svg_name="$1"
    local icns_name="$2"
    local iconset="$work_dir/${icns_name%.icns}.iconset"
    render_iconset "$repo_root/Resources/$svg_name" "$iconset"
    iconutil -c icns "$iconset" -o "$repo_root/Resources/$icns_name"
    iconutil -c iconset "$repo_root/Resources/$icns_name" -o "$work_dir/check-${icns_name%.icns}.iconset" >/dev/null
    print "Created: $repo_root/Resources/$icns_name"
}

build_icns "Viewer-logo.svg" "Viewer.icns"
build_icns "Viewer-logo-dev.svg" "Viewer-dev.icns"
