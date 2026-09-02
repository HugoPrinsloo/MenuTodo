import SwiftUI

private enum RowFocus: Hashable {
    case title
    case new
    case row(UUID)
}

struct TodoListView: View {
    @Environment(TodoStore.self) private var store
    @Environment(UpdateChecker.self) private var updateChecker
    @State private var newTitle: String = ""
    @State private var isHoveringCard: Bool = false
    @State private var showingSettings: Bool = false
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
                if let banner = updateChecker.bannerVersion {
                    updateBanner(version: banner.version, url: banner.url)
                }

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
        .animation(.easeInOut(duration: 0.2), value: updateChecker.bannerVersion?.version)
        .onHover { hovering in
            isHoveringCard = hovering
        }
        .onAppear {
            focusedField = .new
            updateChecker.checkIfDue()
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

    private var rows: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(store.todos) { todo in
                TodoRow(todo: todo, focusedField: $focusedField)
            }

            NewTodoRow(newTitle: $newTitle, focusedField: $focusedField)
        }
        .coordinateSpace(name: TodoRow.rowsSpace)
    }

    private var footer: some View {
        HStack(spacing: 10) {
            if !store.todos.isEmpty {
                Text("\(openCount) left")
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

private struct TodoRow: View {
    @Environment(TodoStore.self) private var store
    let todo: Todo
    var focusedField: FocusState<RowFocus?>.Binding
    @State private var isHovering: Bool = false
    @State private var isDragging: Bool = false

    static let rowsSpace = "rows"
    static let rowHeight: CGFloat = 28

    private var titleBinding: Binding<String> {
        Binding(
            get: { todo.title },
            set: { store.rename(todo.id, to: $0) }
        )
    }

    var body: some View {
        HStack(spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    store.toggle(todo.id)
                }
            } label: {
                Image(systemName: todo.isDone ? "checkmark.square.fill" : "square")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(todo.isDone ? Color("Ink") : Color("InkSecondary"))
            }
            .buttonStyle(.plain)

            TextField("", text: titleBinding)
                .textFieldStyle(.plain)
                .font(.system(size: 13, design: .monospaced))
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

            Spacer()

            // Drag grip: the text field swallows mouse-downs, so the drag
            // gesture lives on this handle rather than the whole row.
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(Color("InkSecondary"))
                .frame(width: 16, height: 16)
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
                    .frame(width: 16, height: 16)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .opacity(isHovering ? 1 : 0)
        }
        .animation(.easeOut(duration: 0.12), value: isHovering)
        .frame(height: Self.rowHeight)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color("Ink").opacity(isDragging ? 0.08 : 0))
                .padding(.horizontal, -6)
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
    /// pointer's y position in the rows' coordinate space. Rows are fixed-height,
    /// so the slot is simple arithmetic; called repeatedly during a drag.
    private func reorder(toRowAt y: CGFloat) {
        guard let sourceIndex = store.todos.firstIndex(where: { $0.id == todo.id }) else { return }
        let slot = Int((y / Self.rowHeight).rounded(.down))
        let targetIndex = min(max(slot, 0), store.todos.count - 1)
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
        HStack(spacing: 8) {
            Image(systemName: "square")
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(Color("InkSecondary"))

            TextField("", text: $newTitle)
                .textFieldStyle(.plain)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(Color("Ink"))
                .focused(focusedField, equals: .new)
                .overlay(alignment: .leading) {
                    if newTitle.isEmpty {
                        Text("New todo…")
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundStyle(Color("InkSecondary"))
                            .allowsHitTesting(false)
                    }
                }
                .onSubmit {
                    store.add(newTitle)
                    newTitle = ""
                    focusedField.wrappedValue = .new
                }

            Spacer()
        }
        .frame(minHeight: 28)
    }
}
