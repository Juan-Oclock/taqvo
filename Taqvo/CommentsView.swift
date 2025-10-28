//
//  CommentsView.swift
//  Taqvo
//
//  Lightweight comments UI for feed items with local persistence.
//

import SwiftUI

struct CommentsView: View {
    let activityID: UUID
    @EnvironmentObject var store: ActivityStore
    @EnvironmentObject var feedService: ActivityFeedService
    @State private var commentText: String = ""

    private var activity: FeedActivity? {
        // Check feedService first (for public activities), then store (for user's own)
        if let publicActivity = feedService.publicActivities.first(where: { $0.id == activityID }) {
            return publicActivity
        }
        return store.activities.first(where: { $0.id == activityID })
    }

    private var comments: [ActivityComment] {
        activity?.comments.sorted { $0.date < $1.date } ?? []
    }

    var body: some View {
        List {
            if comments.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "bubble.right")
                        .foregroundColor(.taqvoAccentText)
                    Text("No comments yet")
                        .foregroundColor(.taqvoAccentText)
                        .font(.caption)
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.black.opacity(0.08))
            } else {
                ForEach(comments) { c in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(c.authorUsername ?? c.author)
                                .font(.subheadline)
                                .foregroundColor(.taqvoTextDark)
                            Spacer()
                            Text(c.date.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption2)
                                .foregroundColor(.taqvoAccentText)
                        }
                        Text(c.text)
                            .font(.body)
                            .foregroundColor(.taqvoTextDark)
                    }
                    .padding(.vertical, 6)
                    .listRowBackground(Color.black.opacity(0.08))
                }
            }
        }
        .listStyle(.plain)
        .background(Color.taqvoBackgroundDark)
        .navigationTitle("Comments")
        .safeAreaInset(edge: .bottom) {
            composer
        }
        .onAppear {
            Task {
                await ProfileService.shared.loadCurrentUserProfile()
                
                print("🔍 CommentsView appeared for activity: \(activityID)")
                
                // Load comments from Supabase
                guard let supabase = SupabaseCommunityDataSource.makeFromInfoPlist(authManager: SupabaseAuthManager.shared) else {
                    print("❌ Failed to create Supabase data source")
                    return
                }
                
                do {
                    print("🔄 Loading comments from Supabase for activity: \(activityID)")
                    let comments = try await supabase.loadComments(activityID: activityID)
                    print("✅ Loaded \(comments.count) comments from Supabase")
                    
                    // Update activity with loaded comments in both store and feedService
                    await MainActor.run {
                        // Update in store (for user's own activities)
                        store.updateActivityComments(activityID: activityID, comments: comments)
                        print("✅ Updated comments in store")
                        
                        // Update in feedService (for public activities)
                        if let index = feedService.publicActivities.firstIndex(where: { $0.id == activityID }) {
                            var updatedActivity = feedService.publicActivities[index]
                            updatedActivity.comments = comments
                            updatedActivity.commentCount = comments.count // Update counter to match loaded comments
                            feedService.publicActivities[index] = updatedActivity
                            print("✅ Updated comments in feedService for activity \(activityID) - count: \(comments.count)")
                        } else {
                            print("⚠️ Activity \(activityID) not found in feedService.publicActivities")
                        }
                    }
                } catch {
                    print("❌ Failed to load comments from Supabase: \(error)")
                    if let urlError = error as? URLError {
                        print("   URLError code: \(urlError.code)")
                    }
                }
            }
        }
    }
    private var composer: some View {
        HStack(spacing: 8) {
            TextField("Add a comment…", text: $commentText)
                .textFieldStyle(.roundedBorder)
            Button("Send") {
                let trimmed = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                commentText = ""
                store.addComment(activityID: activityID, text: trimmed)
            }
            .disabled(commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .buttonStyle(TaqvoCTAButtonStyle())
        }
        .padding()
        .background(Color(.systemBackground).opacity(0.95))
    }
}

#Preview {
    let store = ActivityStore()
    // Simple preview with a fake activity
    let id = UUID()
    store.addComment(activityID: id, text: "Nice run!", author: "Alex") // no-op if not found
    return NavigationStack {
        CommentsView(activityID: id).environmentObject(store)
    }
}