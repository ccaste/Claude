import SwiftUI

// Day-based schedule of visits. A full month calendar comes in Phase 2.
struct ScheduleView: View {
    @State private var selectedDate = Date()
    @State private var visits: [Visit] = []
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                DatePicker("Date", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .padding()

                List {
                    if visits.isEmpty && !isLoading {
                        ContentUnavailableView("No visits",
                            systemImage: "calendar.badge.exclamationmark",
                            description: Text("Nothing scheduled for this day."))
                    }
                    ForEach(visits) { visit in
                        HStack {
                            VStack(alignment: .leading) {
                                if let start = visit.scheduled_start {
                                    Text(start, format: .dateTime.hour().minute()).font(.headline)
                                } else {
                                    Text("Unscheduled").font(.headline)
                                }
                                Text(visit.kind.label).font(.subheadline).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(visit.status.label).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Schedule")
            .task(id: selectedDate) { await load() }
            .overlay { if isLoading { ProgressView() } }
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        let cal = Calendar.current
        let start = cal.startOfDay(for: selectedDate)
        let end = cal.date(byAdding: .day, value: 1, to: start)!
        visits = (try? await supabase
            .from("visits").select()
            .gte("scheduled_start", value: start.ISO8601Format())
            .lt("scheduled_start", value: end.ISO8601Format())
            .order("scheduled_start")
            .execute().value) ?? []
    }
}
