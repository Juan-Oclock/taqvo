import Foundation

protocol CommunityDataSource {
    // Challenges
    func loadChallenges() async throws -> [Challenge]
    func loadLeaderboard() async throws -> [LeaderboardEntry]
    func setJoinState(challengeID: UUID, isJoined: Bool) async throws
    func uploadDailyContributions(challengeID: UUID, items: [SupabaseCommunityDataSource.ContributionUpload]) async throws
    func createChallenge(title: String, detail: String, startDate: Date, endDate: Date, goalDistanceMeters: Double, isPublic: Bool) async throws -> Challenge
    func deleteChallenge(challengeID: UUID) async throws
    func canDeleteChallenge(challengeID: UUID) async -> Bool

    // Clubs / Groups
    func loadClubs() async throws -> [Club]
    func createClub(name: String, description: String, isPublic: Bool) async throws -> Club
    func setClubMembership(clubID: UUID, isJoined: Bool) async throws

    // Invites
    func inviteToChallenge(challengeID: UUID, usernames: [String]) async throws
}

final class MockCommunityDataSource: CommunityDataSource {
    func loadChallenges() async throws -> [Challenge] {
        [
            Challenge(id: UUID(), title: "City Marathon", detail: "Run across the city.", startDate: Date(), endDate: Calendar.current.date(byAdding: .day, value: 30, to: Date())!, goalDistanceMeters: 42195, isJoined: false, progressMeters: 0, isPublic: true),
            Challenge(id: UUID(), title: "Trail Trek", detail: "Explore mountain trails.", startDate: Date(), endDate: Calendar.current.date(byAdding: .day, value: 45, to: Date())!, goalDistanceMeters: 100000, isJoined: true, progressMeters: 25000, isPublic: false)
        ]
    }

    func loadLeaderboard() async throws -> [LeaderboardEntry] {
        [
            LeaderboardEntry(id: UUID(), rank: 1, userName: "Alex", totalDistanceMeters: 42000, totalDurationSeconds: 14000, currentStreakDays: 6),
            LeaderboardEntry(id: UUID(), rank: 2, userName: "Sam", totalDistanceMeters: 38000, totalDurationSeconds: 13000, currentStreakDays: 8),
            LeaderboardEntry(id: UUID(), rank: 3, userName: "Taylor", totalDistanceMeters: 35000, totalDurationSeconds: 12000, currentStreakDays: 3)
        ]
    }

    func setJoinState(challengeID: UUID, isJoined: Bool) async throws { _ = (challengeID, isJoined) }

    func uploadDailyContributions(challengeID: UUID, items: [SupabaseCommunityDataSource.ContributionUpload]) async throws { _ = (challengeID, items) }

    func createChallenge(title: String, detail: String, startDate: Date, endDate: Date, goalDistanceMeters: Double, isPublic: Bool) async throws -> Challenge {
        Challenge(
            id: UUID(),
            title: title,
            detail: detail,
            startDate: startDate,
            endDate: endDate,
            goalDistanceMeters: goalDistanceMeters,
            isJoined: false,
            progressMeters: 0,
            isPublic: isPublic
        )
    }

    func deleteChallenge(challengeID: UUID) async throws { _ = challengeID }
    func canDeleteChallenge(challengeID: UUID) async -> Bool { true }

    // Clubs
    func loadClubs() async throws -> [Club] {
        [
            Club(id: UUID(), name: "Downtown Runners", description: "Local running group.", isPublic: true, isJoined: false, memberCount: 124),
            Club(id: UUID(), name: "Trail Blazers", description: "Trail and ultra crew.", isPublic: true, isJoined: true, memberCount: 58)
        ]
    }

    func createClub(name: String, description: String, isPublic: Bool) async throws -> Club {
        Club(id: UUID(), name: name, description: description, isPublic: isPublic, isJoined: true, memberCount: 1)
    }

    func setClubMembership(clubID: UUID, isJoined: Bool) async throws { _ = (clubID, isJoined) }

    // Invites
    func inviteToChallenge(challengeID: UUID, usernames: [String]) async throws { _ = (challengeID, usernames) }
}