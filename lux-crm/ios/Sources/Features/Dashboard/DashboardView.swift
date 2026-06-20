import SwiftUI

// "Today" tab — at-a-glance for the crew: today's visits and quick counts.
struct DashboardView: View {
    @EnvironmentObject var auth: AuthViewModel
    @State private var todaysVisits: [Visit] = []
    @State private var openJobsCount = 0

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        statTile("Today's Visits", "\(todaysVisits.count)", "calendar")
                        statTile("Open Jobs", "\(openJobsCount)", "briefcase")
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }

                Section("Today") {
                    if todaysVisits.isEmpty {
                        Text("Nothing scheduled for today.").foregroundStyle(.secondary)
                    }
                    ForEach(todaysVisits) { visit in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(visit.kind.label).font(.headline)
                            if let start = visit.scheduled_start {
                                Text(start, format: .dateTime.hour().minute())
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Text(visit.status.label).font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle(greeting)
            .task { await load() }
            .refreshable { await load() }
        }
    }

    private var greeting: String {
        let name = auth.profile?.full_name.split(separator: " ").first.map(String.init) ?? "Hi"
        return "Hi, \(name)"
    }

    private func statTile(_ title: String, _ value: String, _ icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon).foregroundStyle(.green)
            Text(value).font(.title.bold())
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func load() async {
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        let end = cal.date(byAdding: .day, value: 1, to: start)!

        todaysVisits = (try? await supabase
            .from("visits").select()
            .gte("scheduled_start", value: start.ISO8601Format())
            .lt("scheduled_start", value: end.ISO8601Format())
            .order("scheduled_start")
            .execute().value) ?? []

        let openJobs: [Job] = (try? await supabase
            .from("jobs").select()
            .in("status", values: JobStatus.openStatuses.map(\.rawValue))
            .execute().value) ?? []
        openJobsCount = openJobs.count
    }
}
