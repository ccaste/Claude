import SwiftUI

struct JobsListView: View {
    @State private var jobs: [Job] = []
    @State private var isLoading = false
    @State private var stage: Stage = .all
    @State private var showingNewLead = false

    // High-level groupings of the lifecycle for quick filtering.
    enum Stage: String, CaseIterable {
        case all = "All", leads = "Leads", active = "Active", closed = "Closed"
        func matches(_ s: JobStatus) -> Bool {
            switch self {
            case .all:    return true
            case .leads:  return s == .lead || s == .quoted
            case .active: return [.approved, .partially_installed, .installed, .ready_for_takedown].contains(s)
            case .closed: return [.stored, .declined, .cancelled].contains(s)
            }
        }
    }

    var shown: [Job] { jobs.filter { stage.matches($0.status) } }

    var body: some View {
        NavigationStack {
            List {
                Picker("Stage", selection: $stage) {
                    ForEach(Stage.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                if shown.isEmpty && !isLoading {
                    ContentUnavailableView("No jobs here",
                        systemImage: "briefcase",
                        description: Text("Tap + to create a lead."))
                }
                ForEach(shown) { job in
                    NavigationLink(value: job) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(job.title).font(.headline)
                                Spacer()
                                statusBadge(job.status)
                            }
                            HStack(spacing: 8) {
                                Label(job.service_type.label, systemImage: "lightbulb")
                                if let year = job.season_year { Text("· \(String(year)) season") }
                            }
                            .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Jobs")
            .navigationDestination(for: Job.self) { JobDetailView(job: $0) }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingNewLead = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showingNewLead) {
                NewRequestView { Task { await load() } }
            }
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
            .lineLimit(1)
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
