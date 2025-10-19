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
    @State private var commentText: String = ""

    private var activity: FeedActivity? {
        store.activities.first(where: { $0.id == activityID })
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
                            Text(c.author)
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
    }
    private var composer: some View {
        HStack(spacing: 8) {
            TextField("Add a comment…", text: $commentText)
                .textFieldStyle(.roundedBorder)
            Button("Send") {
                let trimmed = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                commentText = ""
                store.addComment(activityID: activityID, text: trimmed, author: "You")
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