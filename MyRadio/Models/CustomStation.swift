import Foundation

struct CustomStation: Codable, Identifiable {
    var id: UUID
    var name: String
    var url: String
    var country: String?
    var language: String?
    var tags: String?
    var bitrate: Int?
    var addedAt: Date
}
