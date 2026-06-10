import SwiftUI

struct SettingsView: View {
    @AppStorage(DailyNotifications.enabledKey) private var dailyEnabled = false
    @AppStorage(DailyNotifications.countKey) private var dailyCount = 3
    @AppStorage(DailyNotifications.startKey) private var startMinutes = 9 * 60
    @AppStorage(DailyNotifications.endKey) private var endMinutes = 21 * 60

    @AppStorage(BibleBrainConfig.keyDefaultsKey) private var bibleBrainKey = ""
    @AppStorage(BibleBrainConfig.voiceDefaultsKey) private var twiVoice = "asante"

    private var startTime: Binding<Date> { minutesBinding($startMinutes) }
    private var endTime: Binding<Date> { minutesBinding($endMinutes) }

    var body: some View {
        NavigationStack {
            Form {
                dailyVerseSection
                twiAudioSection
                aboutSection
            }
            .navigationTitle("Settings")
        }
    }

    // MARK: - Sections

    private var dailyVerseSection: some View {
        Section {
            Toggle("Daily verses", isOn: $dailyEnabled)
                .onChange(of: dailyEnabled) { on in
                    if on {
                        DailyNotifications.requestPermissionAndEnable { granted in
                            if !granted { dailyEnabled = false }
                        }
                    } else {
                        DailyNotifications.reschedule()
                    }
                }

            if dailyEnabled {
                Picker("How many per day", selection: $dailyCount) {
                    ForEach([1, 3, 5, 10], id: \.self) { Text("\($0)×").tag($0) }
                }
                DatePicker("Start at", selection: startTime, displayedComponents: .hourAndMinute)
                DatePicker("End by", selection: endTime, displayedComponents: .hourAndMinute)
                Button("Send a test notification") {
                    DailyNotifications.sendTest()
                }
            }
        } header: {
            Text("Daily Verse")
        } footer: {
            Text("Verses arrive throughout the day between your start and end times, like the Motivation app.")
        }
        .onChange(of: dailyCount) { _ in DailyNotifications.reschedule() }
        .onChange(of: startMinutes) { _ in DailyNotifications.reschedule() }
        .onChange(of: endMinutes) { _ in DailyNotifications.reschedule() }
    }

    private var twiAudioSection: some View {
        Section {
            Picker("Twi voice", selection: $twiVoice) {
                Text("Asante Twi").tag("asante")
                Text("Akuapem Twi").tag("akuapem")
            }
            TextField("Bible Brain API key", text: $bibleBrainKey)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .font(.system(.body, design: .monospaced))
            Link(destination: URL(string: BibleBrainConfig.keyRequestURL)!) {
                Label("Get a free key (4.dbt.io)", systemImage: "key.fill")
            }
        } header: {
            Text("Twi Audio")
        } footer: {
            Text("With a free Bible Brain key, the play button streams human-recorded Twi chapter audio from Faith Comes By Hearing. Without it, a synthesized voice (beta) reads the Twi text.")
        }
    }

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—")
            LabeledContent("English text", value: "KJV")
            LabeledContent("Twi text", value: "Akuapem Twi (Biblica, CC BY-SA)")
        }
    }

    // MARK: - Helpers

    private func minutesBinding(_ source: Binding<Int>) -> Binding<Date> {
        Binding<Date>(
            get: {
                Calendar.current.date(
                    bySettingHour: source.wrappedValue / 60,
                    minute: source.wrappedValue % 60,
                    second: 0, of: Date()
                ) ?? Date()
            },
            set: { newDate in
                let c = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                source.wrappedValue = (c.hour ?? 9) * 60 + (c.minute ?? 0)
            }
        )
    }
}
