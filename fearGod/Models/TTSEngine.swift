import AVFoundation
import SwiftUI

// MARK: - State

enum TTSLanguage {
    case english
    case twi
}

struct TTSHighlight {
    var verseIndex: Int?         // which verse row is the "sentence" (light blue)
    var wordRange: Range<String.Index>?  // range within that verse's kjv text (darker blue)
}

// MARK: - Twi phonetic preprocessing
// iOS has no Akan/Twi synthesis voice, so we respell Twi text so an
// English voice approximates it: ɔ → "aw", ɛ → "eh", and the Akan
// digraphs ky/gy/hy → ch/j/sh. Sentence-level highlight only — the
// respelled string no longer maps 1:1 onto the original characters.

func twiPhonetic(_ text: String) -> String {
    var s = text
    let maps: [(String, String)] = [
        ("ɔɔ", "aw"), ("ƆƆ", "AW"), ("ɔ", "aw"), ("Ɔ", "Aw"),
        ("ɛɛ", "eh"), ("ƐƐ", "EH"), ("ɛ", "eh"), ("Ɛ", "Eh"),
        ("ky", "ch"), ("Ky", "Ch"), ("KY", "CH"),
        ("gy", "j"),  ("Gy", "J"),  ("GY", "J"),
        ("hy", "sh"), ("Hy", "Sh"), ("HY", "SH")
    ]
    for (from, to) in maps {
        s = s.replacingOccurrences(of: from, with: to)
    }
    return s
}

private func twiVoice() -> AVSpeechSynthesisVoice? {
    // Prefer a real Akan voice if Apple ever ships one, then accents
    // whose vowels sit closest to Twi.
    for lang in ["ak-GH", "tw-GH", "en-ZA", "en-GB", "en-US"] {
        if let v = AVSpeechSynthesisVoice(language: lang) { return v }
    }
    return AVSpeechSynthesisVoice(language: "en-US")
}

// MARK: - Engine

final class TTSEngine: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {

    static let shared = TTSEngine()

    @Published var highlight = TTSHighlight()
    @Published var isPlaying = false
    @Published var playingBookId: Int?
    @Published var playingChapter: Int?
    @Published var language: TTSLanguage = .english

    private let synth = AVSpeechSynthesizer()

    // Mapping: character offset in utterance → (verseIndex, verse)
    private var verseOffsets: [(start: Int, end: Int, index: Int, text: String)] = []
    private var utteranceText = ""

    override private init() {
        super.init()
        synth.delegate = self
    }

    // MARK: - Public

    func play(verses: [Verse], bookId: Int, chapter: Int, language: TTSLanguage = .english) {
        stop()
        guard !verses.isEmpty else { return }
        self.language = language
        playingBookId = bookId
        playingChapter = chapter
        buildUtterance(verses: verses)
    }

    func speakVerse(_ verse: Verse, language: TTSLanguage) {
        play(verses: [verse], bookId: verse.bookId, chapter: verse.chapter, language: language)
    }

    func stop() {
        synth.stopSpeaking(at: .immediate)
        highlight = TTSHighlight()
        isPlaying = false
        playingBookId = nil
        playingChapter = nil
    }

    // MARK: - Private

    private func speechText(for verse: Verse) -> String {
        switch language {
        case .english: return verse.kjv
        case .twi:     return twiPhonetic(verse.twi ?? "")
        }
    }

    private func buildUtterance(verses: [Verse]) {
        verseOffsets = []
        var full = ""
        for (i, v) in verses.enumerated() {
            let text = speechText(for: v)
            let start = full.count
            full += text
            let end = full.count
            // For English the stored text is the on-screen KJV text, so
            // word ranges can be mapped back; for Twi it's the respelled
            // string, used for verse lookup only.
            verseOffsets.append((start: start, end: end, index: i, text: language == .english ? v.kjv : text))
            if i < verses.count - 1 { full += " " }
        }
        utteranceText = full

        let utt = AVSpeechUtterance(string: full)
        switch language {
        case .english:
            utt.voice = AVSpeechSynthesisVoice(language: "en-US")
            utt.rate = 0.50
        case .twi:
            utt.voice = twiVoice()
            utt.rate = 0.42   // slower — respelled words need room
        }
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

        // Twi is respelled, so character ranges don't map back to the
        // original text — highlight at verse level only.
        if language == .twi {
            if highlight.verseIndex != vi {
                DispatchQueue.main.async {
                    self.highlight = TTSHighlight(verseIndex: vi, wordRange: nil)
                }
            }
            return
        }

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
