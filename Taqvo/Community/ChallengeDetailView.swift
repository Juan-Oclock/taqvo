import SwiftUI

struct ChallengeDetailView: View {
    @EnvironmentObject var community: CommunityViewModel
    @EnvironmentObject var store: ActivityStore
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirm = false
    @State private var canDelete = false
    @State private var showInviteSheet = false
    @State private var inviteUsernamesText = ""

    let challenge: Challenge

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text(currentChallenge.title)
                            .font(.title2)
                            .foregroundColor(.taqvoTextDark)
                        Spacer()
                        Button(currentChallenge.isJoined ? "Leave" : "Join") {
                            community.toggleJoin(challengeID: currentChallenge.id)
                            community.refreshProgress(from: store)
                            // If joining, jump to Activity to start tracking with sensible defaults
                            if community.challenges.first(where: { $0.id == currentChallenge.id })?.isJoined == true {
                                appState.activityIntent = .run
                                appState.goalIntentType = .distance
                                appState.goalIntentMeters = 5000
                                appState.linkedChallengeTitle = currentChallenge.title
                                appState.linkedChallengeIsPublic = currentChallenge.isPublic
                                appState.navigateToActivity = true
                            }
                        }
                        .buttonStyle(TaqvoCTAButtonStyle())
                    }

                    Text(currentChallenge.detail)
                        .foregroundColor(.taqvoAccentText)

                    HStack {
                        Text(dateRangeText)
                            .font(.caption)
                            .foregroundColor(.taqvoAccentText)
                        Spacer()
                        Text(String(format: "Goal: %.0f km", currentChallenge.goalDistanceMeters/1000.0))
                    }

                    // Contributions list
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Daily Contributions")
                            .font(.headline)
                            .foregroundColor(.taqvoTextDark)
                        ForEach(dayContributions()) { c in
                            HStack {
                                Text(c.date.formatted(date: .abbreviated, time: .omitted))
                                    .foregroundColor(.taqvoAccentText)
                                Spacer()
                                Text(String(format: "%.2f km", c.distanceMeters/1000.0))
                                    .foregroundColor(.taqvoTextDark)
                            }
                        }
                    }

                    if currentChallenge.isJoined {
                        Button {
                            appState.activityIntent = .run
                            appState.goalIntentType = .distance
                            appState.goalIntentMeters = 5000
                            appState.linkedChallengeTitle = currentChallenge.title
                            appState.linkedChallengeIsPublic = currentChallenge.isPublic
                            appState.navigateToActivity = true
                        } label: {
                            Text("Start Activity")
                                .font(.headline)
                                .foregroundColor(.taqvoTextLight)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.taqvoCTA)
                                .cornerRadius(16)
                        }
                    }

                    // Invite participants
                    Button {
                        showInviteSheet = true
                    } label: {
                        Label("Invite Participants", systemImage: "person.crop.circle.badge.plus")
                    }
                    .buttonStyle(.bordered)
                }
            }
            .navigationTitle("Challenge")
            .toolbar {
                if canDelete {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Text("Delete")
                        }
                    }
                }
            }
            .alert("Delete this challenge?", isPresented: $showDeleteConfirm) {
                Button("Delete", role: .destructive) {
                    Task {
                        try? await community.deleteChallenge(challengeID: currentChallenge.id)
                        await MainActor.run { dismiss() }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This cannot be undone.")
            }
        }
        .task {
            canDelete = await community.canDelete(challengeID: challenge.id)
        }
        .onAppear {
            community.refreshProgress(from: store)
        }
        .sheet(isPresented: $showInviteSheet) {
            InviteParticipantsSheet(challengeID: currentChallenge.id, inviteUsernamesText: $inviteUsernamesText)
                .environmentObject(community)
        }
    }

    private var currentChallenge: Challenge {
        community.challenges.first(where: { $0.id == challenge.id }) ?? challenge
    }

    private var dateRangeText: String {
        let df = DateFormatter()
        df.dateStyle = .medium
        return "\(df.string(from: currentChallenge.startDate)) - \(df.string(from: currentChallenge.endDate))"
    }

    private func dayContributions() -> [ContributionDay] {
        // Placeholder until wired to real data
        return []
    }
}

struct ContributionDay: Identifiable {
    let id = UUID()
    let date: Date
    let distanceMeters: Double
}

struct InviteParticipantsSheet: View {
    let challengeID: UUID
    @EnvironmentObject var community: CommunityViewModel
    @Environment(\.dismiss) private var dismiss
    @Binding var inviteUsernamesText: String
    @State private var sending = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Usernames") {
                    TextField("alice, bob, charlie", text: $inviteUsernamesText)
                }
                if let msg = errorMessage {
                    Section { Text(msg).foregroundColor(.red) }
                }
            }
            .navigationTitle("Invite Participants")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(sending ? "Sending..." : "Send Invites") {
                        let names = inviteUsernamesText
                            .split(separator: ",")
                            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                            .filter { !$0.isEmpty }
                        Task {
                            sending = true
                            do {
                                try await community.inviteParticipants(challengeID: challengeID, usernames: names)
                                await MainActor.run { dismiss() }
                            } catch {
                                errorMessage = (error as NSError).localizedDescription
                            }
                            sending = false
                        }
                    }
                    .disabled(inviteUsernamesText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || sending)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}