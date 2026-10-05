import UIKit
import Photos

/// Service responsible for locating and retrieving the screenshot triggered during Back Tap.
///
/// Workflow:
/// 1. First inspects `UIPasteboard.general.image` (if the iOS Shortcut copied the screenshot).
/// 2. If not found in pasteboard, queries the iOS Photo Library for the latest screenshot
///    in the `smartAlbumScreenshots` album.
@MainActor
final class BackTapScreenshotService {

    /// Retrieves the most recent screenshot image either from the clipboard or from the photo library.
    static func getLatestScreenshot() async -> UIImage? {
        // 1. Check Pasteboard first (fastest, no disk read, no photo permissions required)
        if let clipboardImage = UIPasteboard.general.image {
            return clipboardImage
        }

        // 2. Check Photo Library for recent screenshots
        return await fetchLatestFromPhotoLibrary()
    }

    /// Fetches the newest asset from the Screenshots smart album in Photos.
    private static func fetchLatestFromPhotoLibrary() async -> UIImage? {
        var status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if status == .notDetermined {
            status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        }

        guard status == .authorized || status == .limited else {
            return nil
        }

        // Fetch Screenshots smart album
        let smartAlbums = PHAssetCollection.fetchAssetCollections(
            with: .smartAlbum,
            subtype: .smartAlbumScreenshots,
            options: nil
        )

        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.fetchLimit = 1

        var targetAsset: PHAsset? = nil

        smartAlbums.enumerateObjects { collection, _, stop in
            let assets = PHAsset.fetchAssets(in: collection, options: fetchOptions)
            if let first = assets.firstObject {
                targetAsset = first
                stop.pointee = true
            }
        }

        // Fallback: If no screenshot album found or empty, fetch latest from all photos
        if targetAsset == nil {
            let allPhotos = PHAsset.fetchAssets(with: .image, options: fetchOptions)
            targetAsset = allPhotos.firstObject
        }

        guard let asset = targetAsset else { return nil }

        // Load UIImage from PHAsset
        return await withCheckedContinuation { continuation in
            let imageManager = PHImageManager.default()
            let requestOptions = PHImageRequestOptions()
            requestOptions.isSynchronous = false
            requestOptions.deliveryMode = .highQualityFormat
            requestOptions.isNetworkAccessAllowed = true

            imageManager.requestImage(
                for: asset,
                targetSize: PHImageManagerMaximumSize,
                contentMode: .aspectFit,
                options: requestOptions
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }
}
