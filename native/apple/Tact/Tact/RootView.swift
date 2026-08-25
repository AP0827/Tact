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

    private let devices = [
        TactDevice(
            name: "Studio-Mac",
            platform: "macOS",
            model: "MacBook Pro",
            os: "macOS 27",
            ip: "192.168.1.42"
        ),
        TactDevice(
            name: "Workstation",
            platform: "Windows",
            model: "Windows PC",
            os: "Windows 11",
            ip: "192.168.1.38"
        ),
        TactDevice(
            name: "Linux-Dev",
            platform: "Linux",
            model: "Linux Workstation",
            os: "Ubuntu 24.04",
            ip: "192.168.1.51"
        ),
        TactDevice(
            name: "Mac Mini",
            platform: "macOS",
            model: "Mac mini",
            os: "macOS 27",
            ip: "192.168.1.44"
        )
    ]

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
                            model.phase = .login
                        }
                        .foregroundStyle(blue)
                    }

                    VStack(
                        alignment: .leading,
                        spacing: 0
                    ) {
                        ForEach(
                            Array(devices.enumerated()),
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

                            if index < devices.count - 1 {
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
    let device: TactDevice
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
                Text(device.name)
                    .font(.headline)

                Text(
                    "\(device.model) · \(device.os)"
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)

                Text(device.ip)
                    .font(.caption.monospaced())
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            if busy {
                ProgressView()
                    .tint(blue)
            } else {
                Text("Connect")
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
    }

    private var icon: String {
        switch device.platform {
        case "Windows":
            return "desktopcomputer"

        case "Linux":
            return "server.rack"

        default:
            return "laptopcomputer"
        }
    }
}
