import SwiftUI
import TactCore

struct RootView: View {
    @EnvironmentObject private var model: TactAppModel

    private let blue = Color(
        red: 0.02,
        green: 0.68,
        blue: 0.88
    )

    var body: some View {
        Group {
            switch model.phase {
            case .login:
                AuthView()

            case .devices:
                DeviceSelectionView()

            case .connected:
                MainShellView()
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct DeviceSelectionView: View {
    @EnvironmentObject private var model: TactAppModel

    private let blue = Color(
        red: 0.02,
        green: 0.68,
        blue: 0.88
    )

    var body: some View {
        ZStack {
            TactBackground()

            ScrollView {
                VStack(
                    alignment: .leading,
                    spacing: 28
                ) {
                    HStack {
                        VStack(
                            alignment: .leading,
                            spacing: 5
                        ) {
                            Text("Choose a computer")
                                .font(
                                    .system(
                                        size: 32,
                                        weight: .bold
                                    )
                                )

                            Text(
                                "Select a computer to control remotely."
                            )
                            .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button("Sign Out") {
                            Task { await model.signOut() }
                        }
                        .foregroundStyle(blue)
                    }

                    VStack(
                        alignment: .leading,
                        spacing: 0
                    ) {
                        ForEach(
                            Array(model.accountDevices.enumerated()),
                            id: \.element.id
                        ) { index, device in

                            Button {
                                Task {
                                    await model.connect(
                                        device: device
                                    )
                                }
                            } label: {
                                DeviceRow(
                                    device: device,
                                    busy:
                                        model.isBusy &&
                                        model.selectedDevice?.id ==
                                        device.id
                                )
                            }
                            .buttonStyle(.plain)

                            if index < model.accountDevices.count - 1 {
                                Divider()
                                    .overlay(
                                        Color.white.opacity(0.08)
                                    )
                                    .padding(.leading, 74)
                            }
                        }
                    }
                    .padding(8)
                    .background(
                        Color.white.opacity(0.055),
                        in: RoundedRectangle(
                            cornerRadius: 24
                        )
                    )

                    if model.accountDevices.isEmpty {
                        ContentUnavailableView(
                            "No computers yet",
                            systemImage: "desktopcomputer",
                            description: Text(
                                "Sign in on a desktop Tact app to make it available here."
                            )
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 34)
                    }

                    Button {
                        Task {
                            do {
                                try await model.refreshDevices()
                            } catch {
                                model.error = error.localizedDescription
                            }
                        }
                    } label: {
                        Label("Refresh devices", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.tactSecondary)

                    Button {
                        /*
                         IP + OTP navigation is handled
                         directly by AuthView's own mode.
                         */
                        model.phase = .login
                    } label: {
                        HStack {
                            Image(systemName: "network")
                            Text("Connect using IP + OTP")
                            Spacer()
                            Image(systemName: "arrow.right")
                        }
                        .foregroundStyle(blue)
                        .padding(.horizontal, 18)
                        .frame(height: 56)
                        .frame(maxWidth: .infinity)
                        .background(
                            Color.white.opacity(0.055),
                            in: RoundedRectangle(
                                cornerRadius: 18
                            )
                        )
                    }
                }
                .padding(24)
                .frame(maxWidth: 900)
                .frame(maxWidth: .infinity)
            }
        }
    }
}

struct DeviceRow: View {
    let device: TactAccountDevice
    let busy: Bool

    private let blue = Color(
        red: 0.02,
        green: 0.68,
        blue: 0.88
    )

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(
                    cornerRadius: 14
                )
                .fill(
                    blue.opacity(0.10)
                )

                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundStyle(blue)
            }
            .frame(
                width: 52,
                height: 52
            )

            VStack(
                alignment: .leading,
                spacing: 4
            ) {
                Text(device.label)
                    .font(.headline)

                Text(
                    "\(device.model.isEmpty ? device.platform : device.model) · \(device.platform)"
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)

                Text(device.host ?? "Not available on this network")
                    .font(.caption.monospaced())
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            if busy {
                ProgressView()
                    .tint(blue)
            } else if device.canConnect {
                VStack(alignment: .trailing, spacing: 5) {
                    Text("Connect")
                        .font(
                            .system(
                                size: 15,
                                weight: .semibold
                            )
                        )
                        .foregroundStyle(blue)
                    Label(
                        device.active ? "Active now" : "Offline",
                        systemImage: device.active ? "circle.fill" : "circle"
                    )
                    .font(.caption2)
                    .foregroundStyle(device.active ? .green : .secondary)
                }
            } else {
                Text(device.active ? "This device" : "Offline")
                    .font(
                        .system(
                            size: 15,
                            weight: .semibold
                        )
                    )
                    .foregroundStyle(blue)
            }
        }
        .padding(14)
        .contentShape(Rectangle())
        .opacity(device.canConnect ? 1 : 0.72)
    }

    private var icon: String {
        switch device.platform {
        case "windows":
            return "desktopcomputer"

        case "linux":
            return "server.rack"

        case "macos":
            return "laptopcomputer"

        case "ipados":
            return "ipad"

        case "ios":
            return "iphone"

        case "android":
            return "smartphone"

        default:
            return "desktopcomputer"
        }
    }
}
