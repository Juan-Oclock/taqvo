//
//  ActivityStore.swift
//  Taqvo
//
//  Implements persistent storage for completed activities shown in Feed.
//

import Foundation
import SwiftUI
import MapKit
import CoreLocation

struct Coordinate: Codable {
    let latitude: Double
    let longitude: Double
}

struct ActivityComment: Identifiable, Codable {
    let id: UUID
    let author: String
    let text: String
    let date: Date
}

struct FeedActivity: Identifiable, Codable {
    let id: UUID
    let distanceMeters: Double
    let durationSeconds: Double
    let route: [Coordinate]
    let startDate: Date
    let endDate: Date
    let snapshotPNG: Data?
    let note: String?
    let photoPNG: Data?
    var likeCount: Int
    var isLiked: Bool
    var comments: [ActivityComment]
    let kind: ActivityKind
    let caloriesKilocalories: Double
    let averageHeartRateBPM: Double?
    let splitsSeconds: [Double]?
    // Challenge context
    let challengeTitle: String?
    let challengeIsPublic: Bool?

    enum CodingKeys: String, CodingKey {
        case id, distanceMeters, durationSeconds, route, startDate, endDate, snapshotPNG, note, photoPNG, likeCount, isLiked, comments, kind, caloriesKilocalories, averageHeartRateBPM, splitsSeconds, challengeTitle, challengeIsPublic
    }

    init(id: UUID,
         distanceMeters: Double,
         durationSeconds: Double,
         route: [Coordinate],
         startDate: Date,
         endDate: Date,
         snapshotPNG: Data?,
         note: String?,
         photoPNG: Data?,
         likeCount: Int = 0,
         isLiked: Bool = false,
         comments: [ActivityComment] = [],
         kind: ActivityKind,
         caloriesKilocalories: Double,
         averageHeartRateBPM: Double? = nil,
         splitsSeconds: [Double]? = nil,
         challengeTitle: String? = nil,
         challengeIsPublic: Bool? = nil) {
        self.id = id
        self.distanceMeters = distanceMeters
        self.durationSeconds = durationSeconds
        self.route = route
        self.startDate = startDate
        self.endDate = endDate
        self.snapshotPNG = snapshotPNG
        self.note = note
        self.photoPNG = photoPNG
        self.likeCount = likeCount
        self.isLiked = isLiked
        self.comments = comments
        self.kind = kind
        self.caloriesKilocalories = caloriesKilocalories
        self.averageHeartRateBPM = averageHeartRateBPM
        self.splitsSeconds = splitsSeconds
        self.challengeTitle = challengeTitle
        self.challengeIsPublic = challengeIsPublic
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        distanceMeters = try c.decode(Double.self, forKey: .distanceMeters)
        durationSeconds = try c.decode(Double.self, forKey: .durationSeconds)
        route = try c.decode([Coordinate].self, forKey: .route)
        startDate = try c.decode(Date.self, forKey: .startDate)
        endDate = try c.decode(Date.self, forKey: .endDate)
        snapshotPNG = try c.decodeIfPresent(Data.self, forKey: .snapshotPNG)
        note = try c.decodeIfPresent(String.self, forKey: .note)
        photoPNG = try c.decodeIfPresent(Data.self, forKey: .photoPNG)
        likeCount = try c.decodeIfPresent(Int.self, forKey: .likeCount) ?? 0
        isLiked = try c.decodeIfPresent(Bool.self, forKey: .isLiked) ?? false
        comments = try c.decodeIfPresent([ActivityComment].self, forKey: .comments) ?? []
        kind = try c.decodeIfPresent(ActivityKind.self, forKey: .kind) ?? .run
        caloriesKilocalories = try c.decodeIfPresent(Double.self, forKey: .caloriesKilocalories) ?? 0
        averageHeartRateBPM = try c.decodeIfPresent(Double.self, forKey: .averageHeartRateBPM)
        splitsSeconds = try c.decodeIfPresent([Double].self, forKey: .splitsSeconds)
        challengeTitle = try c.decodeIfPresent(String.self, forKey: .challengeTitle)
        challengeIsPublic = try c.decodeIfPresent(Bool.self, forKey: .challengeIsPublic)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(distanceMeters, forKey: .distanceMeters)
        try c.encode(durationSeconds, forKey: .durationSeconds)
        try c.encode(route, forKey: .route)
        try c.encode(startDate, forKey: .startDate)
        try c.encode(endDate, forKey: .endDate)
        try c.encodeIfPresent(snapshotPNG, forKey: .snapshotPNG)
        try c.encodeIfPresent(note, forKey: .note)
        try c.encodeIfPresent(photoPNG, forKey: .photoPNG)
        try c.encode(likeCount, forKey: .likeCount)
        try c.encode(isLiked, forKey: .isLiked)
        try c.encode(comments, forKey: .comments)
        try c.encode(kind, forKey: .kind)
        try c.encode(caloriesKilocalories, forKey: .caloriesKilocalories)
        try c.encodeIfPresent(averageHeartRateBPM, forKey: .averageHeartRateBPM)
        try c.encodeIfPresent(splitsSeconds, forKey: .splitsSeconds)
        try c.encodeIfPresent(challengeTitle, forKey: .challengeTitle)
        try c.encodeIfPresent(challengeIsPublic, forKey: .challengeIsPublic)
    }
}

final class ActivityStore: ObservableObject {
    @Published private(set) var activities: [FeedActivity] = []

    private let fileURL: URL
    private let queue = DispatchQueue(label: "ActivityStoreQueue")

    init() {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        fileURL = dir.appendingPathComponent("activities.json")
        load()
    }

    private static func computeSplits(from samples: [RouteSample], totalDistanceMeters: Double, totalDurationSeconds: Double) -> [Double] {
        guard totalDistanceMeters > 0, totalDurationSeconds > 0 else { return [] }
        guard samples.count > 1 else {
            // Fallback to coarse average: allocate time proportionally by distance
            let secPerMeter = totalDurationSeconds / totalDistanceMeters
            var result: [Double] = []
            var remainingMeters = totalDistanceMeters
            while remainingMeters >= 1000.0 {
                result.append(secPerMeter * 1000.0)
                remainingMeters -= 1000.0
            }
            if remainingMeters > 1 { result.append(secPerMeter * remainingMeters) }
            return result
        }
        var result: [Double] = []
        var kmAccumDistance: Double = 0
        var kmAccumTime: Double = 0
        for i in 1..<samples.count {
            let a = samples[i-1]
            let b = samples[i]
            let locA = CLLocation(latitude: a.latitude, longitude: a.longitude)
            let locB = CLLocation(latitude: b.latitude, longitude: b.longitude)
            let d = max(0, locB.distance(from: locA))
            let dt = max(0, b.timestamp.timeIntervalSince(a.timestamp))
            if d == 0 {
                kmAccumTime += dt
                continue
            }
            var distRemaining = d
            var timeRemaining = dt
            while kmAccumDistance + distRemaining >= 1000.0 {
                let need = 1000.0 - kmAccumDistance
                let frac = need / distRemaining
                let timeForNeed = timeRemaining * frac
                kmAccumTime += timeForNeed
                result.append(kmAccumTime)
                // advance
                distRemaining -= need
                timeRemaining -= timeForNeed
                kmAccumDistance = 0
                kmAccumTime = 0
            }
            kmAccumDistance += distRemaining
            kmAccumTime += timeRemaining
        }
        if kmAccumDistance > 1 || kmAccumTime > 0.1 {
            result.append(kmAccumTime)
        }
        return result
    }

    func add(summary: ActivitySummary, snapshot: UIImage?, note: String? = nil, photo: UIImage? = nil, avgHeartRateBPM: Double? = nil) {
        let coords = summary.route.map { Coordinate(latitude: $0.latitude, longitude: $0.longitude) }
        let splits = ActivityStore.computeSplits(from: summary.routeSamples, totalDistanceMeters: summary.distanceMeters, totalDurationSeconds: summary.durationSeconds)
        let activity = FeedActivity(
            id: UUID(),
            distanceMeters: summary.distanceMeters,
            durationSeconds: summary.durationSeconds,
            route: coords,
            startDate: summary.startDate,
            endDate: summary.endDate,
            snapshotPNG: snapshot?.pngData(),
            note: note,
            photoPNG: photo?.pngData(),
            likeCount: 0,
            isLiked: false,
            comments: [],
            kind: summary.kind,
            caloriesKilocalories: summary.caloriesKilocalories,
            averageHeartRateBPM: avgHeartRateBPM,
            splitsSeconds: splits,
            challengeTitle: summary.linkedChallengeTitle,
            challengeIsPublic: summary.linkedChallengeIsPublic
        )
        activities.insert(activity, at: 0)
        save()
    }

    func save() {
        let activitiesCopy = activities
        queue.async { [fileURL] in
            do {
                let data = try JSONEncoder().encode(activitiesCopy)
                try data.write(to: fileURL, options: [.atomic])
            } catch {
                print("ActivityStore save error: \(error)")
            }
        }
    }

    func load() {
        queue.async { [weak self] in
            guard let self = self else { return }
            do {
                if FileManager.default.fileExists(atPath: self.fileURL.path) {
                    let data = try Data(contentsOf: self.fileURL)
                    let decoded = try JSONDecoder().decode([FeedActivity].self, from: data)
                    DispatchQueue.main.async { self.activities = decoded }
                }
            } catch {
                print("ActivityStore load error: \(error)")
            }
        }
    }

    static func clCoordinates(from coords: [Coordinate]) -> [CLLocationCoordinate2D] {
        coords.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
    }

    func delete(activity: FeedActivity) {
        activities.removeAll { $0.id == activity.id }
        save()
    }

    func toggleLike(activityID: UUID) {
        guard let idx = activities.firstIndex(where: { $0.id == activityID }) else { return }
        var a = activities[idx]
        if a.isLiked {
            a.isLiked = false
            if a.likeCount > 0 { a.likeCount -= 1 }
        } else {
            a.isLiked = true
            a.likeCount += 1
        }
        activities[idx] = a
        save()
    }

    func addComment(activityID: UUID, text: String, author: String = "You") {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let idx = activities.firstIndex(where: { $0.id == activityID }) else { return }
        var a = activities[idx]
        let comment = ActivityComment(id: UUID(), author: author, text: trimmed, date: Date())
        a.comments.append(comment)
        activities[idx] = a
        save()
    }
}

struct WeeklySummary: Identifiable {
    let id: Date
    let weekStart: Date
    var totalDistanceMeters: Double
    var totalDurationSeconds: Double
    var longestRunMeters: Double
    var longestRunDurationSeconds: Double
    var totalCaloriesKilocalories: Double

    var averagePaceString: String {
        ActivityTrackingViewModel.formattedPace(distanceMeters: totalDistanceMeters, durationSeconds: totalDurationSeconds)
    }
}
struct DailySummary: Identifiable {
    let id: Date
    let dayStart: Date
    var totalDistanceMeters: Double
    var totalDurationSeconds: Double
    var runCount: Int
    var longestRunMeters: Double
    var longestRunDurationSeconds: Double
    var totalCaloriesKilocalories: Double

    var averagePaceString: String {
        ActivityTrackingViewModel.formattedPace(distanceMeters: totalDistanceMeters, durationSeconds: totalDurationSeconds)
    }
}

struct MonthlySummary: Identifiable {
    let id: Date
    let monthStart: Date
    var totalDistanceMeters: Double
    var totalDurationSeconds: Double
    var runCount: Int
    var longestRunMeters: Double
    var longestRunDurationSeconds: Double
    var totalCaloriesKilocalories: Double

    var averagePaceString: String {
        ActivityTrackingViewModel.formattedPace(distanceMeters: totalDistanceMeters, durationSeconds: totalDurationSeconds)
    }
}

extension ActivityStore {
    func dailySummaries(using calendar: Calendar = Calendar(identifier: .iso8601)) -> [DailySummary] {
        guard !activities.isEmpty else { return [] }
        var bucket: [Date: DailySummary] = [:]

        for a in activities {
            let day = calendar.startOfDay(for: a.endDate)
            var summary = bucket[day] ?? DailySummary(id: day, dayStart: day, totalDistanceMeters: 0, totalDurationSeconds: 0, runCount: 0, longestRunMeters: 0, longestRunDurationSeconds: 0, totalCaloriesKilocalories: 0)
            summary.totalDistanceMeters += a.distanceMeters
            summary.totalDurationSeconds += a.durationSeconds
            summary.runCount += 1
            summary.totalCaloriesKilocalories += a.caloriesKilocalories
            if a.distanceMeters > summary.longestRunMeters {
                summary.longestRunMeters = a.distanceMeters
                summary.longestRunDurationSeconds = a.durationSeconds
            }
            bucket[day] = summary
        }

        return bucket.values.sorted { $0.dayStart > $1.dayStart }
    }

    func monthlySummaries(using calendar: Calendar = Calendar(identifier: .iso8601)) -> [MonthlySummary] {
        guard !activities.isEmpty else { return [] }
        var bucket: [Date: MonthlySummary] = [:]

        for a in activities {
            let comps = calendar.dateComponents([.year, .month], from: a.endDate)
            guard let startOfMonth = calendar.date(from: comps) else { continue }
            var summary = bucket[startOfMonth] ?? MonthlySummary(id: startOfMonth, monthStart: startOfMonth, totalDistanceMeters: 0, totalDurationSeconds: 0, runCount: 0, longestRunMeters: 0, longestRunDurationSeconds: 0, totalCaloriesKilocalories: 0)
            summary.totalDistanceMeters += a.distanceMeters
            summary.totalDurationSeconds += a.durationSeconds
            summary.runCount += 1
            summary.totalCaloriesKilocalories += a.caloriesKilocalories
            if a.distanceMeters > summary.longestRunMeters {
                summary.longestRunMeters = a.distanceMeters
                summary.longestRunDurationSeconds = a.durationSeconds
            }
            bucket[startOfMonth] = summary
        }

        return bucket.values.sorted { $0.monthStart > $1.monthStart }
    }
}
extension ActivityStore {
    func weeklySummaries(using calendar: Calendar = Calendar(identifier: .iso8601)) -> [WeeklySummary] {
        guard !activities.isEmpty else { return [] }
        var bucket: [Date: WeeklySummary] = [:]

        for a in activities {
            let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: a.endDate)
            guard let startOfWeek = calendar.date(from: comps) else { continue }
            var summary = bucket[startOfWeek] ?? WeeklySummary(id: startOfWeek, weekStart: startOfWeek, totalDistanceMeters: 0, totalDurationSeconds: 0, longestRunMeters: 0, longestRunDurationSeconds: 0, totalCaloriesKilocalories: 0)
            summary.totalDistanceMeters += a.distanceMeters
            summary.totalDurationSeconds += a.durationSeconds
            summary.totalCaloriesKilocalories += a.caloriesKilocalories
            if a.distanceMeters > summary.longestRunMeters {
                summary.longestRunMeters = a.distanceMeters
                summary.longestRunDurationSeconds = a.durationSeconds
            }
            bucket[startOfWeek] = summary
        }

        return bucket.values.sorted { $0.weekStart > $1.weekStart }
    }

    func activeDaysStreak(using calendar: Calendar = Calendar(identifier: .iso8601)) -> Int {
        guard !activities.isEmpty else { return 0 }
        let daysWithActivity: Set<Date> = Set(activities.map { calendar.startOfDay(for: $0.endDate) })
        var streak = 0
        var day = calendar.startOfDay(for: Date())
        while daysWithActivity.contains(day) {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return streak
    }
}