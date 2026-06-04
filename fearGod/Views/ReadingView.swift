import SwiftUI

struct ReadingView: View {
    let book: Book
    @State var chapter: Int

    @State private var verses: [Verse] = []
    @State private var totalChapters = 0
    @State private var fontSize: CGFloat = 15

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(verses) { verse in
                        VerseRow(verse: verse, fontSize: fontSize)
                        Divider().opacity(0.3)
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .navigationTitle("\(book.nameEn) \(chapter)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button { if chapter > 1 { loadChapter(chapter - 1) } } label: {
                    Image(systemName: "chevron.left")
                }
                .disabled(chapter <= 1)

                Button { if chapter < totalChapters { loadChapter(chapter + 1) } } label: {
                    Image(systemName: "chevron.right")
                }
                .disabled(chapter >= totalChapters)

                Menu {
                    Button { if fontSize > 11 { fontSize -= 1 } } label: {
                        Label("Smaller", systemImage: "textformat.size.smaller")
                    }
                    Button { if fontSize < 22 { fontSize += 1 } } label: {
                        Label("Larger", systemImage: "textformat.size.larger")
                    }
                } label: {
                    Image(systemName: "textformat.size")
                }
            }
        }
        .onAppear { loadChapter(chapter) }
    }

    private func loadChapter(_ ch: Int) {
        chapter = ch
        if totalChapters == 0 {
            totalChapters = BibleDatabase.shared.chapterCount(bookId: book.id)
        }
        verses = BibleDatabase.shared.verses(bookId: book.id, chapter: ch)
    }
}

private struct VerseColumn: View {
    let verseNum: Int
    let text: String
    let fontSize: CGFloat
    var muted: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Text("\(verseNum)")
                .font(.system(size: fontSize - 3, weight: .bold))
                .foregroundStyle(.secondary)
                .frame(minWidth: 20, alignment: .trailing)
                .padding(.top, 1)
            Text(text)
                .font(.system(size: fontSize))
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(muted ? Color.secondary : Color.primary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

private struct VerseRow: View {
    let verse: Verse
    let fontSize: CGFloat

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            VerseColumn(verseNum: verse.verse, text: verse.kjv, fontSize: fontSize)
            Divider()
            VerseColumn(verseNum: verse.verse, text: verse.twi ?? "—", fontSize: fontSize, muted: verse.twi == nil)
        }
    }
}
