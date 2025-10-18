import SwiftUI

struct DayContribution: Identifiable {
    let id = UUID()
    let date: Date
    let distanceMeters: Double
}

struct ChallengeDetailView: View {
    let challenge: Challenge
    @EnvironmentObject var store: ActivityStore
    @EnvironmentObject var community: CommunityViewModel

    private var currentChallenge: Challenge {
        community.challenges.first(where: { $0.id == challenge.id }) ?? challenge
    }

    private var dateRangeText: String {
        let startStr = currentChallenge.startDate.formatted(date: .abbreviated, time: .omitted)
        let endStr = currentChallenge.endDate.formatted(date: .abbreviated, time: .omitted)
        return "\(startStr) – \(endStr)"
    }

    private func dayContributions() -> [DayContribution] {
        var items: [DayContribution] = []
        let cal = Calendar(identifier: .iso8601)
        var day = cal.startOfDay(for: currentChallenge.startDate)
        let end = cal.startOfDay(for: currentChallenge.endDate)
        while day <= end {
            let distance = store.dailySummaries()
                .filter { $0.dayStart == day }
                .reduce(0.0) { $0 + $1.totalDistanceMeters }
            items.append(DayContribution(date: day, distanceMeters: distance))
            day = cal.date(byAdding: .day, value: 1, to: day) ?? day
        }
        return items
    }

    var body: some View {
        let contributions = dayContributions()
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text(currentChallenge.title)
                            .font(.title2)
                            .foregroundColor(.taqvoTextDark)
                        Spacer()
                        Button(currentChallenge.isJoined ? "Leave" : "Join") {
                            community.toggleJoin(challengeID: currentChallenge.id)
                            community.refreshProgress(from: store)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.taqvoCTA)
                    }

                    Text(currentChallenge.detail)
                        .foregroundColor(.taqvoAccentText)

                    HStack {
                        Text(dateRangeText)
                            .font(.caption)
                            .foregroundColor(.taqvoAccentText)
                        Spacer()
                        Text(String(format: "Goal: %.0f km", currentChallenge.goalDistanceMeters/1000.0))
                            .font(.caption)
                            .foregroundColor(.taqvoAccentText)
                    }

                    ProgressView(value: currentChallenge.progressFraction) {
                        Text(String(format: "Progress: %.1f/%.1f km", currentChallenge.progressMeters/1000.0, currentChallenge.goalDistanceMeters/1000.0))
                            .foregroundColor(.taqvoTextDark)
                    }
                    .tint(.taqvoCTA)

                    Text("Per-day contribution")
                        .font(.headline)
                        .foregroundColor(.taqvoTextDark)

                    DailyContributionsBarChart(days: contributions)
                        .frame(height: 160)
                        .padding(.vertical, 4)

                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(contributions) { d in
                            HStack {
                                Text(d.date.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption)
                                    .foregroundColor(.taqvoAccentText)
                                Spacer()
                                Text(String(format: "%.2f km", d.distanceMeters/1000.0))
                                    .foregroundColor(.taqvoTextDark)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .padding()
            }
            .background(Color.taqvoBackgroundDark)
            .navigationTitle("Challenge")
        }
        .onAppear {
            community.refreshProgress(from: store)
        }
    }
}

struct DailyContributionsBarChart: View {
    let days: [DayContribution]

    private var maxDistance: Double { max(days.map { $0.distanceMeters }.max() ?? 0, 1) }

    var body: some View {
        GeometryReader { geo in
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(days) { d in
                    let ratio = CGFloat(d.distanceMeters / maxDistance)
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.taqvoCTA)
                            .frame(width: max(8, (geo.size.width - 6 * CGFloat(days.count - 1)) / CGFloat(days.count)), height: max(8, geo.size.height * ratio))
                        Text(d.date.formatted(.dateTime.day()))
                            .font(.caption2)
                            .foregroundColor(.taqvoAccentText)
                            .lineLimit(1)
                    }
                }
            }
        }
    }
}