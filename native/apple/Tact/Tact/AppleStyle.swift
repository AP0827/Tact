import SwiftUI

extension Color {
    static let tactCyan = Color(
        red: 0.02,
        green: 0.72,
        blue: 0.88
    )

    static let tactBackground = Color.black
}

struct TactBackground: View {
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color.tactCyan.opacity(0.06),
                    Color.clear,
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
    }
}

struct TactCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(Color.white.opacity(0.055))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(
                        Color.white.opacity(0.08),
                        lineWidth: 1
                    )
            )
    }
}

extension View {
    func tactCard() -> some View {
        modifier(TactCard())
    }

    @ViewBuilder
    func tactGlass(prominent: Bool = false) -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            self.glassEffect(
                prominent ? .regular.interactive() : .regular,
                in: .rect(cornerRadius: 20)
            )
        } else {
            self
                .background(
                    .thinMaterial,
                    in: RoundedRectangle(
                        cornerRadius: 20,
                        style: .continuous
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            prominent
                            ? Color.tactCyan.opacity(0.25)
                            : Color.white.opacity(0.08),
                            lineWidth: 1
                        )
                )
        }
    }
}

struct TactPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Color.black)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                Color.tactCyan.opacity(
                    configuration.isPressed ? 0.7 : 1
                ),
                in: RoundedRectangle(cornerRadius: 14)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct TactSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Color.white)
            .padding(.horizontal, 18)
            .frame(minHeight: 48)
            .background(
                Color.white.opacity(
                    configuration.isPressed ? 0.10 : 0.055
                ),
                in: RoundedRectangle(cornerRadius: 14)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        Color.white.opacity(0.08),
                        lineWidth: 1
                    )
            )
    }
}

extension ButtonStyle where Self == TactPrimaryButtonStyle {
    static var tactPrimary: Self {
        TactPrimaryButtonStyle()
    }
}

extension ButtonStyle where Self == TactSecondaryButtonStyle {
    static var tactSecondary: Self {
        TactSecondaryButtonStyle()
    }
}

struct GoogleLogo: View {
    var body: some View {
        Text("G")
            .font(
                .system(
                    size: 20,
                    weight: .bold,
                    design: .rounded
                )
            )
            .foregroundStyle(
                AngularGradient(
                    colors: [
                        Color(red: 0.26, green: 0.52, blue: 0.96),
                        Color(red: 0.85, green: 0.20, blue: 0.18),
                        Color(red: 0.98, green: 0.73, blue: 0.10),
                        Color(red: 0.20, green: 0.65, blue: 0.32),
                        Color(red: 0.26, green: 0.52, blue: 0.96)
                    ],
                    center: .center
                )
            )
    }
}

struct TactMetricView: View {
    let title: String
    let systemImage: String
    let value: Double?

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(Color.tactCyan)
                .frame(width: 42)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(Color.secondary)

                Text(
                    value.map {
                        String(format: "%.0f%%", $0)
                    } ?? "—"
                )
                .font(.title3.weight(.semibold))
            }

            Spacer()
        }
        .padding(18)
        .tactCard()
    }
}
