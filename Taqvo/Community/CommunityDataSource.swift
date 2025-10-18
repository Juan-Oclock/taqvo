import Foundation

protocol CommunityDataSource {
    func loadChallenges() async throws -> [Challenge]
    func loadLeaderboard() async throws -> [LeaderboardEntry]
    func setJoinState(challengeID: UUID, isJoined: Bool) async throws
}

struct MockCommunityDataSource: CommunityDataSource {
    func loadChallenges() async throws -> [Challenge] {
        let now = Date()
        return [
            Challenge.demo(start: now, days: 7, title: "7-Day Sprint", detail: "Run 10 km this week", goalKm: 10),
            Challenge.demo(start: now, days: 30, title: "October Mileage", detail: "Log 50 km in October", goalKm: 50),
            Challenge.demo(start: now, days: 90, title: "Season Challenge", detail: "Rack up 150 km", goalKm: 150)
        ]
    }

    func loadLeaderboard() async throws -> [LeaderboardEntry] {
        [
            LeaderboardEntry(id: UUID(), rank: 1, userName: "Alex", totalDistanceMeters: 42000),
            LeaderboardEntry(id: UUID(), rank: 2, userName: "Sam", totalDistanceMeters: 38000),
            LeaderboardEntry(id: UUID(), rank: 3, userName: "Taylor", totalDistanceMeters: 35000),
            LeaderboardEntry(id: UUID(), rank: 4, userName: "Jordan", totalDistanceMeters: 33000),
            LeaderboardEntry(id: UUID(), rank: 5, userName: "Riley", totalDistanceMeters: 30000)
        ]
    }

    func setJoinState(challengeID: UUID, isJoined: Bool) async throws {
        // No-op in mock implementation
    }
}