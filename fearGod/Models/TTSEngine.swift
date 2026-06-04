import AVFoundation
import SwiftUI

// MARK: - State

struct TTSHighlight {
    var verseIndex: Int?         // which verse row is the "sentence" (light blue)
    var wordRange: Range<String.Index>?  // range within that verse's kjv text (darker blue)
}

// MARK: - Engine

final class TTSEngine: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {

    static let shared = TTSEngine()

    @Published var highlight = TTSHighlight()
    @Published var isPlaying = false
    @Published var playingBookId: Int?
    @Published var playingChapter: Int?

    private let synth = AVSpeechSynthesizer()

    // Mapping: character offset in utterance → (verseIndex, verse)
    private var verseOffsets: [(start: Int, end: Int, index: Int, text: String)] = []
    private var utteranceText = ""

    override private init() {
        super.init()
        synth.delegate = self
    }

    // MARK: - Public

    func play(verses: [Verse], bookId: Int, chapter: Int) {
        stop()
        guard !verses.isEmpty else { return }
        playingBookId = bookId
        playingChapter = chapter
        buildUtterance(verses: verses)
    }

    func stop() {
        synth.stopSpeaking(at: .immediate)
        highlight = TTSHighlight()
        isPlaying = false
        playingBookId = nil
        playingChapter = nil
    }

    // MARK: - Private

    private func buildUtterance(verses: [Verse]) {
        verseOffsets = []
        var full = ""
        for (i, v) in verses.enumerated() {
            let start = full.count
            full += v.kjv
            let end = full.count
            verseOffsets.append((start: start, end: end, index: i, text: v.kjv))
            if i < verses.count - 1 { full += " " }
        }
        utteranceText = full

        let utt = AVSpeechUtterance(string: full)
        utt.voice = AVSpeechSynthesisVoice(language: "en-US")
        utt.rate = 0.50
        utt.pitchMultiplier = 1.0
        utt.volume = 1.0
        isPlaying = true
        synth.speak(utt)
    }

    private func verseIndex(for charOffset: Int) -> Int? {
        verseOffsets.first { charOffset >= $0.start && charOffset < $0.end }?.index
    }

    // MARK: - AVSpeechSynthesizerDelegate

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                           willSpeakRangeOfSpeechString characterRange: NSRange,
                           utterance: AVSpeechUtterance) {
        guard let range = Range(characterRange, in: utteranceText) else { return }
        let offset = utteranceText.distance(from: utteranceText.startIndex, to: range.lowerBound)
        guard let vi = verseIndex(for: offset),
              vi < verseOffsets.count else { return }
        let verseInfo = verseOffsets[vi]

        // Convert the word range into a range within the verse's own text
        let verseStart = utteranceText.index(utteranceText.startIndex, offsetBy: verseInfo.start)
        let wordStart  = utteranceText.index(utteranceText.startIndex, offsetBy: max(offset, verseInfo.start))
        let wordEnd    = range.upperBound <= utteranceText.index(utteranceText.startIndex, offsetBy: verseInfo.end)
            ? range.upperBound
            : utteranceText.index(utteranceText.startIndex, offsetBy: verseInfo.end)

        let verseRelativeStart = verseInfo.text.index(verseInfo.text.startIndex,
            offsetBy: utteranceText.distance(from: verseStart, to: wordStart))
        let verseRelativeEnd   = verseInfo.text.index(verseInfo.text.startIndex,
            offsetBy: utteranceText.distance(from: verseStart, to: wordEnd))

        DispatchQueue.main.async {
            self.highlight = TTSHighlight(
                verseIndex: vi,
                wordRange: verseRelativeStart..<verseRelativeEnd
            )
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                           didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.highlight = TTSHighlight()
            self.isPlaying = false
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                           didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.highlight = TTSHighlight()
            self.isPlaying = false
        }
    }
}
