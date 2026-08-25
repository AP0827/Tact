import SwiftUI
import TactCore

struct EventsView: View {
    @EnvironmentObject private var model: TactAppModel
    @State private var filter = "All"
    let filters = ["All", "Security", "Git", "Build"]
    var body: some View {
        NavigationStack { List { ForEach(filtered.indices, id: \.self) { i in EventRow(event: filtered[i]) } }.navigationTitle("Events").toolbar { Picker("Filter", selection: $filter) { ForEach(filters, id: \.self) { Text($0).tag($0) } }.pickerStyle(.menu) } }
    }
    private var filtered: [[String: AnySendable]] { guard filter != "All" else { return model.events }; return model.events.filter { ($0["category"]?.value as? String)?.localizedCaseInsensitiveContains(filter) == true } }
}
struct EventRow: View { let event: [String: AnySendable]; var body: some View { HStack(alignment: .top, spacing: 12) { Image(systemName: "bell.badge").foregroundStyle(Color.tactCyan); VStack(alignment: .leading, spacing: 4) { Text(event["title"]?.value as? String ?? "Tact event").font(.headline); Text(event["description"]?.value as? String ?? "").foregroundStyle(.secondary); Text(event["timestamp"]?.value as? String ?? "").font(.caption).foregroundStyle(.tertiary) } } }
}
