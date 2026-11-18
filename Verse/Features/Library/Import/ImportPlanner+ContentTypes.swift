import UniformTypeIdentifiers

extension ImportPlanner {
    /// Types offered in the Files picker.
    static var contentTypes: [UTType] {
        var types: [UTType] = [.audio, .mp3, .mpeg4Audio, .wav, .aiff]
        if let flac = UTType("org.xiph.flac") {
            types.append(flac)
        }
        if let lrc = UTType(filenameExtension: "lrc", conformingTo: .text) {
            types.append(lrc)
        }
        types.append(.plainText)
        return types
    }
}
