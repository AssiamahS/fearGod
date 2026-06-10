import Foundation
import UserNotifications

// MARK: - Curated verse references (bookId, chapter, verse)
// Well-known encouragement/promise verses — the daily-quote pool.

private let curatedRefs: [(Int, Int, Int)] = [
    (1, 1, 1), (1, 28, 15),
    (2, 14, 14),
    (4, 6, 24), (4, 6, 25), (4, 6, 26),
    (5, 31, 6),
    (6, 1, 9),
    (19, 23, 1), (19, 23, 4), (19, 27, 1), (19, 34, 8), (19, 37, 4),
    (19, 46, 1), (19, 46, 10), (19, 51, 10), (19, 55, 22), (19, 91, 1),
    (19, 91, 11), (19, 103, 2), (19, 118, 24), (19, 119, 105), (19, 121, 1),
    (19, 121, 2), (19, 127, 1), (19, 139, 14), (19, 147, 3),
    (20, 3, 5), (20, 3, 6), (20, 16, 3), (20, 18, 10), (20, 22, 6),
    (21, 3, 1),
    (23, 26, 3), (23, 40, 31), (23, 41, 10), (23, 43, 2), (23, 53, 5),
    (23, 54, 17), (23, 55, 8),
    (24, 29, 11), (24, 33, 3),
    (25, 3, 22), (25, 3, 23),
    (33, 6, 8),
    (34, 1, 7),
    (36, 3, 17),
    (40, 5, 16), (40, 6, 33), (40, 7, 7), (40, 11, 28), (40, 19, 26),
    (40, 28, 19), (40, 28, 20),
    (41, 11, 24),
    (42, 1, 37), (42, 6, 31),
    (43, 1, 1), (43, 3, 16), (43, 8, 12), (43, 10, 10), (43, 13, 34),
    (43, 14, 6), (43, 14, 27), (43, 15, 5), (43, 16, 33),
    (44, 1, 8),
    (45, 5, 8), (45, 8, 28), (45, 8, 31), (45, 10, 9), (45, 12, 2),
    (45, 12, 12), (45, 15, 13),
    (46, 10, 13), (46, 13, 4), (46, 13, 13), (46, 16, 14),
    (47, 5, 7), (47, 5, 17), (47, 12, 9),
    (48, 2, 20), (48, 5, 22), (48, 6, 9),
    (49, 2, 8), (49, 3, 20), (49, 4, 32), (49, 6, 10),
    (50, 1, 6), (50, 4, 4), (50, 4, 6), (50, 4, 7), (50, 4, 13), (50, 4, 19),
    (51, 3, 23),
    (52, 5, 16), (52, 5, 17), (52, 5, 18),
    (55, 1, 7),
    (58, 11, 1), (58, 12, 2), (58, 13, 5), (58, 13, 8),
    (59, 1, 5), (59, 1, 12), (59, 4, 7),
    (60, 5, 7),
    (62, 1, 9), (62, 4, 18), (62, 4, 19),
    (66, 21, 4)
]

struct DailyVerse {
    let verse: Verse
    let book: Book

    var referenceEn: String { "\(book.nameEn) \(verse.chapter):\(verse.verse)" }
    var referenceTwi: String { "\(book.nameTwi) \(verse.chapter):\(verse.verse)" }

    // MARK: - Pool

    static let pool: [DailyVerse] = curatedRefs.compactMap { ref in
        guard let v = BibleDatabase.shared.verse(bookId: ref.0, chapter: ref.1, verse: ref.2),
              let b = BibleDatabase.shared.book(id: ref.0) else { return nil }
        return DailyVerse(verse: v, book: b)
    }

    static func forDay(_ date: Date = Date()) -> DailyVerse {
        let day = Int(date.timeIntervalSince1970 / 86_400)
        return pool[day % max(pool.count, 1)]
    }

    static func random(excluding current: Verse? = nil) -> DailyVerse {
        var pick = pool.randomElement()!
        while pool.count > 1 && pick.verse.id == current?.id {
            pick = pool.randomElement()!
        }
        return pick
    }
}

// MARK: - Daily notifications (Motivation-app style)

enum DailyNotifications {
    static let enabledKey = "dailyVerseEnabled"
    static let countKey   = "dailyVerseCount"     // notifications per day
    static let startKey   = "dailyVerseStartMin"  // minutes from midnight
    static let endKey     = "dailyVerseEndMin"

    static var enabled: Bool { UserDefaults.standard.bool(forKey: enabledKey) }
    static var count: Int {
        let c = UserDefaults.standard.integer(forKey: countKey)
        return c == 0 ? 3 : c
    }
    static var startMinutes: Int {
        UserDefaults.standard.object(forKey: startKey) as? Int ?? 9 * 60
    }
    static var endMinutes: Int {
        UserDefaults.standard.object(forKey: endKey) as? Int ?? 21 * 60
    }

    static func requestPermissionAndEnable(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async {
                UserDefaults.standard.set(granted, forKey: enabledKey)
                if granted { reschedule() }
                completion(granted)
            }
        }
    }

    /// Schedules a rolling 7-day window of verse notifications.
    /// Called on every app foreground so the window keeps moving.
    static func reschedule() {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        guard enabled, !DailyVerse.pool.isEmpty else { return }

        let perDay = max(1, min(count, 10))
        let start = startMinutes
        let span = max(endMinutes - start, 0)
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        for dayOffset in 0..<7 {
            guard let day = cal.date(byAdding: .day, value: dayOffset, to: today) else { continue }
            let epochDay = Int(day.timeIntervalSince1970 / 86_400)
            for slot in 0..<perDay {
                let minute = perDay == 1 ? start : start + (span * slot) / (perDay - 1)
                guard let fireDate = cal.date(byAdding: .minute, value: minute, to: day),
                      fireDate > Date() else { continue }

                let dv = DailyVerse.pool[(epochDay * perDay + slot) % DailyVerse.pool.count]
                let content = UNMutableNotificationContent()
                content.title = "\(dv.referenceTwi) · \(dv.referenceEn)"
                content.body = [dv.verse.twi, dv.verse.kjv].compactMap { $0 }.joined(separator: "\n\n")
                content.sound = .default
                content.userInfo = ["bookId": dv.verse.bookId, "chapter": dv.verse.chapter, "verse": dv.verse.verse]

                let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                center.add(UNNotificationRequest(
                    identifier: "dailyVerse-\(epochDay)-\(slot)",
                    content: content,
                    trigger: trigger
                ))
            }
        }
    }

    static func sendTest() {
        let dv = DailyVerse.random()
        let content = UNMutableNotificationContent()
        content.title = "\(dv.referenceTwi) · \(dv.referenceEn)"
        content.body = [dv.verse.twi, dv.verse.kjv].compactMap { $0 }.joined(separator: "\n\n")
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: "dailyVerse-test", content: content, trigger: trigger)
        )
    }
}
