import Photos
import UIKit

/// Manages photo library access, saving, and deletion
class PhotoManager: ObservableObject {
    static let shared = PhotoManager()

    @Published var authorizationStatus: PHAuthorizationStatus = .notDetermined

    init() {
        authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    // MARK: - Authorization

    func requestAuthorization() async -> PHAuthorizationStatus {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        await MainActor.run {
            self.authorizationStatus = status
        }
        return status
    }

    // MARK: - Save to Photos

    func saveImageToPhotos(
        _ image: UIImage, originalAssetId: String,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        guard let imageData = image.jpegData(compressionQuality: 1.0) else {
            completion(.failure(PhotoManagerError.imageConversionFailed))
            return
        }

        var localIdentifier: String?

        PHPhotoLibrary.shared().performChanges {
            let creationRequest = PHAssetCreationRequest.forAsset()
            creationRequest.addResource(with: .photo, data: imageData, options: nil)
            localIdentifier = creationRequest.placeholderForCreatedAsset?.localIdentifier
        } completionHandler: { success, error in
            DispatchQueue.main.async {
                if success, let identifier = localIdentifier {
                    // Track the blurred photo
                    BlurredPhotosStore.shared.addBlurredPhoto(identifier)
                    completion(.success(identifier))
                } else {
                    completion(.failure(error ?? PhotoManagerError.saveFailed))
                }
            }
        }
    }

    // MARK: - Save to Files

    func saveImageToFiles(_ image: UIImage, completion: @escaping (Result<URL, Error>) -> Void) {
        guard let imageData = image.jpegData(compressionQuality: 1.0) else {
            completion(.failure(PhotoManagerError.imageConversionFailed))
            return
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let fileName = "BlurredPhoto_\(dateFormatter.string(from: Date())).jpg"

        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[
            0]
        let fileURL = documentsPath.appendingPathComponent(fileName)

        do {
            try imageData.write(to: fileURL)

            // Present share sheet to save to Files app
            DispatchQueue.main.async {
                self.presentShareSheet(for: fileURL, completion: completion)
            }
        } catch {
            completion(.failure(error))
        }
    }

    private func presentShareSheet(for url: URL, completion: @escaping (Result<URL, Error>) -> Void)
    {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
            let viewController = windowScene.windows.first?.rootViewController
        else {
            completion(.failure(PhotoManagerError.noViewController))
            return
        }

        let activityVC = UIActivityViewController(
            activityItems: [url],
            applicationActivities: nil
        )

        activityVC.completionWithItemsHandler = { _, completed, _, error in
            if let error = error {
                completion(.failure(error))
            } else if completed {
                completion(.success(url))
            } else {
                completion(.failure(PhotoManagerError.userCancelled))
            }
        }

        // For iPad support
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = viewController.view
            popover.sourceRect = CGRect(
                x: viewController.view.bounds.midX, y: viewController.view.bounds.midY, width: 0,
                height: 0)
            popover.permittedArrowDirections = []
        }

        viewController.present(activityVC, animated: true)
    }

    // MARK: - Delete Photos

    func deletePhotos(identifiers: [String]) async -> DeletionResult {
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
        var assetsToDelete: [PHAsset] = []

        fetchResult.enumerateObjects { asset, _, _ in
            assetsToDelete.append(asset)
        }

        guard !assetsToDelete.isEmpty else {
            return DeletionResult(
                successCount: 0, failedCount: identifiers.count, deletedIdentifiers: [])
        }

        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.deleteAssets(assetsToDelete as NSArray)
            }

            let deletedIdentifiers = assetsToDelete.map { $0.localIdentifier }
            return DeletionResult(
                successCount: assetsToDelete.count,
                failedCount: identifiers.count - assetsToDelete.count,
                deletedIdentifiers: deletedIdentifiers
            )
        } catch {
            print("Failed to delete photos: \(error)")
            return DeletionResult(
                successCount: 0, failedCount: identifiers.count, deletedIdentifiers: [])
        }
    }

    // MARK: - Load Thumbnail

    func loadThumbnail(for identifier: String, size: CGSize) async -> UIImage? {
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)

        guard let asset = fetchResult.firstObject else { return nil }

        return await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            options.resizeMode = .fast
            options.isSynchronous = false

            PHImageManager.default().requestImage(
                for: asset,
                targetSize: size,
                contentMode: .aspectFill,
                options: options
            ) { image, info in
                // Only resume if this is the final image (not a degraded preview)
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                if !isDegraded {
                    continuation.resume(returning: image)
                }
            }
        }
    }
}

// MARK: - Errors

enum PhotoManagerError: LocalizedError {
    case imageConversionFailed
    case saveFailed
    case noViewController
    case userCancelled

    var errorDescription: String? {
        switch self {
        case .imageConversionFailed:
            return "Failed to convert image"
        case .saveFailed:
            return "Failed to save photo"
        case .noViewController:
            return "Could not present file picker"
        case .userCancelled:
            return "Save cancelled"
        }
    }
}
