import SwiftUI
import TactCore

struct EventsView: View {
    @EnvironmentObject private var model: TactAppModel

    @State private var filter = "All"

    private let blue = Color(
        red: 0.02,
        green: 0.68,
        blue: 0.88
    )

    private let filters = [
        "All",
        "Security",
        "Git",
        "Build"
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    VStack(
                        alignment: .leading,
                        spacing: 5
                    ) {
                        Text("Events")
                            .font(
                                .system(
                                    size: 30,
                                    weight: .bold
                                )
                            )

                        Text(
                            "Recent activity from your Tact host."
                        )
                        .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Menu {
                        ForEach(
                            filters,
                            id: \.self
                        ) { item in
                            Button(item) {
                                filter = item
                            }
                        }
                    } label: {
                        Label(
                            filter,
                            systemImage:
                                "line.3.horizontal.decrease"
                        )
                        .foregroundStyle(blue)
                    }
                }

                if filtered.isEmpty {
                    VStack(spacing: 14) {
                        Image(systemName: "bell")
                            .font(.system(size: 32))
                            .foregroundStyle(blue)

                        Text("No Events")
                            .font(.headline)

                        Text(
                            "Events from the connected Tact host will appear here."
                        )
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(50)
                    .background(
                        Color.white.opacity(0.055),
                        in: RoundedRectangle(cornerRadius: 24)
                    )
                } else {
                    VStack(spacing: 0) {
                        ForEach(
                            Array(filtered.enumerated()),
                            id: \.offset
                        ) { _, event in
                            EventRow(event: event)
                        }
                    }
                    .background(
                        Color.white.opacity(0.055),
                        in: RoundedRectangle(cornerRadius: 24)
                    )
                }
            }
            .padding(24)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
    }

    private var filtered:
        [[String: AnySendable]] {
        guard filter != "All" else {
            return model.events
        }

        return model.events.filter {
            (
                $0["category"]?.value as? String
            )?
                .localizedCaseInsensitiveContains(filter)
                == true
        }
    }
}

struct EventRow: View {
    let event: [String: AnySendable]

    private let blue = Color(
        red: 0.02,
        green: 0.68,
        blue: 0.88
    )

    var body: some View {
        HStack(
            alignment: .top,
            spacing: 14
        ) {
            ZStack {
                Circle()
                    .fill(
                        blue.opacity(0.10)
                    )

                Image(systemName: "bell.fill")
                    .foregroundStyle(blue)
            }
            .frame(width: 42, height: 42)

            VStack(
                alignment: .leading,
                spacing: 5
            ) {
                Text(
                    event["title"]?.value as? String
                    ?? "Tact Event"
                )
                .font(.headline)

                Text(
                    event["description"]?.value as? String
                    ?? ""
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)

                Text(
                    event["timestamp"]?.value as? String
                    ?? ""
                )
                .font(.caption.monospaced())
                .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .padding(18)
    }
}
