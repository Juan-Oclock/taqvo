//
//  SpotifyAuthManager.swift
//  Taqvo
//
//  Handles Spotify OAuth using PKCE and provides access tokens.
//

import Foundation
import SwiftUI
import AuthenticationServices
import CryptoKit
import UIKit

@MainActor
final class SpotifyAuthManager: NSObject, ObservableObject {
    static let shared = SpotifyAuthManager()

    // MARK: - Config (replace placeholders during setup)
    // Set your registered values from https://developer.spotify.com/dashboard
    private let clientID: String = "593743d854b348558f5341b06368d1a7"
    private let redirectURI: String = "taqvo://spotify-callback"
    private let scopes: [String] = [
        "user-read-playback-state",
        "user-modify-playback-state",
        "playlist-read-private"
    ]

    // MARK: - Published state
    @Published private(set) var isAuthorized: Bool = false
    @Published private(set) var accessToken: String?
    @Published private(set) var refreshToken: String?
    @Published private(set) var tokenExpiry: Date?

    // MARK: - Internal auth state
    private var codeVerifier: String?
    private var state: String?
    private var session: ASWebAuthenticationSession?

    private override init() {
        super.init()
        loadStoredTokens()
    }

    // MARK: - Public API
    func startAuthorization() {
        // Generate PKCE values
        let verifier = Self.randomString(length: 64)
        let challenge = Self.codeChallenge(for: verifier)
        let state = Self.randomString(length: 16)

        self.codeVerifier = verifier
        self.state = state

        // Build authorize URL
        var comps = URLComponents(string: "https://accounts.spotify.com/authorize")!
        let scopeString = scopes.joined(separator: " ")
        comps.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "scope", value: scopeString),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "code_challenge", value: challenge)
        ]

        guard let url = comps.url else { return }

        // Present ASWebAuthenticationSession
        let session = ASWebAuthenticationSession(url: url, callbackURLScheme: URL(string: redirectURI)?.scheme) { [weak self] callbackURL, error in
            guard let self else { return }
            if let error = error {
                print("Spotify auth error: \(error)")
                return
            }
            guard let url = callbackURL else { return }
            self.handleCallbackURL(url)
        }
        session.presentationContextProvider = self
        session.prefersEphemeralWebBrowserSession = true
        self.session = session
        session.start()
    }

    func handleCallbackURL(_ url: URL) {
        guard let comps = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }
        var code: String?
        var returnedState: String?
        var errorParam: String?
        comps.queryItems?.forEach { item in
            switch item.name {
            case "code": code = item.value
            case "state": returnedState = item.value
            case "error": errorParam = item.value
            default: break
            }
        }

        if let e = errorParam {
            print("Spotify auth returned error: \(e)")
            return
        }
        guard let code, let expectedState = state, returnedState == expectedState else {
            print("Spotify auth state mismatch or missing code")
            return
        }
        Task { await exchangeCodeForToken(code: code) }
    }

    func signOut() {
        accessToken = nil
        refreshToken = nil
        tokenExpiry = nil
        isAuthorized = false
        UserDefaults.standard.removeObject(forKey: "spotify_access_token")
        UserDefaults.standard.removeObject(forKey: "spotify_refresh_token")
        UserDefaults.standard.removeObject(forKey: "spotify_token_expiry")
        NotificationCenter.default.post(name: .spotifyAuthStateChanged, object: nil)
    }

    // MARK: - Token exchange & refresh
    private func exchangeCodeForToken(code: String) async {
        guard let verifier = codeVerifier else { return }
        var req = URLRequest(url: URL(string: "https://accounts.spotify.com/api/token")!)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        var body = URLComponents()
        body.queryItems = [
            URLQueryItem(name: "grant_type", value: "authorization_code"),
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "code_verifier", value: verifier)
        ]
        req.httpBody = body.percentEncodedQuery?.data(using: .utf8)

        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse else { return }
            if http.statusCode != 200 {
                let msg = String(data: data, encoding: .utf8) ?? ""
                print("Spotify token exchange failed: \(http.statusCode) \(msg)")
                return
            }
            let tok = try JSONDecoder().decode(SpotifyTokenResponse.self, from: data)
            self.accessToken = tok.access_token
            self.refreshToken = tok.refresh_token
            self.tokenExpiry = Date().addingTimeInterval(TimeInterval(tok.expires_in))
            self.isAuthorized = true
            persistTokens()
            NotificationCenter.default.post(name: .spotifyAuthStateChanged, object: nil)
        } catch {
            print("Spotify token exchange error: \(error)")
        }
    }

    func refreshAccessTokenIfNeeded() async {
        guard let expiry = tokenExpiry, let refresh = refreshToken else { return }
        if Date() < expiry.addingTimeInterval(-300) { return } // refresh 5m early
        await refreshAccessToken(refreshToken: refresh)
    }

    private func refreshAccessToken(refreshToken: String) async {
        var req = URLRequest(url: URL(string: "https://accounts.spotify.com/api/token")!)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        var body = URLComponents()
        body.queryItems = [
            URLQueryItem(name: "grant_type", value: "refresh_token"),
            URLQueryItem(name: "refresh_token", value: refreshToken),
            URLQueryItem(name: "client_id", value: clientID)
        ]
        req.httpBody = body.percentEncodedQuery?.data(using: .utf8)

        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse else { return }
            if http.statusCode != 200 {
                let msg = String(data: data, encoding: .utf8) ?? ""
                print("Spotify token refresh failed: \(http.statusCode) \(msg)")
                return
            }
            let tok = try JSONDecoder().decode(SpotifyTokenRefreshResponse.self, from: data)
            self.accessToken = tok.access_token
            self.tokenExpiry = Date().addingTimeInterval(TimeInterval(tok.expires_in))
            self.isAuthorized = true
            persistTokens(accessOnly: true)
            NotificationCenter.default.post(name: .spotifyAuthStateChanged, object: nil)
        } catch {
            print("Spotify token refresh error: \(error)")
        }
    }

    // MARK: - Storage
    private func loadStoredTokens() {
        let defaults = UserDefaults.standard
        if let at = defaults.string(forKey: "spotify_access_token") {
            accessToken = at
            isAuthorized = true
        }
        if let rt = defaults.string(forKey: "spotify_refresh_token") {
            refreshToken = rt
        }
        if let expiryInterval = defaults.double(forKey: "spotify_token_expiry") as Double?, expiryInterval > 0 {
            tokenExpiry = Date(timeIntervalSince1970: expiryInterval)
        }
    }

    private func persistTokens(accessOnly: Bool = false) {
        let defaults = UserDefaults.standard
        if let at = accessToken {
            defaults.set(at, forKey: "spotify_access_token")
        }
        if !accessOnly, let rt = refreshToken {
            defaults.set(rt, forKey: "spotify_refresh_token")
        }
        if let exp = tokenExpiry?.timeIntervalSince1970 {
            defaults.set(exp, forKey: "spotify_token_expiry")
        }
    }

    // MARK: - Helpers
    private static func randomString(length: Int) -> String {
        let chars = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        var str = ""
        for _ in 0..<length { str.append(chars.randomElement()!) }
        return str
    }

    private static func codeChallenge(for verifier: String) -> String {
        let data = Data(verifier.utf8)
        let hash = SHA256.hash(data: data)
        let challenge = Data(hash).base64EncodedString()
        return challenge
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

// MARK: - Token DTOs
private struct SpotifyTokenResponse: Decodable {
    let access_token: String
    let token_type: String
    let expires_in: Int
    let refresh_token: String?
    let scope: String
}

private struct SpotifyTokenRefreshResponse: Decodable {
    let access_token: String
    let token_type: String
    let expires_in: Int
    let scope: String?
}

// MARK: - ASWebAuthenticationSession Context Provider
extension SpotifyAuthManager: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // Attempt to return the key window
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let win = scene.keyWindow ?? scene.windows.first {
            return win
        }
        return ASPresentationAnchor()
    }
}