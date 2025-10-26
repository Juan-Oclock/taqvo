//
//  ProfileService.swift
//  Taqvo
//
//  Handles user profile data synchronization with Supabase.
//

import Foundation
import UIKit

struct UserProfile: Codable {
    let id: String
    var username: String?
    var avatarUrl: String?
    let createdAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case username
        case avatarUrl = "avatar_url"
        case createdAt = "created_at"
    }
}

@MainActor
final class ProfileService: ObservableObject {
    static let shared = ProfileService()
    
    @Published private(set) var currentProfile: UserProfile?
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var lastError: String?
    
    private let authManager = SupabaseAuthManager.shared
    private var profileCache: [String: UserProfile] = [:]
    
    private init() {}
    
    // MARK: - Current User Profile
    
    func loadCurrentUserProfile() async {
        guard let userId = authManager.userId else {
            print("DEBUG: No userId available, cannot load profile")
            currentProfile = nil
            return
        }
        
        print("DEBUG: Loading profile for userId: \(userId)")
        isLoading = true
        lastError = nil
        
        do {
            let profile = try await loadProfile(userId: userId)
            currentProfile = profile
            print("✅ SUCCESS: Profile loaded from database")
            print("DEBUG: ProfileService - Loaded currentProfile: \(String(describing: profile))")
            print("DEBUG: ProfileService - Loaded username: \(String(describing: profile.username))")
            print("DEBUG: ProfileService - Loaded avatarUrl: \(String(describing: profile.avatarUrl))")
        } catch {
            lastError = error.localizedDescription
            print("❌ ERROR: Failed to load current user profile: \(error)")
        }
        
        isLoading = false
    }
    
    func updateCurrentUserProfile(username: String?, profileImage: UIImage?) async throws {
        guard let userId = authManager.userId else {
            throw NSError(domain: "ProfileService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        print("DEBUG: Starting profile update - UserID: \(userId)")
        print("DEBUG: Username: \(username ?? "nil"), Has Image: \(profileImage != nil)")
        
        isLoading = true
        lastError = nil
        
        do {
            // Upload image if provided (but don't fail if upload fails)
            var avatarUrl: String? = currentProfile?.avatarUrl
            if let image = profileImage {
                print("DEBUG: Uploading profile image...")
                do {
                    avatarUrl = try await uploadProfileImage(image: image, userId: userId)
                    print("DEBUG: Image uploaded successfully - URL: \(avatarUrl ?? "nil")")
                } catch {
                    print("⚠️ WARNING: Image upload failed (will save username anyway): \(error)")
                    // Keep existing avatar URL if upload fails
                    avatarUrl = currentProfile?.avatarUrl
                }
            }
            
            // Update profile (this should succeed even if image upload failed)
            print("DEBUG: Updating profile in database...")
            let updatedProfile = try await updateProfile(
                userId: userId,
                username: username,
                avatarUrl: avatarUrl
            )
            
            currentProfile = updatedProfile
            profileCache[userId] = updatedProfile
            print("✅ SUCCESS: Profile saved to database")
            print("DEBUG: ProfileService - Updated currentProfile: \(String(describing: updatedProfile))")
            print("DEBUG: ProfileService - Username: \(String(describing: updatedProfile.username))")
            print("DEBUG: ProfileService - AvatarUrl: \(String(describing: updatedProfile.avatarUrl))")
        } catch {
            print("❌ ERROR: Failed to save profile: \(error)")
            lastError = error.localizedDescription
            throw error
        }
        
        isLoading = false
    }
    
    // MARK: - Profile Loading (for comments, etc.)
    
    func loadProfile(userId: String) async throws -> UserProfile {
        // Check cache first
        if let cachedProfile = profileCache[userId] {
            return cachedProfile
        }
        
        guard let info = Bundle.main.infoDictionary,
              let urlString = info["SUPABASE_URL"] as? String,
              let anon = info["SUPABASE_ANON_KEY"] as? String,
              let baseURL = URL(string: urlString) else {
            throw NSError(domain: "ProfileService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Missing Supabase configuration"])
        }
        
        let url = baseURL.appendingPathComponent("/rest/v1/profiles")
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "id", value: "eq.\(userId)"),
            URLQueryItem(name: "select", value: "id,username,avatar_url,created_at")
        ]
        
        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anon, forHTTPHeaderField: "apikey")
        
        // Add auth header if available
        if let token = await authManager.getValidAccessToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else {
            request.setValue("Bearer \(anon)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "ProfileService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        
        if httpResponse.statusCode == 404 || httpResponse.statusCode == 200 {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let profiles = try decoder.decode([UserProfile].self, from: data)
            
            if let profile = profiles.first {
                profileCache[userId] = profile
                return profile
            } else {
                // Profile doesn't exist, create a default one
                let defaultProfile = UserProfile(
                    id: userId,
                    username: nil,
                    avatarUrl: nil,
                    createdAt: Date()
                )
                profileCache[userId] = defaultProfile
                return defaultProfile
            }
        } else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "ProfileService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to load profile: \(errorMessage)"])
        }
    }
    
    // MARK: - Profile Updates
    
    private func updateProfile(userId: String, username: String?, avatarUrl: String?) async throws -> UserProfile {
        guard let info = Bundle.main.infoDictionary,
              let urlString = info["SUPABASE_URL"] as? String,
              let anon = info["SUPABASE_ANON_KEY"] as? String,
              let baseURL = URL(string: urlString) else {
            throw NSError(domain: "ProfileService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Missing Supabase configuration"])
        }
        
        guard let token = await authManager.getValidAccessToken() else {
            throw NSError(domain: "ProfileService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Authentication required"])
        }
        
        // Use UPSERT (POST with Prefer: resolution=merge-duplicates) to create or update
        let url = baseURL.appendingPathComponent("/rest/v1/profiles")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anon, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        // Use Prefer header for UPSERT behavior (insert or update if exists)
        request.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        
        let profileData: [String: Any?] = [
            "id": userId,
            "username": username,
            "avatar_url": avatarUrl
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: profileData.compactMapValues { $0 })
        
        print("DEBUG: Upserting profile - URL: \(url)")
        print("DEBUG: Profile data: \(profileData.compactMapValues { $0 })")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "ProfileService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        
        print("DEBUG: Profile upsert response status: \(httpResponse.statusCode)")
        print("DEBUG: Profile upsert response: \(String(data: data, encoding: .utf8) ?? "No data")")
        
        if !(200...299).contains(httpResponse.statusCode) {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "ProfileService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to update profile: \(errorMessage)"])
        }
        
        // Return updated profile
        let updatedProfile = UserProfile(
            id: userId,
            username: username,
            avatarUrl: avatarUrl,
            createdAt: currentProfile?.createdAt ?? Date()
        )
        
        return updatedProfile
    }
    
    // MARK: - Image Upload
    
    private func uploadProfileImage(image: UIImage, userId: String) async throws -> String {
        guard let info = Bundle.main.infoDictionary,
              let urlString = info["SUPABASE_URL"] as? String,
              let anon = info["SUPABASE_ANON_KEY"] as? String,
              let baseURL = URL(string: urlString) else {
            throw NSError(domain: "ProfileService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Missing Supabase configuration"])
        }
        
        guard let token = await authManager.getValidAccessToken() else {
            throw NSError(domain: "ProfileService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Authentication required"])
        }
        
        guard let imageData = image.compressForAvatar() else {
            throw NSError(domain: "ProfileService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Failed to process image"])
        }
        
        print("📸 Avatar compressed: \(String(format: "%.1f", ImageCompressor.sizeInKB(imageData))) KB")
        
        let bucket = "avatars"
        let filename = "avatar-\(userId)-\(Int(Date().timeIntervalSince1970)).jpg"
        let storageURL = baseURL.appendingPathComponent("/storage/v1/object/\(bucket)/\(userId)/\(filename)")
        var request = URLRequest(url: storageURL)
        request.httpMethod = "POST"
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        request.setValue(anon, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = imageData
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "Unknown error"
            let code = (response as? HTTPURLResponse)?.statusCode ?? 500
            throw NSError(domain: "ProfileService", code: code, userInfo: [NSLocalizedDescriptionKey: "Failed to upload image: \(msg)"])
        }
        
        // Construct public URL
        let publicURL = "\(urlString)/storage/v1/object/public/\(bucket)/\(userId)/\(filename)"
        print("✅ Avatar uploaded: \(publicURL)")
        
        return publicURL
    }
    
    // MARK: - Challenge Image Upload
    
    func uploadChallengeImage(_ image: UIImage, challengeId: UUID) async throws -> String {
        guard let info = Bundle.main.infoDictionary,
              let urlString = info["SUPABASE_URL"] as? String,
              let anon = info["SUPABASE_ANON_KEY"] as? String,
              let baseURL = URL(string: urlString) else {
            throw NSError(domain: "ProfileService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Missing Supabase configuration"])
        }
        
        guard let token = await authManager.getValidAccessToken() else {
            throw NSError(domain: "ProfileService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Authentication required"])
        }
        
        guard let imageData = image.compressForActivity() else {
            throw NSError(domain: "ProfileService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Failed to process image"])
        }
        
        print("📸 Challenge image compressed: \(String(format: "%.1f", ImageCompressor.sizeInKB(imageData))) KB")
        
        let bucket = "Challenges"  // Match the bucket name exactly (case-sensitive)
        let filename = "challenge-\(challengeId.uuidString)-\(Int(Date().timeIntervalSince1970)).jpg"
        let storageURL = baseURL.appendingPathComponent("/storage/v1/object/\(bucket)/\(filename)")
        var request = URLRequest(url: storageURL)
        request.httpMethod = "POST"
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        request.setValue(anon, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = imageData
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "Unknown error"
            let code = (response as? HTTPURLResponse)?.statusCode ?? 500
            throw NSError(domain: "ProfileService", code: code, userInfo: [NSLocalizedDescriptionKey: "Failed to upload challenge image: \(msg)"])
        }
        
        // Construct public URL
        let publicURL = "\(urlString)/storage/v1/object/public/\(bucket)/\(filename)"
        print("✅ Challenge image uploaded: \(publicURL)")
        
        return publicURL
    }
    
    func getCachedProfile(userId: String) -> UserProfile? {
        return profileCache[userId]
    }
}