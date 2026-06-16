import SwiftUI

// MARK: - Size presets

/// A canvas size tuned for a specific social platform.
/// Width / height are in pixels (1 SwiftUI point == 1 px on export).
struct SizePreset: Identifiable, Hashable {
    let id = UUID()
    let platform: String
    let name: String
    let width: CGFloat
    let height: CGFloat

    var pixelLabel: String { "\(Int(width)) × \(Int(height))" }
    var menuLabel: String { "\(platform) · \(name) (\(pixelLabel))" }

    static let presets: [SizePreset] = [
        SizePreset(platform: "Instagram",  name: "Square Post",   width: 1080, height: 1080),
        SizePreset(platform: "Instagram",  name: "Portrait Post", width: 1080, height: 1350),
        SizePreset(platform: "Instagram",  name: "Story / Reel",  width: 1080, height: 1920),
        SizePreset(platform: "RedNote",    name: "Vertical 3:4",  width: 1080, height: 1440),
        SizePreset(platform: "RedNote",    name: "Square 1:1",    width: 1080, height: 1080),
        SizePreset(platform: "Weibo",      name: "Feed Square",   width: 1080, height: 1080),
        SizePreset(platform: "Weibo",      name: "Vertical 9:16", width: 1080, height: 1920),
        SizePreset(platform: "Twitter / X", name: "Landscape",    width: 1600, height: 900),
        SizePreset(platform: "Poster",     name: "A-Series 2:3",  width: 1200, height: 1800),
    ]
}

// MARK: - Fonts

enum FontCatalog {
    /// A curated list that includes Latin and CJK-capable faces
    /// (RedNote / Weibo are Chinese-first platforms).
    static let names: [String] = [
        "System",
        "Helvetica Neue",
        "Avenir Next",
        "Arial",
        "Georgia",
        "Times New Roman",
        "Courier New",
        "Futura",
        "Snell Roundhand",
        "PingFang SC",
        "Hiragino Sans",
        "STSong"
    ]

    static func font(name: String, size: CGFloat, bold: Bool) -> Font {
        let base: Font = (name == "System")
            ? .system(size: size)
            : .custom(name, fixedSize: size)
        return bold ? base.bold() : base
    }
}

// MARK: - Text item

/// One movable line (or block) of text on the poster.
/// `position` is stored in the poster's native pixel coordinate space.
struct TextItem: Identifiable {
    let id = UUID()
    var text: String = "Your text"
    var fontName: String = "System"
    var fontSize: CGFloat = 120
    var color: Color = .white
    var isBold: Bool = true
    var position: CGPoint   // box center, poster space
    var size: CGSize        // box size, poster space (controls wrapping)

    /// The text box as a rect in poster space (origin = top-left).
    var rect: CGRect {
        CGRect(x: position.x - size.width / 2,
               y: position.y - size.height / 2,
               width: size.width,
               height: size.height)
    }
}
