import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ContentView: View {
    // Default to RedNote Vertical 3:4.
    @State private var preset: SizePreset =
        SizePreset.presets.first(where: { $0.platform == "RedNote" && $0.name == "Vertical 3:4" })
        ?? SizePreset.presets[0]
    @State private var background: Color = Color(red: 0.11, green: 0.16, blue: 0.30)
    @State private var items: [TextItem] = []
    @State private var selectedID: UUID?
    @State private var editingID: UUID?
    @State private var activeGuides = SmartGuides()

    // Last hovered point on the poster, in poster coordinates (for "Add Text here").
    @State private var hoverPoint: CGPoint?

    private var posterSize: CGSize { CGSize(width: preset.width, height: preset.height) }

    var body: some View {
        HStack(spacing: 0) {
            inspector
                .frame(width: 320)
                .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            canvasArea
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .underPageBackgroundColor))
        }
        .background(
            DeleteKeyMonitor(canDelete: { selectedID != nil && editingID == nil },
                             onDelete: { deleteSelected() })
        )
    }

    // MARK: - Canvas

    private var canvasArea: some View {
        GeometryReader { geo in
            let scale = min(geo.size.width / preset.width,
                            geo.size.height / preset.height) * 0.9
            let dispW = preset.width * scale
            let dispH = preset.height * scale

            ZStack {
                Rectangle()
                    .fill(background)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedID = nil
                        editingID = nil
                        activeGuides = SmartGuides()
                    }

                ForEach($items) { $item in
                    TextLayerView(item: $item,
                                  scale: scale,
                                  canvasSize: posterSize,
                                  isEditing: editingID == item.id,
                                  onSelect: { selectedID = item.id },
                                  onBeginEdit: { selectedID = item.id; editingID = item.id },
                                  onEndEdit: { if editingID == item.id { editingID = nil } },
                                  onGuidesChanged: { activeGuides = $0 })
                }

                renderSmartGuides(guides: activeGuides,
                                  canvasSize: CGSize(width: dispW, height: dispH))

                if editingID == nil, let sel = selectedBinding {
                    SelectionOverlay(item: sel,
                                     scale: scale,
                                     canvasSize: CGSize(width: dispW, height: dispH))
                }
            }
            .frame(width: dispW, height: dispH)
            .clipped()
            .shadow(color: .black.opacity(0.25), radius: 18, y: 8)
            .overlay(Rectangle().strokeBorder(Color.black.opacity(0.15)))
            .contentShape(Rectangle())
            .onContinuousHover { phase in
                if case .active(let p) = phase {
                    hoverPoint = CGPoint(x: p.x / scale, y: p.y / scale)
                }
            }
            .contextMenu {
                Button {
                    addText(at: hoverPoint)
                } label: {
                    Label("Add Text", systemImage: "textformat")
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .padding(24)
    }

    // MARK: - Inspector

    private var inspector: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header

                section("Canvas size") {
                    Picker("", selection: $preset) {
                        ForEach(SizePreset.presets) { p in
                            Text(p.menuLabel).tag(p)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }

                section("Background") {
                    ColorPicker("Color", selection: $background, supportsOpacity: false)
                }

                section("Text") {
                    Button {
                        addText()
                    } label: {
                        Label("Add text", systemImage: "textformat")
                            .frame(maxWidth: .infinity)
                    }
                    .controlSize(.large)

                    if let item = selectedBinding {
                        textEditor(for: item)
                    } else if !items.isEmpty {
                        Text("Select a text layer, then drag the corner or edge handles to resize the box.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Divider()

                Button {
                    exportPNG()
                } label: {
                    Label("Export PNG…", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
                .disabled(items.isEmpty)
            }
            .padding(20)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Poster")
                .font(.system(size: 22, weight: .bold))
            Text("Make a poster in three steps.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func textEditor(for item: Binding<TextItem>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            TextEditor(text: item.text)
                .font(.body)
                .scrollContentBackground(.hidden)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Color(nsColor: .separatorColor))
                )
                .frame(minHeight: 72)

            Picker("Font", selection: item.fontName) {
                ForEach(FontCatalog.names, id: \.self) { Text($0).tag($0) }
            }

            HStack {
                Text("Size")
                Slider(value: item.fontSize, in: 16...400)
                Text("\(Int(item.fontSize.wrappedValue))")
                    .monospacedDigit()
                    .frame(width: 40, alignment: .trailing)
            }
            Text("Text shrinks automatically to fit inside the box.")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Toggle("Bold", isOn: item.isBold)

            ColorPicker("Text color", selection: item.color, supportsOpacity: true)

            Button(role: .destructive) {
                deleteSelected()
            } label: {
                Label("Delete layer", systemImage: "trash")
            }
        }
        .padding(.top, 4)
    }

    private func section<Content: View>(_ title: String,
                                        @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            content()
        }
    }

    // MARK: - Selection helpers

    private var selectedBinding: Binding<TextItem>? {
        guard let id = selectedID,
              let idx = items.firstIndex(where: { $0.id == id }) else { return nil }
        return $items[idx]
    }

    private func addText(at point: CGPoint? = nil) {
        let w = preset.width * 0.8
        let h = preset.height * 0.25
        let center = point ?? CGPoint(x: preset.width / 2, y: preset.height / 2)
        let clamped = CGPoint(x: min(max(center.x, 0), preset.width),
                              y: min(max(center.y, 0), preset.height))
        let item = TextItem(position: clamped, size: CGSize(width: w, height: h))
        items.append(item)
        selectedID = item.id
    }

    private func deleteSelected() {
        // Don't delete the layer while the user is editing its text.
        guard editingID == nil, let id = selectedID else { return }
        items.removeAll { $0.id == id }
        selectedID = nil
    }

    // MARK: - Export

    @MainActor
    private func exportPNG() {
        let content = PosterCanvasView(size: posterSize, background: background, items: items)
        let renderer = ImageRenderer(content: content)
        renderer.proposedSize = ProposedViewSize(posterSize)
        renderer.scale = 1.0

        guard let cgImage = renderer.cgImage else {
            NSSound.beep()
            return
        }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "poster.png"
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }

        let rep = NSBitmapImageRep(cgImage: cgImage)
        rep.size = posterSize
        if let data = rep.representation(using: .png, properties: [:]) {
            try? data.write(to: url)
        }
    }
}

// MARK: - Smart guides + snapping

struct ComponentBounds {
    let left: CGFloat
    let right: CGFloat
    let top: CGFloat
    let bottom: CGFloat
    let centerX: CGFloat
    let centerY: CGFloat

    init(position: CGPoint, size: CGSize) {
        left = position.x - size.width / 2
        right = position.x + size.width / 2
        top = position.y - size.height / 2
        bottom = position.y + size.height / 2
        centerX = position.x
        centerY = position.y
    }
}

struct SmartGuides: Equatable {
    var verticalCenter = false
    var horizontalCenter = false
}

struct SnapState {
    var x = false
    var y = false
}

struct SnapResult {
    let position: CGPoint
    let guides: SmartGuides
    let state: SnapState
    let enteredX: Bool
    let enteredY: Bool
}

private let enterSnapThreshold: CGFloat = 8
private let exitSnapThreshold: CGFloat = 14

func calculateSnap(position: CGPoint,
                   componentSize: CGSize,
                   canvasSize: CGSize,
                   scale: CGFloat,
                   previousState: SnapState) -> SnapResult {
    let worldEnterThreshold = enterSnapThreshold / scale
    let worldExitThreshold = exitSnapThreshold / scale
    let bounds = ComponentBounds(position: position, size: componentSize)
    let canvasCenterX = canvasSize.width / 2
    let canvasCenterY = canvasSize.height / 2

    var snappedPosition = position
    var nextState = previousState
    var guides = SmartGuides()
    var enteredX = false
    var enteredY = false

    let dx = bounds.centerX - canvasCenterX
    if previousState.x {
        if abs(dx) > worldExitThreshold {
            nextState.x = false
        } else {
            snappedPosition.x = canvasCenterX
            guides.verticalCenter = true
        }
    } else if abs(dx) < worldEnterThreshold {
        nextState.x = true
        enteredX = true
        snappedPosition.x = canvasCenterX
        guides.verticalCenter = true
    }

    let dy = bounds.centerY - canvasCenterY
    if previousState.y {
        if abs(dy) > worldExitThreshold {
            nextState.y = false
        } else {
            snappedPosition.y = canvasCenterY
            guides.horizontalCenter = true
        }
    } else if abs(dy) < worldEnterThreshold {
        nextState.y = true
        enteredY = true
        snappedPosition.y = canvasCenterY
        guides.horizontalCenter = true
    }

    return SnapResult(position: snappedPosition,
                      guides: guides,
                      state: nextState,
                      enteredX: enteredX,
                      enteredY: enteredY)
}

func applySnapping(position: CGPoint,
                   componentSize: CGSize,
                   canvasSize: CGSize,
                   scale: CGFloat,
                   state: inout SnapState) -> SnapResult {
    let result = calculateSnap(position: position,
                               componentSize: componentSize,
                               canvasSize: canvasSize,
                               scale: scale,
                               previousState: state)
    state = result.state
    return result
}

@ViewBuilder
func renderSmartGuides(guides: SmartGuides, canvasSize: CGSize) -> some View {
    ZStack {
        if guides.verticalCenter {
            Rectangle()
                .fill(Color.accentColor.opacity(0.85))
                .frame(width: 1, height: canvasSize.height)
                .position(x: canvasSize.width / 2, y: canvasSize.height / 2)
        }

        if guides.horizontalCenter {
            Rectangle()
                .fill(Color.accentColor.opacity(0.85))
                .frame(width: canvasSize.width, height: 1)
                .position(x: canvasSize.width / 2, y: canvasSize.height / 2)
        }
    }
    .frame(width: canvasSize.width, height: canvasSize.height)
    .allowsHitTesting(false)
}

// MARK: - Text layer (display + move)

struct TextLayerView: View {
    @Binding var item: TextItem
    let scale: CGFloat
    let canvasSize: CGSize
    let isEditing: Bool
    let onSelect: () -> Void
    let onBeginEdit: () -> Void
    let onEndEdit: () -> Void
    let onGuidesChanged: (SmartGuides) -> Void

    @State private var moveBaseline: CGPoint?
    @State private var snapState = SnapState()
    @FocusState private var focused: Bool

    var body: some View {
        let styled = content
            .font(FontCatalog.font(name: item.fontName,
                                   size: item.fontSize * scale,
                                   bold: item.isBold))
            .foregroundColor(item.color)
            .multilineTextAlignment(.center)
            .minimumScaleFactor(0.05)
            .frame(width: item.size.width * scale, height: item.size.height * scale)
            .contentShape(Rectangle())
            .position(x: item.position.x * scale, y: item.position.y * scale)
            .onChange(of: isEditing) { editing in
                if editing { focused = true }
            }

        if isEditing {
            styled
        } else {
            styled
                .onTapGesture(count: 2) { onBeginEdit() }
                .onTapGesture { onSelect() }
                .gesture(moveGesture)
        }
    }

    @ViewBuilder
    private var content: some View {
        if isEditing {
            TextEditor(text: $item.text)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .focused($focused)
                .onAppear {
                    DispatchQueue.main.async {
                        focused = true
                    }
                }
                .onChange(of: focused) { isFocused in
                    if !isFocused { onEndEdit() }
                }
        } else {
            Text(item.text.isEmpty ? "Double-click to edit" : item.text)
                .opacity(item.text.isEmpty ? 0.5 : 1)
        }
    }

    private var moveGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if moveBaseline == nil {
                    moveBaseline = item.position
                    snapState = SnapState()
                    onSelect()
                }
                if let base = moveBaseline {
                    let rawPosition = CGPoint(
                        x: base.x + value.translation.width / scale,
                        y: base.y + value.translation.height / scale)
                    let snap = applySnapping(position: rawPosition,
                                             componentSize: item.size,
                                             canvasSize: canvasSize,
                                             scale: scale,
                                             state: &snapState)
                    item.position = snap.position
                    onGuidesChanged(snap.guides)
                    if snap.enteredX || snap.enteredY {
                        NSHapticFeedbackManager.defaultPerformer.perform(.alignment,
                                                                          performanceTime: .now)
                    }
                }
            }
            .onEnded { _ in
                moveBaseline = nil
                snapState = SnapState()
                onGuidesChanged(SmartGuides())
            }
    }
}

// MARK: - Selection chrome (resize handles)

/// One of the 8 resize handles, described by its normalized position on the
/// box (fx / fy each ∈ {0, 0.5, 1}): corners use 0/1, edges use 0.5.
struct ResizeHandle: Identifiable {
    let id: Int
    let fx: CGFloat
    let fy: CGFloat

    static let all: [ResizeHandle] = [
        ResizeHandle(id: 0, fx: 0,   fy: 0),
        ResizeHandle(id: 1, fx: 0.5, fy: 0),
        ResizeHandle(id: 2, fx: 1,   fy: 0),
        ResizeHandle(id: 3, fx: 0,   fy: 0.5),
        ResizeHandle(id: 4, fx: 1,   fy: 0.5),
        ResizeHandle(id: 5, fx: 0,   fy: 1),
        ResizeHandle(id: 6, fx: 0.5, fy: 1),
        ResizeHandle(id: 7, fx: 1,   fy: 1)
    ]
}

struct SelectionOverlay: View {
    @Binding var item: TextItem
    let scale: CGFloat
    let canvasSize: CGSize

    @State private var baseline: CGRect?
    private let minBox: CGFloat = 40
    private let handle: CGFloat = 10

    var body: some View {
        // Box rect in display (canvas) coordinates.
        let dr = CGRect(x: item.rect.minX * scale,
                        y: item.rect.minY * scale,
                        width: item.size.width * scale,
                        height: item.size.height * scale)

        ZStack(alignment: .topLeading) {
            Rectangle()
                .strokeBorder(Color.accentColor.opacity(0.9), lineWidth: 1)
                .frame(width: dr.width, height: dr.height)
                .position(x: dr.midX, y: dr.midY)
                .allowsHitTesting(false)

            ForEach(ResizeHandle.all) { h in
                Circle()
                    .fill(Color.white)
                    .overlay(Circle().strokeBorder(Color.black.opacity(0.18), lineWidth: 0.5))
                    .shadow(color: .black.opacity(0.3), radius: 1.5, x: 0, y: 0.5)
                    .frame(width: handle, height: handle)
                    .contentShape(Circle().inset(by: -6))
                    .position(x: dr.minX + h.fx * dr.width,
                              y: dr.minY + h.fy * dr.height)
                    .gesture(resizeDrag(h))
            }
        }
        .frame(width: canvasSize.width, height: canvasSize.height, alignment: .topLeading)
    }

    private func resizeDrag(_ h: ResizeHandle) -> some Gesture {
        DragGesture()
            .onChanged { value in
                if baseline == nil { baseline = item.rect }
                guard let b = baseline else { return }

                let dx = value.translation.width / scale
                let dy = value.translation.height / scale

                // Move only the edges this handle controls.
                let minX = (h.fx == 0)   ? b.minX + dx : b.minX
                let maxX = (h.fx == 1)   ? b.maxX + dx : b.maxX
                let minY = (h.fy == 0)   ? b.minY + dy : b.minY
                let maxY = (h.fy == 1)   ? b.maxY + dy : b.maxY

                let w = max(minBox, maxX - minX)
                let hgt = max(minBox, maxY - minY)
                // Anchor the opposite edge so it stays put.
                let originX = (h.fx == 0) ? maxX - w : minX
                let originY = (h.fy == 0) ? maxY - hgt : minY

                item.position = CGPoint(x: originX + w / 2, y: originY + hgt / 2)
                item.size = CGSize(width: w, height: hgt)
            }
            .onEnded { _ in baseline = nil }
    }
}

// MARK: - Delete key handling

/// Watches for the Delete / Backspace key and removes the selected layer,
/// but stays out of the way while any text field is being edited.
/// Uses a local NSEvent monitor so there's no focus ring on the canvas.
struct DeleteKeyMonitor: NSViewRepresentable {
    var canDelete: () -> Bool
    var onDelete: () -> Void

    func makeNSView(context: Context) -> NSView {
        context.coordinator.install(canDelete: canDelete, onDelete: onDelete)
        return NSView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.canDelete = canDelete
        context.coordinator.onDelete = onDelete
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.remove()
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        private var monitor: Any?
        var canDelete: (() -> Bool)?
        var onDelete: (() -> Void)?

        func install(canDelete: @escaping () -> Bool, onDelete: @escaping () -> Void) {
            self.canDelete = canDelete
            self.onDelete = onDelete
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self else { return event }
                // 51 = Delete (Backspace), 117 = Forward Delete
                guard event.keyCode == 51 || event.keyCode == 117 else { return event }
                // If a text field / editor is first responder, let it handle the key.
                let responder = event.window?.firstResponder
                if responder is NSText || responder is NSTextView { return event }
                if self.canDelete?() == true {
                    self.onDelete?()
                    return nil   // consume the event
                }
                return event
            }
        }

        func remove() {
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
        }
    }
}

#Preview {
    ContentView()
}
