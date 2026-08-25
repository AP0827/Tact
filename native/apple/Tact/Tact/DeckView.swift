import SwiftUI

struct DeckTile: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let action: String
}

struct DeckView: View {
    @EnvironmentObject private var model: TactAppModel

    @State private var page = 0
    @State private var active = false

    private let blue = Color(
        red: 0.02,
        green: 0.68,
        blue: 0.88
    )

    private let pages: [(String, [DeckTile])] = [
        (
            "Development",
            [
                DeckTile(title: "VS Code", icon: "curlybraces", action: "vscode.open_workspace"),
                DeckTile(title: "Terminal", icon: "terminal", action: "system.open_terminal"),
                DeckTile(title: "Git Status", icon: "arrow.triangle.branch", action: "git.status"),
                DeckTile(title: "Build", icon: "hammer", action: "git.status"),
                DeckTile(title: "Git Pull", icon: "arrow.down", action: "git.pull"),
                DeckTile(title: "Git Push", icon: "arrow.up", action: "git.push"),
                DeckTile(title: "Command Palette", icon: "command", action: "vscode.open_workspace"),
                DeckTile(title: "Screenshot", icon: "camera.viewfinder", action: "system.screenshot")
            ]
        ),
        (
            "Media",
            [
                DeckTile(title: "Previous", icon: "backward.end.fill", action: "media.previous"),
                DeckTile(title: "Play / Pause", icon: "play.fill", action: "media.play_pause"),
                DeckTile(title: "Next", icon: "forward.end.fill", action: "media.next"),
                DeckTile(title: "Mute", icon: "speaker.slash", action: "system.mute"),
                DeckTile(title: "Volume −", icon: "speaker.wave.1", action: "media.volume"),
                DeckTile(title: "Volume +", icon: "speaker.wave.2", action: "media.volume"),
                DeckTile(title: "Spotify", icon: "music.note", action: "media.open_spotify"),
                DeckTile(title: "VLC", icon: "play.rectangle", action: "media.status")
            ]
        ),
        (
            "Streaming",
            [
                DeckTile(title: "OBS", icon: "dot.radiowaves.left.and.right", action: "system.open_url"),
                DeckTile(title: "Start Stream", icon: "play", action: "system.open_url"),
                DeckTile(title: "Stop Stream", icon: "stop", action: "system.open_url"),
                DeckTile(title: "Mute Mic", icon: "mic.slash", action: "system.mute"),
                DeckTile(title: "Scene 1", icon: "rectangle.on.rectangle", action: "system.open_url"),
                DeckTile(title: "Scene 2", icon: "rectangle.on.rectangle", action: "system.open_url"),
                DeckTile(title: "YouTube", icon: "play.rectangle", action: "system.open_url"),
                DeckTile(title: "Twitch", icon: "tv", action: "system.open_url")
            ]
        ),
        (
            "Productivity",
            [
                DeckTile(title: "Lock Screen", icon: "lock.fill", action: "system.lock_screen"),
                DeckTile(title: "Open URL", icon: "link", action: "system.open_url"),
                DeckTile(title: "New Note", icon: "note.text", action: "system.open_url"),
                DeckTile(title: "Calendar", icon: "calendar", action: "system.open_url"),
                DeckTile(title: "Slack", icon: "bubble.left.and.bubble.right", action: "system.open_url"),
                DeckTile(title: "Safari", icon: "safari", action: "system.open_url"),
                DeckTile(title: "Git Commit", icon: "checkmark.circle", action: "git.commit"),
                DeckTile(title: "Empty", icon: "plus", action: "")
            ]
        )
    ]

    var body: some View {
        if active {
            activeDeck
        } else {
            deckHome
        }
    }

    private var deckHome: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Deck")
                        .font(.system(size: 30, weight: .bold))

                    Text("Quick actions for your computer.")
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 0) {
                    ForEach(
                        Array(pages.enumerated()),
                        id: \.offset
                    ) { index, item in
                        Button {
                            page = index
                            active = true
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: "square.grid.2x2")
                                    .foregroundStyle(blue)

                                Text(item.0)
                                    .font(.headline)

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(18)
                        }
                        .buttonStyle(.plain)

                        if index < pages.count - 1 {
                            Divider()
                                .overlay(Color.white.opacity(0.08))
                        }
                    }
                }
                .background(
                    Color.white.opacity(0.055),
                    in: RoundedRectangle(cornerRadius: 24)
                )
            }
            .padding(24)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
    }

    private var activeDeck: some View {
        VStack(spacing: 18) {
            HStack {
                Button {
                    active = false
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "chevron.left")
                        Text("Deck")
                    }
                    .foregroundStyle(blue)
                }

                Spacer()

                Text(pages[page].0)
                    .font(.title3.weight(.bold))

                Spacer()

                Button {
                    active = false
                } label: {
                    Image(systemName: "xmark")
                }
                .foregroundStyle(.secondary)
            }

            LazyVGrid(
                columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ],
                spacing: 14
            ) {
                ForEach(pages[page].1) { tile in
                    Button {
                        if !tile.action.isEmpty {
                            model.action(tile.action)
                        }
                    } label: {
                        VStack(spacing: 12) {
                            Image(systemName: tile.icon)
                                .font(.system(size: 25))
                                .foregroundStyle(blue)

                            Text(tile.title)
                                .font(
                                    .system(
                                        size: 14,
                                        weight: .semibold
                                    )
                                )
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 130)
                        .background(
                            Color.white.opacity(0.055),
                            in: RoundedRectangle(cornerRadius: 22)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 22)
                                .stroke(
                                    Color.white.opacity(0.08),
                                    lineWidth: 1
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()
        }
        .padding(20)
    }
}
