import Foundation
import os

@Observable
@MainActor
final class TodoStore {
    private static let logger = Logger(subsystem: "com.hugoprinsloo.MenuTodo", category: "TodoStore")

    var todos: [Todo]

    var title: String {
        didSet {
            UserDefaults.standard.set(title, forKey: Self.titleDefaultsKey)
        }
    }

    var autoSortDone: Bool {
        didSet {
            UserDefaults.standard.set(autoSortDone, forKey: Self.autoSortDoneDefaultsKey)
            normalizeOrder()
        }
    }

    private static let titleDefaultsKey = "listTitle"
    private static let autoSortDoneDefaultsKey = "autoSortDone"

    private let fileURL: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        let directory = appSupport?.appendingPathComponent("MenuTodo", isDirectory: true)
        self.fileURL = directory?.appendingPathComponent("todos.json") ?? URL(fileURLWithPath: "/dev/null")

        if let directory {
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            } catch {
                Self.logger.error("Failed to create Application Support directory: \(error, privacy: .public)")
            }
        }

        self.todos = []
        self.todos = Self.load(from: fileURL)
        self.title = UserDefaults.standard.string(forKey: Self.titleDefaultsKey) ?? "Todo"
        self.autoSortDone = UserDefaults.standard.bool(forKey: Self.autoSortDoneDefaultsKey)
    }

    private static func load(from url: URL) -> [Todo] {
        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode([Todo].self, from: data)
            return decoded
        } catch {
            logger.error("Failed to load todos: \(error, privacy: .public)")
            return []
        }
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(todos)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            Self.logger.error("Failed to persist todos: \(error, privacy: .public)")
        }
    }

    func add(_ title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        todos.append(Todo(title: trimmed))
        normalizeOrder()
        persist()
    }

    func toggle(_ id: Todo.ID) {
        guard let index = todos.firstIndex(where: { $0.id == id }) else { return }
        todos[index].isDone.toggle()
        normalizeOrder()
        persist()
    }

    func rename(_ id: Todo.ID, to title: String) {
        guard let index = todos.firstIndex(where: { $0.id == id }) else { return }
        todos[index].title = title
        persist()
    }

    func delete(_ id: Todo.ID) {
        todos.removeAll { $0.id == id }
        persist()
    }

    func clearCompleted() {
        todos.removeAll { $0.isDone }
        persist()
    }

    func move(from source: IndexSet, to destination: Int) {
        todos.move(fromOffsets: source, toOffset: destination)
        normalizeOrder()
        persist()
    }

    /// When `autoSortDone` is on, stably partitions `todos` so open items come
    /// first and done items follow, preserving relative order within each group.
    private func normalizeOrder() {
        guard autoSortDone else { return }
        let sorted = todos.filter { !$0.isDone } + todos.filter { $0.isDone }
        guard sorted != todos else { return }
        todos = sorted
        persist()
    }
}
