import SwiftUI
import TactCore

struct DeveloperView: View {
    @EnvironmentObject private var model: TactAppModel

    private let blue = Color(
        red: 0.02,
        green: 0.68,
        blue: 0.88
    )

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {

                VStack(alignment: .leading, spacing: 5) {
                    Text("Developer")
                        .font(.system(size: 30, weight: .bold))

                    Text("Control your development environment.")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Label(
                        "Git Repository",
                        systemImage: "folder"
                    )
                    .foregroundStyle(blue)

                    Spacer()

                    Text(
                        model.string("workspace.git.branch")
                        ?? "main"
                    )
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                }
                .padding(18)
                .background(
                    Color.white.opacity(0.055),
                    in: RoundedRectangle(cornerRadius: 22)
                )

                SectionCard(title: "Git") {
                    HStack(spacing: 10) {
                        action(
                            "Stage All",
                            "checkmark.circle",
                            "git.add"
                        )

                        action(
                            "Pull",
                            "arrow.down",
                            "git.pull"
                        )

                        action(
                            "Push",
                            "arrow.up",
                            "git.push"
                        )
                    }

                    Text(
                        model.string("workspace.git.summary")
                        ?? "Live Git status is provided by the Tact agent."
                    )
                    .foregroundStyle(.secondary)
                }

                SectionCard(title: "VS Code") {
                    Button {
                        model.action("vscode.open_workspace")
                    } label: {
                        Label(
                            "Open current workspace",
                            systemImage: "curlybraces.square"
                        )
                    }
                    .foregroundStyle(blue)

                    Text(
                        model.string("workspace.vscode.summary")
                        ?? "VS Code workspace detection is live when available."
                    )
                    .foregroundStyle(.secondary)
                }

                SectionCard(title: "Docker") {
                    HStack(spacing: 10) {
                        action(
                            "Start all",
                            "play.fill",
                            "docker.start_all"
                        )

                        action(
                            "Stop all",
                            "stop.fill",
                            "docker.stop_all"
                        )

                        action(
                            "Restart",
                            "arrow.clockwise",
                            "docker.restart_all"
                        )
                    }
                }

                SectionCard(title: "Git History") {
                    Text(
                        "Commit graph and tree data are supplied by git.log and git.tree."
                    )
                    .foregroundStyle(.secondary)

                    Button("Refresh") {
                        model.action("git.status")
                    }
                    .foregroundStyle(blue)
                }
            }
            .padding(24)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
    }

    private func action(
        _ title: String,
        _ icon: String,
        _ id: String
    ) -> some View {
        Button {
            model.action(id)
        } label: {
            Label(title, systemImage: icon)
        }
        .foregroundStyle(blue)
        .padding(.horizontal, 13)
        .padding(.vertical, 9)
        .background(
            Color.white.opacity(0.055),
            in: Capsule()
        )
    }
}

struct SectionCard<Content: View>: View {
    let title: String
    let content: () -> Content

    init(
        title: String,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.headline)

            content()
        }
        .padding(18)
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .background(
            Color.white.opacity(0.055),
            in: RoundedRectangle(cornerRadius: 22)
        )
    }
}
