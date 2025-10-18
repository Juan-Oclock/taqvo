import Foundation

final class SupabaseCommunityDataSource: CommunityDataSource {
    private let baseURL: URL
    private let anonKey: String

    init(baseURL: URL, anonKey: String) {
        self.baseURL = baseURL
        self.anonKey = anonKey
    }

    static func makeFromInfoPlist() -> SupabaseCommunityDataSource? {
        guard let info = Bundle.main.infoDictionary,
              let urlString = info["SUPABASE_URL"] as? String,
              let key = info["SUPABASE_ANON_KEY"] as? String,
              let url = URL(string: urlString),
              !key.isEmpty
        else { return nil }
        return SupabaseCommunityDataSource(baseURL: url, anonKey: key)
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
        let rows: [Row] = try await get(path: "/rest/v1/challenges", queryItems: [
            URLQueryItem(name: "select", value: "id,title,detail,start_date,end_date,goal_distance_meters,is_public"),
            URLQueryItem(name: "is_public", value: "eq.true"),
            URLQueryItem(name: "order", value: "start_date.asc")
        ])
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
                progressMeters: 0
            )
        }
    }

    func loadLeaderboard() async throws -> [LeaderboardEntry] {
        struct Row: Decodable {
            let challenge_id: String?
            let user_id: String
            let total_distance_meters: Double
        }
        let rows: [Row] = try await get(path: "/rest/v1/leaderboard_view", queryItems: [
            URLQueryItem(name: "select", value: "challenge_id,user_id,total_distance_meters"),
            URLQueryItem(name: "order", value: "total_distance_meters.desc"),
            URLQueryItem(name: "limit", value: "20")
        ])
        var entries: [LeaderboardEntry] = []
        for (idx, r) in rows.enumerated() {
            let name = "Runner " + String(r.user_id.prefix(6))
            entries.append(LeaderboardEntry(id: UUID(), rank: idx + 1, userName: name, totalDistanceMeters: r.total_distance_meters))
        }
        return entries
    }

    func setJoinState(challengeID: UUID, isJoined: Bool) async throws {
        // Without authenticated user context, we cannot write due to RLS.
        // Implement as a no-op; CommunityViewModel locally toggles state.
        // If auth is added, upsert/delete:
        // POST /rest/v1/challenge_participants with Prefer: resolution=merge-duplicates
        // or DELETE /rest/v1/challenge_participants?challenge_id=eq.<id>&user_id=eq.<uid>
    }

    // MARK: - Networking

    private func get<T: Decodable>(path: String, queryItems: [URLQueryItem]) async throws -> T {
        var comps = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        comps.queryItems = queryItems
        let req = try makeRequest(url: comps.url!, method: "GET")
        let (data, resp) = try await URLSession.shared.data(for: req)
        try validateHTTP(resp: resp)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func makeRequest(url: URL, method: String, body: Data? = nil, prefer: String? = nil) throws -> URLRequest {
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.httpBody = body
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(anonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        if let prefer = prefer { req.setValue(prefer, forHTTPHeaderField: "Prefer") }
        return req
    }

    private func validateHTTP(resp: URLResponse) throws {
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
}