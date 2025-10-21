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
    var createdBy: UUID?
    var createdByUsername: String?

    var durationDays: Int {
        Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0
    }

    var progressFraction: Double {
        guard goalDistanceMeters > 0 else { return 0 }
        return min(progressMeters / goalDistanceMeters, 1)
    }

    static func demo(start: Date, days: Int, title: String, detail: String, goalKm: Double, isPublic: Bool = true, createdBy: UUID? = nil, createdByUsername: String? = nil) -> Challenge {
        let end = Calendar.current.date(byAdding: .day, value: days, to: start) ?? start
        return Challenge(id: UUID(), title: title, detail: detail, startDate: start, endDate: end, goalDistanceMeters: goalKm * 1000, isJoined: false, progressMeters: 0, isPublic: isPublic, createdBy: createdBy, createdByUsername: createdByUsername)
    }
}

struct Club: Identifiable, Hashable {
    let id: UUID
    var name: String
    var description: String
    var isPublic: Bool
    var isJoined: Bool
    var memberCount: Int
}

import Foundation
import Combine

struct LeaderboardEntry: Identifiable, Hashable {
    let id: UUID
    var rank: Int
    var userName: String
    var totalDistanceMeters: Double
    // Optional fields to support filters beyond distance
    var totalDurationSeconds: Double?
    var currentStreakDays: Int?
}

enum LeaderboardSort: String, CaseIterable { case distance, pace, streak }

final class CommunityViewModel: ObservableObject {
    @Published var challenges: [Challenge] = []
    @Published var leaderboard: [LeaderboardEntry] = []
    @Published var leaderboardSort: LeaderboardSort = .distance
    @Published var clubs: [Club] = []

    private let dataSource: CommunityDataSource
    
    // User-specific keys to prevent join state sharing between users
    @MainActor
    private func getJoinStatesKey() -> String {
        guard let userId = SupabaseAuthManager.shared.userId else {
            print("DEBUG: getJoinStatesKey() - No userId, using anonymous key")
            return "community_join_states_anonymous"
        }
        let key = "community_join_states_\(userId)"
        print("DEBUG: getJoinStatesKey() - Using key: \(key)")
        return key
    }
    
    @MainActor
    private func getClubJoinStatesKey() -> String {
        guard let userId = SupabaseAuthManager.shared.userId else {
            return "community_club_join_states_anonymous"
        }
        return "community_club_join_states_\(userId)"
    }
    
    @MainActor
    private func loadJoinStates() -> [String: Bool] {
        (UserDefaults.standard.dictionary(forKey: getJoinStatesKey()) as? [String: Bool]) ?? [:]
    }
    
    @MainActor
    private func saveJoinState(challengeID: UUID, isJoined: Bool) {
        var map = loadJoinStates()
        map[challengeID.uuidString] = isJoined
        let key = getJoinStatesKey()
        print("DEBUG: saveJoinState() - Saving challengeID: \(challengeID.uuidString), isJoined: \(isJoined) to key: \(key)")
        print("DEBUG: saveJoinState() - Full map: \(map)")
        UserDefaults.standard.set(map, forKey: key)
    }
    
    @MainActor
    private func loadClubJoinStates() -> [String: Bool] {
        (UserDefaults.standard.dictionary(forKey: getClubJoinStatesKey()) as? [String: Bool]) ?? [:]
    }
    
    @MainActor
    private func saveClubJoinState(clubID: UUID, isJoined: Bool) {
        var map = loadClubJoinStates()
        map[clubID.uuidString] = isJoined
        UserDefaults.standard.set(map, forKey: getClubJoinStatesKey())
    }

    // Offline write queue (user-specific)
    @MainActor
    private func getWriteQueueKey() -> String {
        guard let userId = SupabaseAuthManager.shared.userId else {
            return "community_write_queue_anonymous"
        }
        return "community_write_queue_\(userId)"
    }
    
    private struct QueuedWrite: Codable {
        enum Kind: String, Codable { case join, contributions, clubJoin, invite }
        let kind: Kind
        let challengeID: UUID?
        let isJoined: Bool?
        let items: [SupabaseCommunityDataSource.ContributionUpload]?
        let clubID: UUID?
        let usernames: [String]?
    }
    
    @MainActor
    private func loadQueuedWrites() -> [QueuedWrite] {
        guard let data = UserDefaults.standard.data(forKey: getWriteQueueKey()) else { return [] }
        return (try? JSONDecoder().decode([QueuedWrite].self, from: data)) ?? []
    }
    
    @MainActor
    private func persistQueuedWrites(_ ops: [QueuedWrite]) {
        let data = try? JSONEncoder().encode(ops)
        UserDefaults.standard.set(data, forKey: getWriteQueueKey())
    }
    
    @MainActor
    private func enqueue(_ op: QueuedWrite) {
        var ops = loadQueuedWrites()
        ops.append(op)
        persistQueuedWrites(ops)
    }

    init(dataSource: CommunityDataSource = MockCommunityDataSource()) {
        self.dataSource = dataSource
        
        // Clean up old shared keys on first launch (migration)
        cleanupOldSharedKeys()
        
        Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(named: .supabaseAuthStateChanged) {
                print("DEBUG: Auth state changed - clearing challenges and reloading")
                await MainActor.run {
                    self?.challenges = []
                    self?.leaderboard = []
                    self?.clubs = []
                }
                await self?.flushOfflineQueue()
                self?.load()
            }
        }
    }
    
    // Migration: Remove old shared keys that caused join state to leak between users
    private func cleanupOldSharedKeys() {
        let oldKeys = ["community_join_states", "community_club_join_states", "community_write_queue"]
        for key in oldKeys {
            if UserDefaults.standard.object(forKey: key) != nil {
                print("DEBUG: Removing old shared key: \(key)")
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
    }

    func load() {
        Task {
            let ch = try await dataSource.loadChallenges()
            let lb = try await dataSource.loadLeaderboard()
            
            let persisted = await MainActor.run { loadJoinStates() }
            print("DEBUG: CommunityViewModel.load() - Loaded \(ch.count) challenges")
            print("DEBUG: CommunityViewModel.load() - Persisted join states: \(persisted)")
            let adjusted = ch.map { c -> Challenge in
                var copy = c
                copy.isJoined = persisted[c.id.uuidString] ?? false
                print("DEBUG: Challenge '\(c.title)' - ID: \(c.id.uuidString) - isJoined: \(copy.isJoined)")
                return copy
            }
            
            let clubs = try await dataSource.loadClubs()
            let clubPersisted = await MainActor.run { loadClubJoinStates() }
            let adjustedClubs = clubs.map { cl -> Club in
                var c = cl
                c.isJoined = clubPersisted[cl.id.uuidString] ?? c.isJoined
                return c
            }
            
            await MainActor.run {
                self.challenges = adjusted
                self.leaderboard = lb
                self.applyLeaderboardSort()
                self.clubs = adjustedClubs
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
                let op = QueuedWrite(kind: .join, challengeID: challengeID, isJoined: joined, items: nil as [SupabaseCommunityDataSource.ContributionUpload]?, clubID: nil, usernames: nil)
                await MainActor.run { enqueue(op) }
            }
        }
    }

    @MainActor
    func toggleClubJoin(clubID: UUID) {
        guard let idx = clubs.firstIndex(where: { $0.id == clubID }) else { return }
        clubs[idx].isJoined.toggle()
        saveClubJoinState(clubID: clubID, isJoined: clubs[idx].isJoined)
        let joined = clubs[idx].isJoined
        Task {
            do { try await dataSource.setClubMembership(clubID: clubID, isJoined: joined) }
            catch {
                let op = QueuedWrite(kind: .clubJoin, challengeID: nil, isJoined: joined, items: nil, clubID: clubID, usernames: nil)
                await MainActor.run { enqueue(op) }
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
                let op = QueuedWrite(kind: .join, challengeID: created.id, isJoined: true, items: nil as [SupabaseCommunityDataSource.ContributionUpload]?, clubID: nil, usernames: nil)
                await MainActor.run { enqueue(op) }
            }
        }
    }

    func createClub(name: String, description: String, isPublic: Bool) async throws {
        let created = try await dataSource.createClub(name: name, description: description, isPublic: isPublic)
        await MainActor.run {
            self.clubs.insert(created, at: 0)
            self.saveClubJoinState(clubID: created.id, isJoined: created.isJoined)
        }
        do { try await dataSource.setClubMembership(clubID: created.id, isJoined: created.isJoined) }
        catch {
            let op = QueuedWrite(kind: .clubJoin, challengeID: nil, isJoined: created.isJoined, items: nil, clubID: created.id, usernames: nil)
            await MainActor.run { enqueue(op) }
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
        applyLeaderboardSort()
        Task { await syncContributionsForJoinedChallenges(from: store) }
    }

    @MainActor
    func setLeaderboardSort(_ sort: LeaderboardSort) {
        leaderboardSort = sort
        applyLeaderboardSort()
    }

    @MainActor
    private func applyLeaderboardSort() {
        switch leaderboardSort {
        case .distance:
            leaderboard.sort { $0.totalDistanceMeters > $1.totalDistanceMeters }
        case .pace:
            // Sort by average pace (min/km) ascending; requires distance & duration
            leaderboard.sort { a, b in
                let aDur = a.totalDurationSeconds ?? 0
                let bDur = b.totalDurationSeconds ?? 0
                let aDist = max(a.totalDistanceMeters, 1)
                let bDist = max(b.totalDistanceMeters, 1)
                let aSecPerKm = aDur / (aDist / 1000.0)
                let bSecPerKm = bDur / (bDist / 1000.0)
                return aSecPerKm < bSecPerKm
            }
        case .streak:
            // Sort by streak days descending
            leaderboard.sort { ($0.currentStreakDays ?? 0) > ($1.currentStreakDays ?? 0) }
        }
        for i in leaderboard.indices { leaderboard[i].rank = i + 1 }
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
                    self.applyLeaderboardSort()
                }
            } catch {
                let op = QueuedWrite(kind: .contributions, challengeID: ch.id, isJoined: nil, items: items, clubID: nil, usernames: nil)
                await MainActor.run { enqueue(op) }
            }
        }
    }

    private func flushOfflineQueue() async {
        let ops = await MainActor.run { loadQueuedWrites() }
        guard !ops.isEmpty else { return }
        var remaining: [QueuedWrite] = []
        for op in ops {
            do {
                switch op.kind {
                case .join:
                    try await dataSource.setJoinState(challengeID: op.challengeID!, isJoined: op.isJoined ?? true)
                case .contributions:
                    try await dataSource.uploadDailyContributions(challengeID: op.challengeID!, items: op.items ?? [])
                case .clubJoin:
                    try await dataSource.setClubMembership(clubID: op.clubID!, isJoined: op.isJoined ?? true)
                case .invite:
                    try await dataSource.inviteToChallenge(challengeID: op.challengeID!, usernames: op.usernames ?? [])
                }
            } catch {
                remaining.append(op)
            }
        }
        await MainActor.run { persistQueuedWrites(remaining) }
    }

    // Delete APIs

    func inviteParticipants(challengeID: UUID, usernames: [String]) {
        Task {
            do { try await dataSource.inviteToChallenge(challengeID: challengeID, usernames: usernames) }
            catch {
                let op = QueuedWrite(kind: .invite, challengeID: challengeID, isJoined: nil, items: nil, clubID: nil, usernames: usernames)
                await MainActor.run { enqueue(op) }
            }
        }
    }
    
    // MARK: - Ownership Methods
    
    @MainActor
    func canModifyChallenge(_ challenge: Challenge) -> Bool {
        guard let currentUserId = getCurrentUserId() else { return false }
        return challenge.createdBy == currentUserId
    }
    
    @MainActor
    func canDeleteChallenge(_ challenge: Challenge) -> Bool {
        return canModifyChallenge(challenge)
    }
    
    @MainActor
    private func getCurrentUserId() -> UUID? {
        guard let userIdString = SupabaseAuthManager.shared.userId else { return nil }
        return UUID(uuidString: userIdString)
    }
    
    @MainActor
    func deleteChallenge(challengeID: UUID) async throws {
        guard let challenge = challenges.first(where: { $0.id == challengeID }),
              canDeleteChallenge(challenge) else {
            throw NSError(domain: "CommunityViewModel", code: 403, userInfo: [NSLocalizedDescriptionKey: "You don't have permission to delete this challenge"])
        }
        
        try await dataSource.deleteChallenge(challengeID: challengeID)
        challenges.removeAll { $0.id == challengeID }
        var states = self.loadJoinStates()
        states.removeValue(forKey: challengeID.uuidString)
        UserDefaults.standard.set(states, forKey: self.getJoinStatesKey())
    }
}