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
    var isPublic: Bool

    var durationDays: Int {
        Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0
    }

    var progressFraction: Double {
        guard goalDistanceMeters > 0 else { return 0 }
        return min(progressMeters / goalDistanceMeters, 1)
    }

    static func demo(start: Date, days: Int, title: String, detail: String, goalKm: Double, isPublic: Bool = true) -> Challenge {
        let end = Calendar.current.date(byAdding: .day, value: days, to: start) ?? start
        return Challenge(id: UUID(), title: title, detail: detail, startDate: start, endDate: end, goalDistanceMeters: goalKm * 1000, isJoined: false, progressMeters: 0, isPublic: isPublic)
    }
}

import Foundation
import Combine

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
    private let joinStatesKey = "community_join_states"
    private func loadJoinStates() -> [String: Bool] {
        (UserDefaults.standard.dictionary(forKey: joinStatesKey) as? [String: Bool]) ?? [:]
    }
    private func saveJoinState(challengeID: UUID, isJoined: Bool) {
        var map = loadJoinStates()
        map[challengeID.uuidString] = isJoined
        UserDefaults.standard.set(map, forKey: joinStatesKey)
    }

    // Offline write queue
    private let writeQueueKey = "community_write_queue"
    private struct QueuedWrite: Codable {
        enum Kind: String, Codable { case join, contributions }
        let kind: Kind
        let challengeID: UUID
        let isJoined: Bool?
        let items: [SupabaseCommunityDataSource.ContributionUpload]?
    }
    private func loadQueuedWrites() -> [QueuedWrite] {
        guard let data = UserDefaults.standard.data(forKey: writeQueueKey) else { return [] }
        return (try? JSONDecoder().decode([QueuedWrite].self, from: data)) ?? []
    }
    private func persistQueuedWrites(_ ops: [QueuedWrite]) {
        let data = try? JSONEncoder().encode(ops)
        UserDefaults.standard.set(data, forKey: writeQueueKey)
    }
    private func enqueue(_ op: QueuedWrite) {
        var ops = loadQueuedWrites()
        ops.append(op)
        persistQueuedWrites(ops)
    }

    init(dataSource: CommunityDataSource = MockCommunityDataSource()) {
        self.dataSource = dataSource
        Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(named: .supabaseAuthStateChanged) {
                await self?.flushOfflineQueue()
            }
        }
    }

    func load() {
        Task {
            let ch = try await dataSource.loadChallenges()
            let lb = try await dataSource.loadLeaderboard()
            let persisted = loadJoinStates()
            let adjusted = ch.map { c -> Challenge in
                var copy = c
                copy.isJoined = persisted[c.id.uuidString] ?? false
                return copy
            }
            await MainActor.run {
                self.challenges = adjusted
                self.leaderboard = lb
            }
            await flushOfflineQueue()
        }
    }

    func loadDemoData() { load() }

    @MainActor
    func toggleJoin(challengeID: UUID) {
        guard let idx = challenges.firstIndex(where: { $0.id == challengeID }) else { return }
        challenges[idx].isJoined.toggle()
        saveJoinState(challengeID: challengeID, isJoined: challenges[idx].isJoined)
        let joined = challenges[idx].isJoined
        Task {
            do { try await dataSource.setJoinState(challengeID: challengeID, isJoined: joined) }
            catch {
                let op = QueuedWrite(kind: .join, challengeID: challengeID, isJoined: joined, items: nil as [SupabaseCommunityDataSource.ContributionUpload]?)
                enqueue(op)
            }
        }
    }

    func createChallenge(title: String, detail: String, startDate: Date, endDate: Date, goalDistanceMeters: Double, isPublic: Bool, autoJoin: Bool = true) async throws {
        let created = try await dataSource.createChallenge(title: title, detail: detail, startDate: startDate, endDate: endDate, goalDistanceMeters: goalDistanceMeters, isPublic: isPublic)
        await MainActor.run {
            var model = created
            model.isJoined = autoJoin
            self.challenges.insert(model, at: 0)
            self.saveJoinState(challengeID: model.id, isJoined: model.isJoined)
        }
        if autoJoin {
            do { try await dataSource.setJoinState(challengeID: created.id, isJoined: true) }
            catch {
                let op = QueuedWrite(kind: .join, challengeID: created.id, isJoined: true, items: nil as [SupabaseCommunityDataSource.ContributionUpload]?)
                enqueue(op)
            }
        }
    }

    @MainActor
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
        Task { await syncContributionsForJoinedChallenges(from: store) }
    }

    private func syncContributionsForJoinedChallenges(from store: ActivityStore) async {
        let cal = Calendar(identifier: .iso8601)
        let daily = store.dailySummaries(using: cal)
        for ch in challenges where ch.isJoined {
            var items: [SupabaseCommunityDataSource.ContributionUpload] = []
            var day = cal.startOfDay(for: ch.startDate)
            let end = cal.startOfDay(for: ch.endDate)
            while day <= end {
                let distance = daily.first(where: { $0.dayStart == day })?.totalDistanceMeters ?? 0
                let count = daily.first(where: { $0.dayStart == day })?.runCount ?? 0
                items.append(SupabaseCommunityDataSource.ContributionUpload(day: day, distanceMeters: distance, contributionCount: count))
                day = cal.date(byAdding: .day, value: 1, to: day) ?? day
            }
            do {
                try await dataSource.uploadDailyContributions(challengeID: ch.id, items: items)
                let lb = try await dataSource.loadLeaderboard()
                await MainActor.run {
                    self.leaderboard = lb
                    self.leaderboard.sort { $0.totalDistanceMeters > $1.totalDistanceMeters }
                    for i in self.leaderboard.indices { self.leaderboard[i].rank = i + 1 }
                }
            } catch {
                let op = QueuedWrite(kind: .contributions, challengeID: ch.id, isJoined: nil, items: items)
                enqueue(op)
            }
        }
    }

    private func flushOfflineQueue() async {
        let ops = loadQueuedWrites()
        guard !ops.isEmpty else { return }
        var remaining: [QueuedWrite] = []
        for op in ops {
            do {
                switch op.kind {
                case .join:
                    try await dataSource.setJoinState(challengeID: op.challengeID, isJoined: op.isJoined ?? true)
                case .contributions:
                    try await dataSource.uploadDailyContributions(challengeID: op.challengeID, items: op.items ?? [])
                }
            } catch {
                remaining.append(op)
            }
        }
        persistQueuedWrites(remaining)
    }

    // Delete APIs
    func canDelete(challengeID: UUID) async -> Bool {
        await dataSource.canDeleteChallenge(challengeID: challengeID)
    }

    func deleteChallenge(challengeID: UUID) async throws {
        try await dataSource.deleteChallenge(challengeID: challengeID)
        await MainActor.run {
            self.challenges.removeAll { $0.id == challengeID }
            var states = self.loadJoinStates()
            states.removeValue(forKey: challengeID.uuidString)
            UserDefaults.standard.set(states, forKey: self.joinStatesKey)
        }
    }
}