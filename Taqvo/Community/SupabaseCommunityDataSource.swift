import Foundation
import UIKit

final class SupabaseCommunityDataSource: CommunityDataSource {
    private let baseURL: URL
    private let authManager: SupabaseAuthManager

    init(baseURL: URL = URL(string: "https://api.supabase.example")!, authManager: SupabaseAuthManager) {
        self.baseURL = baseURL
        self.authManager = authManager
    }

    static func makeFromInfoPlist(authManager: SupabaseAuthManager) -> SupabaseCommunityDataSource? {
        guard let info = Bundle.main.infoDictionary,
              let urlString = info["SUPABASE_URL"] as? String,
              let _ = info["SUPABASE_ANON_KEY"] as? String,
              let url = URL(string: urlString) else {
            return nil
        }
        return SupabaseCommunityDataSource(baseURL: url, authManager: authManager)
    }

    // MARK: - CommunityDataSource

    func loadChallenges() async throws -> [Challenge] {
        struct Row: Decodable {
            let id: String
            let title: String
            let detail: String?
            let start_date: String
            let end_date: String
            let goal_distance_meters: Double?
            let is_public: Bool?
        }
        let rows: [Row]
        do {
            rows = try await get(path: "/rest/v1/challenges", queryItems: [
                URLQueryItem(name: "select", value: "id,title,detail,start_date,end_date,goal_distance_meters,is_public"),
                URLQueryItem(name: "is_public", value: "eq.true"),
                URLQueryItem(name: "order", value: "start_date.asc")
            ])
        } catch {
            // Offline or unconfigured Supabase: return empty list
            return []
        }
        let df = DateFormatter()
        df.calendar = Calendar(identifier: .iso8601)
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyy-MM-dd"
        return rows.compactMap { r in
            guard let id = UUID(uuidString: r.id),
                  let start = df.date(from: r.start_date),
                  let end = df.date(from: r.end_date) else { return nil }
            return Challenge(
                id: id,
                title: r.title,
                detail: r.detail ?? "",
                startDate: start,
                endDate: end,
                goalDistanceMeters: (r.goal_distance_meters ?? 0),
                isJoined: false,
                progressMeters: 0,
                isPublic: r.is_public ?? true
            )
        }
    }

    func loadLeaderboard() async throws -> [LeaderboardEntry] {
        [
            LeaderboardEntry(id: UUID(), rank: 1, userName: "Alex", totalDistanceMeters: 42000, totalDurationSeconds: 14000, currentStreakDays: 6),
            LeaderboardEntry(id: UUID(), rank: 2, userName: "Sam", totalDistanceMeters: 38000, totalDurationSeconds: 13000, currentStreakDays: 8),
            LeaderboardEntry(id: UUID(), rank: 3, userName: "Taylor", totalDistanceMeters: 35000, totalDurationSeconds: 12000, currentStreakDays: 3),
            LeaderboardEntry(id: UUID(), rank: 4, userName: "Jordan", totalDistanceMeters: 33000, totalDurationSeconds: 11000, currentStreakDays: 2),
            LeaderboardEntry(id: UUID(), rank: 5, userName: "Riley", totalDistanceMeters: 30000, totalDurationSeconds: 10000, currentStreakDays: 5)
        ]
    }

    func setJoinState(challengeID: UUID, isJoined: Bool) async throws {
        // POST to /rpc/set_join_state
        _ = (challengeID, isJoined)
    }

    struct ContributionUpload: Codable { let day: Date; let distanceMeters: Double; let contributionCount: Int }

    func uploadDailyContributions(challengeID: UUID, items: [ContributionUpload]) async throws {
        _ = (challengeID, items)
    }

    func createChallenge(title: String, detail: String, startDate: Date, endDate: Date, goalDistanceMeters: Double, isPublic: Bool) async throws -> Challenge {
        guard let userId = await authManager.userId else {
            throw NSError(domain: "Supabase", code: 401, userInfo: [NSLocalizedDescriptionKey: "Sign in required to create a challenge"])
        }
        let newId = UUID()
        _ = userId
        // Try server create
        do {
            struct Row: Decodable { let id: String? }
            let _: Row = try await post(path: "/rest/v1/challenges", jsonBody: [
                "id": newId.uuidString,
                "title": title,
                "detail": detail,
                "start_date": ISO8601DateFormatter().string(from: startDate),
                "end_date": ISO8601DateFormatter().string(from: endDate),
                "goal_distance_meters": goalDistanceMeters,
                "is_public": isPublic
            ])
        } catch {
            // Offline or unconfigured Supabase: return a local challenge instance
            return Challenge(
                id: newId,
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
        // If server returned but no rows, return local instance
        return Challenge(
            id: newId,
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

    func deleteChallenge(challengeID: UUID) async throws {
        _ = challengeID
    }

    func canDeleteChallenge(challengeID: UUID) async -> Bool {
        true
    }

    // MARK: - Clubs / Groups
    func loadClubs() async throws -> [Club] {
        // Stub: offline or no server
        [
            Club(id: UUID(), name: "Downtown Runners", description: "Local running group.", isPublic: true, isJoined: false, memberCount: 124),
            Club(id: UUID(), name: "Trail Blazers", description: "Trail and ultra crew.", isPublic: true, isJoined: true, memberCount: 58)
        ]
    }

    func createClub(name: String, description: String, isPublic: Bool) async throws -> Club {
        guard let _ = await authManager.userId else {
            throw NSError(domain: "Supabase", code: 401, userInfo: [NSLocalizedDescriptionKey: "Sign in required to create a club"])
        }
        return Club(id: UUID(), name: name, description: description, isPublic: isPublic, isJoined: true, memberCount: 1)
    }

    func setClubMembership(clubID: UUID, isJoined: Bool) async throws {
        _ = (clubID, isJoined)
    }

    // MARK: - Invites
    func inviteToChallenge(challengeID: UUID, usernames: [String]) async throws {
        _ = (challengeID, usernames)
    }

    // MARK: - HTTP helpers (stubs)
    private func get<T: Decodable>(path: String, queryItems: [URLQueryItem]) async throws -> T {
        _ = (path, queryItems)
        throw NSError(domain: "Supabase", code: -1)
    }
    private func post<T: Decodable>(path: String, jsonBody: [String: Any]) async throws -> T {
        _ = (path, jsonBody)
        throw NSError(domain: "Supabase", code: -1)
    }
}