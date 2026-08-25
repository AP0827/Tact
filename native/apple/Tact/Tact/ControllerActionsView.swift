import SwiftUI

struct ControllerActionsView: View {
    @EnvironmentObject private var model: TactAppModel
    @State private var search = ""
    @State private var selectedAction: String?

    private var actions: [String] {
        model.availableActions.filter {
            search.isEmpty || $0.localizedCaseInsensitiveContains(search)
        }
    }

    private var groups: [String] {
        Array(Set(actions.map { $0.split(separator: ".").first.map(String.init) ?? "other" })).sorted()
    }

    var body: some View {
        NavigationStack {
            List {
                if actions.isEmpty {
                    ContentUnavailableView(
                        "Waiting for host capabilities",
                        systemImage: "slider.horizontal.3",
                        description: Text("The complete action catalog appears after the host sends its first snapshot.")
                    )
                }
                ForEach(groups, id: \.self) { group in
                    Section(group.capitalized) {
                        ForEach(actions.filter { $0.hasPrefix("\(group).") }, id: \.self) { action in
                            Button {
                                if ActionPayload.fields(for: action).isEmpty {
                                    model.action(action)
                                } else {
                                    selectedAction = action
                                }
                            } label: {
                                HStack {
                                    Image(systemName: ActionPayload.symbol(for: group))
                                        .foregroundStyle(Color.tactCyan)
                                        .frame(width: 28)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(ActionPayload.title(for: action))
                                        Text(action).font(.caption.monospaced()).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: ActionPayload.fields(for: action).isEmpty ? "play.fill" : "chevron.right")
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                    }
                }
                if let result = model.lastActionResult {
                    Section("Latest result") { Text(result).font(.caption.monospaced()).textSelection(.enabled) }
                }
            }
            .navigationTitle("All Controls")
            .searchable(text: $search, prompt: "Search host actions")
            .sheet(item: $selectedAction) { action in
                ActionPayloadSheet(action: action)
                    .environmentObject(model)
            }
        }
    }
}

private struct ActionPayloadSheet: View {
    @EnvironmentObject private var model: TactAppModel
    @Environment(\.dismiss) private var dismiss
    let action: String
    @State private var values: [String: String] = [:]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(ActionPayload.fields(for: action), id: \.self) { field in
                        TextField(ActionPayload.label(for: field), text: Binding(
                            get: { values[field, default: ""] },
                            set: { values[field] = $0 }
                        ), axis: field == "text" ? .vertical : .horizontal)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    }
                } footer: {
                    Text(action).font(.caption.monospaced())
                }
            }
            .navigationTitle(ActionPayload.title(for: action))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Run") {
                        model.action(action, payload: values.filter { !$0.value.isEmpty })
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

private enum ActionPayload {
    static func fields(for action: String) -> [String] {
        if action == "clipboard.set" { return ["text"] }
        if action == "context.override" { return ["app", "project"] }
        if action.hasPrefix("docker.") && !["docker.status"].contains(action) { return action == "docker.logs" ? ["name", "tail"] : ["name"] }
        if action == "git.commit" { return ["message", "path"] }
        if ["git.switch_branch", "git.pull", "git.push"].contains(action) { return ["branch", "path"] }
        if ["git.status", "git.branches", "git.add"].contains(action) { return ["path"] }
        if action == "git.tree" { return ["path", "max_depth"] }
        if action == "git.log" { return ["path", "limit"] }
        if action == "media.volume" { return ["player", "value"] }
        if action == "media.seek" { return ["player", "position"] }
        if ["media.play_pause", "media.next", "media.previous"].contains(action) { return ["player"] }
        if action.hasPrefix("project.") { return ["path"] }
        if ["system.open_url"].contains(action) { return ["url"] }
        if ["system.open_terminal", "system.open_project", "system.set_workspace"].contains(action) { return ["path"] }
        if ["system.volume", "system.brightness"].contains(action) { return ["value"] }
        if ["system.open_app", "system.focus_app"].contains(action) { return ["app"] }
        if action == "system.set_sink" { return ["sink"] }
        if action == "system.set_source" { return ["source"] }
        if action == "vscode.open_workspace" || action == "vscode.status" { return ["path"] }
        if action == "vscode.run_task" { return ["task"] }
        if action == "vscode.open_file" { return ["path", "line"] }
        if ["window.focus", "window.minimize", "window.maximize", "window.close"].contains(action) { return ["title"] }
        if action == "window.move" { return ["title", "desktop", "x", "y", "width", "height"] }
        if action == "window.apply_layout" { return ["name"] }
        return []
    }

    static func title(for action: String) -> String {
        action.split(separator: ".").last.map { $0.replacingOccurrences(of: "_", with: " ").capitalized } ?? action
    }
    static func label(for field: String) -> String { field.replacingOccurrences(of: "_", with: " ").capitalized }
    static func symbol(for group: String) -> String {
        ["system":"desktopcomputer", "vscode":"chevron.left.forwardslash.chevron.right", "git":"arrow.triangle.branch", "media":"play.circle", "docker":"shippingbox", "clipboard":"doc.on.clipboard", "context":"scope", "chrome":"globe", "teams":"video", "window":"macwindow", "project":"folder", "terminal":"terminal"][group] ?? "bolt"
    }
}

extension String: @retroactive Identifiable { public var id: String { self } }
