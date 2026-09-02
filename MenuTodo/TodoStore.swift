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

    /// `calendarIdentifier` of the mirrored Reminders list, or nil when off.
    var reminderListID: String? {
        didSet {
            UserDefaults.standard.set(reminderListID, forKey: Self.reminderListIDDefaultsKey)
        }
    }

    /// Short message for the settings UI; deliberately not persisted.
    var syncStatus: String?

    @ObservationIgnored private(set) var sync: ReminderSync!

    private static let titleDefaultsKey = "listTitle"
    private static let autoSortDoneDefaultsKey = "autoSortDone"
    private static let reminderListIDDefaultsKey = "reminderListID"

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
        self.reminderListID = UserDefaults.standard.string(forKey: Self.reminderListIDDefaultsKey)

        self.sync = ReminderSync(store: self)
        if reminderListID != nil, sync.authorizationStatus == .fullAccess {
            sync.beginObserving()
            Task { await sync.refresh() }
        }
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

    func persist() {
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
        let todo = Todo(title: trimmed)
        todos.append(todo)
        normalizeOrder()
        persist()
        sync.pushAdd(todo.id)
    }

    func toggle(_ id: Todo.ID) {
        guard let index = todos.firstIndex(where: { $0.id == id }) else { return }
        todos[index].isDone.toggle()
        normalizeOrder()
        persist()
        sync.pushToggle(id)
    }

    func rename(_ id: Todo.ID, to title: String) {
        guard let index = todos.firstIndex(where: { $0.id == id }) else { return }
        todos[index].title = title
        persist()
        sync.pushRename(id)
    }

    func delete(_ id: Todo.ID) {
        let reminderIDs = todos.filter { $0.id == id }.compactMap(\.reminderID)
        todos.removeAll { $0.id == id }
        persist()
        sync.pushDelete(reminderIDs)
    }

    func clearCompleted() {
        let reminderIDs = todos.filter(\.isDone).compactMap(\.reminderID)
        todos.removeAll { $0.isDone }
        persist()
        sync.pushDelete(reminderIDs)
    }

    /// Reordering isn't pushed — Reminders lists have no order of their own.
    func move(from source: IndexSet, to destination: Int) {
        todos.move(fromOffsets: source, toOffset: destination)
        normalizeOrder()
        persist()
    }

    /// When `autoSortDone` is on, stably partitions `todos` so open items come
    /// first and done items follow, preserving relative order within each group.
    func normalizeOrder() {
        guard autoSortDone else { return }
        let sorted = todos.filter { !$0.isDone } + todos.filter { $0.isDone }
        guard sorted != todos else { return }
        todos = sorted
        persist()
    }
}
