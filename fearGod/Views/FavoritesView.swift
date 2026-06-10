import SwiftUI

struct FavoritesView: View {
    @ObservedObject private var favorites = FavoritesStore.shared
    @State private var shareImage: UIImage?
    @State private var shareText = ""
    @State private var showShare = false

    var body: some View {
        NavigationStack {
            Group {
                if favorites.refs.isEmpty {
                    ContentUnavailableCompat()
                } else {
                    List {
                        ForEach(favorites.refs, id: \.self) { ref in
                            if let dv = dailyVerse(for: ref) {
                                FavoriteRow(dailyVerse: dv)
                                    .swipeActions {
                                        Button(role: .destructive) {
                                            favorites.toggle(dv.verse)
                                        } label: {
                                            Label("Remove", systemImage: "heart.slash")
                                        }
                                        Button {
                                            shareImage = VerseCardRenderer.image(for: dv)
                                            shareText = "\(dv.verse.twi ?? dv.verse.kjv) — \(dv.referenceTwi) (\(dv.referenceEn))"
                                            if shareImage != nil { showShare = true }
                                        } label: {
                                            Label("Share", systemImage: "square.and.arrow.up")
                                        }
                                        .tint(.blue)
                                    }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Saved Verses")
            .sheet(isPresented: $showShare) {
                if let img = shareImage {
                    VerseShareSheet(image: img, text: shareText)
                        .presentationDetents([.medium, .large])
                }
            }
        }
    }

    private func dailyVerse(for ref: VerseRef) -> DailyVerse? {
        guard let v = BibleDatabase.shared.verse(bookId: ref.bookId, chapter: ref.chapter, verse: ref.verse),
              let b = BibleDatabase.shared.book(id: ref.bookId) else { return nil }
        return DailyVerse(verse: v, book: b)
    }
}

private struct FavoriteRow: View {
    let dailyVerse: DailyVerse

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let twi = dailyVerse.verse.twi {
                Text(twi)
                    .font(.system(.body, design: .serif))
            }
            Text(dailyVerse.verse.kjv)
                .font(.system(.caption, design: .serif))
                .italic()
                .foregroundStyle(.secondary)
            Text("\(dailyVerse.referenceTwi) · \(dailyVerse.referenceEn)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// iOS 16 fallback for ContentUnavailableView (iOS 17+)
private struct ContentUnavailableCompat: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "heart")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("No saved verses yet")
                .font(.headline)
            Text("Long-press a verse while reading, or tap the heart on Today's verse.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
}
