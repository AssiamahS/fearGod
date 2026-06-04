import SwiftUI
import AVFoundation

// MARK: - Highlight colors (Speechify-style)
private let sentenceColor = Color.blue.opacity(0.13)   // whole verse tint
private let wordColor     = Color.blue.opacity(0.35)   // active word

struct ReadingView: View {
    let book: Book
    @State var chapter: Int

    @State private var verses: [Verse] = []
    @State private var totalChapters = 0
    @State private var fontSize: CGFloat = 15

    @StateObject private var tts = TTSEngine.shared

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(verses.enumerated()), id: \.element.id) { idx, verse in
                        VerseRow(
                            verse: verse,
                            verseIndex: idx,
                            fontSize: fontSize
                        )
                        .id(idx)
                        Divider().opacity(0.3)
                    }
                }
                .padding(.vertical, 8)
            }
            .onChange(of: tts.highlight.verseIndex) { newIdx in
                if let i = newIdx {
                    withAnimation { proxy.scrollTo(i, anchor: .center) }
                }
            }
        }
        .navigationTitle("\(book.nameEn) \(chapter)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .onAppear { loadChapter(chapter) }
        .onDisappear {
            if tts.playingBookId == book.id && tts.playingChapter == chapter {
                tts.stop()
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .navigationBarTrailing) {
            Button {
                if tts.isPlaying && tts.playingBookId == book.id && tts.playingChapter == chapter {
                    tts.stop()
                } else {
                    tts.play(verses: verses, bookId: book.id, chapter: chapter)
                }
            } label: {
                let isThisChapter = tts.isPlaying && tts.playingBookId == book.id && tts.playingChapter == chapter
                Image(systemName: isThisChapter ? "stop.fill" : "play.fill")
            }

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

    // MARK: - Data

    private func loadChapter(_ ch: Int) {
        tts.stop()
        chapter = ch
        if totalChapters == 0 {
            totalChapters = BibleDatabase.shared.chapterCount(bookId: book.id)
        }
        verses = BibleDatabase.shared.verses(bookId: book.id, chapter: ch)
    }
}

// MARK: - VerseColumn

private struct VerseColumn: View {
    let verseNum: Int
    let text: String
    let fontSize: CGFloat
    var muted: Bool = false
    var isActiveSentence: Bool = false
    var wordRange: Range<String.Index>? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Text("\(verseNum)")
                .font(.system(size: fontSize - 3, weight: .bold))
                .foregroundStyle(.secondary)
                .frame(minWidth: 20, alignment: .trailing)
                .padding(.top, 1)
            if let wordRange, isActiveSentence {
                highlightedText(wordRange: wordRange)
            } else {
                Text(text)
                    .font(.system(size: fontSize))
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundStyle(muted ? Color.secondary : Color.primary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(isActiveSentence ? sentenceColor : Color.clear)
    }

    private func highlightedText(wordRange: Range<String.Index>) -> some View {
        var attributed = AttributedString(text)
        if let attrRange = Range(wordRange, in: attributed) {
            attributed[attrRange].backgroundColor = UIColor(wordColor)
        }
        return Text(attributed)
            .font(.system(size: fontSize))
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - VerseRow

private struct VerseRow: View {
    let verse: Verse
    let verseIndex: Int
    let fontSize: CGFloat

    @StateObject private var tts = TTSEngine.shared

    private var isActiveSentence: Bool { tts.highlight.verseIndex == verseIndex }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            VerseColumn(
                verseNum: verse.verse,
                text: verse.kjv,
                fontSize: fontSize,
                isActiveSentence: isActiveSentence,
                wordRange: isActiveSentence ? tts.highlight.wordRange : nil
            )
            Divider()
            VerseColumn(
                verseNum: verse.verse,
                text: verse.twi ?? "—",
                fontSize: fontSize,
                muted: verse.twi == nil,
                isActiveSentence: isActiveSentence   // Twi side tinted same verse, no word highlight
            )
        }
    }
}
