import SwiftUI

struct TodayView: View {
    @State private var current: DailyVerse = .forDay()
    @State private var shareImage: UIImage?
    @State private var showShare = false
    @State private var askedPermission = UserDefaults.standard.bool(forKey: "askedNotifPermission")

    @StateObject private var tts = TTSEngine.shared
    @ObservedObject private var favorites = FavoritesStore.shared

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.07, green: 0.09, blue: 0.15), Color(red: 0.13, green: 0.23, blue: 0.33)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Text("ASƐM A ƐWƆ HƆ MA WO ƐNNƐ")
                    .font(.system(size: 12, weight: .heavy))
                    .kerning(2)
                    .foregroundStyle(.white.opacity(0.45))
                    .padding(.top, 24)
                Text("Today's Verse")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.35))

                Spacer()

                verseBlock
                    .padding(.horizontal, 30)
                    .id(current.verse.id)
                    .transition(.opacity)

                Spacer()

                if !askedPermission {
                    enableRemindersButton
                        .padding(.bottom, 14)
                }

                actionBar
                    .padding(.bottom, 28)
            }
        }
        .sheet(isPresented: $showShare) {
            if let img = shareImage {
                VerseShareSheet(
                    image: img,
                    text: "\(current.verse.twi ?? current.verse.kjv) — \(current.referenceTwi) (\(current.referenceEn))"
                )
                .presentationDetents([.medium, .large])
            }
        }
    }

    // MARK: - Pieces

    private var verseBlock: some View {
        VStack(spacing: 22) {
            if let twi = current.verse.twi {
                Text(twi)
                    .font(.system(size: 28, weight: .semibold, design: .serif))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.45)
            }
            Text(current.verse.kjv)
                .font(.system(size: 16, design: .serif))
                .italic()
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.45)
            Text("\(current.referenceTwi) · \(current.referenceEn)")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white.opacity(0.9))
        }
    }

    private var enableRemindersButton: some View {
        Button {
            askedPermission = true
            UserDefaults.standard.set(true, forKey: "askedNotifPermission")
            DailyNotifications.requestPermissionAndEnable { _ in }
        } label: {
            Label("Get daily verses", systemImage: "bell.badge.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Capsule().fill(.white.opacity(0.16)))
        }
    }

    private var actionBar: some View {
        HStack(spacing: 38) {
            actionButton(
                icon: favorites.isFavorite(current.verse) ? "heart.fill" : "heart",
                label: "Save"
            ) {
                favorites.toggle(current.verse)
            }

            actionButton(icon: "square.and.arrow.up", label: "Share") {
                shareImage = VerseCardRenderer.image(for: current)
                if shareImage != nil { showShare = true }
            }

            actionButton(
                icon: tts.isPlaying && tts.language == .twi ? "stop.fill" : "speaker.wave.2.fill",
                label: "Listen"
            ) {
                if tts.isPlaying {
                    tts.stop()
                } else if current.verse.twi != nil {
                    tts.speakVerse(current.verse, language: .twi)
                }
            }

            actionButton(icon: "arrow.2.squarepath", label: "Another") {
                withAnimation(.easeInOut(duration: 0.25)) {
                    current = DailyVerse.random(excluding: current.verse)
                }
            }
        }
    }

    private func actionButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 21, weight: .semibold))
                Text(label)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(.white.opacity(0.85))
            .frame(width: 56)
        }
    }
}
