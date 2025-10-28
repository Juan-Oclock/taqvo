//
//  ActivityStore.swift
//  Taqvo
//
//  Implements persistent storage for completed activities shown in Feed.
//

import Foundation
import Combine
import SwiftUI
import MapKit
import CoreLocation

// Notification names
extension Notification.Name {
    static let activityDeleted = Notification.Name("activityDeleted")
    static let activityUpdated = Notification.Name("activityUpdated")
}

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
    var commentCount: Int // Total comment count from database (may differ from comments.count if not all loaded)
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
        case id, userId, username, avatarUrl, distanceMeters, durationSeconds, route, startDate, endDate, snapshotPNG, note, photoPNG, title, likeCount, likedByUserIds, comments, commentCount, kind, caloriesKilocalories, averageHeartRateBPM, splitsSeconds, challengeTitle, challengeIsPublic, stepsCount, elevationGainMeters, visibility
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
         commentCount: Int = 0,
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
        self.commentCount = commentCount
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
        commentCount = try c.decodeIfPresent(Int.self, forKey: .commentCount) ?? 0
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
            let existingActivity = activities[index]
            var merged = updatedActivity
            
            // Intelligently merge to preserve data
            // Preserve comments if updated version is missing them but existing has them
            if merged.comments.isEmpty && !existingActivity.comments.isEmpty {
                merged.comments = existingActivity.comments
            }
            
            // Use max count for safety
            merged.commentCount = max(merged.commentCount, existingActivity.commentCount)
            
            activities[index] = merged
            save()
            
            print("✅ Updated activity \(updatedActivity.id) in ActivityStore")
        } else {
            // Activity not in local store, but might be a public activity we're viewing
            // Don't add it to local store, just broadcast the update
            print("⚠️ Activity \(updatedActivity.id) not in local store, broadcasting update anyway")
        }
        
        // Always notify observers that activity was updated (for UI updates in public feed)
        // This ensures FeedService and other observers receive the update
        NotificationCenter.default.post(
            name: .activityUpdated, 
            object: nil, 
            userInfo: ["activity": updatedActivity]
        )
    }
    
    @MainActor
    func updateActivityComments(activityID: UUID, comments: [ActivityComment]) {
        if let index = activities.firstIndex(where: { $0.id == activityID }) {
            var activity = activities[index]
            activity.comments = comments
            activities[index] = activity
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
        
        // Delete from local store
        activities.removeAll { $0.id == activity.id }
        save()
        
        // Notify observers that activity was deleted (for UI updates)
        NotificationCenter.default.post(name: .activityDeleted, object: nil, userInfo: ["activityID": activity.id])
        
        // Delete from Supabase in background
        Task {
            do {
                guard let supabase = SupabaseCommunityDataSource.makeFromInfoPlist(authManager: SupabaseAuthManager.shared) else {
                    print("⚠️ Supabase not configured, skipping remote delete")
                    return
                }
                try await supabase.deleteActivity(activityID: activity.id)
                print("✅ Activity deleted from Supabase")
            } catch {
                print("⚠️ Failed to delete activity from Supabase: \(error)")
                // Activity is already deleted locally, so we don't need to revert
            }
        }
    }

    @MainActor
    func toggleLike(activityID: UUID) {
        guard let idx = activities.firstIndex(where: { $0.id == activityID }) else { return }
        guard let currentUserId = SupabaseAuthManager.shared.userId else { return }
        
        var a = activities[idx]
        let wasLiked = a.likedByUserIds.contains(currentUserId)
        
        // Optimistic update
        if wasLiked {
            a.likedByUserIds.removeAll { $0 == currentUserId }
            if a.likeCount > 0 { a.likeCount -= 1 }
        } else {
            a.likedByUserIds.append(currentUserId)
            a.likeCount += 1
        }
        
        activities[idx] = a
        save()
        
        // Notify UI
        NotificationCenter.default.post(name: .activityUpdated, object: nil, userInfo: ["activity": a])
        
        // Sync to Supabase in background
        Task {
            do {
                guard let supabase = SupabaseCommunityDataSource.makeFromInfoPlist(authManager: SupabaseAuthManager.shared) else {
                    return
                }
                let isNowLiked = try await supabase.toggleLike(activityID: activityID)
                print("✅ Like synced to Supabase: \(isNowLiked)")
            } catch {
                print("⚠️ Failed to sync like to Supabase: \(error)")
                // Revert optimistic update on failure
                await MainActor.run {
                    guard let idx = activities.firstIndex(where: { $0.id == activityID }) else { return }
                    var a = activities[idx]
                    if wasLiked {
                        a.likedByUserIds.append(currentUserId)
                        a.likeCount += 1
                    } else {
                        a.likedByUserIds.removeAll { $0 == currentUserId }
                        if a.likeCount > 0 { a.likeCount -= 1 }
                    }
                    activities[idx] = a
                    save()
                    NotificationCenter.default.post(name: .activityUpdated, object: nil, userInfo: ["activity": a])
                }
            }
        }
    }

    @MainActor
    func addComment(activityID: UUID, text: String, author: String? = nil, authorUsername: String? = nil, authorProfileImageBase64: String? = nil) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        // Get current user's userId as the primary identifier (always available when authenticated)
        let currentUserId = SupabaseAuthManager.shared.userId ?? "unknown"
        let commentAuthor = author ?? (SupabaseAuthManager.shared.userEmail ?? currentUserId)
        
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
            // If profile not loaded, load it asynchronously and we'll use it next time
            // For now, use nil and let the UI show email
            Task {
                await profileService.loadCurrentUserProfile()
            }
            finalUsername = nil
        }
        
        // For profile image: use provided value or profile avatar
        let finalProfileImage = authorProfileImageBase64 ?? profileService.currentProfile?.avatarUrl
        
        print("DEBUG: Final username for comment: \(String(describing: finalUsername))")
        print("DEBUG: Final profile image for comment: \(String(describing: finalProfileImage))")
        
        let commentId = UUID()
        let comment = ActivityComment(
            id: commentId,
            author: commentAuthor,
            text: trimmed,
            date: Date(),
            authorUsername: finalUsername,
            authorProfileImageBase64: finalProfileImage
        )
        
        // Optimistic update - update local store if activity exists there
        if let idx = activities.firstIndex(where: { $0.id == activityID }) {
            var a = activities[idx]
            a.comments.append(comment)
            a.commentCount += 1 // Increment counter
            activities[idx] = a
            save()
            
            print("✅ Comment added to local activity \(activityID)")
            
            // Notify observers that activity was updated (for UI updates in public feed)
            NotificationCenter.default.post(name: .activityUpdated, object: nil, userInfo: ["activity": a])
        } else {
            // Activity not in local store - might be a public activity
            // Just broadcast the comment addition for FeedService to handle
            print("⚠️ Activity \(activityID) not in local store, broadcasting comment update")
            
            // Create a temporary activity object with just the comment for notification
            // FeedService will handle merging this properly
            var tempActivity = FeedActivity(
                id: activityID,
                userId: currentUserId,
                distanceMeters: 0,
                durationSeconds: 0,
                route: [],
                startDate: Date(),
                endDate: Date(),
                snapshotPNG: nil,
                note: nil,
                photoPNG: nil,
                comments: [comment],
                commentCount: 1,
                kind: .run,
                caloriesKilocalories: 0
            )
            NotificationCenter.default.post(name: .activityUpdated, object: nil, userInfo: ["activity": tempActivity])
        }
        
        // Sync to Supabase in background
        Task {
            do {
                guard let supabase = SupabaseCommunityDataSource.makeFromInfoPlist(authManager: SupabaseAuthManager.shared) else {
                    return
                }
                let _ = try await supabase.addComment(
                    activityID: activityID,
                    text: trimmed,
                    username: finalUsername,
                    avatarUrl: finalProfileImage
                )
                print("✅ Comment synced to Supabase")
            } catch {
                print("⚠️ Failed to sync comment to Supabase: \(error)")
                // TODO: Consider rollback on failure
            }
        }
    }
    
    @MainActor
    func deleteComment(activityID: UUID, commentID: UUID) {
        guard let activityIdx = activities.firstIndex(where: { $0.id == activityID }) else { return }
        var activity = activities[activityIdx]
        
        // Find the comment to delete
        guard let commentIdx = activity.comments.firstIndex(where: { $0.id == commentID }) else { return }
        let comment = activity.comments[commentIdx]
        
        // Check if current user is the author of the comment
        let currentUserId = SupabaseAuthManager.shared.userId
        let currentUserEmail = SupabaseAuthManager.shared.userEmail
        
        let isAuthor = (currentUserEmail != nil && comment.author == currentUserEmail) ||
                       (currentUserId != nil && comment.author == currentUserId)
        guard isAuthor else { return }
        
        // Remove the comment
        activity.comments.remove(at: commentIdx)
        if activity.commentCount > 0 {
            activity.commentCount -= 1 // Decrement counter
        }
        activities[activityIdx] = activity
        save()
        
        // Notify observers that activity was updated (for UI updates in public feed)
        NotificationCenter.default.post(name: .activityUpdated, object: nil, userInfo: ["activity": activity])
        
        // Sync to Supabase in background
        Task {
            do {
                guard let supabase = SupabaseCommunityDataSource.makeFromInfoPlist(authManager: SupabaseAuthManager.shared) else {
                    return
                }
                try await supabase.deleteComment(commentID: commentID)
                print("✅ Comment deletion synced to Supabase")
            } catch {
                print("⚠️ Failed to sync comment deletion to Supabase: \(error)")
            }
        }
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