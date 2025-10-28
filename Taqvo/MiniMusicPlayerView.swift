//
//  MiniMusicPlayerView.swift
//  Taqvo
//
//  Mini music player bottom sheet with playback controls
//

import SwiftUI

struct MiniMusicPlayerView: View {
    @ObservedObject var musicVM: MusicViewModel
    @ObservedObject var spotifyVM: SpotifyViewModel
    @AppStorage("preferredMusicProvider") private var storedProviderString: String = MusicProvider.spotify.rawValue
    @State private var provider: MusicProvider = .spotify
    
    var body: some View {
        VStack(spacing: 24) {
            // Provider Toggle
            HStack(spacing: 8) {
                Button {
                    provider = .apple
                    storedProviderString = MusicProvider.apple.rawValue
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "music.note")
                            .font(.system(size: 14, weight: .medium))
                        Text("Apple")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(provider == .apple ? .black : .white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(provider == .apple ? Color.taqvoCTA : Color.white.opacity(0.1))
                    .cornerRadius(24)
                }
                
                Button {
                    provider = .spotify
                    storedProviderString = MusicProvider.spotify.rawValue
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 14, weight: .medium))
                        Text("Spotify")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(provider == .spotify ? .black : .white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(provider == .spotify ? Color.taqvoCTA : Color.white.opacity(0.1))
                    .cornerRadius(24)
                }
            }
            
            // Album Art & Song Info
            HStack(spacing: 16) {
                // Album Art
                if let artworkImage = currentArtwork {
                    Image(uiImage: artworkImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 72, height: 72)
                        .cornerRadius(12)
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.1))
                            .frame(width: 72, height: 72)
                        
                        Image(systemName: "music.note")
                            .font(.system(size: 28))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                
                // Song Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(currentTitle)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text(currentArtist)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(1)
                }
                
                Spacer()
            }
            .padding(.horizontal, 24)
            
            // Playback Controls
            HStack(spacing: 32) {
                // Previous
                Button {
                    previousTrack()
                } label: {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 26))
                        .foregroundColor(.white)
                }
                .disabled(!isAuthorized)
                
                // Play/Pause
                Button {
                    togglePlayPause()
                } label: {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.taqvoCTA)
                }
                .disabled(!isAuthorized)
                
                // Next
                Button {
                    nextTrack()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 26))
                        .foregroundColor(.white)
                }
                .disabled(!isAuthorized)
            }
            
            // Status Text
            if !isAuthorized {
                Text("Please authorize \(provider == .apple ? "Apple Music" : "Spotify") to play music")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
            }
        }
        .padding(.top, 20)
        .padding(.bottom, 8)
        .onAppear {
            provider = MusicProvider(rawValue: storedProviderString) ?? .spotify
        }
    }
    
    // MARK: - Computed Properties
    
    private var isAuthorized: Bool {
        provider == .apple ? musicVM.isAuthorized : spotifyVM.isAuthorized
    }
    
    private var isPlaying: Bool {
        provider == .apple ? musicVM.isPlaying : spotifyVM.isPlaying
    }
    
    private var currentTitle: String {
        let title = provider == .apple ? musicVM.currentTitle : spotifyVM.currentTitle
        return title.isEmpty ? "No track playing" : title
    }
    
    private var currentArtist: String {
        let artist = provider == .apple ? musicVM.currentArtist : spotifyVM.currentArtist
        return artist.isEmpty ? "Unknown artist" : artist
    }
    
    private var currentArtwork: UIImage? {
        if provider == .apple {
            return musicVM.currentArtwork
        } else {
            return spotifyVM.currentArtwork
        }
    }
    
    // MARK: - Actions
    
    private func togglePlayPause() {
        if provider == .apple {
            if musicVM.isPlaying {
                musicVM.pause()
            } else {
                musicVM.play()
            }
        } else {
            Task {
                if spotifyVM.isPlaying {
                    await spotifyVM.pause()
                } else {
                    await spotifyVM.resume()
                }
            }
        }
    }
    
    private func previousTrack() {
        if provider == .apple {
            musicVM.skipToPrevious()
        } else {
            Task {
                await spotifyVM.skipToPrevious()
            }
        }
    }
    
    private func nextTrack() {
        if provider == .apple {
            musicVM.skipToNext()
        } else {
            Task {
                await spotifyVM.skipToNext()
            }
        }
    }
}
