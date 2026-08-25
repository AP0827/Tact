import SwiftUI

@main
struct TactApp: App {
    @StateObject
    private var model = TactAppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
        }
    }
}
