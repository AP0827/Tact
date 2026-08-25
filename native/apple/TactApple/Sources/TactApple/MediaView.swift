import SwiftUI

struct MediaView: View {
    @EnvironmentObject private var model: TactAppModel
    var body: some View {
        VStack(spacing: 22) {
            Spacer()
            Image(systemName: "music.note.list").font(.system(size: 42)).foregroundStyle(Color.tactCyan)
            Text(model.string("media.title") ?? "No media playing").font(.title2.weight(.semibold))
            Text(model.string("media.artist") ?? "Choose Spotify, browser media, or VLC on the host.").foregroundStyle(.secondary)
            HStack(spacing: 22) {
                mediaButton("backward.end.fill", "media.previous"); mediaButton("play.fill", "media.play_pause", large: true); mediaButton("forward.end.fill", "media.next")
            }
            HStack { Button { model.action("media.volume", payload: ["volume": 0]) } label: { Image(systemName: "speaker.slash") }; Slider(value: Binding(get: { model.value("media.volume") ?? 0.5 }, set: { model.action("media.volume", payload: ["volume": $0]) }), in: 0...1); Button { model.action("media.volume", payload: ["volume": 1]) } label: { Image(systemName: "speaker.3.fill") } }.padding().tactGlass()
            HStack { Button("Spotify") { model.action("media.open_spotify") }; Button("Check player") { model.action("media.status") } }.buttonStyle(.bordered)
            Spacer()
        }.padding(24).frame(maxWidth: 720).frame(maxWidth: .infinity)
    }
    private func mediaButton(_ icon: String, _ id: String, large: Bool = false) -> some View { Button { model.action(id) } label: { Image(systemName: icon).font(.system(size: large ? 28 : 20)).frame(width: large ? 72 : 52, height: large ? 72 : 52) }.buttonStyle(.borderedProminent).tint(large ? Color.tactCyan : Color.secondary) }
}
