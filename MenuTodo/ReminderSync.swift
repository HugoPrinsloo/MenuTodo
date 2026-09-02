import EventKit
import Foundation
import os

/// Two-way mirror between the local todo list and one Reminders list.
///
/// Local order is ours to keep — Reminders has no ordering — but for any todo
/// that carries a `reminderID`, Reminders owns existence, title and done state.
@MainActor
final class ReminderSync {
    private static let logger = Logger(subsystem: "com.hugoprinsloo.MenuTodo", category: "ReminderSync")

    /// Completed reminders older than this are never imported as local todos.
    private static let completedRetention: TimeInterval = 30 * 24 * 60 * 60
    private static let changeDebounce: Duration = .milliseconds(500)
    private static let renameDebounce: Duration = .milliseconds(600)

    private static let failureStatus = "Couldn't update Reminders"

    private unowned let store: TodoStore
    private let eventStore = EKEventStore()

    private var observationTask: Task<Void, Never>?
    private var pullTask: Task<Void, Never>?
    private var renameTasks: [Todo.ID: Task<Void, Never>] = [:]

    /// True while we are writing remote state into the store, so the store's
    /// push hooks don't echo those mutations straight back to EventKit.
    private var isApplyingRemote = false

    init(store: TodoStore) {
        self.store = store
    }

    // MARK: - Access

    var authorizationStatus: EKAuthorizationStatus {
        EKEventStore.authorizationStatus(for: .reminder)
    }

    var isConnected: Bool {
        store.reminderListID != nil
    }

    var connectedListTitle: String? {
        calendar?.title
    }

    func availableLists() -> [EKCalendar] {
        eventStore.calendars(for: .reminder)
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    func requestAccess() async -> Bool {
        do {
            return try await eventStore.requestFullAccessToReminders()
        } catch {
            Self.logger.error("Failed to request Reminders access: \(error, privacy: .public)")
            return false
        }
    }

    // MARK: - Connecting

    func connect(listID: String) async {
        if authorizationStatus != .fullAccess {
            guard await requestAccess() else {
                store.syncStatus = "Reminders access was denied"
                return
            }
        }

        guard let calendar = eventStore.calendar(withIdentifier: listID) else {
            Self.logger.error("No Reminders list with identifier \(listID, privacy: .public)")
            store.syncStatus = "Couldn't open that list"
            return
        }

        store.reminderListID = listID
        store.syncStatus = nil
        await initialMerge(in: calendar)
        beginObserving()
    }

    func disconnect() {
        stopObserving()
        store.reminderListID = nil
        for index in store.todos.indices {
            store.todos[index].reminderID = nil
        }
        store.persist()
        store.syncStatus = nil
    }

    /// Called on popover appear, and once at launch when already connected.
    func refresh() async {
        guard isConnected else { return }
        await pullFromReminders()
    }

    // MARK: - Observing

    func beginObserving() {
        guard observationTask == nil else { return }
        observationTask = Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(named: .EKEventStoreChanged) {
                guard let self else { return }
                self.schedulePull()
            }
        }
    }

    private func stopObserving() {
        observationTask?.cancel()
        observationTask = nil
        pullTask?.cancel()
        pullTask = nil
        for task in renameTasks.values { task.cancel() }
        renameTasks.removeAll()
    }

    /// EventKit also fires a change notification for our own commits; the
    /// debounce collapses those bursts and the pull then finds nothing differs.
    private func schedulePull() {
        pullTask?.cancel()
        pullTask = Task { [weak self] in
            try? await Task.sleep(for: Self.changeDebounce)
            guard !Task.isCancelled, let self else { return }
            self.pullTask = nil
            await self.pullFromReminders()
        }
    }

    // MARK: - Reconciliation

    /// Adopts same-titled reminders, creates reminders for the rest of the local
    /// list, and imports whatever reminders nothing claimed.
    private func initialMerge(in calendar: EKCalendar) async {
        let reminders = await fetchReminders(in: calendar)

        isApplyingRemote = true
        defer { isApplyingRemote = false }

        var claimed = Set(store.todos.compactMap(\.reminderID))
        var unclaimed = reminders.filter { !claimed.contains($0.calendarItemIdentifier) }
        var pendingCreations: [(index: Int, reminder: EKReminder)] = []

        for index in store.todos.indices where store.todos[index].reminderID == nil {
            let key = matchKey(store.todos[index].title)
            if let match = unclaimed.firstIndex(where: { matchKey($0.title ?? "") == key }) {
                let reminder = unclaimed.remove(at: match)
                store.todos[index].reminderID = reminder.calendarItemIdentifier
                store.todos[index].isDone = reminder.isCompleted
                claimed.insert(reminder.calendarItemIdentifier)
            } else {
                let reminder = EKReminder(eventStore: eventStore)
                reminder.title = store.todos[index].title
                reminder.isCompleted = store.todos[index].isDone
                reminder.calendar = calendar
                do {
                    try eventStore.save(reminder, commit: false)
                    pendingCreations.append((index, reminder))
                } catch {
                    report(error, "create reminder during merge")
                }
            }
        }

        if !pendingCreations.isEmpty {
            do {
                try eventStore.commit()
                // Identifiers are only dependable once the batch is committed.
                for creation in pendingCreations {
                    store.todos[creation.index].reminderID = creation.reminder.calendarItemIdentifier
                }
            } catch {
                report(error, "commit reminders during merge")
            }
        }

        for reminder in unclaimed where !isStaleCompletion(reminder) {
            store.todos.append(Todo(
                title: reminder.title ?? "",
                isDone: reminder.isCompleted,
                reminderID: reminder.calendarItemIdentifier
            ))
        }

        store.persist()
        store.normalizeOrder()
    }

    /// Pulls remote existence, title and done state onto the local list.
    private func pullFromReminders() async {
        guard let calendar else { return }
        let reminders = await fetchReminders(in: calendar)
        let byIdentifier = Dictionary(
            reminders.map { ($0.calendarItemIdentifier, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        isApplyingRemote = true
        defer { isApplyingRemote = false }

        var updated: [Todo] = []
        updated.reserveCapacity(store.todos.count)
        var changed = false

        for todo in store.todos {
            guard let reminderID = todo.reminderID else {
                updated.append(todo)
                continue
            }
            guard let reminder = byIdentifier[reminderID] else {
                // Deleted in Reminders, so drop it here too.
                changed = true
                continue
            }

            var todo = todo
            // A rename we haven't pushed yet would otherwise be clobbered by the
            // still-stale remote title.
            if renameTasks[todo.id] == nil, let remoteTitle = reminder.title, remoteTitle != todo.title {
                todo.title = remoteTitle
                changed = true
            }
            if todo.isDone != reminder.isCompleted {
                todo.isDone = reminder.isCompleted
                changed = true
            }
            updated.append(todo)
        }

        let mapped = Set(updated.compactMap(\.reminderID))
        for reminder in reminders where !mapped.contains(reminder.calendarItemIdentifier) {
            guard !isStaleCompletion(reminder) else { continue }
            updated.append(Todo(
                title: reminder.title ?? "",
                isDone: reminder.isCompleted,
                reminderID: reminder.calendarItemIdentifier
            ))
            changed = true
        }

        guard changed else { return }
        store.todos = updated
        store.persist()
        store.normalizeOrder()
    }

    // MARK: - Pushing local changes

    func pushAdd(_ id: Todo.ID) {
        guard canPush, let calendar else { return }
        guard let index = store.todos.firstIndex(where: { $0.id == id }) else { return }

        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = store.todos[index].title
        reminder.isCompleted = store.todos[index].isDone
        reminder.calendar = calendar
        do {
            try eventStore.save(reminder, commit: true)
            store.todos[index].reminderID = reminder.calendarItemIdentifier
            store.persist()
            store.syncStatus = nil
        } catch {
            report(error, "create reminder")
        }
    }

    func pushToggle(_ id: Todo.ID) {
        guard canPush else { return }
        guard let index = store.todos.firstIndex(where: { $0.id == id }) else { return }
        guard let reminder = reminder(for: store.todos[index]) else {
            recreate(id)
            return
        }

        // EventKit fills in completionDate for us.
        reminder.isCompleted = store.todos[index].isDone
        save(reminder, "toggle reminder")
    }

    /// The row's text field fires per keystroke, so coalesce into one save.
    func pushRename(_ id: Todo.ID) {
        guard canPush else { return }
        renameTasks[id]?.cancel()
        renameTasks[id] = Task { [weak self] in
            try? await Task.sleep(for: Self.renameDebounce)
            guard !Task.isCancelled, let self else { return }
            self.renameTasks[id] = nil
            self.commitRename(id)
        }
    }

    func pushDelete(_ reminderIDs: [String]) {
        guard canPush, !reminderIDs.isEmpty else { return }
        for reminderID in reminderIDs {
            guard let reminder = eventStore.calendarItem(withIdentifier: reminderID) as? EKReminder else { continue }
            do {
                try eventStore.remove(reminder, commit: true)
                store.syncStatus = nil
            } catch {
                report(error, "remove reminder")
            }
        }
    }

    private func commitRename(_ id: Todo.ID) {
        guard canPush else { return }
        guard let index = store.todos.firstIndex(where: { $0.id == id }) else { return }
        guard let reminder = reminder(for: store.todos[index]) else {
            recreate(id)
            return
        }

        reminder.title = store.todos[index].title
        save(reminder, "rename reminder")
    }

    /// The reminder went missing between syncs: forget the stale mapping and
    /// make a fresh reminder from the local todo.
    private func recreate(_ id: Todo.ID) {
        guard let index = store.todos.firstIndex(where: { $0.id == id }) else { return }
        store.todos[index].reminderID = nil
        store.persist()
        pushAdd(id)
    }

    private func save(_ reminder: EKReminder, _ action: String) {
        do {
            try eventStore.save(reminder, commit: true)
            store.syncStatus = nil
        } catch {
            report(error, action)
        }
    }

    // MARK: - Helpers

    private var canPush: Bool {
        isConnected && !isApplyingRemote
    }

    private var calendar: EKCalendar? {
        guard let listID = store.reminderListID, authorizationStatus == .fullAccess else { return nil }
        return eventStore.calendar(withIdentifier: listID)
    }

    private func reminder(for todo: Todo) -> EKReminder? {
        guard let reminderID = todo.reminderID else { return nil }
        return eventStore.calendarItem(withIdentifier: reminderID) as? EKReminder
    }

    private func matchKey(_ title: String) -> String {
        title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func isStaleCompletion(_ reminder: EKReminder) -> Bool {
        guard reminder.isCompleted, let completionDate = reminder.completionDate else { return false }
        return Date().timeIntervalSince(completionDate) > Self.completedRetention
    }

    private func fetchReminders(in calendar: EKCalendar) async -> [EKReminder] {
        let predicate = eventStore.predicateForReminders(in: [calendar])
        let batch: ReminderBatch = await withCheckedContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { reminders in
                continuation.resume(returning: ReminderBatch(reminders: reminders ?? []))
            }
        }
        return batch.reminders
    }

    /// EventKit delivers fetch results on its own queue. The reminders are inert
    /// by the time they reach us and every read and mutation of them happens
    /// back on the main actor, so carrying them across is safe here.
    private struct ReminderBatch: @unchecked Sendable {
        let reminders: [EKReminder]
    }

    private func report(_ error: any Error, _ action: String) {
        Self.logger.error("Failed to \(action, privacy: .public): \(error, privacy: .public)")
        store.syncStatus = Self.failureStatus
    }
}
