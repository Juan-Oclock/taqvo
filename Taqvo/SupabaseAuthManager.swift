//
//  SupabaseAuthManager.swift
//  Taqvo
//
//  Handles Supabase Auth using Sign in with Apple and provides JWT for RLS writes.
//

import Foundation
import AuthenticationServices
import CryptoKit
import UIKit

extension Notification.Name {
    static let supabaseAuthStateChanged = Notification.Name("supabaseAuthStateChanged")
}

@MainActor
final class SupabaseAuthManager: NSObject, ObservableObject {
    static let shared = SupabaseAuthManager()

    @Published private(set) var isAuthenticated: Bool = false
    @Published private(set) var accessToken: String?
    @Published private(set) var userId: String?
    @Published private(set) var tokenExpiry: Date?
    @Published private(set) var refreshToken: String?
    @Published var lastAuthError: String?

    private var currentNonce: String?

    private override init() {
        super.init()
        loadStoredSession()
    }

    // MARK: - Public API
    func signInWithApple() {
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        // Create a random nonce and pass its SHA256 to the request (recommended by Apple)
        let nonce = Self.randomString(length: 32)
        currentNonce = nonce
        request.nonce = Self.sha256(nonce)
        request.requestedScopes = []

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    func signOut() {
        accessToken = nil
        userId = nil
        tokenExpiry = nil
        refreshToken = nil
        isAuthenticated = false
        let d = UserDefaults.standard
        d.removeObject(forKey: "supabase_access_token")
        d.removeObject(forKey: "supabase_user_id")
        d.removeObject(forKey: "supabase_token_expiry")
        d.removeObject(forKey: "supabase_refresh_token")
        NotificationCenter.default.post(name: .supabaseAuthStateChanged, object: nil)
    }

    // MARK: - Session Storage
    private func loadStoredSession() {
        let d = UserDefaults.standard
        if let at = d.string(forKey: "supabase_access_token"), !at.isEmpty {
            accessToken = at
            isAuthenticated = true
        }
        if let uid = d.string(forKey: "supabase_user_id"), !uid.isEmpty {
            userId = uid
        }
        if let rt = d.string(forKey: "supabase_refresh_token"), !rt.isEmpty {
            refreshToken = rt
        }
        let expiry = d.double(forKey: "supabase_token_expiry")
        if expiry > 0 {
            tokenExpiry = Date(timeIntervalSince1970: expiry)
        }
    }

    private func persistSession() {
        let d = UserDefaults.standard
        d.set(accessToken ?? "", forKey: "supabase_access_token")
        d.set(userId ?? "", forKey: "supabase_user_id")
        d.set(tokenExpiry?.timeIntervalSince1970 ?? 0, forKey: "supabase_token_expiry")
        d.set(refreshToken ?? "", forKey: "supabase_refresh_token")
    }
}

// MARK: - Apple Sign-In Delegate
extension SupabaseAuthManager: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else { return }
        guard let identityTokenData = credential.identityToken,
              let identityToken = String(data: identityTokenData, encoding: .utf8) else {
            print("Sign in with Apple missing identity token")
            lastAuthError = "Sign in with Apple missing identity token"
            return
        }
        let nonce = currentNonce ?? ""
        Task { await exchangeAppleIDTokenForSupabaseSession(idToken: identityToken, nonce: nonce) }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        print("Sign in with Apple error: \(error)")
        lastAuthError = error.localizedDescription
    }
}

// MARK: - Presentation Context
extension SupabaseAuthManager: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let win = scene.keyWindow ?? scene.windows.first {
            return win
        }
        return ASPresentationAnchor()
    }
}

// MARK: - Supabase Token Exchange
extension SupabaseAuthManager {
    private func exchangeAppleIDTokenForSupabaseSession(idToken: String, nonce: String) async {
        guard let info = Bundle.main.infoDictionary,
              let urlString = info["SUPABASE_URL"] as? String,
              let anon = info["SUPABASE_ANON_KEY"] as? String,
              let url = URL(string: urlString)?.appendingPathComponent("/auth/v1/token") else {
            print("Missing SUPABASE_URL or SUPABASE_ANON_KEY in Info.plist")
            lastAuthError = "Missing SUPABASE_URL or SUPABASE_ANON_KEY in Info.plist"
            return
        }
        var comps = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        comps.queryItems = [URLQueryItem(name: "grant_type", value: "id_token")]
        var req = URLRequest(url: comps.url!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(anon, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(anon)", forHTTPHeaderField: "Authorization")
        let clientID = Bundle.main.bundleIdentifier ?? ""
        let body: [String: Any] = [
            "provider": "apple",
            "id_token": idToken,
            "nonce": nonce,
            "client_id": clientID
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])

        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse else { return }
            if !(200...299).contains(http.statusCode) {
                let msg = String(data: data, encoding: .utf8) ?? ""
                print("Supabase token exchange failed: \(http.statusCode) \(msg)")
                lastAuthError = "Supabase token exchange failed: \(http.statusCode) \(msg)"
                isAuthenticated = false
                return
            }
            let session = try JSONDecoder().decode(SupabaseSessionResponse.self, from: data)
            self.accessToken = session.access_token
            self.userId = session.user?.id
            if let expiresIn = session.expires_in {
                self.tokenExpiry = Date().addingTimeInterval(TimeInterval(expiresIn))
            }
            if let rt = session.refresh_token, !rt.isEmpty {
                self.refreshToken = rt
            }
            self.isAuthenticated = (self.accessToken != nil)
            self.lastAuthError = nil
            self.persistSession()
            NotificationCenter.default.post(name: .supabaseAuthStateChanged, object: nil)
        } catch {
            print("Supabase exchange error: \(error)")
            lastAuthError = error.localizedDescription
        }
    }
}

// MARK: - DTOs
private struct SupabaseSessionResponse: Decodable {
    let access_token: String
    let token_type: String?
    let expires_in: Int?
    let refresh_token: String?
    let user: SupabaseUser?
}

private struct SupabaseUser: Decodable {
    let id: String
    let email: String?
}

// MARK: - Helpers
extension SupabaseAuthManager {
    private static func randomString(length: Int) -> String {
        let charset: Array<Character> = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz")
        var result = ""
        var remaining = length
        while remaining > 0 {
            let randoms: [UInt8] = (0 ..< 16).map { _ in
                var rnd: UInt8 = 0
                let err = SecRandomCopyBytes(kSecRandomDefault, 1, &rnd)
                if err != errSecSuccess { rnd = UInt8.random(in: 0...255) }
                return rnd
            }
            randoms.forEach { r in
                if remaining == 0 { return }
                result.append(charset[Int(r) % charset.count])
                remaining -= 1
            }
        }
        return result
    }

    private static func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let hashed = SHA256.hash(data: data)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Supabase Token Refresh
extension SupabaseAuthManager {
    /// Returns a valid access token, attempting a refresh if the token is expired or close to expiry.
    func getValidAccessToken() async -> String? {
        // If token is valid for at least 30s, reuse it
        if let exp = tokenExpiry, exp.timeIntervalSinceNow > 30, let token = accessToken, !token.isEmpty {
            return token
        }
        // If we have no token, nothing to return
        guard accessToken != nil else { return nil }
        // Try to refresh using refresh token
        let refreshed = await refreshAccessToken()
        if refreshed { return accessToken }
        // Refresh failed — clear stale token so callers fall back to anon
        accessToken = nil
        isAuthenticated = false
        persistSession()
        NotificationCenter.default.post(name: .supabaseAuthStateChanged, object: nil)
        return nil
    }

    /// Refresh the Supabase session using the stored refresh token.
    /// - Returns: true if refresh succeeded and accessToken was updated.
    func refreshAccessToken() async -> Bool {
        guard let rt = refreshToken, !rt.isEmpty else { return false }
        guard let info = Bundle.main.infoDictionary,
              let urlString = info["SUPABASE_URL"] as? String,
              let anon = info["SUPABASE_ANON_KEY"] as? String,
              let url = URL(string: urlString)?.appendingPathComponent("/auth/v1/token") else { return false }
        var comps = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        comps.queryItems = [URLQueryItem(name: "grant_type", value: "refresh_token")]
        var req = URLRequest(url: comps.url!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(anon, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(anon)", forHTTPHeaderField: "Authorization")
        let body: [String: Any] = ["refresh_token": rt]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return false
            }
            let session = try JSONDecoder().decode(SupabaseSessionResponse.self, from: data)
            self.accessToken = session.access_token
            if let expiresIn = session.expires_in { self.tokenExpiry = Date().addingTimeInterval(TimeInterval(expiresIn)) }
            if let newRT = session.refresh_token, !newRT.isEmpty { self.refreshToken = newRT }
            self.isAuthenticated = (self.accessToken != nil)
            self.persistSession()
            NotificationCenter.default.post(name: .supabaseAuthStateChanged, object: nil)
            return true
        } catch {
            return false
        }
    }
}