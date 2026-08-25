import SwiftUI
import TactCore

struct SettingsView: View {
    @EnvironmentObject private var model: TactAppModel

    var body: some View {
        ZStack {
            TactBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("Settings")
                        .font(.system(size: 32, weight: .bold))

                    settingsSection("Appearance") {
                        HStack {
                            Label(
                                "Theme",
                                systemImage: "circle.lefthalf.filled"
                            )

                            Spacer()

                            Picker(
                                "Theme",
                                selection: Binding(
                                    get: {
                                        model.appearance
                                    },
                                    set: {
                                        model.appearance = $0
                                    }
                                )
                            ) {
                                Text("System").tag("system")
                                Text("Light").tag("light")
                                Text("Dark").tag("dark")
                            }
                            .pickerStyle(.menu)
                            .tint(Color.tactCyan)
                        }
                    }

                    settingsSection("Connection") {
                        settingRow(
                            "Device",
                            model.selectedDevice?.name ?? "None"
                        )

                        settingRow(
                            "Host",
                            model.selectedDevice?.ip ?? "—"
                        )

                        settingRow(
                            "Status",
                            String(describing: model.connection)
                        )
                    }

                    settingsSection("About") {
                        settingRow(
                            "Version",
                            "Native 2.0"
                        )

                        Text(
                            "A native control surface for your development machines."
                        )
                        .font(.subheadline)
                        .foregroundStyle(Color.secondary)
                    }
                }
                .padding(24)
                .frame(maxWidth: 800)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("")
    }

    private func settingsSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.tactCyan)

            VStack(spacing: 0) {
                content()
            }
            .padding(18)
            .tactCard()
        }
    }

    private func settingRow(
        _ title: String,
        _ value: String
    ) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(Color.secondary)

            Spacer()

            Text(value)
                .font(.subheadline.weight(.medium))
        }
        .padding(.vertical, 8)
    }
}

struct GeneralView: View {
    @EnvironmentObject private var model: TactAppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                VStack(alignment: .leading, spacing: 5) {
                    Text("Overview")
                        .font(.system(size: 30, weight: .bold))

                    Text(
                        "Everything happening on your computer."
                    )
                    .foregroundStyle(Color.secondary)
                }

                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(
                                Color.tactCyan.opacity(0.12)
                            )

                        Image(systemName: "laptopcomputer")
                            .font(.title2)
                            .foregroundStyle(Color.tactCyan)
                    }
                    .frame(width: 52, height: 52)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(
                            model.selectedDevice?.name
                            ?? "Tact Host"
                        )
                        .font(.headline)

                        Text(
                            "\(model.selectedDevice?.model ?? "Desktop") · \(model.selectedDevice?.os ?? "Connected host")"
                        )
                        .font(.subheadline)
                        .foregroundStyle(Color.secondary)

                        Text(
                            model.selectedDevice?.ip ?? "—"
                        )
                        .font(.caption.monospaced())
                        .foregroundStyle(Color.secondary)
                    }

                    Spacer()

                    Text("Connected")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.tactCyan)
                }
                .padding(18)
                .tactCard()

                LazyVGrid(
                    columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ],
                    spacing: 14
                ) {
                    TactMetricView(
                        title: "CPU",
                        systemImage: "cpu",
                        value: model.value("system.cpu")
                    )

                    TactMetricView(
                        title: "Memory",
                        systemImage: "memorychip",
                        value: model.value("system.memory")
                    )

                    TactMetricView(
                        title: "Disk",
                        systemImage: "internaldrive",
                        value: model.value("system.disk")
                    )

                    TactMetricView(
                        title: "Battery",
                        systemImage: "battery.100percent",
                        value: model.value("system.battery")
                    )
                }

                Text("Quick Controls")
                    .font(.title3.weight(.bold))

                LazyVGrid(
                    columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ],
                    spacing: 12
                ) {
                    QuickAction(
                        "Lock Screen",
                        "lock.fill",
                        "system.lock_screen"
                    )

                    QuickAction(
                        "Terminal",
                        "terminal",
                        "system.open_terminal"
                    )

                    QuickAction(
                        "Open URL",
                        "link",
                        "system.open_url"
                    )

                    QuickAction(
                        "Project",
                        "folder",
                        "system.open_project"
                    )

                    QuickAction(
                        "Screenshot",
                        "camera.viewfinder",
                        "system.screenshot"
                    )

                    QuickAction(
                        "Mute",
                        "speaker.slash",
                        "system.mute"
                    )
                }
            }
            .padding(24)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
    }
}

struct QuickAction: View {
    @EnvironmentObject private var model: TactAppModel

    let title: String
    let icon: String
    let actionID: String

    init(
        _ title: String,
        _ icon: String,
        _ actionID: String
    ) {
        self.title = title
        self.icon = icon
        self.actionID = actionID
    }

    var body: some View {
        Button {
            model.action(actionID)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)

                Text(title)
                    .font(
                        .system(
                            size: 15,
                            weight: .semibold
                        )
                    )

                Spacer()
            }
            .foregroundStyle(Color.tactCyan)
            .padding(.horizontal, 18)
            .frame(height: 64)
            .tactGlass(prominent: true)
        }
        .buttonStyle(.plain)
    }
}
