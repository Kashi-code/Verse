import SwiftUI

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(LyricsController.self) private var lyrics
    @Environment(\.dismiss) private var dismiss

    @State private var imageCacheSize: Int64 = 0
    @State private var lyricsCacheSize: Int64 = 0
    @State private var isConfirmingClear = false

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
                    Picker("On Launch", selection: $settings.launchBehavior) {
                        ForEach(LaunchBehavior.allCases) { behavior in
                            Text(behavior.title).tag(behavior)
                        }
                    }
                    Toggle("Autoplay", isOn: $settings.autoplay)
                } header: {
                    Text("Playback")
                } footer: {
                    Text("When your queue ends, keep playing similar songs.")
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
                    Text("Lyrics come from LRCLIB. Only the song title, artist, album and length are sent.")
                }

                Section {
                    LabeledContent("Status", value: String(localized: "Not Connected"))
                } header: {
                    Text("Apple Music")
                } footer: {
                    Text("Popular songs play as 30-second previews. Full songs need Apple Music, which arrives in a later update.")
                }

                Section {
                    LabeledContent("Images", value: ByteCountFormatter.string(fromByteCount: imageCacheSize, countStyle: .file))
                    LabeledContent("Lyrics", value: ByteCountFormatter.string(fromByteCount: lyricsCacheSize, countStyle: .file))
                    Button("Clear Cache", role: .destructive) { isConfirmingClear = true }
                } header: {
                    Text("Storage")
                } footer: {
                    Text("Clearing the cache never removes your likes, playlists or history.")
                }

                Section("About") {
                    LabeledContent("Version", value: Bundle.main.versionString)
                    Text("Music from Audius. Previews provided courtesy of Apple Music. Lyrics from LRCLIB.")
                        .font(.footnote)
                        .foregroundStyle(DS.Text.secondary)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog("Clear Cache?", isPresented: $isConfirmingClear, titleVisibility: .visible) {
                Button("Clear Cache", role: .destructive) { clearCache() }
            } message: {
                Text("Cover images and lyrics will be downloaded again when needed.")
            }
            .task { refreshSizes() }
        }
    }

    private func refreshSizes() {
        imageCacheSize = DirectorySize.of(ImageLoader.shared.directory)
        lyricsCacheSize = LyricsCache.shared.totalSize()
    }

    private func clearCache() {
        ImageLoader.shared.clearDiskCache()
        try? LyricsCache.shared.removeAll()
        lyrics.forgetLoadedLyrics()
        refreshSizes()
    }
}
