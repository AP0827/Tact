import SwiftUI

extension Color {
    static let tactCyan = Color(red: 0.13, green: 0.83, blue: 0.93)
    static let tactBackground = Color.black
}

struct TactGlassModifier: ViewModifier {
    var prominent = false
    func body(content: Content) -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            content.glassEffect(prominent ? .regular.interactive() : .regular, in: .rect(cornerRadius: 22))
        } else {
            content.background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
    }
}
extension View { func tactGlass(prominent: Bool = false) -> some View { modifier(TactGlassModifier(prominent: prominent)) } }

struct MetricView: View {
    let title: String; let systemImage: String; let value: Double?
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { Image(systemName: systemImage).foregroundStyle(Color.tactCyan); Spacer(); Text(value.map { "\(Int($0))%" } ?? "—").font(.system(.title2, design: .rounded).weight(.semibold)) }
            ProgressView(value: min(max((value ?? 0) / 100, 0), 1)).tint(Color.tactCyan)
            Text(title).foregroundStyle(.secondary)
        }.padding(18).tactGlass()
    }
}
