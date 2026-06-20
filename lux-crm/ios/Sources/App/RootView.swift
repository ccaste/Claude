import SwiftUI

// Switches between the login screen and the main tab bar based on auth state.
struct RootView: View {
    @EnvironmentObject var auth: AuthViewModel

    var body: some View {
        Group {
            if auth.isLoading {
                ProgressView("Loading…")
            } else if auth.isAuthenticated {
                MainTabView()
            } else {
                LoginView()
            }
        }
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Today", systemImage: "sun.max") }

            ScheduleView()
                .tabItem { Label("Schedule", systemImage: "calendar") }

            ClientsListView()
                .tabItem { Label("Clients", systemImage: "person.2") }

            JobsListView()
                .tabItem { Label("Jobs", systemImage: "briefcase") }

            CatalogListView()
                .tabItem { Label("Price Book", systemImage: "tag") }
        }
    }
}
