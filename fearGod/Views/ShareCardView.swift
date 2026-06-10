import SwiftUI

// MARK: - Shareable verse card (Motivation-app style)

struct VerseCardView: View {
    let dailyVerse: DailyVerse

    private let gradients: [[Color]] = [
        [Color(red: 0.07, green: 0.09, blue: 0.15), Color(red: 0.13, green: 0.23, blue: 0.33)],
        [Color(red: 0.16, green: 0.10, blue: 0.23), Color(red: 0.42, green: 0.18, blue: 0.32)],
        [Color(red: 0.05, green: 0.18, blue: 0.16), Color(red: 0.10, green: 0.33, blue: 0.25)],
        [Color(red: 0.22, green: 0.12, blue: 0.05), Color(red: 0.45, green: 0.27, blue: 0.10)]
    ]

    private var gradient: [Color] {
        gradients[abs(dailyVerse.verse.id) % gradients.count]
    }

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: "quote.opening")
                .font(.system(size: 34))
                .foregroundStyle(.white.opacity(0.45))

            if let twi = dailyVerse.verse.twi {
                Text(twi)
                    .font(.system(size: 30, weight: .semibold, design: .serif))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.5)
            }

            Text(dailyVerse.verse.kjv)
                .font(.system(size: 18, design: .serif))
                .italic()
                .foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.5)

            Text("\(dailyVerse.referenceTwi) · \(dailyVerse.referenceEn)")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white.opacity(0.9))
                .padding(.top, 4)

            Spacer()

            Text("TWI BIBLE")
                .font(.system(size: 13, weight: .heavy))
                .kerning(3)
                .foregroundStyle(.white.opacity(0.5))
                .padding(.bottom, 36)
        }
        .padding(.horizontal, 44)
        .frame(width: 540, height: 675)   // 4:5 — Instagram/WhatsApp friendly
        .background(
            LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
        )
    }
}

// MARK: - Renderer

enum VerseCardRenderer {
    @MainActor
    static func image(for dailyVerse: DailyVerse) -> UIImage? {
        let renderer = ImageRenderer(content: VerseCardView(dailyVerse: dailyVerse))
        renderer.scale = 3
        return renderer.uiImage
    }
}

// MARK: - Share sheet wrapper

struct VerseShareSheet: UIViewControllerRepresentable {
    let image: UIImage
    let text: String

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [image, text], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
