import Photos
import SwiftUI

class PhotoLibraryManager: ObservableObject {
    @Published var authorizationStatus: PHAuthorizationStatus = .notDetermined
    @Published var assets: [PHAsset] = []

    private var fetchResult: PHFetchResult<PHAsset>?

    init() {
        authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if authorizationStatus == .authorized || authorizationStatus == .limited {
            fetchAssets()
        }
    }

    func requestAuthorization() {
        let currentStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)

        if currentStatus == .notDetermined {
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] status in
                DispatchQueue.main.async {
                    self?.authorizationStatus = status
                    if status == .authorized || status == .limited {
                        self?.fetchAssets()
                    }
                }
            }
        } else {
            authorizationStatus = currentStatus
            if currentStatus == .authorized || currentStatus == .limited {
                fetchAssets()
            }
        }
    }

    func fetchAssets() {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.predicate = NSPredicate(
            format: "mediaType == %d", PHAssetMediaType.image.rawValue)

        fetchResult = PHAsset.fetchAssets(with: fetchOptions)

        var fetchedAssets: [PHAsset] = []
        fetchResult?.enumerateObjects { asset, _, _ in
            fetchedAssets.append(asset)
        }

        DispatchQueue.main.async {
            self.assets = fetchedAssets
        }
    }

    func refreshAssets() {
        fetchAssets()
    }
}
