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

// MARK: - Native resize cursors

extension NSCursor {
    /// AppKit ships public ↔ and ↕ cursors but no public diagonal ones.
    /// macOS draws window-frame corners with these long-stable private
    /// cursors; we load them defensively and fall back if they ever vanish.
    static let resizeNWSE: NSCursor = undocumented("_windowResizeNorthWestSouthEastCursor")
        ?? .crosshair
    static let resizeNESW: NSCursor = undocumented("_windowResizeNorthEastSouthWestCursor")
        ?? .crosshair

    private static func undocumented(_ name: String) -> NSCursor? {
        let sel = NSSelectorFromString(name)
        guard NSCursor.responds(to: sel),
              let value = NSCursor.perform(sel)?.takeUnretainedValue() as? NSCursor
        else { return nil }
        return value
    }
}

// MARK: - Resize handle model

/// The 8 resize handles on a selection's bounding box.
enum HandlePos: CaseIterable, Hashable {
    case topLeft, top, topRight, right, bottomRight, bottom, bottomLeft, left

    /// Normalized x / y position on the box (0 = min edge, 0.5 = center, 1 = max edge).
    var fx: CGFloat {
        switch self {
        case .topLeft, .left, .bottomLeft:    return 0
        case .top, .bottom:                   return 0.5
        case .topRight, .right, .bottomRight: return 1
        }
    }
    var fy: CGFloat {
        switch self {
        case .topLeft, .top, .topRight:       return 0
        case .left, .right:                   return 0.5
        case .bottomLeft, .bottom, .bottomRight: return 1
        }
    }

    /// Which edges this handle drags (rule 7).
    var movesLeft: Bool   { fx == 0 }
    var movesRight: Bool  { fx == 1 }
    var movesTop: Bool    { fy == 0 }
    var movesBottom: Bool { fy == 1 }

    /// Native directional cursor (rule 4).
    var cursor: NSCursor {
        switch self {
        case .left, .right:                   return .resizeLeftRight   // ew-resize
        case .top, .bottom:                   return .resizeUpDown      // ns-resize
        case .topLeft, .bottomRight:          return .resizeNWSE        // nwse-resize
        case .topRight, .bottomLeft:          return .resizeNESW        // nesw-resize
        }
    }
}

/// A handle placed in screen (display/canvas) space.
struct PlacedHandle: Identifiable {
    let pos: HandlePos
    let center: CGPoint
    var id: HandlePos { pos }
}

// MARK: - Pure geometry helpers (decomposed per rule 10)

/// Handle centers in screen space. Edges come first and corners last so that
/// when rendered/hit-tested in order the corners sit on top — on a small box
/// (where corner and edge hit areas overlap) the corner wins.
func getResizeHandles(_ box: CGRect) -> [PlacedHandle] {
    let order: [HandlePos] = [.top, .right, .bottom, .left,
                              .topLeft, .topRight, .bottomLeft, .bottomRight]
    return order.map { pos in
        PlacedHandle(pos: pos,
                     center: CGPoint(x: box.minX + pos.fx * box.width,
                                     y: box.minY + pos.fy * box.height))
    }
}

/// First handle whose hit circle contains `point` (screen space). Returns the
/// highest-priority match because `handles` is corner-first ordered.
func hitTestResizeHandle(_ point: CGPoint,
                         _ handles: [PlacedHandle],
                         hitRadius: CGFloat) -> HandlePos? {
    for h in handles where hypot(point.x - h.center.x, point.y - h.center.y) <= hitRadius {
        return h.pos
    }
    return nil
}

/// New rect from a drag, in world (poster) space. Only the edges the handle
/// owns move; the opposite edge is anchored. Enforces min width / height (rule 8).
func resizeRectByHandle(startRect b: CGRect,
                        handle: HandlePos,
                        dx: CGFloat,
                        dy: CGFloat,
                        minW: CGFloat,
                        minH: CGFloat) -> CGRect {
    var minX = b.minX, maxX = b.maxX, minY = b.minY, maxY = b.maxY

    if handle.movesLeft   { minX += dx }
    if handle.movesRight  { maxX += dx }
    if handle.movesTop    { minY += dy }
    if handle.movesBottom { maxY += dy }

    if maxX - minX < minW {
        if handle.movesLeft { minX = maxX - minW } else { maxX = minX + minW }
    }
    if maxY - minY < minH {
        if handle.movesTop { minY = maxY - minH } else { maxY = minY + minH }
    }

    return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
}

// MARK: - Selection chrome (macOS-style resizable frame)

struct SelectionOverlay: View {
    @Binding var item: TextItem
    let scale: CGFloat
    let canvasSize: CGSize

    /// Explicit interaction state machine (rule 11).
    private enum Interaction: Equatable {
        case idle
        case hoverResizeHandle(HandlePos)
        case resizing(HandlePos)
    }

    @State private var interaction: Interaction = .idle
    @State private var resizeStartRect: CGRect?     // world space, captured on pointer-down

    // Screen-space sizing — looks constant regardless of canvas scale (rule 9).
    private let visualRadius: CGFloat = 5           // 10px circle
    private let hitRadius: CGFloat = 11             // generous hit area (rule 2)

    /// Selection box in display (canvas) space.
    private var displayBox: CGRect {
        CGRect(x: item.rect.minX * scale,
               y: item.rect.minY * scale,
               width: item.size.width * scale,
               height: item.size.height * scale)
    }

    var body: some View {
        let box = displayBox
        let handles = getResizeHandles(box)

        ZStack(alignment: .topLeading) {
            // Bounding box outline — never hittable, so it can't block moving.
            Rectangle()
                .strokeBorder(Color.accentColor.opacity(0.9), lineWidth: 1)
                .frame(width: box.width, height: box.height)
                .position(x: box.midX, y: box.midY)
                .allowsHitTesting(false)

            // One small interactive view per handle. Only these tiny circles are
            // hittable; the rest of the box stays transparent to input, so drags
            // on the body fall through to the text layer underneath for moving.
            // Corners are last in `handles`, so they render/hit on top of edges
            // where the hit areas overlap on a small box.
            ForEach(handles) { h in
                renderHandle(h)
            }
        }
        .frame(width: canvasSize.width, height: canvasSize.height, alignment: .topLeading)
    }

    // MARK: Rendering (renderSelectionBox per rule 10)

    @ViewBuilder
    private func renderHandle(_ h: PlacedHandle) -> some View {
        let activeOrHover: HandlePos? = {
            switch interaction {
            case .resizing(let p), .hoverResizeHandle(let p): return p
            case .idle: return nil
            }
        }()
        let emphasized = (h.pos == activeOrHover)

        Circle()
            .fill(Color.white)
            .overlay(Circle().strokeBorder(Color.black.opacity(0.18), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.3), radius: 1.5, x: 0, y: 0.5)
            .frame(width: visualRadius * 2 * (emphasized ? 1.3 : 1),
                   height: visualRadius * 2 * (emphasized ? 1.3 : 1))
            // Fixed hit footprint, larger than the dot, so you don't need pixel
            // accuracy. Hover + gesture attach HERE, to this small view…
            .frame(width: hitRadius * 2, height: hitRadius * 2)
            .contentShape(Circle())
            .onContinuousHover { phase in hover(phase, on: h.pos) }
            .gesture(resizeGesture(h.pos))
            // …and `.position` is applied LAST. (Applying it earlier makes the
            // view greedy/full-canvas, so its hover+gesture would cover the whole
            // canvas and only the top-most handle would ever be hit.)
            .position(x: h.center.x, y: h.center.y)
    }

    // MARK: Hover (cursor on move — rules 3, 4 & 12)

    private func hover(_ phase: HoverPhase, on pos: HandlePos) {
        // While resizing, direction & cursor are locked — ignore hover (rule 6).
        if case .resizing = interaction { return }

        switch phase {
        case .active:
            interaction = .hoverResizeHandle(pos)
            pos.cursor.set()                       // native resize cursor
        case .ended:
            // Only reset if we're still the handle that set the hover state —
            // avoids a stale exit clobbering an adjacent handle we just entered.
            if interaction == .hoverResizeHandle(pos) {
                interaction = .idle
                NSCursor.arrow.set()
            }
        }
    }

    // MARK: Resize drag (startResize / updateResize / endResize — rule 10)

    private func resizeGesture(_ handle: HandlePos) -> some Gesture {
        // Measure in `.global` (a stable space). The default `.local` space is
        // tied to the handle, which moves as the box resizes — that feedback
        // makes the translation oscillate and the text/box jitter.
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .onChanged { value in
                if case .resizing = interaction {
                    // already started — handle stays locked (rule 6)
                } else {
                    // startResize: capture the starting rect once.
                    resizeStartRect = item.rect                      // world space
                    interaction = .resizing(handle)
                }

                handle.cursor.set()             // hold the cursor through the whole drag

                // updateResize: screen-space delta → world space (rule 9).
                guard let start = resizeStartRect else { return }
                let dx = value.translation.width / scale
                let dy = value.translation.height / scale
                let r = resizeRectByHandle(startRect: start, handle: handle,
                                           dx: dx, dy: dy, minW: 20, minH: 20)
                item.size = CGSize(width: r.width, height: r.height)
                item.position = CGPoint(x: r.midX, y: r.midY)
            }
            .onEnded { _ in
                // endResize: leave resizing mode, resume normal hit testing.
                resizeStartRect = nil
                interaction = .idle
                NSCursor.arrow.set()
            }
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
