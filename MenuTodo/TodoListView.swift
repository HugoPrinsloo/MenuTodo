import SwiftUI
import ServiceManagement
import os

private enum RowFocus: Hashable {
    case new
    case row(UUID)
}

/// Reports the measured height of its content up through the view tree so the
/// scroll area can be sized to exactly fit the todos instead of expanding to
/// fill the popover.
private struct ContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat { 0 }
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct TodoListView: View {
    @Environment(TodoStore.self) private var store
    @State private var newTitle: String = ""
    @State private var launchAtLogin: Bool = false
    @State private var isHoveringCard: Bool = false
    @State private var contentHeight: CGFloat = TodoListView.rowHeight
    @FocusState private var focusedField: RowFocus?

    private static let logger = Logger(subsystem: "com.hugoprinsloo.MenuTodo", category: "TodoListView")

    private static let rowHeight: CGFloat = 26
    private static let maxScrollHeight: CGFloat = 640
    private static let minCardHeight: CGFloat = 140
    private static let footerHeight: CGFloat = 20

    private var hasCompleted: Bool {
        store.todos.contains { $0.isDone }
    }

    private var openCount: Int {
        store.todos.filter { !$0.isDone }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(store.todos) { todo in
                        TodoRow(todo: todo, focusedField: $focusedField)
                        Divider().overlay(Color("Rule"))
                    }

                    NewTodoRow(newTitle: $newTitle, focusedField: $focusedField)
                }
                .background(
                    GeometryReader { proxy in
                        Color.clear.preference(key: ContentHeightKey.self, value: proxy.size.height)
                    }
                )
            }
            .scrollIndicators(.hidden)
            .onPreferenceChange(ContentHeightKey.self) { height in
                contentHeight = height
            }
            .frame(height: min(contentHeight, Self.maxScrollHeight))

            footer
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .frame(width: 340)
        .frame(minHeight: Self.minCardHeight)
        .fixedSize(horizontal: false, vertical: true)
        .background(Color("Paper").ignoresSafeArea())
        .onHover { hovering in
            isHoveringCard = hovering
        }
        .onAppear {
            focusedField = .new
            launchAtLogin = SMAppService.mainApp.status == .enabled
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
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        setLaunchAtLogin(newValue)
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

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            Self.logger.error("Failed to update Launch at Login: \(error, privacy: .public)")
        }
    }
}

private struct TodoRow: View {
    @Environment(TodoStore.self) private var store
    let todo: Todo
    var focusedField: FocusState<RowFocus?>.Binding
    @State private var isHovering: Bool = false

    private var titleBinding: Binding<String> {
        Binding(
            get: { todo.title },
            set: { store.rename(todo.id, to: $0) }
        )
    }

    var body: some View {
        HStack(spacing: 8) {
            Button {
                store.toggle(todo.id)
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

            Spacer()

            if isHovering {
                Button {
                    store.delete(todo.id)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Color("InkSecondary"))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(minHeight: 26)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
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
        .frame(minHeight: 26)
    }
}
