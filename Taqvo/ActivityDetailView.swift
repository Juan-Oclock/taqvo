//
//  ActivityDetailView.swift
//  Taqvo
//
//  Shows a full map, metrics, and coarse splits for a feed activity.
//

import SwiftUI
import MapKit

struct ActivityDetailView: View {
    @EnvironmentObject var store: ActivityStore
    @Environment(\.dismiss) private var dismiss

    let activity: FeedActivity
    @State private var showDeleteConfirm: Bool = false
    @StateObject private var health = HealthSyncService()
    @State private var stepsCount: Int?
    @State private var elevationGainMeters: Double?

    private var routeCoords: [CLLocationCoordinate2D] {
        ActivityStore.clCoordinates(from: activity.route)
    }

    private var paceString: String {
        ActivityTrackingViewModel.formattedPace(distanceMeters: activity.distanceMeters,
                                               durationSeconds: activity.durationSeconds)
    }
    private var avgSpeedString: String {
        guard activity.durationSeconds > 0 else { return "--" }
        let kmh = (activity.distanceMeters / 1000.0) / (activity.durationSeconds / 3600.0)
        return String(format: "%.2f km/h", kmh)
    }

    private var navigationTitleText: String {
        let t = (activity.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? "Activity Detail" : t
    }

    private var splits: [Double] {
        // Prefer stored real splits; fallback to coarse distance-based allocation
        if let stored = activity.splitsSeconds, !stored.isEmpty {
            return stored
        }
        let totalMeters = activity.distanceMeters
        let totalSeconds = activity.durationSeconds
        guard totalMeters > 0, totalSeconds > 0 else { return [] }
        let secPerMeter = totalSeconds / totalMeters
        let coords = ActivityStore.clCoordinates(from: activity.route)
        guard coords.count > 1 else {
            let kmCount = Int(totalMeters / 1000.0)
            var result: [Double] = Array(repeating: secPerMeter * 1000.0, count: max(kmCount, 0))
            let remainder = totalMeters.truncatingRemainder(dividingBy: 1000.0)
            if remainder > 1 { result.append(secPerMeter * remainder) }
            return result
        }
        var result: [Double] = []
        var accMeters: Double = 0
        var kmBucketMeters: Double = 0
        for i in 1..<coords.count {
            let a = CLLocation(latitude: coords[i-1].latitude, longitude: coords[i-1].longitude)
            let b = CLLocation(latitude: coords[i].latitude, longitude: coords[i].longitude)
            let d = max(0, b.distance(from: a))
            accMeters += d
            var remaining = d
            while kmBucketMeters + remaining >= 1000.0 {
                let need = 1000.0 - kmBucketMeters
                result.append(secPerMeter * need)
                remaining -= need
                kmBucketMeters = 0
            }
            kmBucketMeters += remaining
        }
        if kmBucketMeters > 1 {
            result.append(secPerMeter * kmBucketMeters)
        }
        return result
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                MapRouteView(route: routeCoords)
                    .frame(height: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                // Metrics
                HStack(spacing: 16) {
                    VStack(alignment: .leading) {
                        Text("Distance")
                            .font(.caption)
                            .foregroundColor(.taqvoAccentText)
                        Text(String(format: "%.2f km", activity.distanceMeters/1000.0))
                            .font(.title3).bold()
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("Duration")
                            .font(.caption)
                            .foregroundColor(.taqvoAccentText)
                        Text(ActivityTrackingViewModel.formattedDuration(activity.durationSeconds))
                            .font(.title3).bold()
                    }
                }

                HStack {
                    Text("Avg Pace")
                        .font(.caption)
                        .foregroundColor(.taqvoAccentText)
                    Spacer()
                    Text(paceString)
                        .font(.headline)
                }

                // Calories
                HStack {
                    Text("Calories")
                        .font(.caption)
                        .foregroundColor(.taqvoAccentText)
                    Spacer()
                    Text(String(format: "%.0f kcal", activity.caloriesKilocalories))
                        .font(.headline)
                }

                // Optional Average Heart Rate
                if let hr = activity.averageHeartRateBPM {
                    HStack {
                        Text("Avg HR")
                            .font(.caption)
                            .foregroundColor(.taqvoAccentText)
                        Spacer()
                        Text(String(format: "%.0f bpm", hr))
                            .font(.headline)
                    }
                }

                // Avg Speed
                HStack {
                    Text("Avg Speed")
                        .font(.caption)
                        .foregroundColor(.taqvoAccentText)
                    Spacer()
                    Text(avgSpeedString)
                        .font(.headline)
                }

                // Steps
                HStack {
                    Text("Steps")
                        .font(.caption)
                        .foregroundColor(.taqvoAccentText)
                    Spacer()
                    Text((stepsCount ?? activity.stepsCount).map { String($0) } ?? "—")
                        .font(.headline)
                }

                // Elevation
                HStack {
                    Text("Elevation")
                        .font(.caption)
                        .foregroundColor(.taqvoAccentText)
                    Spacer()
                    Text((elevationGainMeters ?? activity.elevationGainMeters).map { String(format: "%.0f m", $0) } ?? "—")
                        .font(.headline)
                }

                // Splits
                VStack(alignment: .leading, spacing: 8) {
                    Text("Splits")
                        .font(.headline)
                    ForEach(splits.indices, id: \.self) { idx in
                        HStack {
                            Text("Km \(idx + 1)")
                                .foregroundColor(.taqvoAccentText)
                            Spacer()
                            Text(ActivityTrackingViewModel.formattedDuration(splits[idx]))
                                .font(.body).monospacedDigit()
                        }
                        .padding(.vertical, 4)
                    }
                    if splits.isEmpty {
                        Text("No splits available")
                            .foregroundColor(.taqvoAccentText)
                            .font(.caption)
                    }
                }

                Text(activity.endDate.formatted(date: .abbreviated, time: .shortened))
                    .foregroundColor(.taqvoAccentText)
                    .font(.caption)
            }
            .padding()
        }
        .navigationTitle(navigationTitleText)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .alert("Delete this activity?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                store.delete(activity: activity)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove it from your feed and insights.")
        }
        .task {
            let ok = await health.ensureAuthorization()
            if ok {
                if let s = await health.stepCount(start: activity.startDate, end: activity.endDate) {
                    stepsCount = s
                }
                if let elev = await health.elevationGainMeters(start: activity.startDate, end: activity.endDate) {
                    elevationGainMeters = elev
                }
            }
        }
        .background(Color.taqvoBackgroundDark)
    }
}