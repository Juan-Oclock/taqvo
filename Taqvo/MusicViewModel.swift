//
//  MusicViewModel.swift
//  Taqvo
//
//  Created by Assistant on 10/17/25
//

import Foundation
import SwiftUI
import MediaPlayer

final class MusicViewModel: ObservableObject {
    // System player controls Apple Music playback
    private let player = MPMusicPlayerController.systemMusicPlayer
    private var observersAdded = false

    @Published var isAuthorized: Bool = (MPMediaLibrary.authorizationStatus() == .authorized)
    @Published var isPlaying: Bool = false
    @Published var currentTitle: String = "Not Playing"
    @Published var currentArtist: String = ""

    @Published var playlists: [MPMediaPlaylist] = []

    @AppStorage("selectedPlaylistID") private var storedPlaylistID: String = ""
    
    var currentPlaylistName: String {
        guard !storedPlaylistID.isEmpty else { return "" }
        if let playlist = playlists.first(where: { $0.persistentID.description == storedPlaylistID }) {
            return playlist.name ?? ""
        }
        return ""
    }

    // Request access to Apple Music / Media Library
    func requestAuthorization() {
        MPMediaLibrary.requestAuthorization { status in
            DispatchQueue.main.async {
                self.isAuthorized = (status == .authorized)
                if self.isAuthorized {
                    self.startObserving()
                    self.loadPlaylists()
                    self.restoreStoredPlaylistIfPossible()
                }
            }
        }
    }

    func startObserving() {
        guard !observersAdded else { return }
        observersAdded = true
        player.beginGeneratingPlaybackNotifications()
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(nowPlayingChanged),
                                               name: .MPMusicPlayerControllerNowPlayingItemDidChange,
                                               object: player)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(playbackStateChanged),
                                               name: .MPMusicPlayerControllerPlaybackStateDidChange,
                                               object: player)
        updateNowPlaying()
    }

    @objc private func nowPlayingChanged() {
        updateNowPlaying()
    }

    @objc private func playbackStateChanged() {
        DispatchQueue.main.async {
            self.isPlaying = self.player.playbackState == .playing
        }
    }

    private func updateNowPlaying() {
        DispatchQueue.main.async {
            let item = self.player.nowPlayingItem
            self.currentTitle = item?.title ?? "Not Playing"
            self.currentArtist = item?.artist ?? ""
            self.isPlaying = self.player.playbackState == .playing
        }
    }

    func togglePlayPause() {
        if player.playbackState == .playing {
            player.pause()
        } else {
            player.play()
        }
        updateNowPlaying()
    }

    func stopPlayback() {
        player.stop()
        updateNowPlaying()
    }

    func loadPlaylists() {
        let query = MPMediaQuery.playlists()
        if let collections = query.collections {
            self.playlists = collections.compactMap { $0 as? MPMediaPlaylist }
        } else {
            self.playlists = []
        }
    }

    func setQueue(playlist: MPMediaPlaylist) {
        player.setQueue(with: playlist)
        player.play()
        storedPlaylistID = String(playlist.persistentID)
        updateNowPlaying()
    }

    private func restoreStoredPlaylistIfPossible() {
        guard !storedPlaylistID.isEmpty else { return }
        if playlists.isEmpty { loadPlaylists() }
        if let pid = UInt64(storedPlaylistID), let p = playlists.first(where: { $0.persistentID == pid }) {
            setQueue(playlist: p)
        }
    }

    deinit {
        if observersAdded {
            NotificationCenter.default.removeObserver(self)
            player.endGeneratingPlaybackNotifications()
        }
    }
}

// MARK: - Playlist Picker UI
struct PlaylistPickerView: View {
    @ObservedObject var musicVM: MusicViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(musicVM.playlists, id: \.persistentID) { p in
                Button(action: {
                    musicVM.setQueue(playlist: p)
                    dismiss()
                }) {
                    VStack(alignment: .leading) {
                        Text(p.name ?? "Untitled Playlist")
                            .foregroundColor(.taqvoTextDark)
                        Text("\(p.items.count) songs")
                            .font(.caption)
                            .foregroundColor(.taqvoAccentText)
                    }
                }
                .listRowBackground(Color.black.opacity(0.08))
            }
            .navigationTitle("Choose Playlist")
            .onAppear {
                if musicVM.isAuthorized {
                    musicVM.loadPlaylists()
                }
            }
        }
    }
}