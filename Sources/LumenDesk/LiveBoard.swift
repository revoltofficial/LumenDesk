import SwiftUI

enum BoardAction: String, Codable, CaseIterable { case cue, layer, effect, blackout, stop, text }
enum BoardBehavior: String, Codable, CaseIterable { case trigger, toggle, momentary }
struct BoardControl: Identifiable, Codable {
    var id = UUID()
    var label = "New button"
    var action: BoardAction = .cue
    var targetID: UUID? = nil
    var behavior: BoardBehavior = .trigger
    var column = 0
    var row = 0
    var width = 2
    var height = 1
    var color = "mint"
    var fontSize = 14
}
struct LiveBoard: Codable {
    var controls: [BoardControl] = []
    func validate() throws {
        guard Set(controls.map(\.id)).count == controls.count, controls.count <= 200 else { throw ProjectError.invalid("Invalid live board identifiers or size.") }
        for c in controls {
            guard (0..<12).contains(c.column), (0..<12).contains(c.row), (1...12).contains(c.width), (1...12).contains(c.height), c.column + c.width <= 12, c.row + c.height <= 12, (10...36).contains(c.fontSize), ["mint", "blue", "orange", "pink", "white"].contains(c.color), c.label.count <= 200 else { throw ProjectError.invalid("Invalid live board control layout.") }
            guard c.behavior != .momentary || [.layer, .effect].contains(c.action) else { throw ProjectError.invalid("Momentary controls require a layer or effect.") }
        }
    }
}
extension LightingStore {
    func boardActive(_ c: BoardControl) -> Bool {
        switch c.action {
        case .cue: return c.targetID != nil && activeCueID == c.targetID
        case .layer: return layerMixer.layers.contains { $0.id == c.targetID }
        case .effect: return project.effects.contains { $0.id == c.targetID && $0.enabled }
        case .blackout: return blackout
        default: return false
        }
    }
    func boardPress(_ c: BoardControl) {
        switch c.action {
        case .cue: if let id = c.targetID { activateCue(id: id) }
        case .layer: if let id = c.targetID { if c.behavior == .toggle && boardActive(c) { releaseLayer(id: id) } else { activateLayer(id: id) } }
        case .effect: if let i = project.effects.firstIndex(where: { $0.id == c.targetID }) { project.effects[i].enabled = c.behavior == .toggle ? !project.effects[i].enabled : true }
        case .blackout: blackout.toggle()
        case .stop: stop()
        case .text: break
        }
    }
    func boardRelease(_ c: BoardControl) {
        guard c.behavior == .momentary else { return }
        if c.action == .layer, let id = c.targetID { releaseLayer(id: id) }
        if c.action == .effect, let i = project.effects.firstIndex(where: { $0.id == c.targetID }) { project.effects[i].enabled = false }
    }
}
struct LiveBoardView: View {
    @EnvironmentObject var store: LightingStore
    @State private var editing = false
    @State private var selected: UUID? = nil
    @State private var held: Set<UUID> = []
    @State private var acquired: Set<UUID> = []
    private var controls: [BoardControl] { store.project.liveBoard?.controls ?? [] }
    private func tint(_ name: String) -> Color { switch name { case "blue": return .blue; case "orange": return .orange; case "pink": return .pink; case "white": return .white; default: return .mint } }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button(editing ? "Done editing" : "Edit board") { releaseHeld(); editing.toggle() }
                if editing {
                    Button("Add button") { add(text: false) }
                    Button("Add text") { add(text: true) }
                }
                Spacer()
                Text(editing ? "Drag controls to arrange. Select one to edit." : "Custom live board").font(.caption).foregroundStyle(.secondary)
            }
            HStack(alignment: .top) {
                ScrollView {
                    GeometryReader { geometry in
                        let cell = geometry.size.width / 12
                        ZStack(alignment: .topLeading) {
                            if editing {
                                Path { p in
                                    for n in 0...12 { p.move(to: CGPoint(x: CGFloat(n) * cell, y: 0)); p.addLine(to: CGPoint(x: CGFloat(n) * cell, y: 480)); p.move(to: CGPoint(x: 0, y: CGFloat(n) * 40)); p.addLine(to: CGPoint(x: geometry.size.width, y: CGFloat(n) * 40)) }
                                }.stroke(Color.white.opacity(0.08))
                            }
                            ForEach(controls) { c in
                                tile(c, cell: cell)
                                    .frame(width: CGFloat(c.width) * cell - 4, height: CGFloat(c.height) * 40 - 4)
                                    .offset(x: CGFloat(c.column) * cell, y: CGFloat(c.row) * 40)
                            }
                        }
                    }.frame(height: 480)
                }
                if editing, let id = selected, let i = controls.firstIndex(where: { $0.id == id }) { inspector(i).frame(width: 240) }
            }
            if controls.isEmpty { Text("Choose Edit board to add buttons and text.").font(.caption).foregroundStyle(.secondary) }
        }.onDisappear { releaseHeld() }
    }
    private func face(_ c: BoardControl) -> some View {
        Text(c.label).font(.system(size: CGFloat(c.fontSize), weight: .semibold)).multilineTextAlignment(.center).frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(c.action == .text ? Color.clear : tint(c.color).opacity(store.boardActive(c) ? 0.6 : 0.18), in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(selected == c.id && editing ? Color.white : tint(c.color).opacity(c.action == .text ? 0 : 0.7), lineWidth: store.boardActive(c) ? 2 : 1))
    }
    @ViewBuilder private func tile(_ c: BoardControl, cell: CGFloat) -> some View {
        if editing {
            face(c).contentShape(Rectangle()).onTapGesture { selected = c.id }.gesture(DragGesture().onEnded { v in
                selected = c.id
                guard let i = controls.firstIndex(where: { $0.id == c.id }) else { return }
                store.project.liveBoard?.controls[i].column = min(12 - c.width, max(0, c.column + Int((v.translation.width / cell).rounded())))
                store.project.liveBoard?.controls[i].row = min(12 - c.height, max(0, c.row + Int((v.translation.height / 40).rounded())))
            })
        } else if c.action == .text { face(c) }
        else if c.behavior == .momentary {
            face(c).contentShape(Rectangle()).gesture(DragGesture(minimumDistance: 0).onChanged { _ in
                if held.insert(c.id).inserted, !store.boardActive(c) { acquired.insert(c.id); store.boardPress(c) }
            }.onEnded { _ in
                held.remove(c.id)
                if acquired.remove(c.id) != nil { store.boardRelease(c) }
            }).accessibilityLabel("Hold \(c.label)").accessibilityAddTraits(.isButton)
        } else { Button { store.boardPress(c) } label: { face(c) }.buttonStyle(.plain).accessibilityLabel(c.label) }
    }
    private func add(text: Bool) {
        var c = BoardControl(); c.action = text ? .text : .cue; c.label = text ? "Heading" : "New button"
        c.targetID = text ? nil : store.project.cues.first?.id
        c.row = min(11, controls.count / 6); c.column = (controls.count % 6) * 2
        if store.project.liveBoard == nil { store.project.liveBoard = LiveBoard() }
        store.project.liveBoard?.controls.append(c); selected = c.id
    }
    private func releaseHeld() {
        for c in controls where acquired.contains(c.id) { store.boardRelease(c) }
        held = []; acquired = []
    }
    private func binding<T>(_ i: Int, _ key: WritableKeyPath<BoardControl, T>) -> Binding<T> {
        Binding(get: { controls[i][keyPath: key] }, set: { store.project.liveBoard?.controls[i][keyPath: key] = $0 })
    }
    private func inspector(_ i: Int) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                TextField("Label", text: binding(i, \.label)).textFieldStyle(.roundedBorder)
                Picker("Action", selection: Binding(get: { controls[i].action }, set: { a in
                    store.project.liveBoard?.controls[i].action = a; store.project.liveBoard?.controls[i].targetID = nil; store.project.liveBoard?.controls[i].behavior = .trigger
                })) { ForEach(BoardAction.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) } }
                Picker("Target", selection: binding(i, \.targetID)) {
                    Text("Choose…").tag(nil as UUID?)
                    if controls[i].action == .cue { ForEach(store.project.cues) { Text($0.name).tag(Optional($0.id)) } }
                    if controls[i].action == .layer { ForEach(store.project.layerCues ?? []) { Text($0.name).tag(Optional($0.id)) } }
                    if controls[i].action == .effect { ForEach(store.project.effects) { Text($0.name).tag(Optional($0.id)) } }
                }.disabled(![.cue, .layer, .effect].contains(controls[i].action))
                if [.layer, .effect].contains(controls[i].action) {
                    Picker("Behavior", selection: binding(i, \.behavior)) { ForEach(BoardBehavior.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) } }
                }
                Picker("Color", selection: binding(i, \.color)) { ForEach(["mint", "blue", "orange", "pink", "white"], id: \.self) { Text($0.capitalized).tag($0) } }
                Stepper("Font \(controls[i].fontSize)", value: binding(i, \.fontSize), in: 10...36)
                Stepper("Width \(controls[i].width)", value: binding(i, \.width), in: 1...(12 - controls[i].column))
                Stepper("Height \(controls[i].height)", value: binding(i, \.height), in: 1...(12 - controls[i].row))
                Button("Delete control", role: .destructive) { store.project.liveBoard?.controls.remove(at: i); selected = nil }
            }.font(.caption)
        }
    }
}
