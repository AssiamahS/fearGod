import AVFoundation
import SwiftUI
import Combine

// MARK: - Config
// Free key: https://4.dbt.io/api_key/request — paste it in Settings.

enum BibleBrainConfig {
    static let keyDefaultsKey = "bibleBrainKey"
    static let voiceDefaultsKey = "twiAudioVoice"   // "asante" | "akuapem"
    static let keyRequestURL = "https://4.dbt.io/api_key/request"

    // Twi fileset IDs (Faith Comes By Hearing)
    static let asanteTwiFileset  = "TWIASTN"   // Asante Twi Non-Dramatized
    static let akuapemTwiFileset = "TWIAKTN"   // Akuapem Twi Non-Dramatized

    static var apiKey: String {
        (UserDefaults.standard.string(forKey: keyDefaultsKey) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static var fileset: String {
        UserDefaults.standard.string(forKey: voiceDefaultsKey) == "akuapem"
            ? akuapemTwiFileset : asanteTwiFileset
    }
}

// MARK: - Bible Brain chapter audio fetcher

final class BibleBrainAudio: NSObject, ObservableObject, AVAudioPlayerDelegate {
    static let shared = BibleBrainAudio()

    @Published var isPlaying = false
    @Published var isLoading = false
    @Published var activeVerseIndex: Int? = nil
    @Published var playingBookId: Int?
    @Published var playingChapter: Int?
    @Published var lastError: String?

    private var player: AVAudioPlayer?
    private var chapterDuration: TimeInterval = 0
    private var verseCount: Int = 0
    private var timer: Timer?

    var hasKey: Bool { !BibleBrainConfig.apiKey.isEmpty }

    // MARK: - Public

    func play(bookAbbrev: String, chapter: Int, bookId: Int, verseCount: Int) {
        guard hasKey else {
            lastError = "No Bible Brain API key. Add one in Settings to hear human-recorded Twi audio."
            return
        }
        stop()
        self.verseCount = verseCount
        self.playingBookId = bookId
        self.playingChapter = chapter
        self.isLoading = true
        self.lastError = nil

        Task {
            guard let url = await audioURL(fileset: BibleBrainConfig.fileset, book: bookAbbrev, chapter: chapter) else {
                await MainActor.run {
                    self.isLoading = false
                    if self.lastError == nil {
                        self.lastError = "Could not fetch Twi audio for this chapter. Check the API key and your connection."
                    }
                }
                return
            }
            await MainActor.run { self.stream(url: url, verseCount: verseCount) }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        player?.stop()
        player = nil
        isPlaying = false
        isLoading = false
        activeVerseIndex = nil
        playingBookId = nil
        playingChapter = nil
    }

    // MARK: - Private

    private func audioURL(fileset: String, book: String, chapter: Int) async -> URL? {
        let chStr = String(format: "%02d", chapter)
        let urlStr = "https://4.dbt.io/api/bibles/filesets/\(fileset)/\(book)/\(chStr)?v=4&key=\(BibleBrainConfig.apiKey)"
        guard let apiURL = URL(string: urlStr) else { return nil }
        do {
            let (data, response) = try await URLSession.shared.data(from: apiURL)
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                let msg = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String
                await MainActor.run {
                    self.lastError = msg ?? "Bible Brain returned HTTP \(http.statusCode)."
                }
                return nil
            }
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let items = json?["data"] as? [[String: Any]]
            let path = items?.first?["path"] as? String
            return path.flatMap { URL(string: $0) }
        } catch {
            await MainActor.run { self.lastError = error.localizedDescription }
            return nil
        }
    }

    private func stream(url: URL, verseCount: Int) {
        // Download to temp, then play (AVAudioPlayer needs local file or pre-loaded data for timing)
        Task {
            do {
                let (localURL, _) = try await URLSession.shared.download(from: url)
                let destURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("twi_chapter.mp3")
                try? FileManager.default.removeItem(at: destURL)
                try FileManager.default.moveItem(at: localURL, to: destURL)
                await MainActor.run {
                    do {
                        try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
                        try AVAudioSession.sharedInstance().setActive(true)
                        self.player = try AVAudioPlayer(contentsOf: destURL)
                        self.player?.delegate = self
                        self.player?.prepareToPlay()
                        self.chapterDuration = self.player?.duration ?? 0
                        self.player?.play()
                        self.isLoading = false
                        self.isPlaying = true
                        self.startVerseTimer(verseCount: verseCount)
                    } catch {
                        self.isLoading = false
                        self.isPlaying = false
                        self.lastError = "Could not play the downloaded audio."
                    }
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.isPlaying = false
                    self.lastError = error.localizedDescription
                }
            }
        }
    }

    private func startVerseTimer(verseCount: Int) {
        guard chapterDuration > 0, verseCount > 0 else { return }
        let interval = 0.1
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self, let p = self.player, p.isPlaying else { return }
            let fraction = p.currentTime / self.chapterDuration
            let idx = min(Int(fraction * Double(verseCount)), verseCount - 1)
            if self.activeVerseIndex != idx {
                DispatchQueue.main.async { self.activeVerseIndex = idx }
            }
        }
    }

    // MARK: - AVAudioPlayerDelegate

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.timer?.invalidate()
            self.timer = nil
            self.isPlaying = false
            self.activeVerseIndex = nil
        }
    }
}
