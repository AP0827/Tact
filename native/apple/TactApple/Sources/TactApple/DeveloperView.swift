import SwiftUI

struct DeveloperView: View {
    @EnvironmentObject private var model: TactAppModel
    var body: some View {
        ScrollView { VStack(alignment: .leading, spacing: 18) {
            Text("Developer").font(.largeTitle.weight(.bold))
            HStack { Label(model.string("workspace.git.current") ?? "Git repository", systemImage: "folder"); Spacer(); Text(model.string("workspace.git.branch") ?? "main").font(.caption.monospaced()).foregroundStyle(.secondary) }.padding(16).tactGlass()
            SectionCard(title: "Git") {
                HStack { action("Stage All", "checkmark.circle", "git.add"); action("Pull", "arrow.down", "git.pull"); action("Push", "arrow.up", "git.push") }
                Text(model.string("workspace.git.summary") ?? "Live Git status is provided by the Tact agent.").font(.callout).foregroundStyle(.secondary)
            }
            SectionCard(title: "VS Code") { Button { model.action("vscode.open_workspace") } label: { Label("Open current workspace", systemImage: "curlybraces.square") }; Text(model.string("workspace.vscode.summary") ?? "VS Code workspace detection is live when available.").foregroundStyle(.secondary) }
            SectionCard(title: "Docker") { HStack { action("Start all", "play.fill", "docker.start_all"); action("Stop all", "stop.fill", "docker.stop_all"); action("Restart", "arrow.clockwise", "docker.restart_all") } }
            SectionCard(title: "Git history") { Text("Commit graph and tree data are supplied by git.log and git.tree.").foregroundStyle(.secondary); Button("Refresh") { model.action("git.status") } }
        }.padding(24).frame(maxWidth: 1100).frame(maxWidth: .infinity) }
    }
    @ViewBuilder private func action(_ title: String, _ icon: String, _ id: String) -> some View { Button { model.action(id) } label: { Label(title, systemImage: icon) }.buttonStyle(.bordered) }
}
struct SectionCard<Content: View>: View { let title: String; @ViewBuilder let content: () -> Content; init(title: String, @ViewBuilder content: @escaping () -> Content) { self.title=title; self.content=content }; var body: some View { VStack(alignment: .leading, spacing: 14) { Text(title).font(.headline); content() }.padding(18).frame(maxWidth: .infinity, alignment: .leading).tactGlass() } }
