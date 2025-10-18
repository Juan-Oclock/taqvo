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

    private var routeCoords: [CLLocationCoordinate2D] {
        ActivityStore.clCoordinates(from: activity.route)
    }

    private var paceString: String {
        ActivityTrackingViewModel.formattedPace(distanceMeters: activity.distanceMeters,
                                               durationSeconds: activity.durationSeconds)
    }

    private var splits: [Double] {
        // Coarse per-km splits using average pace; last split is remainder
        let totalMeters = activity.distanceMeters
        let totalSeconds = activity.durationSeconds
        guard totalMeters > 0, totalSeconds > 0 else { return [] }
        let secPerMeter = totalSeconds / totalMeters
        let kmCount = Int(totalMeters / 1000.0)
        var result: [Double] = Array(repeating: secPerMeter * 1000.0, count: max(kmCount, 0))
        let remainder = totalMeters.truncatingRemainder(dividingBy: 1000.0)
        if remainder > 1 {
            result.append(secPerMeter * remainder)
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

                // Splits
                VStack(alignment: .leading, spacing: 8) {
                    Text("Splits")
                        .font(.headline)
                    ForEach(Array(splits.enumerated()), id: \.offset) { idx, seconds in
                        HStack {
                            Text("Km \(idx + 1)")
                                .foregroundColor(.taqvoAccentText)
                            Spacer()
                            Text(ActivityTrackingViewModel.formattedDuration(seconds))
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
        .navigationTitle("Activity Detail")
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
        .background(Color.taqvoBackgroundDark)
    }
}