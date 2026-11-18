import SwiftUI

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var settings = settings

        NavigationStack {
            Form {
                Section("Appearance") {
                    Picker("Theme", selection: $settings.appearance) {
                        ForEach(AppearanceMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                }

                Section {
                    VStack(alignment: .leading) {
                        LabeledContent("Crossfade", value: crossfadeLabel)
                        Slider(value: $settings.crossfadeSeconds, in: AppSettings.crossfadeRange, step: 1) {
                            Text("Crossfade")
                        }
                        .accessibilityValue(crossfadeLabel)
                    }
                    Toggle("Gapless Playback", isOn: $settings.gaplessPlayback)
                    Picker("On Launch", selection: $settings.launchBehavior) {
                        ForEach(LaunchBehavior.allCases) { behavior in
                            Text(behavior.title).tag(behavior)
                        }
                    }
                } header: {
                    Text("Playback")
                } footer: {
                    Text("Crossfade applies to local files only.")
                }

                Section {
                    Picker("Text Size", selection: $settings.lyricsTextSize) {
                        ForEach(LyricsTextSize.allCases) { size in
                            Text(size.title).tag(size)
                        }
                    }
                    Toggle("Show Translations", isOn: $settings.showLyricsTranslations)
                    Toggle("Find Lyrics Online", isOn: $settings.lrclibEnabled)
                } header: {
                    Text("Lyrics")
                } footer: {
                    Text("Online lyrics come from LRCLIB. Only the song title, artist, album and length are sent.")
                }

                Section {
                    LabeledContent("Equaliser", value: String(localized: "Coming Soon"))
                    LabeledContent("Speed & Pitch", value: String(localized: "Coming Soon"))
                } header: {
                    Text("Audio")
                } footer: {
                    Text("Audio effects work with local files only.")
                }

                Section("Storage") {
                    LabeledContent("Imported Files", value: String(localized: "Coming Soon"))
                    LabeledContent("Lyrics Cache", value: String(localized: "Coming Soon"))
                }

                Section("Apple Music") {
                    LabeledContent("Status", value: String(localized: "Not Connected"))
                }

                Section("About") {
                    LabeledContent("Version", value: Bundle.main.versionString)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var crossfadeLabel: String {
        let seconds = Int(settings.crossfadeSeconds.rounded())
        guard seconds > 0 else { return String(localized: "Off") }
        return Duration.seconds(seconds).formatted(.units(allowed: [.seconds], width: .abbreviated))
    }
}

#Preview {
    SettingsView()
        .environment(AppSettings())
}
