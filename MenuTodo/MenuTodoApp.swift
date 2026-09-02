import SwiftUI

@main
struct MenuTodoApp: App {
    @State private var store = TodoStore()

    private var openCount: Int {
        store.todos.filter { !$0.isDone }.count
    }

    var body: some Scene {
        MenuBarExtra {
            TodoListView()
                .environment(store)
        } label: {
            if openCount > 0 {
                Label("\(openCount)", systemImage: "checklist")
            } else {
                Image(systemName: "checklist")
            }
        }
        .menuBarExtraStyle(.window)
    }
}
