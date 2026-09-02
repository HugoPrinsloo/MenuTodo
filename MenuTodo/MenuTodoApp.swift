import SwiftUI

@main
struct MenuTodoApp: App {
    @State private var store = TodoStore()
    @State private var updateChecker = UpdateChecker()

    private var openCount: Int {
        store.todos.filter { !$0.isDone }.count
    }

    var body: some Scene {
        MenuBarExtra {
            TodoListView()
                .environment(store)
                .environment(updateChecker)
                .task {
                    updateChecker.checkIfDue()
                }
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
