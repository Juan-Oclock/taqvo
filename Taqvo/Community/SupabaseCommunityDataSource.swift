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
            let created_by: String?
            let created_by_username: String?
            let image_url: String?
        }
        let rows: [Row]
        do {
            rows = try await get(path: "/rest/v1/challenges", queryItems: [
                URLQueryItem(name: "select", value: "id,title,detail,start_date,end_date,goal_distance_meters,is_public,created_by,created_by_username,image_url"),
                URLQueryItem(name: "is_public", value: "eq.true"),
                URLQueryItem(name: "order", value: "start_date.asc")
            ])
            print("DEBUG: loadChallenges() - Fetched \(rows.count) rows from server")
        } catch {
            // Offline or unconfigured Supabase: return empty list
            print("DEBUG: loadChallenges() - Error fetching challenges: \(error)")
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
                isPublic: r.is_public ?? true,
                createdBy: r.created_by != nil ? UUID(uuidString: r.created_by!) : nil,
                createdByUsername: r.created_by_username,
                imageUrl: r.image_url
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
        guard let userId = await authManager.userId else {
            throw NSError(domain: "Supabase", code: 401, userInfo: [NSLocalizedDescriptionKey: "Sign in required"])
        }
        
        if isJoined {
            // Insert into challenge_participants
            struct EmptyResponse: Decodable {}
            let _: EmptyResponse = try await post(path: "/rest/v1/challenge_participants", jsonBody: [
                "challenge_id": challengeID.uuidString,
                "user_id": userId
            ])
            print("DEBUG: setJoinState() - User joined challenge: \(challengeID)")
        } else {
            // Delete from challenge_participants
            try await delete(path: "/rest/v1/challenge_participants", queryItems: [
                URLQueryItem(name: "challenge_id", value: "eq.\(challengeID.uuidString)"),
                URLQueryItem(name: "user_id", value: "eq.\(userId)")
            ])
            print("DEBUG: setJoinState() - User left challenge: \(challengeID)")
        }
    }

    struct ContributionUpload: Codable { let day: Date; let distanceMeters: Double; let contributionCount: Int }

    func uploadDailyContributions(challengeID: UUID, items: [ContributionUpload]) async throws {
        _ = (challengeID, items)
    }

    func createChallenge(title: String, detail: String, startDate: Date, endDate: Date, goalDistanceMeters: Double, isPublic: Bool, imageUrl: String?) async throws -> Challenge {
        guard let userIdString = await authManager.userId else {
            throw NSError(domain: "Supabase", code: 401, userInfo: [NSLocalizedDescriptionKey: "Sign in required to create a challenge"])
        }
        guard let userId = UUID(uuidString: userIdString) else {
            throw NSError(domain: "Supabase", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid user ID format"])
        }
        let newId = UUID()
        
        // Get current user's username for display purposes
        let username = await ProfileService.shared.currentProfile?.username ?? "Unknown User"
        
        // Try server create
        do {
            let df = DateFormatter()
            df.calendar = Calendar(identifier: .iso8601)
            df.locale = Locale(identifier: "en_US_POSIX")
            df.dateFormat = "yyyy-MM-dd"
            
            var jsonBody: [String: Any] = [
                "id": newId.uuidString,
                "title": title,
                "detail": detail,
                "start_date": df.string(from: startDate),
                "end_date": df.string(from: endDate),
                "goal_distance_meters": goalDistanceMeters,
                "is_public": isPublic,
                "created_by": userIdString,
                "created_by_username": username
            ]
            
            if let imageUrl = imageUrl {
                jsonBody["image_url"] = imageUrl
            }
            
            struct Row: Decodable { let id: String? }
            let _: Row = try await post(path: "/rest/v1/challenges", jsonBody: jsonBody)
            print("DEBUG: createChallenge() - Successfully created challenge on server: \(newId)")
        } catch {
            print("DEBUG: createChallenge() - Error creating challenge: \(error)")
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
                isPublic: isPublic,
                createdBy: userId,
                createdByUsername: username,
                imageUrl: imageUrl
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
            isPublic: isPublic,
            createdBy: userId,
            createdByUsername: username,
            imageUrl: imageUrl
        )
    }

    func deleteChallenge(challengeID: UUID) async throws {
        guard let userId = await authManager.userId else {
            throw NSError(domain: "Supabase", code: 401, userInfo: [NSLocalizedDescriptionKey: "Sign in required to delete a challenge"])
        }
        
        // DELETE request to /rest/v1/challenges?id=eq.{challengeID}
        // RLS policy will ensure only the creator can delete
        do {
            try await delete(path: "/rest/v1/challenges", queryItems: [
                URLQueryItem(name: "id", value: "eq.\(challengeID.uuidString)")
            ])
            print("DEBUG: Challenge deleted successfully - ID: \(challengeID)")
        } catch {
            print("ERROR: Failed to delete challenge: \(error)")
            throw error
        }
    }

    func canDeleteChallenge(challengeID: UUID) async -> Bool {
        // This is checked client-side in CommunityViewModel.canDeleteChallenge()
        // Server-side RLS will enforce the actual permission
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

    // MARK: - Activity Sync
    
    struct ActivityUpload: Codable {
        let id: String
        let user_id: String
        let username: String?
        let avatar_url: String?
        let started_at: String
        let ended_at: String?
        let distance_meters: Int
        let source: String
        let title: String?
        let visibility: String?
        let kind: String?
        let duration_seconds: Double?
        let calories: Double?
        let note: String?
    }
    
    struct ActivityUploadResponse: Codable {
        let id: String?
        let user_id: String?
        let username: String?
        let avatar_url: String?
        let started_at: String?
        let ended_at: String?
        let distance_meters: Int?
        let source: String?
        let title: String?
        let visibility: String?
        let kind: String?
        let duration_seconds: Double?
        let calories: Double?
        let note: String?
    }
    
    func uploadActivity(_ activity: FeedActivity) async throws {
        guard let userId = await authManager.userId else {
            throw NSError(domain: "Supabase", code: 401, userInfo: [NSLocalizedDescriptionKey: "Sign in required to upload activity"])
        }
        
        let upload = ActivityUpload(
            id: activity.id.uuidString,
            user_id: userId,
            username: activity.username,
            avatar_url: activity.avatarUrl,
            started_at: ISO8601DateFormatter().string(from: activity.startDate),
            ended_at: ISO8601DateFormatter().string(from: activity.endDate),
            distance_meters: Int(activity.distanceMeters),
            source: "device",
            title: activity.title,
            visibility: activity.visibility.rawValue,
            kind: activity.kind.rawValue,
            duration_seconds: activity.durationSeconds,
            calories: activity.caloriesKilocalories,
            note: activity.note
        )
        
        do {
            let _: ActivityUploadResponse = try await post(path: "/rest/v1/activities", jsonBody: [
                "id": upload.id,
                "user_id": upload.user_id,
                "username": upload.username as Any,
                "avatar_url": upload.avatar_url as Any,
                "started_at": upload.started_at,
                "ended_at": upload.ended_at,
                "distance_meters": upload.distance_meters,
                "source": upload.source,
                "title": upload.title as Any,
                "visibility": upload.visibility as Any,
                "kind": upload.kind as Any,
                "duration_seconds": upload.duration_seconds as Any,
                "calories": upload.calories as Any,
                "note": upload.note as Any
            ])
        } catch {
            // If offline or server error, we'll retry later
            throw error
        }
    }
    
    func loadUserActivities() async throws -> [ActivityUpload] {
        guard let userId = await authManager.userId else {
            return []
        }
        
        do {
            let activities: [ActivityUpload] = try await get(path: "/rest/v1/activities", queryItems: [
                URLQueryItem(name: "select", value: "id,user_id,started_at,ended_at,distance_meters,source,title"),
                URLQueryItem(name: "user_id", value: "eq.\(userId)"),
                URLQueryItem(name: "order", value: "started_at.desc")
            ])
            return activities
        } catch {
            // If offline or server error, return empty list
            return []
        }
    }
    
    func loadPublicActivities(limit: Int = 20) async throws -> [FeedActivity] {
        do {
            struct ActivityDTO: Decodable {
                let id: String
                let user_id: String
                let username: String?
                let avatar_url: String?
                let started_at: String
                let ended_at: String?
                let distance_meters: Int
                let source: String
                let title: String?
                let visibility: String?
                let kind: String?
                let duration_seconds: Double?
                let calories: Double?
                let note: String?
                let like_count: Int?
                let comment_count: Int?
            }
            
            let activities: [ActivityDTO] = try await get(path: "/rest/v1/activities", queryItems: [
                URLQueryItem(name: "select", value: "id,user_id,username,avatar_url,started_at,ended_at,distance_meters,source,title,visibility,kind,duration_seconds,calories,note,like_count,comment_count"),
                URLQueryItem(name: "visibility", value: "eq.public"),
                URLQueryItem(name: "order", value: "started_at.desc"),
                URLQueryItem(name: "limit", value: "\(limit)")
            ])
            
            // Convert ActivityUpload to FeedActivity
            let feedActivities = activities.compactMap { dto -> FeedActivity? in
                guard let startDate = ISO8601DateFormatter().date(from: dto.started_at) else {
                    print("⚠️ Failed to parse start date: \(dto.started_at)")
                    return nil
                }
                
                let endDate = dto.ended_at.flatMap { ISO8601DateFormatter().date(from: $0) } ?? startDate
                
                // Parse activity kind
                let kind: ActivityKind
                if let kindString = dto.kind {
                    kind = ActivityKind(rawValue: kindString) ?? .run
                } else {
                    kind = .run // Default
                }
                
                return FeedActivity(
                    id: UUID(uuidString: dto.id) ?? UUID(),
                    userId: dto.user_id,
                    username: dto.username,
                    avatarUrl: dto.avatar_url,
                    distanceMeters: Double(dto.distance_meters),
                    durationSeconds: dto.duration_seconds ?? 0,
                    route: [], // Route not stored in basic schema
                    startDate: startDate,
                    endDate: endDate,
                    snapshotPNG: nil,
                    note: dto.note,
                    photoPNG: nil,
                    title: dto.title,
                    likeCount: dto.like_count ?? 0,
                    likedByUserIds: [], // Will be populated separately if needed
                    comments: [], // Will be loaded on-demand when viewing details
                    commentCount: dto.comment_count ?? 0,
                    kind: kind,
                    caloriesKilocalories: dto.calories ?? 0,
                    averageHeartRateBPM: nil,
                    splitsSeconds: nil,
                    challengeTitle: nil,
                    challengeIsPublic: nil,
                    stepsCount: nil,
                    elevationGainMeters: nil,
                    visibility: PostVisibility(rawValue: dto.visibility ?? "private") ?? .privateOnly
                )
            }
            
            // Load likes for current user to populate likedByUserIds
            if let currentUserId = await authManager.userId {
                let activityIds = feedActivities.map { $0.id.uuidString }
                if !activityIds.isEmpty {
                    struct UserLike: Decodable {
                        let activity_id: String
                    }
                    // Get all activities the current user has liked
                    let userLikes: [UserLike] = try await get(path: "/rest/v1/activity_likes", queryItems: [
                        URLQueryItem(name: "user_id", value: "eq.\(currentUserId)"),
                        URLQueryItem(name: "activity_id", value: "in.(\(activityIds.joined(separator: ",")))"),
                        URLQueryItem(name: "select", value: "activity_id")
                    ])
                    
                    let likedActivityIds = Set(userLikes.compactMap { UUID(uuidString: $0.activity_id) })
                    
                    // Update activities with current user's liked status
                    var updatedActivities = feedActivities
                    for i in 0..<updatedActivities.count {
                        if likedActivityIds.contains(updatedActivities[i].id) {
                            var activity = updatedActivities[i]
                            activity.likedByUserIds = [currentUserId]
                            updatedActivities[i] = activity
                        }
                    }
                    
                    print("✅ Loaded \(updatedActivities.count) public activities from Supabase (with like status)")
                    return updatedActivities
                }
            }
            
            print("✅ Loaded \(feedActivities.count) public activities from Supabase")
            return feedActivities
        } catch {
            print("❌ Error loading public activities: \(error)")
            return []
        }
    }
    
    func deleteActivity(activityID: UUID) async throws {
        guard let userId = await authManager.userId else {
            throw NSError(domain: "Supabase", code: 401, userInfo: [NSLocalizedDescriptionKey: "Sign in required to delete activity"])
        }
        
        do {
            // Delete from Supabase with user_id check for security
            try await delete(path: "/rest/v1/activities", queryItems: [
                URLQueryItem(name: "id", value: "eq.\(activityID.uuidString)"),
                URLQueryItem(name: "user_id", value: "eq.\(userId)")
            ])
            print("✅ Deleted activity \(activityID.uuidString) from Supabase")
        } catch {
            print("❌ Error deleting activity from Supabase: \(error)")
            throw error
        }
    }
    
    // MARK: - Likes
    
    func toggleLike(activityID: UUID) async throws -> Bool {
        guard let userId = await authManager.userId else {
            throw NSError(domain: "Supabase", code: 401, userInfo: [NSLocalizedDescriptionKey: "Sign in required"])
        }
        
        // Check if user already liked this activity
        struct LikeCheck: Decodable {
            let id: String
        }
        let existing: [LikeCheck] = try await get(path: "/rest/v1/activity_likes", queryItems: [
            URLQueryItem(name: "activity_id", value: "eq.\(activityID.uuidString)"),
            URLQueryItem(name: "user_id", value: "eq.\(userId)"),
            URLQueryItem(name: "select", value: "id")
        ])
        
        if existing.isEmpty {
            // Insert like
            let like = ["activity_id": activityID.uuidString, "user_id": userId]
            struct EmptyResponse: Decodable {}
            let _: EmptyResponse = try await post(path: "/rest/v1/activity_likes", jsonBody: like)
            print("✅ Liked activity \(activityID.uuidString)")
            return true // Now liked
        } else {
            // Delete like
            try await delete(path: "/rest/v1/activity_likes", queryItems: [
                URLQueryItem(name: "activity_id", value: "eq.\(activityID.uuidString)"),
                URLQueryItem(name: "user_id", value: "eq.\(userId)")
            ])
            print("✅ Unliked activity \(activityID.uuidString)")
            return false // Now unliked
        }
    }
    
    // MARK: - Comments
    
    func addComment(activityID: UUID, text: String, username: String?, avatarUrl: String?) async throws -> UUID {
        guard let userId = await authManager.userId else {
            throw NSError(domain: "Supabase", code: 401, userInfo: [NSLocalizedDescriptionKey: "Sign in required"])
        }
        
        let commentId = UUID()
        let comment: [String: Any] = [
            "id": commentId.uuidString,
            "activity_id": activityID.uuidString,
            "user_id": userId,
            "username": username as Any,
            "avatar_url": avatarUrl as Any,
            "text": text
        ]
        
        struct EmptyResponse: Decodable {}
        let _: EmptyResponse = try await post(path: "/rest/v1/activity_comments", jsonBody: comment)
        print("✅ Added comment to activity \(activityID.uuidString)")
        return commentId
    }
    
    func deleteComment(commentID: UUID) async throws {
        guard let userId = await authManager.userId else {
            throw NSError(domain: "Supabase", code: 401, userInfo: [NSLocalizedDescriptionKey: "Sign in required"])
        }
        
        try await delete(path: "/rest/v1/activity_comments", queryItems: [
            URLQueryItem(name: "id", value: "eq.\(commentID.uuidString)"),
            URLQueryItem(name: "user_id", value: "eq.\(userId)")
        ])
        print("✅ Deleted comment \(commentID.uuidString)")
    }
    
    func loadComments(activityID: UUID) async throws -> [ActivityComment] {
        struct CommentDTO: Decodable {
            let id: String
            let user_id: String
            let username: String?
            let avatar_url: String?
            let text: String
            let created_at: String
        }
        
        let dtos: [CommentDTO] = try await get(path: "/rest/v1/activity_comments", queryItems: [
            URLQueryItem(name: "activity_id", value: "eq.\(activityID.uuidString)"),
            URLQueryItem(name: "select", value: "id,user_id,username,avatar_url,text,created_at"),
            URLQueryItem(name: "order", value: "created_at.asc")
        ])
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        return dtos.compactMap { dto in
            guard let uuid = UUID(uuidString: dto.id),
                  let date = formatter.date(from: dto.created_at) else {
                return nil
            }
            
            return ActivityComment(
                id: uuid,
                author: dto.user_id,
                text: dto.text,
                date: date,
                authorUsername: dto.username,
                authorProfileImageBase64: dto.avatar_url
            )
        }
    }

    // MARK: - HTTP helpers
    private func get<T: Decodable>(path: String, queryItems: [URLQueryItem]) async throws -> T {
        var urlComponents = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        urlComponents.queryItems = queryItems
        
        guard let url = urlComponents.url else {
            throw NSError(domain: "Supabase", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        // Add Supabase headers
        if let anonKey = Bundle.main.infoDictionary?["SUPABASE_ANON_KEY"] as? String {
            request.setValue(anonKey, forHTTPHeaderField: "apikey")
        }
        
        // Add auth token if available
        if let token = await authManager.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "Supabase", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("DEBUG: Supabase GET error (\(httpResponse.statusCode)): \(errorMessage)")
            throw NSError(domain: "Supabase", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])
        }
        
        return try JSONDecoder().decode(T.self, from: data)
    }
    
    private func post<T: Decodable>(path: String, jsonBody: [String: Any]) async throws -> T {
        let url = baseURL.appendingPathComponent(path)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        
        // Add Supabase headers
        if let anonKey = Bundle.main.infoDictionary?["SUPABASE_ANON_KEY"] as? String {
            request.setValue(anonKey, forHTTPHeaderField: "apikey")
        }
        
        // Add auth token if available
        if let token = await authManager.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: jsonBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "Supabase", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("DEBUG: Supabase POST error (\(httpResponse.statusCode)): \(errorMessage)")
            throw NSError(domain: "Supabase", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])
        }
        
        // Handle empty response (for inserts without return)
        if data.isEmpty || data.count == 0 {
            // Return a dummy empty struct if T is EmptyResponse
            if let emptyResponse = try? JSONDecoder().decode(T.self, from: "{}".data(using: .utf8)!) {
                return emptyResponse
            }
        }
        
        // For POST with Prefer: return=representation, Supabase returns an array
        // We need to handle both single object and array responses
        if let array = try? JSONDecoder().decode([T].self, from: data), let first = array.first {
            return first
        }
        
        return try JSONDecoder().decode(T.self, from: data)
    }
    
    private func delete(path: String, queryItems: [URLQueryItem]) async throws {
        var urlComponents = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        urlComponents.queryItems = queryItems
        
        guard let url = urlComponents.url else {
            throw NSError(domain: "Supabase", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add Supabase headers
        if let anonKey = Bundle.main.infoDictionary?["SUPABASE_ANON_KEY"] as? String {
            request.setValue(anonKey, forHTTPHeaderField: "apikey")
        }
        
        // Add auth token if available
        if let token = await authManager.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "Supabase", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("DEBUG: Supabase DELETE error (\(httpResponse.statusCode)): \(errorMessage)")
            throw NSError(domain: "Supabase", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])
        }
    }
}