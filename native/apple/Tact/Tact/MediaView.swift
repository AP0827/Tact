import SwiftUI

struct MediaView: View {
    @EnvironmentObject private var model: TactAppModel

    @State private var volume: Double = 0.55
    @State private var progress: Double = 0
    @State private var isPlaying = false

    var body: some View {
        ZStack {
            backgroundArtwork

            ScrollView {
                VStack(spacing: 22) {

                    VStack(spacing: 18) {
                        artwork

                        HStack(alignment: .center) {
                            VStack(
                                alignment: .leading,
                                spacing: 5
                            ) {
                                Text(
                                    model.string("media.title")
                                    ?? "Not Playing"
                                )
                                .font(
                                    .system(
                                        size: 21,
                                        weight: .bold
                                    )
                                )

                                Text(
                                    model.string("media.artist")
                                    ?? "Tact Media"
                                )
                                .font(.subheadline)
                                .foregroundStyle(
                                    Color.secondary
                                )
                            }

                            Spacer()

                            Image(systemName: "ellipsis")
                                .font(.title3)
                                .foregroundStyle(
                                    Color.secondary
                                )
                        }

                        VStack(spacing: 7) {
                            Slider(
                                value: $progress,
                                in: 0...1
                            )
                            .tint(Color.white)

                            HStack {
                                Text("—:—")
                                Spacer()
                                Text("—:—")
                            }
                            .font(
                                .caption.monospacedDigit()
                            )
                            .foregroundStyle(
                                Color.secondary
                            )
                        }

                        HStack {
                            Spacer()

                            Button {
                                model.action(
                                    "media.previous"
                                )
                            } label: {
                                Image(
                                    systemName:
                                        "backward.end.fill"
                                )
                                .font(.system(size: 28))
                            }

                            Spacer()

                            Button {
                                isPlaying.toggle()

                                model.action(
                                    "media.play_pause"
                                )
                            } label: {
                                Image(
                                    systemName:
                                        isPlaying
                                        ? "pause.fill"
                                        : "play.fill"
                                )
                                .font(.system(size: 32))
                                .foregroundStyle(
                                    Color.black
                                )
                                .frame(
                                    width: 78,
                                    height: 78
                                )
                                .background(
                                    Color.white,
                                    in: Circle()
                                )
                            }

                            Spacer()

                            Button {
                                model.action(
                                    "media.next"
                                )
                            } label: {
                                Image(
                                    systemName:
                                        "forward.end.fill"
                                )
                                .font(.system(size: 28))
                            }

                            Spacer()
                        }
                        .foregroundStyle(Color.white)

                        HStack(spacing: 12) {
                            Image(
                                systemName: "speaker.slash"
                            )

                            Slider(
                                value: $volume,
                                in: 0...1
                            ) { editing in
                                if !editing {
                                    model.action(
                                        "media.volume",
                                        payload: [
                                            "volume": volume
                                        ]
                                    )
                                }
                            }
                            .tint(Color.white)

                            Image(
                                systemName:
                                    "speaker.wave.3.fill"
                            )
                        }
                        .foregroundStyle(Color.white)

                        Button {
                            model.action(
                                "media.airplay"
                            )
                        } label: {
                            Label(
                                "AirPlay",
                                systemImage:
                                    "airplayaudio"
                            )
                            .font(
                                .system(
                                    size: 14,
                                    weight: .semibold
                                )
                            )
                            .foregroundStyle(Color.white)
                            .padding(
                                .horizontal,
                                20
                            )
                            .frame(height: 42)
                            .background(
                                Color.white.opacity(0.12),
                                in: Capsule()
                            )
                        }
                    }
                    .padding(22)
                    .background(
                        .ultraThinMaterial,
                        in: RoundedRectangle(
                            cornerRadius: 30
                        )
                    )
                    .overlay(
                        RoundedRectangle(
                            cornerRadius: 30
                        )
                        .stroke(
                            Color.white.opacity(0.16),
                            lineWidth: 1
                        )
                    )
                }
                .padding(18)
                .frame(maxWidth: 620)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var artwork: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.tactCyan.opacity(0.20),
                            Color.white.opacity(0.06),
                            Color.black.opacity(0.45)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Image(systemName: "music.note")
                .font(
                    .system(
                        size: 58,
                        weight: .medium
                    )
                )
                .foregroundStyle(
                    Color.white.opacity(0.85)
                )
        }
        .frame(
            maxWidth: .infinity,
            minHeight: 300,
            maxHeight: 360
        )
        .clipShape(
            RoundedRectangle(cornerRadius: 22)
        )
    }

    private var backgroundArtwork: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.18, blue: 0.22),
                    Color(red: 0.14, green: 0.07, blue: 0.12),
                    Color.black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(
                    Color.tactCyan.opacity(0.16)
                )
                .frame(width: 330)
                .blur(radius: 100)
                .offset(x: -140, y: -220)

            Circle()
                .fill(
                    Color.purple.opacity(0.12)
                )
                .frame(width: 300)
                .blur(radius: 110)
                .offset(x: 150, y: 260)

            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
        }
    }
}
