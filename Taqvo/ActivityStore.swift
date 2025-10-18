//
//  ActivityStore.swift
//  Taqvo
//
//  Implements persistent storage for completed activities shown in Feed.
//

import Foundation
import SwiftUI
import MapKit

struct Coordinate: Codable {
    let latitude: Double
    let longitude: Double
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
}

final class ActivityStore: ObservableObject {
    @Published private(set) var activities: [FeedActivity] = []

    private let fileURL: URL
    private let queue = DispatchQueue(label: "ActivityStoreQueue")

    init() {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.fileURL = dir.appendingPathComponent("activities.json")
        load()
    }

    func add(summary: ActivitySummary, snapshot: UIImage?, note: String? = nil, photo: UIImage? = nil) {
        let coords = summary.route.map { Coordinate(latitude: $0.latitude, longitude: $0.longitude) }
        let activity = FeedActivity(
            id: UUID(),
            distanceMeters: summary.distanceMeters,
            durationSeconds: summary.durationSeconds,
            route: coords,
            startDate: summary.startDate,
            endDate: summary.endDate,
            snapshotPNG: snapshot?.pngData(),
            note: note,
            photoPNG: photo?.pngData()
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

    // Helper to convert stored coordinates back to CLLocationCoordinate2D
    static func clCoordinates(from coords: [Coordinate]) -> [CLLocationCoordinate2D] {
        coords.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
    }

    // Delete an activity and persist changes
    func delete(activity: FeedActivity) {
        activities.removeAll { $0.id == activity.id }
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
            var summary = bucket[day] ?? DailySummary(id: day, dayStart: day, totalDistanceMeters: 0, totalDurationSeconds: 0, runCount: 0, longestRunMeters: 0, longestRunDurationSeconds: 0)
            summary.totalDistanceMeters += a.distanceMeters
            summary.totalDurationSeconds += a.durationSeconds
            summary.runCount += 1
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
            var summary = bucket[startOfMonth] ?? MonthlySummary(id: startOfMonth, monthStart: startOfMonth, totalDistanceMeters: 0, totalDurationSeconds: 0, runCount: 0, longestRunMeters: 0, longestRunDurationSeconds: 0)
            summary.totalDistanceMeters += a.distanceMeters
            summary.totalDurationSeconds += a.durationSeconds
            summary.runCount += 1
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
            var summary = bucket[startOfWeek] ?? WeeklySummary(id: startOfWeek, weekStart: startOfWeek, totalDistanceMeters: 0, totalDurationSeconds: 0, longestRunMeters: 0, longestRunDurationSeconds: 0)
            summary.totalDistanceMeters += a.distanceMeters
            summary.totalDurationSeconds += a.durationSeconds
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