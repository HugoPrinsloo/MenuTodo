import SwiftUI
import ServiceManagement
import os

struct TodoListView: View {
    @Environment(TodoStore.self) private var store
    @State private var newTitle: String = ""
    @State private var launchAtLogin: Bool = false
    @FocusState private var isFieldFocused: Bool

    private static let logger = Logger(subsystem: "com.hugoprinsloo.MenuTodo", category: "TodoListView")

    private var hasCompleted: Bool {
        store.todos.contains { $0.isDone }
    }

    var body: some View {
        VStack(spacing: 0) {
            TextField("Add a todo…", text: $newTitle)
                .textFieldStyle(.plain)
                .padding(8)
                .focused($isFieldFocused)
                .onSubmit {
                    store.add(newTitle)
                    newTitle = ""
                    isFieldFocused = true
                }

            Divider()

            if store.todos.isEmpty {
                Text("Nothing to do")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.vertical, 32)
            } else {
                List {
                    ForEach(store.todos) { todo in
                        TodoRow(todo: todo)
                    }
                    .onMove { source, destination in
                        store.move(from: source, to: destination)
                    }
                    .onDelete { offsets in
                        for index in offsets {
                            store.delete(store.todos[index].id)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .frame(maxHeight: 340)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Button("Clear completed") {
                    store.clearCompleted()
                }
                .disabled(!hasCompleted)

                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        setLaunchAtLogin(newValue)
                    }

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q", modifiers: .command)
            }
            .padding(10)
        }
        .frame(width: 320)
        .onAppear {
            isFieldFocused = true
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
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
    @State private var isHovering: Bool = false

    var body: some View {
        HStack {
            Toggle("", isOn: Binding(
                get: { todo.isDone },
                set: { _ in store.toggle(todo.id) }
            ))
            .toggleStyle(.checkbox)
            .labelsHidden()

            Text(todo.title)
                .strikethrough(todo.isDone)
                .foregroundStyle(todo.isDone ? .secondary : .primary)

            Spacer()

            if isHovering {
                Button {
                    store.delete(todo.id)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
        }
    }
}
