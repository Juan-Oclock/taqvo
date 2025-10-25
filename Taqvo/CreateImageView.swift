//
//  CreateImageView.swift
//  Taqvo
//
//  Created by Assistant on 10/25/25
//

import SwiftUI
import PhotosUI

struct CreateImageView: View {
    let summary: ActivitySummary
    let selectedPhoto: UIImage?
    let activityTitle: String
    let note: String
    let snapshot: UIImage?
    let onSave: ((Bool) -> Void)?
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedFormat: ImageFormat = .stories
    @State private var showPhotoPicker: Bool = false
    @State private var newPhotoItem: PhotosPickerItem?
    @State private var currentPhoto: UIImage?
    @State private var isSaving: Bool = false
    @State private var showSaveSuccess: Bool = false
    @State private var showDismissAlert: Bool = false
    
    enum ImageFormat: String, CaseIterable {
        case stories = "Stories"
        case square = "Square"
        
        var size: CGSize {
            switch self {
            case .stories: return CGSize(width: 1080, height: 1920)
            case .square: return CGSize(width: 1080, height: 1080)
            }
        }
        
        var aspectRatio: CGFloat {
            size.width / size.height
        }
    }
    
    var body: some View {
        ZStack {
            Color.taqvoBackgroundDark.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Custom Header
                header
                
                // Content
                ScrollView {
                    VStack(spacing: 24) {
                        // Format Selector
                        formatSelector
                        
                        // Image Preview (includes buttons below)
                        imagePreview
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)
                }
            }
        }
        .onChange(of: newPhotoItem) { _, item in
            Task { await loadPhoto(item) }
        }
        .onAppear {
            currentPhoto = selectedPhoto ?? snapshot
        }
        .alert("Saved!", isPresented: $showSaveSuccess) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Image saved to your photo library")
        }
    }
    
    // MARK: - View Components
    
    private var header: some View {
        HStack {
            Button {
                if onSave != nil {
                    showDismissAlert = true
                } else {
                    dismiss()
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.taqvoTextDark)
                    .frame(width: 44, height: 44)
            }
            
            Spacer()
            
            Text("CREATE IMAGE")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.taqvoTextDark)
                .tracking(1.2)
            
            Spacer()
            
            // Save & Close button (if onSave is provided)
            if onSave != nil {
                Button {
                    onSave?(true)
                    dismiss()
                } label: {
                    Text("Done")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.taqvoCTA)
                }
                .frame(width: 44, height: 44)
            } else {
                Color.clear
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.taqvoBackgroundDark)
        .alert("Save Activity?", isPresented: $showDismissAlert) {
            Button("Save to Feed", role: .none) {
                onSave?(true)
                dismiss()
            }
            Button("Discard", role: .destructive) {
                onSave?(false)
                dismiss()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Do you want to save this activity to your feed?")
        }
    }
    
    private var formatSelector: some View {
        HStack(spacing: 12) {
            ForEach(ImageFormat.allCases, id: \.self) { format in
                Button {
                    selectedFormat = format
                } label: {
                    Text(format.rawValue)
                        .font(.system(size: 15, weight: selectedFormat == format ? .semibold : .regular))
                        .foregroundColor(selectedFormat == format ? .black : .taqvoTextDark)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(selectedFormat == format ? Color.taqvoCTA : Color.black.opacity(0.2))
                        .cornerRadius(10)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    private var imagePreview: some View {
        VStack(spacing: 0) {
            if let photo = currentPhoto {
                // Generated Image Preview with Camera Button Overlay
                GeometryReader { previewGeometry in
                    ZStack(alignment: .topLeading) {
                        generatedImageView(photo: photo)
                            .aspectRatio(selectedFormat.aspectRatio, contentMode: .fit)
                            .frame(width: previewGeometry.size.width, height: previewGeometry.size.height)
                            .clipped()
                            .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                        
                        // Camera Button Overlay - positioned relative to actual image bounds
                        Button {
                            showPhotoPicker = true
                        } label: {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.black.opacity(0.6))
                                .clipShape(Circle())
                        }
                        .offset(x: previewGeometry.size.width - 56, y: 12)
                    }
                }
                .aspectRatio(selectedFormat.aspectRatio, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .frame(maxHeight: 550)
                .sheet(isPresented: $showPhotoPicker) {
                    PhotosPicker(selection: $newPhotoItem, matching: .images) {
                        Text("Select Photo")
                    }
                }
                
                // Buttons below image
                actionButtons
                    .padding(.top, 16)
            } else {
                // No Photo - Prompt to Upload
                VStack(spacing: 16) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 60))
                        .foregroundColor(.taqvoAccentText)
                    
                    Text("No Photo Selected")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.taqvoTextDark)
                    
                    Text("Upload a photo to create your shareable image")
                        .font(.system(size: 14))
                        .foregroundColor(.taqvoAccentText)
                        .multilineTextAlignment(.center)
                    
                    Button {
                        showPhotoPicker = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "photo")
                                .font(.system(size: 16))
                            Text("Upload Photo")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.taqvoCTA)
                        .cornerRadius(14)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 350)
                .background(Color.black.opacity(0.2))
                .sheet(isPresented: $showPhotoPicker) {
                    PhotosPicker(selection: $newPhotoItem, matching: .images) {
                        Text("Select Photo")
                    }
                }
            }
        }
    }
    
    private var actionButtons: some View {
        HStack(spacing: 12) {
            // Share Button
            Button {
                shareImage()
            } label: {
                HStack(spacing: 8) {
                    if isSaving {
                        ProgressView()
                            .tint(.black)
                    } else {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 18))
                        Text("Share")
                            .font(.system(size: 17, weight: .semibold))
                    }
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(currentPhoto != nil ? Color.taqvoCTA : Color.gray.opacity(0.3))
                .cornerRadius(14)
            }
            .disabled(currentPhoto == nil || isSaving)
            
            // Save to Device Button
            Button {
                saveToDevice()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 18))
                    Text("Download")
                        .font(.system(size: 17, weight: .semibold))
                }
                .foregroundColor(.taqvoTextDark)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(currentPhoto != nil ? Color.black.opacity(0.2) : Color.gray.opacity(0.1))
                .cornerRadius(14)
            }
            .disabled(currentPhoto == nil || isSaving)
        }
    }
    
    // MARK: - Generated Image View
    
    @ViewBuilder
    private func generatedImageView(photo: UIImage) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                // Background Photo
                Image(uiImage: photo)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                
                // Top Gradient for Logo
                LinearGradient(
                    colors: [.black.opacity(0.6), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(width: geometry.size.width, height: geometry.size.height * 0.3)
                
                // Bottom Gradient for Metrics - starts at 50% height
                LinearGradient(
                    colors: [.clear, .black.opacity(0.7), .black.opacity(0.95)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(width: geometry.size.width, height: geometry.size.height * 0.5)
                .offset(y: geometry.size.height * 0.5)
                
                // Taqvo Logo - Top Left (Absolute Position)
                HStack(spacing: 6) {
                    Image(systemName: "figure.run")
                        .font(.system(size: 20, weight: .semibold))
                    Text("taqvo")
                        .font(.system(size: 16, weight: .heavy))
                        .tracking(1.5)
                }
                .foregroundColor(.taqvoCTA)
                .offset(x: 16, y: 16)
                
                // Stats Overlay - Bottom Left (Absolute Position)
                VStack(alignment: .leading, spacing: 12) {
                    // Route Line (decorative) - above title
                    routeLineDecoration()
                        .frame(width: 100, height: 35)
                        .foregroundColor(.taqvoCTA)
                    
                    // Activity Type
                    Text(activityTitle.isEmpty ? summary.kind.rawValue.uppercased() : activityTitle.uppercased())
                        .font(.system(size: 28, weight: .heavy))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: geometry.size.width - 32, alignment: .leading)
                    
                    // Stats Row
                    HStack(spacing: 12) {
                        statItem(
                            value: String(format: "%.2f", summary.distanceMeters / 1000.0),
                            unit: "km",
                            label: "Distance"
                        )
                        
                        statItem(
                            value: formattedDuration(summary.durationSeconds),
                            unit: "",
                            label: "Duration"
                        )
                        
                        statItem(
                            value: String(format: "%.0f", summary.caloriesKilocalories),
                            unit: "cal",
                            label: "Calories"
                        )
                        
                        if let steps = summary.stepsCount, steps > 0 {
                            statItem(
                                value: String(steps),
                                unit: "",
                                label: "Steps"
                            )
                        }
                    }
                }
                .offset(x: 16, y: geometry.size.height - 180)
            }
        }
    }
    
    @ViewBuilder
    private func statItem(value: String, unit: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Text(value)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.7))
        }
    }
    
    @ViewBuilder
    private func routeLineDecoration() -> some View {
        GeometryReader { geometry in
            if !summary.route.isEmpty {
                // Use actual route data
                Path { path in
                    let route = summary.route
                    
                    // Find bounds of route
                    let lats = route.map { $0.latitude }
                    let lons = route.map { $0.longitude }
                    guard let minLat = lats.min(), let maxLat = lats.max(),
                          let minLon = lons.min(), let maxLon = lons.max() else {
                        return
                    }
                    
                    let latRange = maxLat - minLat
                    let lonRange = maxLon - minLon
                    
                    // Avoid division by zero
                    guard latRange > 0 && lonRange > 0 else {
                        return
                    }
                    
                    // Map coordinates to view space
                    for (index, coord) in route.enumerated() {
                        let x = ((coord.longitude - minLon) / lonRange) * geometry.size.width
                        let y = geometry.size.height - ((coord.latitude - minLat) / latRange) * geometry.size.height
                        
                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            } else {
                // Fallback decorative curve if no route data
                Path { path in
                    path.move(to: CGPoint(x: 0, y: geometry.size.height / 2))
                    path.addCurve(
                        to: CGPoint(x: geometry.size.width, y: geometry.size.height / 2),
                        control1: CGPoint(x: geometry.size.width * 0.25, y: 0),
                        control2: CGPoint(x: geometry.size.width * 0.75, y: geometry.size.height)
                    )
                }
                .stroke(style: StrokeStyle(lineWidth: 3, lineCap: .round))
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func formattedDuration(_ seconds: Double) -> String {
        let s = Int(seconds)
        let h = s / 3600
        let m = (s % 3600) / 60
        let sec = s % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, sec) }
        return String(format: "%02d:%02d", m, sec)
    }
    
    private func loadPhoto(_ item: PhotosPickerItem?) async {
        guard let item = item else { return }
        do {
            if let data: Data = try await item.loadTransferable(type: Data.self),
               let img = UIImage(data: data) {
                await MainActor.run { currentPhoto = img }
            }
        } catch {
            // Silently ignore photo load errors
        }
    }
    
    private func generateFinalImage() -> UIImage? {
        guard let photo = currentPhoto else { return nil }
        
        let renderer = ImageRenderer(content: generatedImageView(photo: photo)
            .frame(width: selectedFormat.size.width / 3, height: selectedFormat.size.height / 3)
        )
        renderer.scale = 3.0
        return renderer.uiImage
    }
    
    private func shareImage() {
        guard let image = generateFinalImage() else { return }
        
        let activityVC = UIActivityViewController(
            activityItems: [image],
            applicationActivities: nil
        )
        
        // Configure for bottom sheet presentation on iPhone
        activityVC.modalPresentationStyle = .pageSheet
        
        // For iPad, set popover presentation
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            
            // Find the topmost presented view controller
            var topVC = rootVC
            while let presented = topVC.presentedViewController {
                topVC = presented
            }
            
            // Configure popover for iPad
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = topVC.view
                popover.sourceRect = CGRect(x: topVC.view.bounds.midX, y: topVC.view.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            
            topVC.present(activityVC, animated: true)
        }
    }
    
    private func saveToDevice() {
        guard let image = generateFinalImage() else { return }
        
        isSaving = true
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isSaving = false
            showSaveSuccess = true
        }
    }
}

#Preview {
    CreateImageView(
        summary: ActivitySummary(
            distanceMeters: 5000,
            durationSeconds: 1800,
            route: [],
            routeSamples: [],
            startDate: Date(),
            endDate: Date(),
            kind: .run,
            caloriesKilocalories: 350,
            activeCaloriesKilocalories: 300
        ),
        selectedPhoto: nil,
        activityTitle: "Morning Run",
        note: "Great run!",
        snapshot: nil,
        onSave: nil
    )
}
