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
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedFormat: ImageFormat = .stories
    @State private var showPhotoPicker: Bool = false
    @State private var newPhotoItem: PhotosPickerItem?
    @State private var currentPhoto: UIImage?
    @State private var isSaving: Bool = false
    @State private var showSaveSuccess: Bool = false
    
    enum ImageFormat: String, CaseIterable {
        case stories = "Stories"
        case square = "Square"
        case landscape = "Landscape"
        
        var size: CGSize {
            switch self {
            case .stories: return CGSize(width: 1080, height: 1920)
            case .square: return CGSize(width: 1080, height: 1080)
            case .landscape: return CGSize(width: 1920, height: 1080)
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
                        
                        // Image Preview
                        imagePreview
                        
                        // Action Buttons
                        actionButtons
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
                dismiss()
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
            
            // Invisible spacer for balance
            Color.clear
                .frame(width: 44, height: 44)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.taqvoBackgroundDark)
    }
    
    private var formatSelector: some View {
        HStack(spacing: 12) {
            ForEach(ImageFormat.allCases, id: \.self) { format in
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        selectedFormat = format
                    }
                } label: {
                    Text(format.rawValue)
                        .font(.system(size: 15, weight: selectedFormat == format ? .semibold : .regular))
                        .foregroundColor(selectedFormat == format ? .black : .taqvoTextDark)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(selectedFormat == format ? Color.taqvoCTA : Color.black.opacity(0.2))
                        .cornerRadius(10)
                }
            }
        }
    }
    
    private var imagePreview: some View {
        VStack(spacing: 16) {
            if let photo = currentPhoto {
                // Generated Image Preview
                generatedImageView(photo: photo)
                    .aspectRatio(selectedFormat.aspectRatio, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                
                // Change Photo Button
                Button {
                    showPhotoPicker = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "photo")
                            .font(.system(size: 16))
                        Text("Change Photo")
                            .font(.system(size: 15, weight: .medium))
                    }
                    .foregroundColor(.taqvoTextDark)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.2))
                    .cornerRadius(20)
                }
                .sheet(isPresented: $showPhotoPicker) {
                    PhotosPicker(selection: $newPhotoItem, matching: .images) {
                        Text("Select Photo")
                    }
                }
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
                .frame(height: 400)
                .background(Color.black.opacity(0.2))
                .cornerRadius(16)
                .sheet(isPresented: $showPhotoPicker) {
                    PhotosPicker(selection: $newPhotoItem, matching: .images) {
                        Text("Select Photo")
                    }
                }
            }
        }
    }
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
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
                .padding(.vertical, 18)
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
                    Text("Save to Device")
                        .font(.system(size: 17, weight: .semibold))
                }
                .foregroundColor(.taqvoTextDark)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(currentPhoto != nil ? Color.black.opacity(0.2) : Color.gray.opacity(0.1))
                .cornerRadius(14)
            }
            .disabled(currentPhoto == nil || isSaving)
        }
    }
    
    // MARK: - Generated Image View
    
    @ViewBuilder
    private func generatedImageView(photo: UIImage) -> some View {
        ZStack(alignment: .bottomLeading) {
            // Background Photo
            Image(uiImage: photo)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: selectedFormat.size.width / 3, height: selectedFormat.size.height / 3)
                .clipped()
            
            // Gradient Overlay
            LinearGradient(
                colors: [.clear, .black.opacity(0.8)],
                startPoint: .center,
                endPoint: .bottom
            )
            
            // Stats Overlay
            VStack(alignment: .leading, spacing: 12) {
                // Taqvo Logo
                HStack(spacing: 6) {
                    Image(systemName: "figure.run")
                        .font(.system(size: 20, weight: .semibold))
                    Text("TAQVO")
                        .font(.system(size: 16, weight: .bold))
                        .tracking(1.5)
                }
                .foregroundColor(.taqvoCTA)
                
                // Activity Type
                Text(activityTitle.isEmpty ? summary.kind.rawValue.uppercased() : activityTitle.uppercased())
                    .font(.system(size: 32, weight: .heavy))
                    .foregroundColor(.white)
                
                // Stats Row
                HStack(spacing: 20) {
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
                }
                
                // Route Line (decorative)
                if selectedFormat == .stories {
                    routeLineDecoration()
                        .frame(width: 80, height: 30)
                        .foregroundColor(.taqvoCTA)
                }
            }
            .padding(24)
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
        Path { path in
            path.move(to: CGPoint(x: 0, y: 15))
            path.addCurve(
                to: CGPoint(x: 80, y: 15),
                control1: CGPoint(x: 20, y: 0),
                control2: CGPoint(x: 60, y: 30)
            )
        }
        .stroke(style: StrokeStyle(lineWidth: 3, lineCap: .round))
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
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            activityVC.popoverPresentationController?.sourceView = rootVC.view
            rootVC.present(activityVC, animated: true)
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
        snapshot: nil
    )
}
