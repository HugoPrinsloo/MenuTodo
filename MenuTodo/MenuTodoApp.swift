import SwiftUI

@main
struct MenuTodoApp: App {
    @State private var store = TodoStore()
    #if !APPSTORE
    @State private var updateChecker = UpdateChecker()
    #endif

    private var openCount: Int {
        store.todos.filter { !$0.isDone }.count
    }

    var body: some Scene {
        MenuBarExtra {
            TodoListView()
                .environment(store)
                #if !APPSTORE
                .environment(updateChecker)
                .task {
                    updateChecker.checkIfDue()
                }
                #endif
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
