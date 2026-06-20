import SwiftUI

struct JobsListView: View {
    @State private var jobs: [Job] = []
    @State private var isLoading = false
    @State private var filter: JobStatus? = nil

    var shown: [Job] {
        guard let filter else { return jobs }
        return jobs.filter { $0.status == filter }
    }

    var body: some View {
        NavigationStack {
            List {
                Picker("Status", selection: $filter) {
                    Text("All").tag(JobStatus?.none)
                    ForEach(JobStatus.allCases, id: \.self) { s in
                        Text(s.label).tag(JobStatus?.some(s))
                    }
                }
                .pickerStyle(.menu)

                if shown.isEmpty && !isLoading {
                    ContentUnavailableView("No jobs",
                        systemImage: "briefcase",
                        description: Text("Jobs you create will show up here."))
                }
                ForEach(shown) { job in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(job.title).font(.headline)
                            Spacer()
                            statusBadge(job.status)
                        }
                        HStack(spacing: 8) {
                            Label(job.service_type.label, systemImage: "lightbulb")
                            if let year = job.season_year {
                                Text("· \(String(year)) season")
                            }
                        }
                        .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Jobs")
            .overlay { if isLoading { ProgressView() } }
            .refreshable { await load() }
            .task { if jobs.isEmpty { await load() } }
        }
    }

    private func statusBadge(_ status: JobStatus) -> some View {
        Text(status.label)
            .font(.caption2.bold())
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(.green.opacity(0.15), in: Capsule())
            .foregroundStyle(.green)
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        jobs = (try? await supabase
            .from("jobs").select()
            .order("created_at", ascending: false)
            .execute().value) ?? []
    }
}
