import SwiftUI
import ServiceManagement
import os

private enum RowFocus: Hashable {
    case new
    case row(UUID)
}

struct TodoListView: View {
    @Environment(TodoStore.self) private var store
    @State private var newTitle: String = ""
    @State private var launchAtLogin: Bool = false
    @State private var isHoveringCard: Bool = false
    @FocusState private var focusedField: RowFocus?

    private static let logger = Logger(subsystem: "com.hugoprinsloo.MenuTodo", category: "TodoListView")

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

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
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
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .frame(width: 340)
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

    private var rows: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(store.todos) { todo in
                TodoRow(todo: todo, focusedField: $focusedField)
                Divider().overlay(Color("Rule"))
            }

            NewTodoRow(newTitle: $newTitle, focusedField: $focusedField)
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
