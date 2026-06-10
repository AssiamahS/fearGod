import Foundation
import SQLite3

final class BibleDatabase {
    static let shared = BibleDatabase()
    private var db: OpaquePointer?

    private init() {
        guard let url = Bundle.main.url(forResource: "fearGod", withExtension: "sqlite") else {
            fatalError("fearGod.sqlite not found in bundle")
        }
        if sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READONLY, nil) != SQLITE_OK {
            fatalError("Cannot open fearGod.sqlite: \(String(cString: sqlite3_errmsg(db)))")
        }
    }

    deinit { sqlite3_close(db) }

    // MARK: - Books

    func allBooks() -> [Book] {
        var books: [Book] = []
        let sql = "SELECT id, name_en, name_twi, abbrev, testament FROM books ORDER BY id"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }
        while sqlite3_step(stmt) == SQLITE_ROW {
            books.append(Book(
                id:       Int(sqlite3_column_int(stmt, 0)),
                nameEn:   String(cString: sqlite3_column_text(stmt, 1)),
                nameTwi:  String(cString: sqlite3_column_text(stmt, 2)),
                abbrev:   String(cString: sqlite3_column_text(stmt, 3)),
                testament: Int(sqlite3_column_int(stmt, 4))
            ))
        }
        return books
    }

    // MARK: - Chapters

    func chapterCount(bookId: Int) -> Int {
        let sql = "SELECT MAX(chapter) FROM verses WHERE book_id = ?"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return 0 }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int(stmt, 1, Int32(bookId))
        if sqlite3_step(stmt) == SQLITE_ROW {
            return Int(sqlite3_column_int(stmt, 0))
        }
        return 0
    }

    func book(id: Int) -> Book? {
        let sql = "SELECT id, name_en, name_twi, abbrev, testament FROM books WHERE id = ?"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int(stmt, 1, Int32(id))
        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        return Book(
            id:       Int(sqlite3_column_int(stmt, 0)),
            nameEn:   String(cString: sqlite3_column_text(stmt, 1)),
            nameTwi:  String(cString: sqlite3_column_text(stmt, 2)),
            abbrev:   String(cString: sqlite3_column_text(stmt, 3)),
            testament: Int(sqlite3_column_int(stmt, 4))
        )
    }

    // MARK: - Verses

    func verse(bookId: Int, chapter: Int, verse: Int) -> Verse? {
        let sql = "SELECT id, book_id, chapter, verse, kjv, twi FROM verses WHERE book_id = ? AND chapter = ? AND verse = ?"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int(stmt, 1, Int32(bookId))
        sqlite3_bind_int(stmt, 2, Int32(chapter))
        sqlite3_bind_int(stmt, 3, Int32(verse))
        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        let twiPtr = sqlite3_column_text(stmt, 5)
        return Verse(
            id:      Int(sqlite3_column_int(stmt, 0)),
            bookId:  Int(sqlite3_column_int(stmt, 1)),
            chapter: Int(sqlite3_column_int(stmt, 2)),
            verse:   Int(sqlite3_column_int(stmt, 3)),
            kjv:     String(cString: sqlite3_column_text(stmt, 4)),
            twi:     twiPtr != nil ? String(cString: twiPtr!) : nil
        )
    }

    func verses(bookId: Int, chapter: Int) -> [Verse] {
        var verses: [Verse] = []
        let sql = "SELECT id, book_id, chapter, verse, kjv, twi FROM verses WHERE book_id = ? AND chapter = ? ORDER BY verse"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int(stmt, 1, Int32(bookId))
        sqlite3_bind_int(stmt, 2, Int32(chapter))
        while sqlite3_step(stmt) == SQLITE_ROW {
            let twiPtr = sqlite3_column_text(stmt, 5)
            let twiText = twiPtr != nil ? String(cString: twiPtr!) : nil
            verses.append(Verse(
                id:      Int(sqlite3_column_int(stmt, 0)),
                bookId:  Int(sqlite3_column_int(stmt, 1)),
                chapter: Int(sqlite3_column_int(stmt, 2)),
                verse:   Int(sqlite3_column_int(stmt, 3)),
                kjv:     String(cString: sqlite3_column_text(stmt, 4)),
                twi:     twiText
            ))
        }
        return verses
    }
}
