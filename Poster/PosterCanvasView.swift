import SwiftUI

/// Pure, non-interactive rendering of the poster at its native pixel size.
/// Used both as the export source (via ImageRenderer) and as a reference layout.
struct PosterCanvasView: View {
    let size: CGSize
    let background: Color
    let items: [TextItem]

    var body: some View {
        ZStack {
            Rectangle()
                .fill(background)

            ForEach(items) { item in
                Text(item.text)
                    .font(FontCatalog.font(name: item.fontName,
                                           size: item.fontSize,
                                           bold: item.isBold))
                    .foregroundColor(item.color)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.05)
                    .frame(width: item.size.width, height: item.size.height)
                    .position(item.position)
            }
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }
}
