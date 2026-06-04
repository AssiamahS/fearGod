import Foundation

struct Book: Identifiable, Hashable {
    let id: Int
    let nameEn: String
    let nameTwi: String
    let abbrev: String
    let testament: Int  // 0 = OT, 1 = NT
}

struct Verse: Identifiable {
    let id: Int
    let bookId: Int
    let chapter: Int
    let verse: Int
    let kjv: String
    let twi: String?
}
