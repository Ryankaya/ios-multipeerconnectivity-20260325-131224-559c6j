import Foundation

struct BoardNote: Identifiable, Codable, Hashable {
    let id: UUID
    let text: String
    let authorName: String
    let createdAt: Date
    let tint: NoteTint

    init(
        id: UUID = UUID(),
        text: String,
        authorName: String,
        createdAt: Date = Date(),
        tint: NoteTint
    ) {
        self.id = id
        self.text = text
        self.authorName = authorName
        self.createdAt = createdAt
        self.tint = tint
    }
}

enum NoteTint: String, Codable, CaseIterable, Hashable {
    case amber
    case mint
    case coral
    case sky
}
