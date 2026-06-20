import SwiftUI

@main
struct LUXApp: App {
    @StateObject private var auth = AuthViewModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(auth)
                .tint(.green)   // LUX brand accent — adjust to taste
        }
    }
}
