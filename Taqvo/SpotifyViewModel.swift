//
//  SpotifyViewModel.swift
//  Taqvo
//
//  Controls Spotify via Web API (Connect, Play/Pause, Play Playlist).
//

import Foundation
import SwiftUI

@MainActor
final class SpotifyViewModel: ObservableObject {
    @Published var isAuthorized: Bool = false
    @Published var isPlaying: Bool = false
    @Published var currentTitle: String = "Not Playing"
    @Published var currentArtist: String = ""

    @Published var playlists: [SpotifyPlaylist] = []

    @AppStorage("spotifySelectedPlaylistURI") private var storedPlaylistURI: String = ""
    @AppStorage("spotifyLastDeviceID") private var lastDeviceID: String = ""

    private let auth = SpotifyAuthManager.shared

    init() {
        isAuthorized = auth.isAuthorized
        // Observe changes from the auth manager
        Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(named: .spotifyAuthStateChanged) {
                await self?.syncAuthState()
            }
        }
    }

    private func syncAuthState() async {
        isAuthorized = auth.isAuthorized
        if isAuthorized {
            await refreshState()
        } else {
            isPlaying = false
            currentTitle = "Not Playing"
            currentArtist = ""
        }
    }

    func connect() {
        auth.startAuthorization()
    }

    // MARK: - State / Devices
    func refreshState() async {
        await auth.refreshAccessTokenIfNeeded()
        guard let token = auth.accessToken else { return }
        var req = URLRequest(url: URL(string: "https://api.spotify.com/v1/me/player")!)
        req.httpMethod = "GET"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse else { return }
            if http.statusCode == 204 {
                // No active device
                isPlaying = false
                currentTitle = "Spotify not active"
                currentArtist = ""
                return
            }
            if http.statusCode != 200 {
                let msg = String(data: data, encoding: .utf8) ?? ""
                print("Spotify player state failed: \(http.statusCode) \(msg)")
                return
            }
            let state = try JSONDecoder().decode(SpotifyPlayerState.self, from: data)
            isPlaying = state.is_playing ?? false
            if let item = state.item {
                currentTitle = item.name
                currentArtist = item.artists?.first?.name ?? ""
            }
            if let dev = state.device, let devId = dev.id {
                lastDeviceID = devId
            }
        } catch {
            print("Spotify player state error: \(error)")
        }
    }

    private func fetchDevices() async -> [SpotifyDevice] {
        await auth.refreshAccessTokenIfNeeded()
        guard let token = auth.accessToken else { return [] }
        var req = URLRequest(url: URL(string: "https://api.spotify.com/v1/me/player/devices")!)
        req.httpMethod = "GET"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse else { return [] }
            if http.statusCode != 200 {
                let msg = String(data: data, encoding: .utf8) ?? ""
                print("Spotify devices failed: \(http.statusCode) \(msg)")
                return []
            }
            let dto = try JSONDecoder().decode(SpotifyDevicesResponse.self, from: data)
            return dto.devices
        } catch {
            print("Spotify devices error: \(error)")
            return []
        }
    }

    private func pickDevice(_ devices: [SpotifyDevice]) -> SpotifyDevice? {
        // Prefer currently active and non-restricted device
        if let active = devices.first(where: { ($0.is_active ?? false) && !($0.is_restricted ?? false) }) {
            return active
        }
        // Otherwise pick first non-restricted device (phone/computer etc.)
        return devices.first(where: { !($0.is_restricted ?? false) })
    }

    private func transferPlayback(to deviceID: String, startPlaying: Bool) async -> Bool {
        await auth.refreshAccessTokenIfNeeded()
        guard let token = auth.accessToken else { return false }
        var req = URLRequest(url: URL(string: "https://api.spotify.com/v1/me/player")!)
        req.httpMethod = "PUT"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["device_ids": [deviceID], "play": startPlaying]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])
        do {
            let (_, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse else { return false }
            if (200...299).contains(http.statusCode) {
                return true
            } else {
                let msg = "transfer failed: \(http.statusCode)"
                print("Spotify \(msg)")
                return false
            }
        } catch {
            print("Spotify transfer error: \(error)")
            return false
        }
    }

    private func ensureActiveDevice(startPlaying: Bool) async -> String? {
        // If we have a remembered device, try to transfer to it
        var devices = await fetchDevices()
        if devices.isEmpty { return nil }
        let chosen = pickDevice(devices)
        guard let device = chosen, let id = device.id else { return nil }
        lastDeviceID = id
        // If not active, transfer playback to the device
        if !(device.is_active ?? false) {
            let ok = await transferPlayback(to: id, startPlaying: startPlaying)
            if !ok {
                // Re-fetch devices and try the first available
                devices = await fetchDevices()
                if let fallback = pickDevice(devices), let fid = fallback.id {
                    lastDeviceID = fid
                    _ = await transferPlayback(to: fid, startPlaying: startPlaying)
                    return fid
                }
                return nil
            }
        }
        return id
    }

    // MARK: - Controls
    func togglePlayPause() async {
        await auth.refreshAccessTokenIfNeeded()
        guard auth.accessToken != nil else { return }

        let startPlaying = !isPlaying
        guard let deviceId = await ensureActiveDevice(startPlaying: startPlaying) else {
            print("Spotify toggle failed: no active device")
            return
        }
        guard let token = auth.accessToken else { return }
        let endpoint = isPlaying ? "pause" : "play"
        var comps = URLComponents(string: "https://api.spotify.com/v1/me/player/\(endpoint)")!
        comps.queryItems = [URLQueryItem(name: "device_id", value: deviceId)]
        var req = URLRequest(url: comps.url!)
        req.httpMethod = "PUT"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        do {
            let (_, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse else { return }
            if (200...299).contains(http.statusCode) {
                isPlaying.toggle()
            } else if http.statusCode == 404 {
                // No active device: try transfer again and retry once
                if let dev = await ensureActiveDevice(startPlaying: startPlaying) {
                    var retryComps = URLComponents(string: "https://api.spotify.com/v1/me/player/\(endpoint)")!
                    retryComps.queryItems = [URLQueryItem(name: "device_id", value: dev)]
                    var retry = URLRequest(url: retryComps.url!)
                    retry.httpMethod = "PUT"
                    retry.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                    retry.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    let (_, rresp) = try await URLSession.shared.data(for: retry)
                    let rhttp = rresp as! HTTPURLResponse
                    if (200...299).contains(rhttp.statusCode) {
                        isPlaying.toggle()
                    } else {
                        print("Spotify \(endpoint) failed after retry: \(rhttp.statusCode)")
                    }
                } else {
                    print("Spotify \(endpoint) failed: 404 no device")
                }
            } else {
                print("Spotify \(endpoint) failed: \(http.statusCode)")
            }
        } catch {
            print("Spotify \(endpoint) error: \(error)")
        }
    }

    func stopPlayback() async {
        // Spotify does not have a distinct "stop"; we use pause.
        if isPlaying { await togglePlayPause() }
    }

    func loadPlaylists() async {
        await auth.refreshAccessTokenIfNeeded()
        guard let token = auth.accessToken else { return }
        var comps = URLComponents(string: "https://api.spotify.com/v1/me/playlists")!
        comps.queryItems = [URLQueryItem(name: "limit", value: "50")]
        var req = URLRequest(url: comps.url!)
        req.httpMethod = "GET"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse else { return }
            if http.statusCode != 200 {
                let msg = String(data: data, encoding: .utf8) ?? ""
                print("Spotify playlists failed: \(http.statusCode) \(msg)")
                return
            }
            let dto = try JSONDecoder().decode(SpotifyPlaylistsResponse.self, from: data)
            playlists = dto.items.map { SpotifyPlaylist(id: $0.id, name: $0.name, uri: $0.uri, tracksCount: $0.tracks.total) }
        } catch {
            print("Spotify playlists error: \(error)")
        }
    }

    func playPlaylist(_ playlist: SpotifyPlaylist) async {
        await auth.refreshAccessTokenIfNeeded()
        guard let token = auth.accessToken else { return }
        storedPlaylistURI = playlist.uri

        guard let deviceId = await ensureActiveDevice(startPlaying: true) else {
            print("Spotify play playlist failed: no active device")
            return
        }

        var comps = URLComponents(string: "https://api.spotify.com/v1/me/player/play")!
        comps.queryItems = [URLQueryItem(name: "device_id", value: deviceId)]
        var req = URLRequest(url: comps.url!)
        req.httpMethod = "PUT"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["context_uri": playlist.uri, "position_ms": 0]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])
        do {
            let (_, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse else { return }
            if (200...299).contains(http.statusCode) {
                isPlaying = true
                currentTitle = playlist.name
                currentArtist = ""
            } else if http.statusCode == 404 {
                // Try to activate a device and retry once
                if let dev = await ensureActiveDevice(startPlaying: true) {
                    var retryComps = URLComponents(string: "https://api.spotify.com/v1/me/player/play")!
                    retryComps.queryItems = [URLQueryItem(name: "device_id", value: dev)]
                    var retry = URLRequest(url: retryComps.url!)
                    retry.httpMethod = "PUT"
                    retry.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                    retry.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    retry.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])
                    let (_, rresp) = try await URLSession.shared.data(for: retry)
                    let rhttp = rresp as! HTTPURLResponse
                    if (200...299).contains(rhttp.statusCode) {
                        isPlaying = true
                        currentTitle = playlist.name
                        currentArtist = ""
                    } else {
                        print("Spotify play playlist failed after retry: \(rhttp.statusCode)")
                    }
                } else {
                    print("Spotify play playlist failed: 404 no device")
                }
            } else {
                print("Spotify play playlist failed: \(http.statusCode)")
            }
        } catch {
            print("Spotify play playlist error: \(error)")
        }
    }
}

// MARK: - DTOs
struct SpotifyPlaylist: Identifiable {
    let id: String
    let name: String
    let uri: String
    let tracksCount: Int
}

private struct SpotifyPlaylistsResponse: Decodable {
    struct Item: Decodable {
        let id: String
        let name: String
        let uri: String
        let tracks: Tracks
        struct Tracks: Decodable { let total: Int }
    }
    let items: [Item]
}

private struct SpotifyPlayerState: Decodable {
    struct Track: Decodable {
        struct Artist: Decodable { let name: String }
        let name: String
        let artists: [Artist]?
    }
    struct Device: Decodable {
        let id: String?
        let name: String?
        let is_active: Bool?
        let is_restricted: Bool?
        let type: String?
    }
    let is_playing: Bool?
    let item: Track?
    let device: Device?
}

private struct SpotifyDevicesResponse: Decodable {
    let devices: [SpotifyDevice]
}

private struct SpotifyDevice: Decodable {
    let id: String?
    let is_active: Bool?
    let is_restricted: Bool?
    let name: String?
    let type: String?
}

// MARK: - Notifications
extension Notification.Name {
    static let spotifyAuthStateChanged = Notification.Name("spotifyAuthStateChanged")
}


// MARK: - Playlist Picker UI
struct SpotifyPlaylistPickerView: View {
    @ObservedObject var spotifyVM: SpotifyViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(spotifyVM.playlists, id: \.id) { p in
                Button(action: {
                    Task { await spotifyVM.playPlaylist(p) }
                    dismiss()
                }) {
                    VStack(alignment: .leading) {
                        Text(p.name)
                            .foregroundColor(.taqvoTextDark)
                        Text("\(p.tracksCount) tracks")
                            .font(.caption)
                            .foregroundColor(.taqvoAccentText)
                    }
                }
                .listRowBackground(Color.black.opacity(0.08))
            }
            .navigationTitle("Choose Spotify Playlist")
            .onAppear {
                Task { await spotifyVM.loadPlaylists() }
            }
        }
    }
}