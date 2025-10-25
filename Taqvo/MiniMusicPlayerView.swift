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
        VStack(spacing: 0) {
            // Drag Handle
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color.gray.opacity(0.5))
                .frame(width: 40, height: 5)
                .padding(.top, 12)
                .padding(.bottom, 20)
            
            // Content
            VStack(spacing: 20) {
                // Provider Toggle
                HStack(spacing: 12) {
                    Button {
                        provider = .apple
                        storedProviderString = MusicProvider.apple.rawValue
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "music.note")
                                .font(.system(size: 16, weight: .medium))
                            Text("Apple")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(provider == .apple ? .black : .taqvoAccentText)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(provider == .apple ? Color.taqvoCTA : Color.black.opacity(0.2))
                        .cornerRadius(20)
                    }
                    
                    Button {
                        provider = .spotify
                        storedProviderString = MusicProvider.spotify.rawValue
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "music.note.list")
                                .font(.system(size: 16, weight: .medium))
                            Text("Spotify")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(provider == .spotify ? .black : .taqvoAccentText)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(provider == .spotify ? Color.taqvoCTA : Color.black.opacity(0.2))
                        .cornerRadius(20)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                
                // Album Art & Song Info
                HStack(spacing: 16) {
                    // Album Art
                    if let artworkImage = currentArtwork {
                        Image(uiImage: artworkImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 80, height: 80)
                            .cornerRadius(12)
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.black.opacity(0.3))
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: "music.note")
                                .font(.system(size: 32))
                                .foregroundColor(.taqvoAccentText)
                        }
                    }
                    
                    // Song Info
                    VStack(alignment: .leading, spacing: 6) {
                        Text(currentTitle)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.taqvoTextDark)
                            .lineLimit(1)
                        
                        Text(currentArtist)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.taqvoAccentText)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                
                // Playback Controls
                HStack(spacing: 24) {
                    // Previous
                    Button {
                        previousTrack()
                    } label: {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.taqvoTextDark)
                            .frame(width: 44, height: 44)
                    }
                    .disabled(!isAuthorized)
                    
                    // Play/Pause
                    Button {
                        togglePlayPause()
                    } label: {
                        Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 56))
                            .foregroundColor(.taqvoCTA)
                    }
                    .disabled(!isAuthorized)
                    
                    // Next
                    Button {
                        nextTrack()
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.taqvoTextDark)
                            .frame(width: 44, height: 44)
                    }
                    .disabled(!isAuthorized)
                }
                .padding(.horizontal, 20)
                
                // Status Text
                if !isAuthorized {
                    Text("Not authorized - Please authorize \(provider == .apple ? "Apple Music" : "Spotify") first")
                        .font(.system(size: 12))
                        .foregroundColor(.taqvoAccentText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
            }
            .padding(.bottom, 30)
        }
        .background(Color(red: 79/255, green: 79/255, blue: 79/255))
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
