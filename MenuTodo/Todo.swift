import Foundation

struct Todo: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var isDone: Bool
    var createdAt: Date
    /// `calendarItemIdentifier` of the mirrored EventKit reminder, when synced.
    var reminderID: String?
    /// Estimated time to complete, in minutes. Local-only; never synced to Reminders.
    var estimateMinutes: Int?

    init(
        id: UUID = UUID(),
        title: String,
        isDone: Bool = false,
        createdAt: Date = Date(),
        reminderID: String? = nil,
        estimateMinutes: Int? = nil
    ) {
        self.id = id
        self.title = title
        self.isDone = isDone
        self.createdAt = createdAt
        self.reminderID = reminderID
        self.estimateMinutes = estimateMinutes
    }
}
