import Foundation
import SwiftUI

struct Challenge: Identifiable, Hashable {
    let id: UUID
    var title: String
    var detail: String
    var startDate: Date
    var endDate: Date
    var goalDistanceMeters: Double
    var isJoined: Bool
    var progressMeters: Double

    var durationDays: Int {
        Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0
    }

    var progressFraction: Double {
        guard goalDistanceMeters > 0 else { return 0 }
        return min(progressMeters / goalDistanceMeters, 1)
    }

    static func demo(start: Date, days: Int, title: String, detail: String, goalKm: Double) -> Challenge {
        let end = Calendar.current.date(byAdding: .day, value: days, to: start) ?? start
        return Challenge(id: UUID(), title: title, detail: detail, startDate: start, endDate: end, goalDistanceMeters: goalKm * 1000, isJoined: false, progressMeters: 0)
    }
}

struct LeaderboardEntry: Identifiable, Hashable {
    let id: UUID
    var rank: Int
    var userName: String
    var totalDistanceMeters: Double
}

final class CommunityViewModel: ObservableObject {
    @Published var challenges: [Challenge] = []
    @Published var leaderboard: [LeaderboardEntry] = []

    private let dataSource: CommunityDataSource

    init(dataSource: CommunityDataSource = MockCommunityDataSource()) {
        self.dataSource = dataSource
    }

    func load() {
        Task {
            let ch = try await dataSource.loadChallenges()
            let lb = try await dataSource.loadLeaderboard()
            await MainActor.run {
                self.challenges = ch
                self.leaderboard = lb
            }
        }
    }

    // Backwards-compatible convenience used by existing UI calls
    func loadDemoData() { load() }

    func toggleJoin(challengeID: UUID) {
        guard let idx = challenges.firstIndex(where: { $0.id == challengeID }) else { return }
        challenges[idx].isJoined.toggle()
        Task { try? await dataSource.setJoinState(challengeID: challengeID, isJoined: challenges[idx].isJoined) }
    }

    func refreshProgress(from store: ActivityStore) {
        for i in challenges.indices {
            let ch = challenges[i]
            let sum = store.dailySummaries()
                .filter { $0.dayStart >= ch.startDate && $0.dayStart <= ch.endDate }
                .reduce(0.0) { $0 + $1.totalDistanceMeters }
            challenges[i].progressMeters = sum
        }
        leaderboard.sort { $0.totalDistanceMeters > $1.totalDistanceMeters }
        for i in leaderboard.indices { leaderboard[i].rank = i + 1 }
    }
}