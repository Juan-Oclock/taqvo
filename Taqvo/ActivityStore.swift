//
//  ActivityStore.swift
//  Taqvo
//
//  Implements persistent storage for completed activities shown in Feed.
//

import Foundation
import SwiftUI
import MapKit
import CoreLocation

enum PostVisibility: String, CaseIterable, Codable, Hashable {
    case publicFeed = "public"
    case friends = "friends"
    case privateOnly = "private"
    
    var displayName: String {
        switch self {
        case .publicFeed: return "Public"
        case .friends: return "Friends"
        case .privateOnly: return "Private"
        }
    }
    
    var iconName: String {
        switch self {
        case .publicFeed: return "globe"
        case .friends: return "person.2"
        case .privateOnly: return "lock"
        }
    }
    
    var description: String {
        switch self {
        case .publicFeed: return "Visible to everyone on the public feed"
        case .friends: return "Visible to your friends only"
        case .privateOnly: return "Only visible to you"
        }
    }
}

struct Coordinate: Codable, Hashable {
    let latitude: Double
    let longitude: Double
}

struct ActivityComment: Identifiable, Codable, Hashable {
    let id: UUID
    let author: String
    let text: String
    let date: Date
    let authorUsername: String?
    let authorProfileImageBase64: String?
    
    // Convenience initializer for backward compatibility
    init(id: UUID, author: String, text: String, date: Date, authorUsername: String? = nil, authorProfileImageBase64: String? = nil) {
        self.id = id
        self.author = author
        self.text = text
        self.date = date
        self.authorUsername = authorUsername
        self.authorProfileImageBase64 = authorProfileImageBase64
    }
}

struct FeedActivity: Identifiable, Codable, Hashable {
    let id: UUID
    let userId: String // User who created this activity
    let username: String? // Username of the user
    let avatarUrl: String? // Profile photo URL or base64
    let distanceMeters: Double
    let durationSeconds: Double
    let route: [Coordinate]
    let startDate: Date
    let endDate: Date
    let snapshotPNG: Data?
    let note: String?
    let photoPNG: Data?
    let title: String?
    var likeCount: Int
    var likedByUserIds: [String] // Array of user IDs who liked this activity
    var comments: [ActivityComment]
    let kind: ActivityKind
    let caloriesKilocalories: Double
    let averageHeartRateBPM: Double?
    let splitsSeconds: [Double]?
    // Challenge context
    let challengeTitle: String?
    let challengeIsPublic: Bool?
    // Persisted metrics (optional)
    let stepsCount: Int?
    let elevationGainMeters: Double?
    // Privacy settings
    let visibility: PostVisibility

    enum CodingKeys: String, CodingKey {
        case id, userId, username, avatarUrl, distanceMeters, durationSeconds, route, startDate, endDate, snapshotPNG, note, photoPNG, title, likeCount, likedByUserIds, comments, kind, caloriesKilocalories, averageHeartRateBPM, splitsSeconds, challengeTitle, challengeIsPublic, stepsCount, elevationGainMeters, visibility
    }

    init(id: UUID,
         userId: String,
         username: String? = nil,
         avatarUrl: String? = nil,
         distanceMeters: Double,
         durationSeconds: Double,
         route: [Coordinate],
         startDate: Date,
         endDate: Date,
         snapshotPNG: Data?,
         note: String?,
         photoPNG: Data?,
         title: String? = nil,
         likeCount: Int = 0,
         likedByUserIds: [String] = [],
         comments: [ActivityComment] = [],
         kind: ActivityKind,
         caloriesKilocalories: Double,
         averageHeartRateBPM: Double? = nil,
         splitsSeconds: [Double]? = nil,
         challengeTitle: String? = nil,
         challengeIsPublic: Bool? = nil,
         stepsCount: Int? = nil,
         elevationGainMeters: Double? = nil,
         visibility: PostVisibility = .privateOnly) {
        self.id = id
        self.userId = userId
        self.username = username
        self.avatarUrl = avatarUrl
        self.distanceMeters = distanceMeters
        self.durationSeconds = durationSeconds
        self.route = route
        self.startDate = startDate
        self.endDate = endDate
        self.snapshotPNG = snapshotPNG
        self.note = note
        self.photoPNG = photoPNG
        self.title = title
        self.likeCount = likeCount
        self.likedByUserIds = likedByUserIds
        self.comments = comments
        self.kind = kind
        self.caloriesKilocalories = caloriesKilocalories
        self.averageHeartRateBPM = averageHeartRateBPM
        self.splitsSeconds = splitsSeconds
        self.challengeTitle = challengeTitle
        self.challengeIsPublic = challengeIsPublic
        self.stepsCount = stepsCount
        self.elevationGainMeters = elevationGainMeters
        self.visibility = visibility
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        userId = try c.decodeIfPresent(String.self, forKey: .userId) ?? ""
        username = try c.decodeIfPresent(String.self, forKey: .username)
        avatarUrl = try c.decodeIfPresent(String.self, forKey: .avatarUrl)
        distanceMeters = try c.decode(Double.self, forKey: .distanceMeters)
        durationSeconds = try c.decode(Double.self, forKey: .durationSeconds)
        route = try c.decode([Coordinate].self, forKey: .route)
        startDate = try c.decode(Date.self, forKey: .startDate)
        endDate = try c.decode(Date.self, forKey: .endDate)
        snapshotPNG = try c.decodeIfPresent(Data.self, forKey: .snapshotPNG)
        note = try c.decodeIfPresent(String.self, forKey: .note)
        photoPNG = try c.decodeIfPresent(Data.self, forKey: .photoPNG)
        title = try c.decodeIfPresent(String.self, forKey: .title)
        likeCount = try c.decodeIfPresent(Int.self, forKey: .likeCount) ?? 0
        likedByUserIds = try c.decodeIfPresent([String].self, forKey: .likedByUserIds) ?? []
        comments = try c.decodeIfPresent([ActivityComment].self, forKey: .comments) ?? []
        kind = try c.decodeIfPresent(ActivityKind.self, forKey: .kind) ?? .run
        caloriesKilocalories = try c.decodeIfPresent(Double.self, forKey: .caloriesKilocalories) ?? 0
        averageHeartRateBPM = try c.decodeIfPresent(Double.self, forKey: .averageHeartRateBPM)
        splitsSeconds = try c.decodeIfPresent([Double].self, forKey: .splitsSeconds)
        challengeTitle = try c.decodeIfPresent(String.self, forKey: .challengeTitle)
        challengeIsPublic = try c.decodeIfPresent(Bool.self, forKey: .challengeIsPublic)
        stepsCount = try c.decodeIfPresent(Int.self, forKey: .stepsCount)
        elevationGainMeters = try c.decodeIfPresent(Double.self, forKey: .elevationGainMeters)
        visibility = try c.decodeIfPresent(PostVisibility.self, forKey: .visibility) ?? .privateOnly
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(userId, forKey: .userId)
        try c.encodeIfPresent(username, forKey: .username)
        try c.encodeIfPresent(avatarUrl, forKey: .avatarUrl)
        try c.encode(distanceMeters, forKey: .distanceMeters)
        try c.encode(durationSeconds, forKey: .durationSeconds)
        try c.encode(route, forKey: .route)
        try c.encode(startDate, forKey: .startDate)
        try c.encode(endDate, forKey: .endDate)
        try c.encodeIfPresent(snapshotPNG, forKey: .snapshotPNG)
        try c.encodeIfPresent(note, forKey: .note)
        try c.encodeIfPresent(photoPNG, forKey: .photoPNG)
        try c.encode(likeCount, forKey: .likeCount)
        try c.encode(likedByUserIds, forKey: .likedByUserIds)
        try c.encode(comments, forKey: .comments)
        try c.encode(kind, forKey: .kind)
        try c.encode(caloriesKilocalories, forKey: .caloriesKilocalories)
        try c.encodeIfPresent(averageHeartRateBPM, forKey: .averageHeartRateBPM)
        try c.encodeIfPresent(splitsSeconds, forKey: .splitsSeconds)
        try c.encodeIfPresent(challengeTitle, forKey: .challengeTitle)
        try c.encodeIfPresent(challengeIsPublic, forKey: .challengeIsPublic)
        try c.encodeIfPresent(stepsCount, forKey: .stepsCount)
        try c.encodeIfPresent(elevationGainMeters, forKey: .elevationGainMeters)
        try c.encode(visibility, forKey: .visibility)
    }
}

final class ActivityStore: ObservableObject {
    @Published private(set) var activities: [FeedActivity] = []

    private let fileURL: URL
    private let queue = DispatchQueue(label: "ActivityStoreQueue")
    private var supabaseDataSource: SupabaseCommunityDataSource?

    init() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = documentsPath.appendingPathComponent("activities.json")
        self.supabaseDataSource = SupabaseCommunityDataSource.makeFromInfoPlist(authManager: SupabaseAuthManager.shared)
        load()
    }

    private static func computeSplits(from samples: [RouteSample], totalDistanceMeters: Double, totalDurationSeconds: Double) -> [Double] {
        guard totalDistanceMeters > 0, totalDurationSeconds > 0 else { return [] }
        guard samples.count > 1 else {
            // Fallback to coarse average: allocate time proportionally by distance
            let secPerMeter = totalDurationSeconds / totalDistanceMeters
            var result: [Double] = []
            var remainingMeters = totalDistanceMeters
            while remainingMeters >= 1000.0 {
                result.append(secPerMeter * 1000.0)
                remainingMeters -= 1000.0
            }
            if remainingMeters > 1 { result.append(secPerMeter * remainingMeters) }
            return result
        }
        var result: [Double] = []
        var kmAccumDistance: Double = 0
        var kmAccumTime: Double = 0
        for i in 1..<samples.count {
            let a = samples[i-1]
            let b = samples[i]
            let locA = CLLocation(latitude: a.latitude, longitude: a.longitude)
            let locB = CLLocation(latitude: b.latitude, longitude: b.longitude)
            let d = max(0, locB.distance(from: locA))
            let dt = max(0, b.timestamp.timeIntervalSince(a.timestamp))
            if d == 0 {
                kmAccumTime += dt
                continue
            }
            var distRemaining = d
            var timeRemaining = dt
            while kmAccumDistance + distRemaining >= 1000.0 {
                let need = 1000.0 - kmAccumDistance
                let frac = need / distRemaining
                let timeForNeed = timeRemaining * frac
                kmAccumTime += timeForNeed
                result.append(kmAccumTime)
                // advance
                distRemaining -= need
                timeRemaining -= timeForNeed
                kmAccumDistance = 0
                kmAccumTime = 0
            }
            kmAccumDistance += distRemaining
            kmAccumTime += timeRemaining
        }
        if kmAccumDistance > 1 || kmAccumTime > 0.1 {
            result.append(kmAccumTime)
        }
        return result
    }

    @MainActor
    func add(summary: ActivitySummary, snapshot: UIImage?, note: String? = nil, photo: UIImage? = nil, avgHeartRateBPM: Double? = nil, title: String? = nil, visibility: PostVisibility = .privateOnly) {
        let coords = summary.route.map { Coordinate(latitude: $0.latitude, longitude: $0.longitude) }
        let splits = ActivityStore.computeSplits(from: summary.routeSamples, totalDistanceMeters: summary.distanceMeters, totalDurationSeconds: summary.durationSeconds)
        
        // Get current user profile info
        let profileService = ProfileService.shared
        let username = profileService.currentProfile?.username
        let avatarUrl = profileService.currentProfile?.avatarUrl
        
        print("DEBUG ActivityStore.add() - Creating activity with:")
        print("  - Username: \(username ?? "nil")")
        print("  - AvatarUrl: \(avatarUrl ?? "nil")")
        print("  - CurrentProfile exists: \(profileService.currentProfile != nil)")
        
        let activity = FeedActivity(
            id: UUID(),
            userId: SupabaseAuthManager.shared.userId ?? "",
            username: username,
            avatarUrl: avatarUrl,
            distanceMeters: summary.distanceMeters,
            durationSeconds: summary.durationSeconds,
            route: coords,
            startDate: summary.startDate,
            endDate: summary.endDate,
            snapshotPNG: snapshot?.compressForThumbnail(),
            note: note,
            photoPNG: photo?.compressForActivity(),
            title: title,
            likeCount: 0,
            likedByUserIds: [],
            comments: [],
            kind: summary.kind,
            caloriesKilocalories: summary.caloriesKilocalories,
            averageHeartRateBPM: avgHeartRateBPM,
            splitsSeconds: splits,
            challengeTitle: summary.linkedChallengeTitle,
            challengeIsPublic: summary.linkedChallengeIsPublic,
            stepsCount: summary.stepsCount,
            elevationGainMeters: summary.elevationGainMeters,
            visibility: visibility
        )
        activities.insert(activity, at: 0)
        save()
        
        // Sync to Supabase if available and user is authenticated
        if let supabase = supabaseDataSource {
            Task {
                do {
                    // Check authentication status in async context
                    if await SupabaseAuthManager.shared.isAuthenticated {
                        try await supabase.uploadActivity(activity)
                    }
                } catch {
                    print("Failed to sync activity to Supabase: \(error)")
                    // Activity is still saved locally, sync will be retried later
                }
            }
        }
    }

    func save() {
        let activitiesCopy = activities
        queue.async { [fileURL] in
            do {
                let data = try JSONEncoder().encode(activitiesCopy)
                try data.write(to: fileURL, options: [.atomic])
            } catch {
                print("ActivityStore save error: \(error)")
            }
        }
    }

    func load() {
        queue.async { [weak self] in
            guard let self = self else { return }
            do {
                if FileManager.default.fileExists(atPath: self.fileURL.path) {
                    let data = try Data(contentsOf: self.fileURL)
                    let decoded = try JSONDecoder().decode([FeedActivity].self, from: data)
                    DispatchQueue.main.async { self.activities = decoded }
                }
            } catch {
                print("ActivityStore load error: \(error)")
            }
        }
    }

    static func clCoordinates(from coords: [Coordinate]) -> [CLLocationCoordinate2D] {
        coords.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
    }

    @MainActor
    func updateActivity(_ updatedActivity: FeedActivity) {
        if let index = activities.firstIndex(where: { $0.id == updatedActivity.id }) {
            activities[index] = updatedActivity
            save()
        }
    }
    
    @MainActor
    func delete(activity: FeedActivity) {
        // Security check: Only allow deletion if user owns the activity
        guard let currentUserId = SupabaseAuthManager.shared.userId,
              activity.userId == currentUserId else {
            print("Unauthorized delete attempt: User \(SupabaseAuthManager.shared.userId ?? "unknown") tried to delete activity owned by \(activity.userId)")
            return
        }
        
        activities.removeAll { $0.id == activity.id }
        save()
    }

    @MainActor
    func toggleLike(activityID: UUID) {
        guard let idx = activities.firstIndex(where: { $0.id == activityID }) else { return }
        guard let currentUserId = SupabaseAuthManager.shared.userId else { return }
        
        var a = activities[idx]
        
        if a.likedByUserIds.contains(currentUserId) {
            // User already liked it, so unlike
            a.likedByUserIds.removeAll { $0 == currentUserId }
            if a.likeCount > 0 { a.likeCount -= 1 }
        } else {
            // User hasn't liked it yet, so like it
            a.likedByUserIds.append(currentUserId)
            a.likeCount += 1
        }
        
        activities[idx] = a
        save()
    }

    @MainActor
    func addComment(activityID: UUID, text: String, author: String? = nil, authorUsername: String? = nil, authorProfileImageBase64: String? = nil) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let idx = activities.firstIndex(where: { $0.id == activityID }) else { return }
        var a = activities[idx]
        
        // Get current user's email as the primary identifier
        let currentUserEmail = SupabaseAuthManager.shared.userEmail ?? "You"
        let commentAuthor = author ?? currentUserEmail
        
        // Get current user's profile info from ProfileService
        let profileService = ProfileService.shared
        print("DEBUG: Current profile in addComment: \(String(describing: profileService.currentProfile))")
        print("DEBUG: Current profile username: \(String(describing: profileService.currentProfile?.username))")
        print("DEBUG: Current profile avatarUrl: \(String(describing: profileService.currentProfile?.avatarUrl))")
        
        // For username: use provided value, or profile username, or nil (don't fallback to email)
        let finalUsername: String?
        if let providedUsername = authorUsername {
            finalUsername = providedUsername
        } else if let profileUsername = profileService.currentProfile?.username, !profileUsername.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            finalUsername = profileUsername
        } else {
            // Don't store email in authorUsername - let CommentRowView handle the fallback
            finalUsername = nil
        }
        
        // For profile image: use provided value or profile avatar
        let finalProfileImage = authorProfileImageBase64 ?? profileService.currentProfile?.avatarUrl
        
        print("DEBUG: Final username for comment: \(String(describing: finalUsername))")
        print("DEBUG: Final profile image for comment: \(String(describing: finalProfileImage))")
        
        let comment = ActivityComment(
            id: UUID(),
            author: commentAuthor,
            text: trimmed,
            date: Date(),
            authorUsername: finalUsername,
            authorProfileImageBase64: finalProfileImage
        )
        a.comments.append(comment)
        activities[idx] = a
        save()
    }
    
    @MainActor
    func deleteComment(activityID: UUID, commentID: UUID) {
        guard let activityIdx = activities.firstIndex(where: { $0.id == activityID }) else { return }
        var activity = activities[activityIdx]
        
        // Find the comment to delete
        guard let commentIdx = activity.comments.firstIndex(where: { $0.id == commentID }) else { return }
        let comment = activity.comments[commentIdx]
        
        // Check if current user is the author of the comment
        let currentUserEmail = SupabaseAuthManager.shared.userEmail ?? "You"
        guard comment.author == currentUserEmail else { return }
        
        // Remove the comment
        activity.comments.remove(at: commentIdx)
        activities[activityIdx] = activity
        save()
    }
}

struct WeeklySummary: Identifiable {
    let id: Date
    let weekStart: Date
    var totalDistanceMeters: Double
    var totalDurationSeconds: Double
    var longestRunMeters: Double
    var longestRunDurationSeconds: Double
    var totalCaloriesKilocalories: Double

    var averagePaceString: String {
        ActivityTrackingViewModel.formattedPace(distanceMeters: totalDistanceMeters, durationSeconds: totalDurationSeconds)
    }
}
struct DailySummary: Identifiable {
    let id: Date
    let dayStart: Date
    var totalDistanceMeters: Double
    var totalDurationSeconds: Double
    var runCount: Int
    var longestRunMeters: Double
    var longestRunDurationSeconds: Double
    var totalCaloriesKilocalories: Double

    var averagePaceString: String {
        ActivityTrackingViewModel.formattedPace(distanceMeters: totalDistanceMeters, durationSeconds: totalDurationSeconds)
    }
}

struct MonthlySummary: Identifiable {
    let id: Date
    let monthStart: Date
    var totalDistanceMeters: Double
    var totalDurationSeconds: Double
    var runCount: Int
    var longestRunMeters: Double
    var longestRunDurationSeconds: Double
    var totalCaloriesKilocalories: Double

    var averagePaceString: String {
        ActivityTrackingViewModel.formattedPace(distanceMeters: totalDistanceMeters, durationSeconds: totalDurationSeconds)
    }
}

extension ActivityStore {
    func dailySummaries(using calendar: Calendar = Calendar(identifier: .iso8601)) -> [DailySummary] {
        guard !activities.isEmpty else { return [] }
        var bucket: [Date: DailySummary] = [:]

        for a in activities {
            let day = calendar.startOfDay(for: a.endDate)
            var summary = bucket[day] ?? DailySummary(id: day, dayStart: day, totalDistanceMeters: 0, totalDurationSeconds: 0, runCount: 0, longestRunMeters: 0, longestRunDurationSeconds: 0, totalCaloriesKilocalories: 0)
            summary.totalDistanceMeters += a.distanceMeters
            summary.totalDurationSeconds += a.durationSeconds
            summary.runCount += 1
            summary.totalCaloriesKilocalories += a.caloriesKilocalories
            if a.distanceMeters > summary.longestRunMeters {
                summary.longestRunMeters = a.distanceMeters
                summary.longestRunDurationSeconds = a.durationSeconds
            }
            bucket[day] = summary
        }

        return bucket.values.sorted { $0.dayStart > $1.dayStart }
    }

    func monthlySummaries(using calendar: Calendar = Calendar(identifier: .iso8601)) -> [MonthlySummary] {
        guard !activities.isEmpty else { return [] }
        var bucket: [Date: MonthlySummary] = [:]

        for a in activities {
            let comps = calendar.dateComponents([.year, .month], from: a.endDate)
            guard let startOfMonth = calendar.date(from: comps) else { continue }
            var summary = bucket[startOfMonth] ?? MonthlySummary(id: startOfMonth, monthStart: startOfMonth, totalDistanceMeters: 0, totalDurationSeconds: 0, runCount: 0, longestRunMeters: 0, longestRunDurationSeconds: 0, totalCaloriesKilocalories: 0)
            summary.totalDistanceMeters += a.distanceMeters
            summary.totalDurationSeconds += a.durationSeconds
            summary.runCount += 1
            summary.totalCaloriesKilocalories += a.caloriesKilocalories
            if a.distanceMeters > summary.longestRunMeters {
                summary.longestRunMeters = a.distanceMeters
                summary.longestRunDurationSeconds = a.durationSeconds
            }
            bucket[startOfMonth] = summary
        }

        return bucket.values.sorted { $0.monthStart > $1.monthStart }
    }
}
extension ActivityStore {
    func weeklySummaries(using calendar: Calendar = Calendar(identifier: .iso8601)) -> [WeeklySummary] {
        guard !activities.isEmpty else { return [] }
        var bucket: [Date: WeeklySummary] = [:]

        for a in activities {
            let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: a.endDate)
            guard let startOfWeek = calendar.date(from: comps) else { continue }
            var summary = bucket[startOfWeek] ?? WeeklySummary(id: startOfWeek, weekStart: startOfWeek, totalDistanceMeters: 0, totalDurationSeconds: 0, longestRunMeters: 0, longestRunDurationSeconds: 0, totalCaloriesKilocalories: 0)
            summary.totalDistanceMeters += a.distanceMeters
            summary.totalDurationSeconds += a.durationSeconds
            summary.totalCaloriesKilocalories += a.caloriesKilocalories
            if a.distanceMeters > summary.longestRunMeters {
                summary.longestRunMeters = a.distanceMeters
                summary.longestRunDurationSeconds = a.durationSeconds
            }
            bucket[startOfWeek] = summary
        }

        return bucket.values.sorted { $0.weekStart > $1.weekStart }
    }

    func activeDaysStreak(using calendar: Calendar = Calendar(identifier: .iso8601)) -> Int {
        guard !activities.isEmpty else { return 0 }
        let daysWithActivity: Set<Date> = Set(activities.map { calendar.startOfDay(for: $0.endDate) })
        var streak = 0
        var day = calendar.startOfDay(for: Date())
        while daysWithActivity.contains(day) {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return streak
    }
}