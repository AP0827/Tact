import SwiftUI
import TactCore

struct MainShellView: View {
    @EnvironmentObject private var model: TactAppModel
    @State private var showingProfile = false

    var body: some View {
        ZStack {
            TactBackground()

            VStack(spacing: 0) {
                HeaderView(
                    showingProfile: $showingProfile
                )

                contentFor(model.screen)
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity
                    )

                BottomNavigation()
            }
        }
        .sheet(isPresented: $showingProfile) {
            ProfileSheet()
        }
    }

    @ViewBuilder
    private func contentFor(
        _ screen: TactScreen
    ) -> some View {
        switch screen {
        case .general:
            GeneralView()

        case .developer:
            DeveloperView()

        case .media:
            MediaView()

        case .events:
            EventsView()

        case .deck:
            DeckView()
        }
    }
}

struct HeaderView: View {
    @EnvironmentObject private var model: TactAppModel
    @Binding var showingProfile: Bool

    private let blue = Color(
        red: 0.02,
        green: 0.68,
        blue: 0.88
    )

    var body: some View {
        HStack(spacing: 14) {
            VStack(
                alignment: .leading,
                spacing: 3
            ) {
                Text(greeting)
                    .font(
                        .system(
                            size: 22,
                            weight: .bold
                        )
                    )

                Text(
                    "\(model.selectedDevice?.name ?? "Tact Host") · Connected"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                showingProfile = true
            } label: {
                Text("A")
                    .font(.headline)
                    .foregroundStyle(blue)
                    .frame(
                        width: 42,
                        height: 42
                    )
                    .background(
                        blue.opacity(0.12),
                        in: Circle()
                    )
                    .overlay(
                        Circle()
                            .stroke(
                                blue.opacity(0.25),
                                lineWidth: 1
                            )
                    )
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }

    private var greeting: String {
        let hour = Calendar.current.component(
            .hour,
            from: .now
        )

        if hour >= 5 && hour < 12 {
            return "Good morning"
        }

        if hour < 17 {
            return "Good afternoon"
        }

        return "Good evening"
    }
}

struct BottomNavigation: View {
    @EnvironmentObject private var model: TactAppModel

    private let blue = Color(
        red: 0.02,
        green: 0.68,
        blue: 0.88
    )

    private let screens: [TactScreen] = [
        .general,
        .developer,
        .media,
        .events,
        .deck
    ]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(
                screens,
                id: \.self
            ) { screen in
                Button {
                    withAnimation(
                        .easeInOut(duration: 0.18)
                    ) {
                        model.screen = screen
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: screen.symbol)
                            .font(
                                .system(
                                    size: 18,
                                    weight: .semibold
                                )
                            )

                        Text(screen.title)
                            .font(
                                .system(
                                    size: 10,
                                    weight: .medium
                                )
                            )
                    }
                    .foregroundStyle(
                        model.screen == screen
                        ? blue
                        : Color.secondary
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(
                        model.screen == screen
                        ? blue.opacity(0.10)
                        : Color.clear,
                        in: RoundedRectangle(
                            cornerRadius: 14
                        )
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(7)
        .background(
            Color.black.opacity(0.86),
            in: RoundedRectangle(
                cornerRadius: 22
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(
                    Color.white.opacity(0.10),
                    lineWidth: 1
                )
        )
        .padding(.horizontal, 14)
        .padding(.bottom, 8)
    }
}

struct ProfileSheet: View {
    @EnvironmentObject private var model: TactAppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Account") {
                    Label(
                        "Local user",
                        systemImage:
                            "person.crop.circle"
                    )
                }

                Section("Tact") {
                    NavigationLink("Settings") {
                        SettingsView()
                    }

                    NavigationLink("Devices") {
                        DeviceSelectionView()
                    }

                    HStack {
                        Text("Connection")

                        Spacer()

                        Text(
                            model.connection.label
                        )
                        .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Button(
                        "Log Out",
                        role: .destructive
                    ) {
                        Task {
                            await model.disconnect()
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle("Profile")
        }
        .preferredColorScheme(.dark)
    }
}

extension TactScreen {
    var title: String {
        switch self {
        case .general:
            return "General"

        case .developer:
            return "Developer"

        case .media:
            return "Media"

        case .events:
            return "Events"

        case .deck:
            return "Deck"
        }
    }

    var symbol: String {
        switch self {
        case .general:
            return "rectangle.grid.2x2"

        case .developer:
            return "chevron.left.forwardslash.chevron.right"

        case .media:
            return "play.circle"

        case .events:
            return "bell"

        case .deck:
            return "square.grid.2x2"
        }
    }
}

extension TactConnectionState {
    var label: String {
        switch self {
        case .disconnected:
            return "Disconnected"

        case .connecting:
            return "Connecting"

        case .connected:
            return "Connected"

        case .reconnecting:
            return "Reconnecting"
        }
    }
}
