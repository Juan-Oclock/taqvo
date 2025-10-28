//
//  ActivityFeedService.swift
//  Taqvo
//
//  Service for fetching public activities from other users
//

import Foundation

@MainActor
class ActivityFeedService: ObservableObject {
    @Published var publicActivities: [FeedActivity] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var lastLoadTimestamp: Date?
    
    private let supabaseDataSource: SupabaseCommunityDataSource?
    
    init() {
        self.supabaseDataSource = SupabaseCommunityDataSource.makeFromInfoPlist(authManager: SupabaseAuthManager.shared)
        
        // Listen for activity deletion notifications
        NotificationCenter.default.addObserver(
            forName: .activityDeleted,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let activityID = notification.userInfo?["activityID"] as? UUID {
                self?.removeActivity(activityID: activityID)
            }
        }
        
        // Listen for activity update notifications (likes, comments, etc.)
        NotificationCenter.default.addObserver(
            forName: .activityUpdated,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            if let activity = notification.userInfo?["activity"] as? FeedActivity {
                // Find existing activity in public feed
                if let existingIndex = self.publicActivities.firstIndex(where: { $0.id == activity.id }) {
                    var existingActivity = self.publicActivities[existingIndex]
                    
                    // Merge likes - use newer data
                    existingActivity.likeCount = activity.likeCount
                    existingActivity.likedByUserIds = activity.likedByUserIds
                    
                    // Merge comments intelligently
                    // If incoming activity has new comments, append them
                    if !activity.comments.isEmpty {
                        // Add any new comments that aren't already in the list
                        let existingCommentIds = Set(existingActivity.comments.map { $0.id })
                        let newComments = activity.comments.filter { !existingCommentIds.contains($0.id) }
                        existingActivity.comments.append(contentsOf: newComments)
                        
                        // Update comment count to reflect total
                        existingActivity.commentCount = max(existingActivity.comments.count, activity.commentCount)
                    } else {
                        // No comments in update, just update count
                        existingActivity.commentCount = max(existingActivity.commentCount, activity.commentCount)
                    }
                    
                    self.publicActivities[existingIndex] = existingActivity
                    print("✅ Merged activity update for \(activity.id) in public feed")
                } else {
                    // Activity not in feed, call standard update which will add it if public
                    self.updateActivity(activity)
                }
            }
        }
    }
    
    /// Load public activities from all users (excluding current user)
    func loadPublicActivities(limit: Int = 20) async {
        guard let supabase = supabaseDataSource else {
            print("Supabase not configured, skipping public feed load")
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Fetch public activities from Supabase
            let activities = try await supabase.loadPublicActivities(limit: limit)
            
            // Preserve ONLY the full comments array if we have it loaded locally
            // ALWAYS use the database comment count as the source of truth
            let existingCommentsMap = Dictionary(uniqueKeysWithValues: publicActivities.map { 
                ($0.id, $0.comments) 
            })
            
            // Process activities: use database counts but preserve loaded comments
            let mergedActivities = activities.map { newActivity -> FeedActivity in
                var activity = newActivity
                
                // If we have full comments loaded locally, keep them
                if let existingComments = existingCommentsMap[activity.id], !existingComments.isEmpty {
                    activity.comments = existingComments
                    // But STILL use database count in case new comments were added
                    print("📊 Activity \(activity.id): Using DB count \(activity.commentCount), have \(existingComments.count) loaded comments")
                }
                
                return activity
            }
            
            // Debug log for first activity
            if let firstActivity = mergedActivities.first {
                let currentUserId = await SupabaseAuthManager.shared.userId ?? ""
                let isLikedByMe = firstActivity.likedByUserIds.contains(currentUserId)
                print("📊 BEFORE update - First activity \(firstActivity.id):")
                print("   💬 commentCount: \(firstActivity.commentCount)")
                print("   ❤️  likeCount: \(firstActivity.likeCount)")
                print("   👤 likedByUserIds: \(firstActivity.likedByUserIds)")
                print("   ✓  Liked by me: \(isLikedByMe)")
            }
            
            // Update publicActivities array - this triggers @Published update
            publicActivities = mergedActivities
            
            // Force objectWillChange for immediate UI update
            objectWillChange.send()
            
            print("✅ Loaded \(publicActivities.count) public activities with counts from database")
            if let firstActivity = publicActivities.first {
                print("📊 AFTER update - First activity in feed: commentCount=\(firstActivity.commentCount), likeCount=\(firstActivity.likeCount)")
            }
            
            // Update timestamp to trigger any observers
            lastLoadTimestamp = Date()
        } catch {
            errorMessage = "Failed to load community feed"
            print("❌ Error loading public activities: \(error)")
        }
        
        isLoading = false
    }
    
    /// Refresh the public feed
    func refresh() async {
        await loadPublicActivities()
    }
    
    /// Remove an activity from the public feed (called when activity is deleted)
    func removeActivity(activityID: UUID) {
        publicActivities.removeAll { $0.id == activityID }
        print("✅ Removed activity \(activityID) from public feed")
    }
    
    /// Update an activity in the public feed (called when activity is liked/commented)
    /// This performs an intelligent merge to preserve data from both sources
    func updateActivity(_ updatedActivity: FeedActivity) {
        if let index = publicActivities.firstIndex(where: { $0.id == updatedActivity.id }) {
            let existingActivity = publicActivities[index]
            var merged = updatedActivity
            
            // Preserve comments array if the updated version has no comments but existing does
            // This prevents losing comments when optimistic updates happen
            if merged.comments.isEmpty && !existingActivity.comments.isEmpty {
                merged.comments = existingActivity.comments
            }
            
            // Use the higher comment count (server truth vs local optimistic count)
            merged.commentCount = max(merged.commentCount, existingActivity.commentCount)
            
            publicActivities[index] = merged
            print("✅ Updated activity \(updatedActivity.id) in public feed (merged)")
        } else {
            // Activity not in public feed yet - add it if it's public visibility
            if updatedActivity.visibility == .publicFeed {
                publicActivities.insert(updatedActivity, at: 0)
                print("✅ Added new public activity \(updatedActivity.id) to feed")
            }
        }
    }
}
