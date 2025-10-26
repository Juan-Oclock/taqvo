//
//  ImageCompressor.swift
//  Taqvo
//
//  Created by Assistant
//

import UIKit

struct ImageCompressor {
    
    /// Compression quality presets
    enum CompressionQuality {
        case low        // 0.3 quality, ~100KB
        case medium     // 0.5 quality, ~200KB
        case high       // 0.7 quality, ~400KB
        case original   // 1.0 quality, no compression
        
        var value: CGFloat {
            switch self {
            case .low: return 0.3
            case .medium: return 0.5
            case .high: return 0.7
            case .original: return 1.0
            }
        }
    }
    
    /// Maximum dimensions for different use cases
    enum MaxDimension {
        case avatar      // 400x400
        case thumbnail   // 800x800
        case standard    // 1200x1200
        case large       // 2000x2000
        
        var size: CGFloat {
            switch self {
            case .avatar: return 400
            case .thumbnail: return 800
            case .standard: return 1200
            case .large: return 2000
            }
        }
    }
    
    /// Compress image with quality and size constraints
    /// - Parameters:
    ///   - image: Original UIImage
    ///   - quality: Compression quality preset
    ///   - maxDimension: Maximum width/height
    /// - Returns: Compressed image data
    static func compress(
        _ image: UIImage,
        quality: CompressionQuality = .medium,
        maxDimension: MaxDimension = .standard
    ) -> Data? {
        // Resize image first
        let resizedImage = resize(image, maxDimension: maxDimension.size)
        
        // Compress to JPEG
        return resizedImage.jpegData(compressionQuality: quality.value)
    }
    
    /// Resize image to fit within max dimension while maintaining aspect ratio
    /// - Parameters:
    ///   - image: Original image
    ///   - maxDimension: Maximum width or height
    /// - Returns: Resized image
    static func resize(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        
        // If image is already smaller, return original
        if size.width <= maxDimension && size.height <= maxDimension {
            return image
        }
        
        // Calculate new size maintaining aspect ratio
        let aspectRatio = size.width / size.height
        var newSize: CGSize
        
        if size.width > size.height {
            newSize = CGSize(width: maxDimension, height: maxDimension / aspectRatio)
        } else {
            newSize = CGSize(width: maxDimension * aspectRatio, height: maxDimension)
        }
        
        // Render resized image
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
    
    /// Compress image to target file size (approximate)
    /// - Parameters:
    ///   - image: Original image
    ///   - targetSizeKB: Target size in kilobytes
    ///   - maxDimension: Maximum dimension
    /// - Returns: Compressed image data
    static func compressToSize(
        _ image: UIImage,
        targetSizeKB: Int,
        maxDimension: MaxDimension = .standard
    ) -> Data? {
        let resizedImage = resize(image, maxDimension: maxDimension.size)
        var compression: CGFloat = 1.0
        var imageData = resizedImage.jpegData(compressionQuality: compression)
        
        let targetBytes = targetSizeKB * 1024
        
        // Iteratively reduce quality until target size is reached
        while let data = imageData, data.count > targetBytes && compression > 0.1 {
            compression -= 0.1
            imageData = resizedImage.jpegData(compressionQuality: compression)
        }
        
        return imageData
    }
    
    /// Get compressed image size in KB
    static func sizeInKB(_ data: Data) -> Double {
        return Double(data.count) / 1024.0
    }
}

// MARK: - UIImage Extension for Convenience

extension UIImage {
    
    /// Compress image for avatar upload
    func compressForAvatar() -> Data? {
        return ImageCompressor.compress(
            self,
            quality: .high,
            maxDimension: .avatar
        )
    }
    
    /// Compress image for activity photo
    func compressForActivity() -> Data? {
        return ImageCompressor.compress(
            self,
            quality: .medium,
            maxDimension: .standard
        )
    }
    
    /// Compress image for thumbnail
    func compressForThumbnail() -> Data? {
        return ImageCompressor.compress(
            self,
            quality: .medium,
            maxDimension: .thumbnail
        )
    }
}
