import SwiftUI

struct CommentsBottomSheet: View {
    @EnvironmentObject var store: ActivityStore
    @Binding var isPresented: Bool
    let activity: FeedActivity
    @State private var commentText: String = ""
    @FocusState private var isTextFieldFocused: Bool
    
    private var commentHeaderText: String {
        if let title = activity.title, !title.isEmpty {
            return "Comment for \(title)"
        } else {
            let activityName: String
            switch activity.kind {
            case .walk:
                activityName = "Walking"
            case .jog:
                activityName = "Jogging"
            case .run:
                activityName = "Running"
            case .ride:
                activityName = "Riding"
            }
            return "Comments for \(activityName)"
        }
    }
    
    var comments: [ActivityComment] {
        activity.comments.sorted { $0.date < $1.date }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Comments for \(activity.title ?? activity.kind.rawValue.capitalized)")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.taqvoTextDark)
                        Text("\(comments.count) comment\(comments.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundColor(.taqvoAccentText)
                    }
                    Spacer()
                    Button("Done") {
                        isPresented = false
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.taqvoCTA)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color.taqvoOnboardingBG)
                
                Divider()
                    .background(Color.taqvoAccentText.opacity(0.3))
                
                // Comments List
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        if comments.isEmpty {
                            // Empty state
                            VStack(spacing: 12) {
                                Image(systemName: "bubble.right")
                                    .font(.system(size: 32))
                                    .foregroundColor(.taqvoAccentText.opacity(0.6))
                                Text("No comments yet")
                                    .font(.headline)
                                    .foregroundColor(.taqvoAccentText)
                                Text("Be the first to comment on this activity!")
                                    .font(.caption)
                                    .foregroundColor(.taqvoAccentText.opacity(0.8))
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                        } else {
                            // Comments
                            ForEach(comments) { comment in
                                CommentRowView(comment: comment, activity: activity, store: store)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        // Only show delete action for user's own comments
                                        let currentUserEmail = SupabaseAuthManager.shared.userEmail ?? "You"
                                        if comment.author == currentUserEmail {
                                            Button(role: .destructive) {
                                                store.deleteComment(activityID: activity.id, commentID: comment.id)
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                    }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 100) // Extra padding for comment composer
                }
                .background(Color.taqvoOnboardingBG)
                
                Spacer()
            }
            .background(Color.taqvoOnboardingBG)
            .overlay(
                // Comment Composer (Fixed at bottom)
                VStack {
                    Spacer()
                    CommentComposerView(
                        commentText: $commentText,
                        isTextFieldFocused: $isTextFieldFocused,
                        onSend: {
                            let trimmed = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !trimmed.isEmpty else { return }
                            commentText = ""
                            isTextFieldFocused = false
                            store.addComment(activityID: activity.id, text: trimmed)
                        }
                    )
                }
            )
        }
        .presentationDetents([.fraction(0.5), .large])
        .presentationDragIndicator(.visible)
        .presentationBackgroundInteraction(.disabled)
    }
}

struct CommentRowView: View {
    let comment: ActivityComment
    let activity: FeedActivity
    let store: ActivityStore
    
    private var displayName: String {
        // Use username if available and not empty, otherwise fall back to email (author)
        if let username = comment.authorUsername, !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return username
        }
        return comment.author
    }
    
    private var profileImageURL: URL? {
        guard let s = comment.authorProfileImageBase64, !s.isEmpty else { return nil }
        if s.hasPrefix("http://") || s.hasPrefix("https://") {
            return URL(string: s)
        }
        return nil
    }
    
    private var profileImage: UIImage? {
        guard let avatarUrl = comment.authorProfileImageBase64,
              !avatarUrl.isEmpty else {
            return nil
        }
        
        // Handle both old base64 format and new data URL format
        if avatarUrl.hasPrefix("data:image/") {
            // New format: data:image/jpeg;base64,<base64string>
            let base64String = String(avatarUrl.dropFirst("data:image/jpeg;base64,".count))
            guard let data = Data(base64Encoded: base64String) else { return nil }
            return UIImage(data: data)
        } else if !avatarUrl.hasPrefix("http://") && !avatarUrl.hasPrefix("https://") {
            // Old format: direct base64 string
            guard let data = Data(base64Encoded: avatarUrl) else { return nil }
            return UIImage(data: data)
        }
        return nil
    }
    
    private var isCurrentUserComment: Bool {
        let currentUserEmail = SupabaseAuthManager.shared.userEmail ?? "You"
        return comment.author == currentUserEmail
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Profile photo or avatar placeholder
                Group {
                    if let url = profileImageURL {
                        AsyncImage(url: url) { image in
                            image.resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 32, height: 32)
                                .clipShape(Circle())
                        } placeholder: {
                            Circle()
                                .fill(Color.taqvoCTA.opacity(0.2))
                                .frame(width: 32, height: 32)
                                .overlay(ProgressView().progressViewStyle(.circular))
                        }
                    } else if let profileImage = profileImage {
                        Image(uiImage: profileImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 32, height: 32)
                            .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(Color.taqvoCTA.opacity(0.2))
                            .frame(width: 32, height: 32)
                            .overlay(
                                Text(String(displayName.prefix(1)).uppercased())
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.taqvoCTA)
                            )
                    }
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(displayName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.taqvoTextDark)
                        Spacer()
                        Text(comment.date.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption2)
                            .foregroundColor(.taqvoAccentText)
                        
                        // Delete button for user's own comments
                        if isCurrentUserComment {
                            Button(action: {
                                store.deleteComment(activityID: activity.id, commentID: comment.id)
                            }) {
                                Image(systemName: "trash")
                                    .font(.system(size: 12))
                                    .foregroundColor(.red.opacity(0.7))
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    Text(comment.text)
                        .font(.system(size: 14))
                        .foregroundColor(.taqvoTextDark)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct CommentComposerView: View {
    @Binding var commentText: String
    var isTextFieldFocused: FocusState<Bool>.Binding
    let onSend: () -> Void
    @StateObject private var profileService = ProfileService.shared
    
    private var currentUserDisplayName: String {
        // Use username if available, otherwise fall back to email
        if let username = profileService.currentProfile?.username, !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return username
        }
        return SupabaseAuthManager.shared.userEmail ?? "You"
    }
    
    private var currentUserProfileImageURL: URL? {
        guard let s = profileService.currentProfile?.avatarUrl, !s.isEmpty else { return nil }
        if s.hasPrefix("http://") || s.hasPrefix("https://") { return URL(string: s) }
        return nil
    }
    
    private var currentUserProfileImage: UIImage? {
        guard let avatarUrl = profileService.currentProfile?.avatarUrl,
              !avatarUrl.isEmpty else {
            return nil
        }
        
        // Handle data URL format: data:image/jpeg;base64,<base64string>
        if avatarUrl.hasPrefix("data:image/") {
            let base64String = String(avatarUrl.dropFirst("data:image/jpeg;base64,".count))
            guard let data = Data(base64Encoded: base64String) else { return nil }
            return UIImage(data: data)
        }
        
        return nil
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .background(Color.taqvoAccentText.opacity(0.3))
            
            HStack(spacing: 12) {
                // Current user profile photo or avatar placeholder
                Group {
                    if let url = currentUserProfileImageURL {
                        AsyncImage(url: url) { image in
                            image.resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 32, height: 32)
                                .clipShape(Circle())
                        } placeholder: {
                            Circle()
                                .fill(Color.taqvoCTA.opacity(0.2))
                                .frame(width: 32, height: 32)
                                .overlay(ProgressView().progressViewStyle(.circular))
                        }
                    } else if let profileImage = currentUserProfileImage {
                        Image(uiImage: profileImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 32, height: 32)
                            .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(Color.taqvoCTA.opacity(0.2))
                            .frame(width: 32, height: 32)
                            .overlay(
                                Text(String(currentUserDisplayName.prefix(1)).uppercased())
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.taqvoCTA)
                            )
                    }
                }
                
                // Text field
                TextField("Add a comment…", text: $commentText, axis: .vertical)
                    .font(.system(size: 14))
                    .foregroundColor(.taqvoTextLight)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.white)
                            .stroke(Color.clear, lineWidth: 2)
                    )
                    .focused(isTextFieldFocused)
                    .lineLimit(1...4)
                    .submitLabel(.send)
                    .onSubmit {
                        onSend()
                    }
                
                // Send button
                Button(action: onSend) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 
                                       .taqvoAccentText.opacity(0.5) : .taqvoCTA)
                }
                .disabled(commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.taqvoOnboardingBG)
        }
    }
}

#Preview {
    CommentsBottomSheet(
        isPresented: .constant(true),
        activity: FeedActivity(
            id: UUID(),
            userId: "user123",
            distanceMeters: 5200,
            durationSeconds: 1800,
            route: [],
            startDate: Date().addingTimeInterval(-1800),
            endDate: Date(),
            snapshotPNG: nil,
            note: "Great morning run!",
            photoPNG: nil,
            title: "Morning Run",
            likeCount: 5,
            likedByUserIds: [],
            comments: [
                ActivityComment(id: UUID(), author: "jane@example.com", text: "Great job!", date: Date().addingTimeInterval(-300), authorUsername: "Jane Smith", authorProfileImageBase64: nil),
                ActivityComment(id: UUID(), author: "mike@example.com", text: "Nice pace!", date: Date().addingTimeInterval(-150), authorUsername: "Mike Johnson", authorProfileImageBase64: nil)
            ],
            kind: .run,
            caloriesKilocalories: 350,
            averageHeartRateBPM: 145,
            splitsSeconds: nil,
            challengeTitle: nil,
            challengeIsPublic: nil,
            stepsCount: 7500,
            elevationGainMeters: 50,
            visibility: .publicFeed
        )
    )
    .environmentObject(ActivityStore())
}