import SwiftUI

/// Each row reports its frame in the rows' coordinate space so a drag can find
/// the slot under the pointer. Used only for drag targeting, never for layout,
/// so there is no measurement feedback loop.
private struct RowFramesKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] { [:] }
    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

private enum RowFocus: Hashable {
    case title
    case new
    case row(UUID)
}

/// Selectable estimate durations, in minutes; `nil` clears the estimate.
private let estimateOptions: [Int?] = [nil, 5, 15, 30, 45, 60, 90, 120, 180, 240]

/// Compact duration text, e.g. "15m", "1h", "1h 30m".
private func formattedEstimate(_ minutes: Int) -> String {
    let hours = minutes / 60
    let mins = minutes % 60
    if hours > 0 && mins > 0 {
        return "\(hours)h \(mins)m"
    } else if hours > 0 {
        return "\(hours)h"
    } else {
        return "\(mins)m"
    }
}

private func estimateLabel(_ minutes: Int?) -> String {
    guard let minutes else { return "None" }
    return formattedEstimate(minutes)
}

struct TodoListView: View {
    @Environment(TodoStore.self) private var store
    #if !APPSTORE
    @Environment(UpdateChecker.self) private var updateChecker
    #endif
    @State private var newTitle: String = ""
    @State private var isHoveringCard: Bool = false
    @State private var showingSettings: Bool = false
    @State private var rowFrames: [UUID: CGRect] = [:]
    @FocusState private var focusedField: RowFocus?

    private static let scrollHeight: CGFloat = 640
    private static let scrollThreshold = 20
    private static let minCardHeight: CGFloat = 140
    private static let footerHeight: CGFloat = 20

    private var hasCompleted: Bool {
        store.todos.contains { $0.isDone }
    }

    private var openCount: Int {
        store.todos.filter { !$0.isDone }.count
    }

    private var openEstimateMinutes: Int {
        store.todos.filter { !$0.isDone }.compactMap(\.estimateMinutes).reduce(0, +)
    }

    private var progressFraction: Double {
        let todos = store.todos
        guard !todos.isEmpty else { return 0 }

        let estimates = todos.compactMap(\.estimateMinutes).map(Double.init)
        let averageEstimate = estimates.isEmpty ? 1 : estimates.reduce(0, +) / Double(estimates.count)

        func weight(_ todo: Todo) -> Double {
            todo.estimateMinutes.map(Double.init) ?? averageEstimate
        }

        let totalWeight = todos.reduce(0) { $0 + weight($1) }
        let doneWeight = todos.filter(\.isDone).reduce(0) { $0 + weight($1) }
        return doneWeight / totalWeight
    }

    private var titleBinding: Binding<String> {
        Binding(
            get: { store.title },
            set: { store.title = $0 }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if showingSettings {
                SettingsView(showingSettings: $showingSettings)
            } else {
                #if !APPSTORE
                if let banner = updateChecker.bannerVersion {
                    updateBanner(version: banner.version, url: banner.url)
                }
                #endif

                TextField("Todo", text: titleBinding)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color("Ink"))
                    .focused($focusedField, equals: .title)
                    .padding(.bottom, 8)
                    .onSubmit {
                        let trimmed = store.title.trimmingCharacters(in: .whitespacesAndNewlines)
                        store.title = trimmed.isEmpty ? "Todo" : trimmed
                        focusedField = .new
                    }

                if !store.todos.isEmpty {
                    ProgressBar(fraction: progressFraction)
                        .padding(.bottom, 8)
                }

                if store.todos.count > Self.scrollThreshold {
                    ScrollView {
                        rows
                    }
                    .scrollIndicators(.hidden)
                    .frame(height: Self.scrollHeight)
                } else {
                    rows
                        .frame(minHeight: Self.minCardHeight - Self.footerHeight, alignment: .top)
                }

                footer
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .frame(width: 340)
        .fixedSize(horizontal: false, vertical: true)
        .background(Color("Paper").ignoresSafeArea())
        #if !APPSTORE
        .animation(.easeInOut(duration: 0.2), value: updateChecker.bannerVersion?.version)
        #endif
        .onHover { hovering in
            isHoveringCard = hovering
        }
        .onAppear {
            focusedField = .new
            #if !APPSTORE
            updateChecker.checkIfDue()
            #endif
            if store.sync.isConnected {
                Task { await store.sync.refresh() }
            }
        }
        .overlay(alignment: .topLeading) {
            Button("Quit MenuTodo") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
            .frame(width: 0, height: 0)
            .opacity(0)
        }
    }

    #if !APPSTORE
    private func updateBanner(version: String, url: URL) -> some View {
        HStack(spacing: 8) {
            Text("MenuTodo \(version) is available")
                .foregroundStyle(Color("Ink"))

            Spacer()

            Button("Download") {
                NSWorkspace.shared.open(url)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color("Ink"))

            Button("Skip") {
                updateChecker.skippedVersion = version
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color("InkSecondary"))
        }
        .font(.system(size: 11, design: .monospaced))
        .padding(.horizontal, 8)
        .frame(height: 28)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color("Ink").opacity(0.06)))
        .padding(.bottom, 8)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
    #endif

    private var rows: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(store.todos) { todo in
                TodoRow(todo: todo, focusedField: $focusedField, rowFrames: rowFrames, isCardHovered: isHoveringCard)
            }

            NewTodoRow(newTitle: $newTitle, focusedField: $focusedField)
        }
        .coordinateSpace(name: TodoRow.rowsSpace)
        .onPreferenceChange(RowFramesKey.self) { frames in
            rowFrames = frames
        }
    }

    private var footerLeftText: String {
        guard openEstimateMinutes > 0 else { return "\(openCount) left" }
        return "\(openCount) left · ~\(formattedEstimate(openEstimateMinutes))"
    }

    private var footer: some View {
        HStack(spacing: 10) {
            if !store.todos.isEmpty {
                Text(footerLeftText)
                    .foregroundStyle(Color("InkSecondary"))
            }

            Spacer()

            if hasCompleted {
                Button("Clear done") {
                    store.clearCompleted()
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color("InkSecondary"))
            }

            Menu {
                Button("Settings…") {
                    showingSettings = true
                }
                Button("Quit MenuTodo") {
                    NSApplication.shared.terminate(nil)
                }
            } label: {
                Text("…")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .foregroundStyle(Color("InkSecondary"))
            .fixedSize()
        }
        .font(.system(size: 11, design: .monospaced))
        .frame(height: Self.footerHeight)
        .opacity(isHoveringCard ? 1 : 0)
        .animation(.easeOut(duration: 0.15), value: isHoveringCard)
    }
}

/// Thin capsule showing the fraction of done todos. Hidden by the caller when
/// the list is empty.
private struct ProgressBar: View {
    let fraction: Double

    private static let height: CGFloat = 3

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color("Rule"))
                Capsule()
                    .fill(Color("Ink"))
                    .frame(width: proxy.size.width * fraction)
            }
        }
        .frame(height: Self.height)
        .animation(.easeOut(duration: 0.2), value: fraction)
    }
}

private struct TodoRow: View {
    @Environment(TodoStore.self) private var store
    let todo: Todo
    var focusedField: FocusState<RowFocus?>.Binding
    let rowFrames: [UUID: CGRect]
    let isCardHovered: Bool
    @State private var isHovering: Bool = false
    @State private var isDragging: Bool = false

    static let rowsSpace = "rows"
    /// Height of a single-line row; icons sit in a frame this tall so they line
    /// up with the first line of a wrapped title.
    static let lineHeight: CGFloat = 28

    private var showsEstimateMenu: Bool {
        todo.estimateMinutes != nil || isCardHovered
    }

    private var titleBinding: Binding<String> {
        Binding(
            get: { todo.title },
            set: { store.rename(todo.id, to: $0) }
        )
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    store.toggle(todo.id)
                }
            } label: {
                Image(systemName: todo.isDone ? "checkmark.square.fill" : "square")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(todo.isDone ? Color("Ink") : Color("InkSecondary"))
                    .frame(height: Self.lineHeight)
            }
            .buttonStyle(.plain)

            TextField("", text: titleBinding, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...8)
                .font(.system(size: 13, design: .monospaced))
                .padding(.vertical, 5)
                .strikethrough(todo.isDone)
                .foregroundStyle(todo.isDone ? Color("InkSecondary") : Color("Ink"))
                .focused(focusedField, equals: .row(todo.id))
                .onSubmit {
                    focusedField.wrappedValue = .new
                }
                .onKeyPress(.delete) {
                    guard todo.title.isEmpty else { return .ignored }
                    store.delete(todo.id)
                    return .handled
                }
                .onKeyPress(.upArrow, phases: .down) { (press: KeyPress) -> KeyPress.Result in
                    guard press.modifiers.contains(.option) else { return .ignored }
                    move(by: -1)
                    return .handled
                }
                .onKeyPress(.downArrow, phases: .down) { (press: KeyPress) -> KeyPress.Result in
                    guard press.modifiers.contains(.option) else { return .ignored }
                    move(by: 1)
                    return .handled
                }

            Spacer(minLength: 0)

            Menu {
                ForEach(estimateOptions, id: \.self) { option in
                    Button {
                        store.setEstimate(option, for: todo.id)
                    } label: {
                        if todo.estimateMinutes == option {
                            Label(estimateLabel(option), systemImage: "checkmark")
                        } else {
                            Text(estimateLabel(option))
                        }
                    }
                }
            } label: {
                Group {
                    if let minutes = todo.estimateMinutes {
                        Text(formattedEstimate(minutes))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(Color("InkSecondary"))
                    } else {
                        Image(systemName: "clock")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(Color("InkSecondary"))
                    }
                }
                .frame(height: Self.lineHeight)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            // A borderless Menu is drawn by AppKit, which ignores opacity set
            // inside its label; fade the Menu itself so the clock only shows
            // while the card is hovered. Estimated rows always show their text.
            .opacity(showsEstimateMenu ? 1 : 0)
            .animation(.easeOut(duration: 0.12), value: showsEstimateMenu)
            .allowsHitTesting(showsEstimateMenu)

            // Drag grip: the text field swallows mouse-downs, so the drag
            // gesture lives on this handle rather than the whole row.
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(Color("InkSecondary"))
                .frame(width: 16, height: Self.lineHeight)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 2, coordinateSpace: .named(Self.rowsSpace))
                        .onChanged { value in
                            isDragging = true
                            reorder(toRowAt: value.location.y)
                        }
                        .onEnded { _ in
                            isDragging = false
                        }
                )
                .onHover { inside in
                    if inside { NSCursor.openHand.push() } else { NSCursor.pop() }
                }
                .opacity(isHovering ? 1 : 0)

            Button {
                store.delete(todo.id)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color("InkSecondary"))
                    .frame(width: 16, height: Self.lineHeight)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .opacity(isHovering ? 1 : 0)
        }
        .animation(.easeOut(duration: 0.12), value: isHovering)
        .frame(minHeight: Self.lineHeight)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color("Ink").opacity(isDragging ? 0.08 : 0))
                .padding(.horizontal, -6)
        )
        .background(
            GeometryReader { proxy in
                Color.clear.preference(
                    key: RowFramesKey.self,
                    value: [todo.id: proxy.frame(in: .named(Self.rowsSpace))]
                )
            }
        )
        .zIndex(isDragging ? 1 : 0)
        .onHover { hovering in
            isHovering = hovering
        }
    }

    private func move(by offset: Int) {
        guard let sourceIndex = store.todos.firstIndex(where: { $0.id == todo.id }) else { return }
        let targetIndex = sourceIndex + offset
        guard store.todos.indices.contains(targetIndex) else { return }
        let destination = sourceIndex < targetIndex ? targetIndex + 1 : targetIndex
        store.move(from: IndexSet(integer: sourceIndex), to: destination)
        focusedField.wrappedValue = .row(todo.id)
    }

    /// Moves this row so that it occupies the slot under the pointer, given the
    /// pointer's y position in the rows' coordinate space. Rows wrap and vary in
    /// height, so the slot comes from the measured row frames; called repeatedly
    /// during a drag.
    private func reorder(toRowAt y: CGFloat) {
        guard let sourceIndex = store.todos.firstIndex(where: { $0.id == todo.id }) else { return }
        var targetIndex = store.todos.count - 1
        for (index, other) in store.todos.enumerated() {
            guard let frame = rowFrames[other.id] else { continue }
            if y < frame.maxY { targetIndex = index; break }
        }
        targetIndex = min(max(targetIndex, 0), store.todos.count - 1)
        guard targetIndex != sourceIndex else { return }
        let destination = sourceIndex < targetIndex ? targetIndex + 1 : targetIndex
        withAnimation(.easeOut(duration: 0.12)) {
            store.move(from: IndexSet(integer: sourceIndex), to: destination)
        }
    }
}

private struct NewTodoRow: View {
    @Environment(TodoStore.self) private var store
    @Binding var newTitle: String
    var focusedField: FocusState<RowFocus?>.Binding

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "square")
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(Color("InkSecondary"))
                .frame(height: TodoRow.lineHeight)

            TextField("", text: $newTitle, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...8)
                .font(.system(size: 13, design: .monospaced))
                .padding(.vertical, 5)
                .foregroundStyle(Color("Ink"))
                .focused(focusedField, equals: .new)
                .overlay(alignment: .topLeading) {
                    if newTitle.isEmpty {
                        Text("New todo…")
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundStyle(Color("InkSecondary"))
                            .padding(.vertical, 5)
                            .allowsHitTesting(false)
                    }
                }
                .onSubmit {
                    store.add(newTitle)
                    newTitle = ""
                    focusedField.wrappedValue = .new
                }

            Spacer(minLength: 0)
        }
        .frame(minHeight: TodoRow.lineHeight)
    }
}
