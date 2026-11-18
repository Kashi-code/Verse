import SwiftUI

/// Placeholder until the player engine exists (milestone 3).
struct MiniPlayerBar: View {
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 6)
                .fill(.quaternary)
                .frame(width: 32, height: 32)
                .overlay {
                    Image(systemName: "music.note")
                        .foregroundStyle(.secondary)
                }
                .accessibilityHidden(true)
            Text("Not Playing")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Button("Play", systemImage: "play.fill") {}
                .labelStyle(.iconOnly)
                .disabled(true)
        }
        .padding(.horizontal)
    }
}
