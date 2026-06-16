# Poster

A tiny native macOS app for making simple posters for Instagram, RedNote, Weibo, and more.

## Three steps
1. **Pick a size** — presets for Instagram (square / portrait / story), RedNote, Weibo, X, and a print poster.
2. **Pick a background color** — any color via the system color picker.
3. **Add text** — choose the font, size, color, bold; drag the box to move it, and drag any of the four corners to resize. Text wraps inside the box, so the export matches the editor exactly.

Then **Export PNG…** to save the poster at full pixel resolution.

## How to run
1. Open `Poster.xcodeproj` in Xcode (15 or newer; requires macOS 13+).
2. Select the **Poster** scheme and press **⌘R**.

## Build script
- `./build.sh install` builds the release app and installs it to `/Applications`.
- `./build.sh dmg` builds the release app and packages `dist/Poster.dmg`.
- `./build.sh` defaults to `install`.

## Project layout
- `Poster/PosterApp.swift` — app entry point
- `Poster/ContentView.swift` — editor UI, canvas, and PNG export
- `Poster/PosterCanvasView.swift` — pixel-accurate render used for export
- `Poster/Models.swift` — size presets, font catalog, text model
