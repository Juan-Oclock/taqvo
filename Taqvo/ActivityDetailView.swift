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

    private var isOwner: Bool {
        guard let currentUserId = SupabaseAuthManager.shared.userId else { return false }
        return activity.userId == currentUserId
    }
    
    @ViewBuilder
    private func metricCard(icon: String, label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "BDF266"))
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.taqvoAccentText)
            }
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.taqvoTextDark)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.black.opacity(0.2))
        .cornerRadius(12)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Map
                MapRouteView(route: routeCoords)
                    .frame(height: 320)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                // Primary Metrics (Distance & Duration)
                HStack(spacing: 12) {
                    // Distance Card
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 16))
                                .foregroundColor(Color(hex: "BDF266"))
                            Text("Distance")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.taqvoAccentText)
                        }
                        Text(String(format: "%.2f", activity.distanceMeters/1000.0))
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.taqvoTextDark)
                        Text("km")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.taqvoAccentText)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Color.black.opacity(0.2))
                    .cornerRadius(16)
                    
                    // Duration Card
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "clock.fill")
                                .font(.system(size: 16))
                                .foregroundColor(Color(hex: "BDF266"))
                            Text("Duration")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.taqvoAccentText)
                        }
                        Text(ActivityTrackingViewModel.formattedDuration(activity.durationSeconds))
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.taqvoTextDark)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Color.black.opacity(0.2))
                    .cornerRadius(16)
                }

                // Secondary Metrics Grid
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        metricCard(icon: "speedometer", label: "Avg Pace", value: paceString)
                        metricCard(icon: "flame.fill", label: "Calories", value: String(format: "%.0f kcal", activity.caloriesKilocalories))
                    }
                    
                    HStack(spacing: 12) {
                        metricCard(icon: "gauge.medium", label: "Avg Speed", value: avgSpeedString)
                        if let hr = activity.averageHeartRateBPM {
                            metricCard(icon: "heart.fill", label: "Avg HR", value: String(format: "%.0f bpm", hr))
                        } else {
                            metricCard(icon: "figure.walk", label: "Steps", value: (stepsCount ?? activity.stepsCount).map { String($0) } ?? "—")
                        }
                    }
                    
                    HStack(spacing: 12) {
                        metricCard(icon: "figure.walk", label: "Steps", value: (stepsCount ?? activity.stepsCount).map { String($0) } ?? "—")
                        metricCard(icon: "mountain.2.fill", label: "Elevation", value: (elevationGainMeters ?? activity.elevationGainMeters).map { String(format: "%.0f m", $0) } ?? "—")
                    }
                }

                // Splits Section
                if !splits.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "figure.run")
                                .font(.system(size: 18))
                                .foregroundColor(Color(hex: "BDF266"))
                            Text("Splits")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.taqvoTextDark)
                        }
                        
                        VStack(spacing: 8) {
                            ForEach(splits.indices, id: \.self) { idx in
                                HStack {
                                    Text("Km \(idx + 1)")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.taqvoAccentText)
                                    Spacer()
                                    Text(ActivityTrackingViewModel.formattedDuration(splits[idx]))
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.taqvoTextDark)
                                        .monospacedDigit()
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(Color.black.opacity(0.1))
                                .cornerRadius(8)
                            }
                        }
                    }
                    .padding(16)
                    .background(Color.black.opacity(0.2))
                    .cornerRadius(16)
                }

                // Date
                Text(activity.endDate.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.taqvoAccentText)
                    .padding(.top, 8)
            }
            .padding(16)
            .padding(.bottom, 80)
        }
        .navigationTitle(navigationTitleText)
        .toolbar {
            if isOwner {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
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