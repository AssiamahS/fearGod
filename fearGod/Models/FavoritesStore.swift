import Foundation
import Combine

struct VerseRef: Codable, Hashable {
    let bookId: Int
    let chapter: Int
    let verse: Int

    init(_ v: Verse) {
        bookId = v.bookId
        chapter = v.chapter
        verse = v.verse
    }
}

final class FavoritesStore: ObservableObject {
    static let shared = FavoritesStore()
    private static let key = "favoriteVerses"

    @Published private(set) var refs: [VerseRef] = []

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.key),
           let saved = try? JSONDecoder().decode([VerseRef].self, from: data) {
            refs = saved
        }
    }

    func isFavorite(_ verse: Verse) -> Bool {
        refs.contains(VerseRef(verse))
    }

    func toggle(_ verse: Verse) {
        let ref = VerseRef(verse)
        if let idx = refs.firstIndex(of: ref) {
            refs.remove(at: idx)
        } else {
            refs.insert(ref, at: 0)
        }
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(refs) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }
}
